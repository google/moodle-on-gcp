#!/bin/sh
# Copyright 2026 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Declarative ConfigMap-driven Moodle core auto-upgrade reconciliation with
# double-checked atomic directory locking (.moodle-upgrade.lock) and O(1)
# same-mount staging swap (.moodle-version-state).

moodle_desired_state() {
  printf '%s|%s' "${MOODLE_URL:-}" "${MOODLE_SHA256:-}"
}

moodle_extract_url_version() {
  printf '%s\n' "${MOODLE_URL:-}" \
    | sed -n 's|.*/v\{0,1\}\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\)\.tar\.gz.*|\1|p' \
    | head -n 1
}

moodle_read_disk_version() {
  for ver_file in "$MOODLE_PATH/public/version.php" "$MOODLE_PATH/version.php"; do
    if [ -f "$ver_file" ]; then
      ver="$(sed -n "s/^[[:space:]]*\\\$release[[:space:]]*=[[:space:]]*['\"]\\([0-9][0-9]*\\.[0-9][0-9]*\\.[0-9][0-9]*\\).*/\\1/p" "$ver_file" | head -n 1)"
      if [ -n "$ver" ]; then
        printf '%s' "$ver"
        return 0
      fi
    fi
  done
  return 0
}

moodle_write_version_state() {
  state_file="$MOODLE_DATAROOT_PATH/.moodle-version-state"
  printf '%s\n' "$(moodle_desired_state)" > "$state_file"
  chown www:www "$state_file" 2>/dev/null || true
  chmod 0640 "$state_file" 2>/dev/null || true
}

moodle_get_installed_state() {
  state_file="$MOODLE_DATAROOT_PATH/.moodle-version-state"
  if [ -f "$state_file" ]; then
    head -n 1 "$state_file" | tr -d '\r\n'
    return 0
  fi
  # Bootstrap state marker for pre-existing deployments when version.php already matches MOODLE_URL.
  disk_ver="$(moodle_read_disk_version)"
  url_ver="$(moodle_extract_url_version)"
  if [ -n "$disk_ver" ] && [ -n "$url_ver" ] && [ "$disk_ver" = "$url_ver" ]; then
    moodle_write_version_state
    moodle_desired_state
    return 0
  fi
  printf 'legacy:%s' "${disk_ver:-unknown}"
}

moodle_clean_stale_lock() {
  lock_dir="$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock"
  max_age="${MOODLE_UPGRADE_LOCK_MAX_AGE:-900}"
  if [ -d "$lock_dir" ] && [ -f "$lock_dir/started_at" ]; then
    started_at="$(head -n 1 "$lock_dir/started_at" 2>/dev/null | tr -cd '0-9')"
    if [ -n "$started_at" ]; then
      now_ts="$(date +%s)"
      age=$((now_ts - started_at))
      if [ "$age" -gt "$max_age" ]; then
        echo "WARNING: Removing stale Moodle upgrade lock at $lock_dir (age ${age}s > ${max_age}s) ..."
        rm -rfv "$lock_dir"
      fi
    fi
  fi
}

moodle_wait_for_upgrade_lock() {
  lock_dir="$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock"
  poll_secs="${MOODLE_UPGRADE_LOCK_POLL_SECS:-5}"
  while [ -d "$lock_dir" ]; do
    moodle_clean_stale_lock
    [ -d "$lock_dir" ] || break
    echo "Another pod holds $lock_dir; waiting ${poll_secs}s for Moodle upgrade to finish ..."
    sleep "$poll_secs"
  done
}

moodle_patch_publicpaths() {
  target_moodle_dir="$1"
  publicpaths_dir="$target_moodle_dir/lib/classes/check/environment"
  if [ -d "$target_moodle_dir/public/lib/classes/check/environment" ]; then
    publicpaths_dir="$target_moodle_dir/public/lib/classes/check/environment"
  fi
  if [ -d "$publicpaths_dir" ] && [ ! -f "$publicpaths_dir/publicpaths.modified" ]; then
    echo "Adjusting publicpaths.php check to internal container on port 8080 ..."
    if [ -f "$publicpaths_dir/publicpaths.php" ]; then
      sed -i 's/\$CFG->wwwroot/"http:\/\/localhost:8080"/g' "$publicpaths_dir/publicpaths.php"
    fi
    touch "$publicpaths_dir/publicpaths.modified"
    chown www:www "$publicpaths_dir/publicpaths.php" "$publicpaths_dir/publicpaths.modified" 2>/dev/null || true
  fi
}

moodle_preserve_noncore_plugins() {
  old_root="$1"
  new_root="$2"
  plugin_rel_dirs="blocks mod local report admin/tool theme auth enrol filter availability/condition course/format question/type question/behaviour repository plagiarism lib/editor/tiny/plugins customfield/field ai/placement ai/provider payment/gateway"

  for prefix in "" "public/"; do
    for rel_dir in $plugin_rel_dirs; do
      src_parent="${old_root}/${prefix}${rel_dir}"
      [ -d "$src_parent" ] || continue
      for plugin_dir in "$src_parent"/*; do
        [ -d "$plugin_dir" ] || continue
        plugin_name="$(basename "$plugin_dir")"
        dst_parent="${new_root}/${prefix}${rel_dir}"
        # If upgrading from Moodle <= 5.0 (no public/) to Moodle 5.1+ (public/), place under public/ as well.
        if [ -z "$prefix" ] && [ -d "${new_root}/public/${rel_dir}" ] && [ ! -d "$dst_parent" ]; then
          dst_parent="${new_root}/public/${rel_dir}"
        fi
        if [ -d "$dst_parent" ] && [ ! -e "${dst_parent}/${plugin_name}" ]; then
          echo "Preserving non-core plugin ${prefix}${rel_dir}/${plugin_name} ..."
          cp -a "$plugin_dir" "${dst_parent}/${plugin_name}"
        fi
      done
    done
  done
}

moodle_swap_staged_tree() {
  stage_dir="$1"
  prev_dir="$MOODLE_PATH/.moodle-prev.$$"
  rm -rfv "$prev_dir"
  mkdir -p "$prev_dir"

  for entry in "$MOODLE_PATH"/* "$MOODLE_PATH"/.[!.]* "$MOODLE_PATH"/..?*; do
    [ -e "$entry" ] || [ -L "$entry" ] || continue
    base="$(basename "$entry")"
    case "$base" in
      .moodle-staging.*|.moodle-prev.*|config.php) continue ;;
    esac
    mv "$entry" "$prev_dir/$base"
  done

  if ! (
    for entry in "$stage_dir"/* "$stage_dir"/.[!.]* "$stage_dir"/..?*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      base="$(basename "$entry")"
      [ "$base" = "config.php" ] && continue
      mv "$entry" "$MOODLE_PATH/$base"
    done
    if [ -f "$stage_dir/config.php" ]; then
      mv -f "$stage_dir/config.php" "$MOODLE_PATH/config.php"
    fi
  ); then
    echo "ERROR: Staging swap failed; rolling back $MOODLE_PATH from $prev_dir ..." >&2
    for entry in "$prev_dir"/* "$prev_dir"/.[!.]* "$prev_dir"/..?*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      mv -f "$entry" "$MOODLE_PATH/$(basename "$entry")"
    done
    rm -rfv "$prev_dir"
    return 1
  fi

  rm -rfv "$stage_dir" "$prev_dir"
}

moodle_reconcile_autoupgrade() {
  # Always wait if a peer pod currently holds the upgrade lock (including upload pods).
  moodle_wait_for_upgrade_lock

  desired_state="$(moodle_desired_state)"
  installed_state="$(moodle_get_installed_state)"

  want_declarative="false"
  if [ "${MOODLE_AUTOUPGRADE:-false}" = "true" ] && [ -n "${MOODLE_URL:-}" ] && [ "$installed_state" != "$desired_state" ]; then
    want_declarative="true"
  fi
  want_dotfile="false"
  if [ -f "$MOODLE_DATAROOT_PATH/.moodle-autoupgrade" ]; then
    want_dotfile="true"
  fi

  if [ "$want_declarative" != "true" ] && [ "$want_dotfile" != "true" ]; then
    echo "Skipped auto update of Moodle (MOODLE_AUTOUPGRADE=${MOODLE_AUTOUPGRADE:-false}, version state up to date)."
    return 0
  fi

  lock_dir="$MOODLE_DATAROOT_PATH/.moodle-upgrade.lock"
  while true; do
    moodle_clean_stale_lock
    if mkdir "$lock_dir" 2>/dev/null; then
      date +%s > "$lock_dir/started_at"
      break
    fi
    moodle_wait_for_upgrade_lock
    installed_state="$(moodle_get_installed_state)"
    if { [ "${MOODLE_AUTOUPGRADE:-false}" != "true" ] || [ "$installed_state" = "$desired_state" ]; } \
       && [ ! -f "$MOODLE_DATAROOT_PATH/.moodle-autoupgrade" ]; then
      echo "Peer pod completed Moodle auto-upgrade; skipping duplicate upgrade."
      return 0
    fi
  done

  # Double-check state inside the lock in case a peer finished right before mkdir succeeded.
  installed_state="$(moodle_get_installed_state)"
  if { [ "${MOODLE_AUTOUPGRADE:-false}" != "true" ] || [ "$installed_state" = "$desired_state" ]; } \
     && [ ! -f "$MOODLE_DATAROOT_PATH/.moodle-autoupgrade" ]; then
    echo "Moodle version state already reconciled inside lock; releasing lock."
    rm -rfv "$lock_dir"
    return 0
  fi

  stage_dir="$MOODLE_PATH/.moodle-staging.$$"
  trap 'rm -rfv "$lock_dir" "$stage_dir" /tmp/moodle-upgrade.tar.gz' INT TERM

  if [ -n "${MOODLE_URL:-}" ] && [ "$installed_state" != "$desired_state" ]; then
    echo "Reconciling Moodle core from '$installed_state' to '$MOODLE_URL' ..."
    if ! curl --silent --location --fail "$MOODLE_URL" --output /tmp/moodle-upgrade.tar.gz; then
      echo "ERROR: Failed to download Moodle archive from '$MOODLE_URL'!" >&2
      rm -rfv /tmp/moodle-upgrade.tar.gz "$lock_dir"
      trap - INT TERM
      return 1
    fi
    if [ -n "${MOODLE_SHA256:-}" ]; then
      echo "Verifying upgraded MOODLE archive checksum ..."
      if ! echo "$MOODLE_SHA256  /tmp/moodle-upgrade.tar.gz" | sha256sum -c -; then
        echo "ERROR: Upgraded MOODLE checksum verification failed!" >&2
        rm -rfv /tmp/moodle-upgrade.tar.gz "$lock_dir"
        trap - INT TERM
        return 1
      fi
      echo "Upgraded MOODLE checksum verified."
    else
      echo "WARNING: MOODLE_SHA256 is not set. Skipping checksum verification."
    fi

    rm -rfv "$stage_dir"
    mkdir -p "$stage_dir"
    if ! tar -xzf /tmp/moodle-upgrade.tar.gz --strip-components=1 -C "$stage_dir"; then
      echo "ERROR: Failed to extract Moodle archive into '$stage_dir'!" >&2
      rm -rfv /tmp/moodle-upgrade.tar.gz "$stage_dir" "$lock_dir"
      trap - INT TERM
      return 1
    fi
    rm -fv /tmp/moodle-upgrade.tar.gz
    if [ ! -f "$stage_dir/version.php" ] && [ ! -f "$stage_dir/public/version.php" ]; then
      echo "ERROR: Extracted Moodle staging tree at '$stage_dir' has no version.php; aborting swap!" >&2
      rm -rfv "$stage_dir" "$lock_dir"
      trap - INT TERM
      return 1
    fi

    chown -R www:www "$stage_dir" 2>/dev/null || true
    if [ -f "$stage_dir/composer.json" ] && [ ! -f "$stage_dir/vendor/autoload.php" ]; then
      echo "Installing Moodle Composer dependencies in staging tree ..."
      if ! sudo -u www composer install --no-dev --classmap-authoritative --no-interaction --working-dir="$stage_dir"; then
        echo "ERROR: Composer install failed in staging tree '$stage_dir'!" >&2
        rm -rfv "$stage_dir" "$lock_dir"
        trap - INT TERM
        return 1
      fi
    fi

    moodle_preserve_noncore_plugins "$MOODLE_PATH" "$stage_dir"
    if [ -f "$MOODLE_PATH/config.php" ]; then
      cp -p "$MOODLE_PATH/config.php" "$stage_dir/config.php"
    fi
    moodle_patch_publicpaths "$stage_dir"

    find "$stage_dir" -type d -exec chmod 0755 {} +
    find "$stage_dir" -type f -exec chmod 0644 {} +
    if [ -f "$stage_dir/config.php" ]; then
      chmod 0444 "$stage_dir/config.php"
    fi
    chown -R www:www "$stage_dir" 2>/dev/null || true

    echo "Enabling Moodle maintenance mode and swapping staged core tree ..."
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/maintenance.php" --enable || true
    if ! moodle_swap_staged_tree "$stage_dir"; then
      sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/maintenance.php" --disable || true
      rm -rfv "$lock_dir"
      trap - INT TERM
      return 1
    fi
    if ! sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/upgrade.php" --non-interactive --allow-unstable; then
      echo "ERROR: Moodle CLI upgrade.php failed!" >&2
      rm -rfv "$lock_dir"
      trap - INT TERM
      return 1
    fi
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/build_theme_css.php" --themes=boost || true
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/maintenance.php" --disable
    moodle_write_version_state
    echo "Moodle core successfully upgraded and recorded in .moodle-version-state."
  else
    echo "Running one-shot .moodle-autoupgrade database/plugin upgrade ..."
    if [ -f "$MOODLE_PATH/composer.json" ] && [ ! -f "$MOODLE_PATH/vendor/autoload.php" ]; then
      if ! sudo -u www composer install --no-dev --classmap-authoritative --no-interaction --working-dir="$MOODLE_PATH"; then
        rm -rfv "$lock_dir"
        trap - INT TERM
        return 1
      fi
    fi
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/maintenance.php" --enable
    if ! sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/upgrade.php" --non-interactive --allow-unstable; then
      rm -rfv "$lock_dir"
      trap - INT TERM
      return 1
    fi
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/maintenance.php" --disable
  fi

  if [ -f "$MOODLE_DATAROOT_PATH/.moodle-autoupgrade" ]; then
    rm -fv "$MOODLE_DATAROOT_PATH/.moodle-autoupgrade"
  fi
  rm -rfv "$lock_dir"
  trap - INT TERM
}
