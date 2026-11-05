#!/bin/sh
#
## Copyright 2022 Google LLC
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     https://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

setupPath() {
  echo "Checking if $1 exists ..."
  if [ ! -d "$1" ] ; then
    echo "Does not, creating $1 and adjusting owner and permissions ..."
    mkdir -p "$1"
    chown -R "$2:$3" "$1"
    echo -e "Done with setting up $1 ...\n"
  else
    echo "Yes! All set with $1 ..."
  fi
}

###
# Usage: setupPath /some/path user group
##

# moodle temp path
setupPath /tmp/moodle www www
setupPath /tmp/moodle/localcache www www

# nginx temp paths
setupPath /tmp/nginx www root
setupPath /tmp/nginx/client_temp www root
setupPath /tmp/nginx/proxy_temp www root
setupPath /tmp/nginx/fastcgi_temp www root
setupPath /tmp/nginx/uwsgi_temp www root
setupPath /tmp/nginx/scgi_temp www root

setupPath /etc/nginx root root
setupPath /etc/php83 root root

setupPath "$MOODLE_ROOT_PATH" www www
setupPath "$MOODLE_PATH" www www
setupPath "$MOODLE_DATAROOT_PATH" www www
setupPath "$MOODLE_DATAROOT_PATH/log" www www
setupPath "$MOODLE_DATAROOT_PATH/moosh" www www

echo "Checking if NGINX config files exists in nfs ..."
if [ ! -f "/etc/nginx/nginx.conf" ] ; then
  echo "NGINX config files not present..ensuring they are now..."
  sudo -u root cp -R /root/etc/nginx/* /etc/nginx/
  echo "Done ensuring NGINX config files are present.."
fi
echo "Done checking if NGINX config files exists in nfs ..."

echo "Checking if PHP8.3 config files exists in nfs ..."
if [ ! -f "/etc/php83/php-fpm.conf" ] ; then
  echo "PHP8.3 config files not present..ensuring they are now..."
  sudo -u root cp -R /root/etc/php83/* /etc/php83/
  echo "Done ensuring PHP8.3 config files are present.."
fi
echo "Done checking if PHP8.3 config files exists in nfs ..."

echo "Cleaning root's temp files ..."
rm -rvf /root/etc

# run envsubst
if [ -f "/etc/nginx/nginx.conf-template" ]; then
  envsubst '$MOODLE_ROOT_PATH' < /etc/nginx/nginx.conf-template > /etc/nginx/nginx.conf
  rm -rvf /etc/nginx/nginx.conf-template
fi

if [ -f "/etc/php83/php.ini-template" ]; then
  envsubst '$MOODLE_ROOT_PATH' < /etc/php83/php.ini-template > /etc/php83/php.ini
  rm -rvf /etc/php83/php.ini-template
fi

# Dynamic PHP and NGINX overrides for specialized deployments (e.g., upload pods)
EFFECTIVE_UPLOAD_MAX_FILESIZE="${PHP_UPLOAD_MAX_FILESIZE:-$UPLOAD_MAX_FILESIZE}"
EFFECTIVE_POST_MAX_SIZE="${PHP_POST_MAX_SIZE:-$POST_MAX_SIZE}"
EFFECTIVE_CLIENT_MAX_BODY_SIZE="${NGINX_CLIENT_MAX_BODY_SIZE:-$CLIENT_MAX_BODY_SIZE}"

if [ -n "$PHP_MEMORY_LIMIT" ]; then
  echo "Adjusting PHP memory_limit to $PHP_MEMORY_LIMIT..."
  sed -i "s/^memory_limit = .*/memory_limit = $PHP_MEMORY_LIMIT/" /etc/php83/php.ini
fi

if [ -n "$EFFECTIVE_UPLOAD_MAX_FILESIZE" ]; then
  echo "Adjusting PHP upload_max_filesize to $EFFECTIVE_UPLOAD_MAX_FILESIZE..."
  sed -i "s/^upload_max_filesize = .*/upload_max_filesize = $EFFECTIVE_UPLOAD_MAX_FILESIZE/" /etc/php83/php.ini
fi

if [ -n "$EFFECTIVE_POST_MAX_SIZE" ]; then
  echo "Adjusting PHP post_max_size to $EFFECTIVE_POST_MAX_SIZE..."
  sed -i "s/^post_max_size = .*/post_max_size = $EFFECTIVE_POST_MAX_SIZE/" /etc/php83/php.ini
fi

if [ -n "$PHP_MAX_EXECUTION_TIME" ]; then
  echo "Adjusting PHP max_execution_time to $PHP_MAX_EXECUTION_TIME..."
  sed -i "s/^max_execution_time = .*/max_execution_time = $PHP_MAX_EXECUTION_TIME/" /etc/php83/php.ini
  sed -i "s/^request_terminate_timeout = .*/request_terminate_timeout = $PHP_MAX_EXECUTION_TIME/" /etc/php83/php-fpm.d/moodle.conf
fi

if [ -n "$PHP_MAX_INPUT_TIME" ]; then
  echo "Adjusting PHP max_input_time to $PHP_MAX_INPUT_TIME..."
  sed -i "s/^max_input_time = .*/max_input_time = $PHP_MAX_INPUT_TIME/" /etc/php83/php.ini
fi

if [ -n "$EFFECTIVE_CLIENT_MAX_BODY_SIZE" ]; then
  echo "Adjusting NGINX client_max_body_size to $EFFECTIVE_CLIENT_MAX_BODY_SIZE..."
  sed -i "s/^[[:space:]#]*client_max_body_size .*/    client_max_body_size $EFFECTIVE_CLIENT_MAX_BODY_SIZE;/" /etc/nginx/nginx.conf
fi

echo "Checking if Moodle is already setup ..."
if [ ! -f "$MOODLE_DATAROOT_PATH/.moodle-installed" ] ; then

  if [ ! -f "$MOODLE_PATH/config.php" ] ; then
    echo -e "Nope, not installed, so, I am setting up Moodle from MOODLE_URL ENV VAR:\n"
    echo -e "$MOODLE_URL ...\n"
    echo "Hang tight, this will take a while !"

    echo "Downloading and extracting MOODLE files ..."
    curl --silent --location "$MOODLE_URL" | tar -xz --totals=USR1 --strip-components=1 -C "$MOODLE_PATH/"
    echo -e "Done downloading and extracting MOODLE files ...\n"

    echo "Setting proper ownership on moodle root and data directories ..."
    chown -R www:www "$MOODLE_PATH" && chown -R www:www "$MOODLE_DATAROOT_PATH"

    if [ -f "$MOODLE_PATH/composer.json" ] && [ ! -f "$MOODLE_PATH/vendor/autoload.php" ]; then
      echo "Installing Moodle Composer dependencies (required for Moodle 5.1+) ..."
      sudo -u www composer install --no-dev --classmap-authoritative --no-interaction --working-dir="$MOODLE_PATH"
      echo "Done installing Moodle Composer dependencies ..."
    fi

    echo "Setting permissions on moodle and moodledata directories ..."
    find "$MOODLE_PATH" -type d -exec chmod 0775 {} \;
    find "$MOODLE_DATAROOT_PATH" -type d -exec chmod 0775 {} \;
    echo "Setting permissions on files in moodle and moodledata directories ..."
    find "$MOODLE_PATH" -type f -exec chmod 0664 {} \;
    find "$MOODLE_DATAROOT_PATH" -type f -exec chmod 0664 {} \;

    echo "Generating config.php file ..."
    sudo -u www php83 -d max_input_vars=10000 \
      "$MOODLE_PATH/admin/cli/install.php" \
      --lang="$MOODLE_LANGUAGE" \
      --wwwroot="$SITE_URL" \
      --dataroot="$MOODLE_DATAROOT_PATH" \
      --dbtype="$DB_TYPE" \
      --dbhost="$DB_HOST" \
      --dbport="$DB_HOST_PORT" \
      --dbname="$DB_NAME" \
      --dbuser="$DB_USER" \
      --dbpass="$DB_PASS" \
      --prefix="$DB_PREFIX" \
      --fullname="$MOODLE_SITENAME" \
      --shortname="$MOODLE_SITENAME" \
      --summary="$MOODLE_SITESUMMARY" \
      --adminuser="$MOODLE_USERNAME" \
      --adminpass="$MOODLE_PASSWORD" \
      --adminemail="$MOODLE_EMAIL" \
      --non-interactive \
      --agree-license \
      --skip-database \
      --allow-unstable
    echo "Done generating config.php file ..."

    echo "Installing database ..."
    sudo -u www php83 -d max_input_vars=10000 \
      "$MOODLE_PATH/admin/cli/install_database.php" \
      --lang="$MOODLE_LANGUAGE" \
      --fullname="$MOODLE_SITENAME" \
      --shortname="$MOODLE_SITENAME" \
      --summary="$MOODLE_SITESUMMARY" \
      --adminuser="$MOODLE_USERNAME" \
      --adminpass="$MOODLE_PASSWORD" \
      --adminemail="$MOODLE_EMAIL" \
      --agree-license
    echo "Done installing database ..."

    echo "Adding read replica settings if needed ..."
    if [ -n "$DB_READ_REPLICA_HOST" ]; then
      if [ -n "$DB_READ_REPLICA_USER" ] && [ -n "$DB_READ_REPLICA_PASSWORD" ] && [ -n "$DB_READ_REPLICA_PORT" ]; then
        sed -i "/\$CFG->dboptions/a \ \ "\''readonly'\'" => [ \'instance\' => [ \'dbhost\' => \'$DB_READ_REPLICA_HOST\', \'dbport\' => \'$DB_READ_REPLICA_PORT\', \'dbuser\' => \'$DB_READ_REPLICA_USER\', \'dbpass\' => \'$DB_READ_REPLICA_PASSWORD\' ] ]," "$MOODLE_PATH/config.php"
      else
        sed -i "/\$CFG->dboptions/a \ \ "\''readonly'\'" => [ \'instance\' => [ \'$DB_READ_REPLICA_HOST\' ] ]," "$MOODLE_PATH/config.php"
      fi
    fi

    echo "Setting ssl proxy setting ..."
    if [ "$SSLPROXY" = 'true' ]; then
      sed -i '/require_once/i $CFG->sslproxy = true;' "$MOODLE_PATH/config.php"
    fi

    echo "Setting no email ever if true ..."
    if [ "$NOEMAIL_EVER" = 'true' ]; then
      sed -i '/require_once/i $CFG->noemailever = true;' "$MOODLE_PATH/config.php"
    fi

    echo "Prevent executable paths to be set via Admin GUI ..."
    sed -i '/require_once/i $CFG->preventexecpath = true;' "$MOODLE_PATH/config.php"

    echo "Forcing clam av executable path in config.php file ..."
    sed -i '/require_once/i $CFG->forced_plugin_settings = array("antivirus_clamav" => array("pathtoclam" => "/usr/bin/clamscan"));' "$MOODLE_PATH/config.php"

    echo "Configuring other specific settings ..."

    # moodle binaries
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=pathtophp --set=/usr/bin/php83
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=pathtodu --set=/usr/bin/du
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=aspellpath --set=/usr/bin/aspell
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=pathtodot --set=/usr/bin/dot
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=pathtogs --set=/usr/bin/gs
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=pathtopython --set=/usr/bin/python3
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=enableblogs --set=0

    # moodle smtp settings
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=smtphosts --set="$SMTP_HOST:$SMTP_PORT"
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=smtpuser --set="$SMTP_USER"
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=smtppass --set="$SMTP_PASSWORD"
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=smtpsecure --set="$SMTP_PROTOCOL"
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=noreplyaddress --set="$MOODLE_MAIL_NOREPLY_ADDRESS"
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/cfg.php" --name=emailsubjectprefix --set="$MOODLE_MAIL_PREFIX"

    sudo -u www cp "$MOODLE_PATH/config.php" "$MOODLE_PATH/config.php.bak"
    envsubst '$REDIS_LOCK_HOST_AND_PORT $REDIS_LOCK_AUTH_STRING $REDIS_SESSION_ID_HOST $REDIS_SESSION_ID_PORT $REDIS_SESSION_ID_AUTH_STRING' < "/root/.templates/config.php.template" \
      | { head -n 23 "$MOODLE_PATH/config.php.bak"; cat /dev/stdin; tail -n +24 "$MOODLE_PATH/config.php.bak"; } > "$MOODLE_PATH/config.php"
  fi

  # Avoid writing the config file
  echo "Protecting config.php file ..."
  chmod 0444 "$MOODLE_PATH/config.php"

  echo "Obtaining latest and initial clamav virus databases ..."
  /usr/bin/freshclam
  echo "Done obtaining latest and initial clamav virus databases ..."

  # Fix publicpaths check to point to the internal container on port 8080
  PUBLICPATHS_DIR="$MOODLE_PATH/lib/classes/check/environment"
  if [ -d "$MOODLE_PATH/public/lib/classes/check/environment" ]; then
    PUBLICPATHS_DIR="$MOODLE_PATH/public/lib/classes/check/environment"
  fi
  if [ -d "$PUBLICPATHS_DIR" ] && [ ! -f "$PUBLICPATHS_DIR/publicpaths.modified" ] ; then
    echo "Marking publicpaths.php check ..."
    sudo -u www touch "$PUBLICPATHS_DIR/publicpaths.modified"
  fi

  # precompile css cache for this pod
  echo "Precompiling boost's css theme ..."
  sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/build_theme_css.php" --themes=boost

  # persist setup
  sudo -u www touch "$MOODLE_DATAROOT_PATH/.moodle-installed"
  echo -e "Done with setting up Moodle ...\n"

else

  echo "Yes! All set Moodle setup ..."

  if [ -f "$MOODLE_DATAROOT_PATH/.moodle-autoupgrade" ]; then
    echo "Upgrading moodle..."
    if [ -f "$MOODLE_PATH/composer.json" ] && [ ! -f "$MOODLE_PATH/vendor/autoload.php" ]; then
      sudo -u www composer install --no-dev --classmap-authoritative --no-interaction --working-dir="$MOODLE_PATH"
    fi
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/maintenance.php" --enable
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/upgrade.php" --non-interactive --allow-unstable
    sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/maintenance.php" --disable
  else
    echo "Skipped auto update of Moodle"
  fi
fi

# Moodle 5.1+ serves web-accessible files from $MOODLE_PATH/public (MDL-83424).
# Automatically point NGINX root to $MOODLE_PATH/public when present, while
# maintaining backward compatibility with Moodle <= 5.0 ($MOODLE_PATH).
if [ -d "$MOODLE_PATH/public" ] && [ -f "/etc/nginx/nginx.conf" ]; then
  sed -i "s|root ${MOODLE_ROOT_PATH}/moodle;|root ${MOODLE_ROOT_PATH}/moodle/public;|g" /etc/nginx/nginx.conf
fi

echo "Adding cron entries for Moodle's cron and AdHoc Tasks ..."
echo "*/1 * * * * /usr/bin/sudo -u www /usr/bin/php83 $MOODLE_PATH/admin/cli/cron.php >> $MOODLE_DATAROOT_PATH/log/moodle_cron.log 2>&1" > /var/spool/cron/crontabs/root
echo "*/1 * * * * /usr/bin/sudo -u www /usr/bin/php83 $MOODLE_PATH/admin/cli/adhoc_task.php --execute >> $MOODLE_DATAROOT_PATH/log/moodle_task.log 2>&1" >> /var/spool/cron/crontabs/root
echo "0 0 * * * /usr/bin/freshclam >> $MOODLE_DATAROOT_PATH/log/freshclam.log 2>&1" >> /var/spool/cron/crontabs/root

## Testing for Moosh setup
filename="$MOODLE_DATAROOT_PATH/moosh/.installed"
echo "Checking if Moosh is already setup ..."
if [ ! -f "$filename" ] ; then
    echo "Downloading and extracting Moosh ..."
    curl --silent --location "$MOOSH_URL" | tar -xz --totals=USR1 --strip-components=1 -C "$MOODLE_DATAROOT_PATH/moosh"
    chown -R www:www "$MOODLE_DATAROOT_PATH/moosh"
    cd "$MOODLE_DATAROOT_PATH/moosh" && composer --quiet --no-interaction --no-cache update && cd /
    sudo -u www sed -i 's/\$arg, \$v);/\$arg, \$v \? \$v \: \"\");/g' "$MOODLE_DATAROOT_PATH/moosh/Moosh/MooshCommand.php" 2>/dev/null || true
    touch "$filename"
    echo -e "Done downloading and setting up Moosh ...\n"
else
  echo "Moosh is already setup, skipping ..."
fi

# create symlink for moosh within the image itself
ln -sf "$MOODLE_DATAROOT_PATH/moosh/moosh.php" /bin/moosh

## Check for plugins and update its available list
echo "Updating Moosh plugins list for www user ..."
sudo -u www moosh --moodle-path="$MOODLE_PATH" plugin-list > /dev/null 2>&1
echo "Done updating Moosh plugins list for www user ..."

## Testing for report_benchmark plugin setup
filename="$MOODLE_DATAROOT_PATH/moosh/.plugin-report-benchmark-installed"
if [ ! -f "$filename" ]; then
  echo "Installing the plugin report_benchmark via Moosh ..."
  sudo -u www moosh --moodle-path="$MOODLE_PATH" plugin-install -f -d report_benchmark
  touch "$filename"
  echo "Done installing the plugin report_benchmark via Moosh ..."
fi

## Testing for tool_opcache plugin setup
filename="$MOODLE_DATAROOT_PATH/moosh/.plugin-tool_opcache-installed"
if [ ! -f "$filename" ]; then
  echo "Installing the plugin tool_opcache via Moosh ..."
  sudo -u www moosh --moodle-path="$MOODLE_PATH" plugin-install -f -d tool_opcache
  touch "$filename"
  echo "Done installing the plugin tool_opcache via Moosh ..."
fi

## Install local_redislock when Redis locking is configured (addresses Issue #13)
if [ -n "$REDIS_LOCK_HOST_AND_PORT" ]; then
  filename="$MOODLE_DATAROOT_PATH/moosh/.plugin-local_redislock-installed"
  if [ ! -f "$filename" ]; then
    echo "Installing the plugin local_redislock (Issue #13) ..."
    sudo -u www moosh --moodle-path="$MOODLE_PATH" plugin-install -f -d local_redislock || true
    if [ ! -f "$MOODLE_PATH/local/redislock/version.php" ] && [ ! -f "$MOODLE_PATH/public/local/redislock/version.php" ]; then
      echo "Downloading local_redislock directly from GitHub (open-lms-open-source/moodle-local_redislock) ..."
      REDISLOCK_URL="${REDISLOCK_PLUGIN_URL:-https://github.com/open-lms-open-source/moodle-local_redislock/archive/refs/heads/master.tar.gz}"
      mkdir -p "$MOODLE_PATH/local/redislock"
      if curl --silent --location --fail "$REDISLOCK_URL" | tar -xz --strip-components=1 -C "$MOODLE_PATH/local/redislock"; then
        chown -R www:www "$MOODLE_PATH/local/redislock"
        if [ -d "$MOODLE_PATH/public/local" ] && [ ! -e "$MOODLE_PATH/public/local/redislock" ]; then
          ln -s "$MOODLE_PATH/local/redislock" "$MOODLE_PATH/public/local/redislock"
          chown -h www:www "$MOODLE_PATH/public/local/redislock"
        fi
        sudo -u www php83 -d max_input_vars=10000 "$MOODLE_PATH/admin/cli/upgrade.php" --non-interactive --allow-unstable || true
      fi
    fi
    touch "$filename"
    echo "Done installing the plugin local_redislock ..."
  fi
fi

# Sets Redis Session cache mapping in Moodle via Moosh
cache_adjusted=""
filename="$MOODLE_DATAROOT_PATH/moosh/.redis-session-mapping-done"
if [ ! -f "$filename" ] && [ -n "$REDIS_SESSION_IP_AND_PORT" ]; then
  echo "Adding cache redis-store for Session Cache via Moosh ..."
  sudo -u www moosh --moodle-path="$MOODLE_PATH" cache-add-redis-store \
    --password "$REDIS_SESSION_AUTH_STRING" \
    --key-prefix "store_session_1_" \
    "Session" \
    "$REDIS_SESSION_IP_AND_PORT"

  cache_adjusted="true"
  touch "$filename"
  echo "Done adding cache redis-store for Session Cache via Moosh ..."
fi

# Sets Redis Application cache mapping in Moodle via Moosh
filename="$MOODLE_DATAROOT_PATH/moosh/.redis-app-mapping-done"
if [ ! -f "$filename" ] && [ -n "$REDIS_APP_IP_AND_PORT" ]; then
  echo "Adding cache redis-store for Application Cache via Moosh ..."
  sudo -u www moosh --moodle-path "$MOODLE_PATH" cache-add-redis-store \
    --password "$REDIS_APP_AUTH_STRING" \
    --key-prefix "store_app_1_" \
    "Application" \
    "$REDIS_APP_IP_AND_PORT"

  cache_adjusted="true"
  touch "$filename"
  echo "Done adding cache redis-store for Application Cache via Moosh ..."
fi

if [ -n "$cache_adjusted" ]; then
  echo "Editing mappings in Cache plugin for both Application and Session "
  echo "and mapping them to the appropriate Redis's store ..."
  sudo -u www moosh --moodle-path "$MOODLE_PATH" cache-clear
  sudo -u www moosh --moodle-path "$MOODLE_PATH" cache-edit-mappings \
    --application "Application" \
    --session "Session"
fi

echo "All steps are done properly now! Moodle is properly installed ..."
