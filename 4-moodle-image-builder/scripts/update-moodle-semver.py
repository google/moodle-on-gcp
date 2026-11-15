#!/usr/bin/env python3
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
"""SemVer monitor and updater for Moodle release tags (v5.x.x -> v5.y.z)."""

import argparse
import hashlib
import json
import os
import pathlib
import re
import sys
import urllib.request

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CONFIGMAP_SAMPLE = REPO_ROOT / "5a-deployment-no-helm/moodle-configmap-nginx.yaml"
SEMVER_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")

TARGET_FILES = [
    "5a-deployment-no-helm/moodle-configmap-nginx.yaml",
    "5a-deployment-no-helm/moodle-configmap-nginx-sample.yaml",
    "5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml",
    "5a-deployment-no-helm/deployment-templates/moodle-configmap-nginx-template.yaml",
    "5a-deployment-no-helm/deployment-templates/moodle-configmap-nginx-uploads-template.yaml",
    "AGENTS.md",
    "docs/repository-organization.md",
]


def get_current_version() -> tuple[int, int, int]:
    content = CONFIGMAP_SAMPLE.read_text(encoding="utf-8")
    match = re.search(
        r"https://github\.com/moodle/moodle/archive/refs/tags/v(\d+)\.(\d+)\.(\d+)\.tar\.gz",
        content,
    )
    if not match:
        raise RuntimeError(f"Could not detect current Moodle version in {CONFIGMAP_SAMPLE}")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def fetch_moodle_tags() -> list[tuple[int, int, int]]:
    req_headers = {"Accept": "application/vnd.github+json", "User-Agent": "moodle-on-gcp-semver-updater"}
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if token:
        req_headers["Authorization"] = f"Bearer {token}"
    versions: list[tuple[int, int, int]] = []
    for page in (1, 2):
        url = f"https://api.github.com/repos/moodle/moodle/tags?per_page=100&page={page}"
        req = urllib.request.Request(url, headers=req_headers)
        with urllib.request.urlopen(req, timeout=30) as resp:
            items = json.loads(resp.read().decode("utf-8"))
        if not items:
            break
        for item in items:
            m = SEMVER_RE.match(item.get("name", ""))
            if m:
                versions.append((int(m.group(1)), int(m.group(2)), int(m.group(3))))
    return sorted(set(versions))


def select_target_version(
    current: tuple[int, int, int],
    candidates: list[tuple[int, int, int]],
    scope: str,
    series: str,
) -> tuple[int, int, int]:
    cur_maj, cur_min, _ = current
    filtered: list[tuple[int, int, int]] = []
    if series:
        parts = [int(x) for x in series.lstrip("v").split(".")]
        if len(parts) == 2:
            filtered = [v for v in candidates if v[0] == parts[0] and v[1] == parts[1]]
        elif len(parts) == 3:
            filtered = [v for v in candidates if v == (parts[0], parts[1], parts[2])]
        else:
            raise ValueError(f"Invalid --series '{series}'; expected 'X.Y' or 'X.Y.Z'.")
    elif scope == "patch":
        filtered = [v for v in candidates if v[0] == cur_maj and v[1] == cur_min and v >= current]
    elif scope == "minor":
        filtered = [v for v in candidates if v[0] == cur_maj and v >= current]
    elif scope == "major":
        filtered = [v for v in candidates if v >= current]
    else:
        raise ValueError(f"Unsupported scope: {scope}")
    return max(filtered) if filtered else current


def compute_tarball_sha256(ver_str: str) -> str:
    url = f"https://github.com/moodle/moodle/archive/refs/tags/v{ver_str}.tar.gz"
    req = urllib.request.Request(url, headers={"User-Agent": "moodle-on-gcp-semver-updater"})
    digest = hashlib.sha256()
    with urllib.request.urlopen(req, timeout=120) as resp:
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def apply_version_update(old_ver: str, new_ver: str, sha256_hex: str) -> list[str]:
    modified: list[str] = []
    for rel_path in TARGET_FILES:
        path = REPO_ROOT / rel_path
        if not path.exists():
            continue
        original = path.read_text(encoding="utf-8")
        updated = original.replace(
            f"https://github.com/moodle/moodle/archive/refs/tags/v{old_ver}.tar.gz",
            f"https://github.com/moodle/moodle/archive/refs/tags/v{new_ver}.tar.gz",
        )
        updated = updated.replace(f"Moodle {old_ver} On GKE", f"Moodle {new_ver} On GKE")
        updated = updated.replace(f"v{old_ver}", f"v{new_ver}")
        updated = updated.replace(f"deploy the {old_ver} version", f"deploy the {new_ver} version")
        if sha256_hex and "MOODLE_SHA256:" in updated:
            updated = re.sub(
                r"(MOODLE_SHA256:\s*)'[^']*'",
                rf"\g<1>'{sha256_hex}'",
                updated,
            )
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            modified.append(rel_path)
    return modified


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--scope",
        choices=["patch", "minor", "major"],
        default=os.environ.get("SEMVER_SCOPE", "patch") or "patch",
        help="SemVer update scope: patch (5.2.x), minor (5.y.z), or major (X.Y.Z).",
    )
    parser.add_argument(
        "--series",
        default=os.environ.get("CUSTOM_SERIES", ""),
        help="Optional explicit target series (e.g. '5.3' or '5.2.5').",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Check current version and validate logic without fetching remote tags or writing files.",
    )
    args = parser.parse_args()

    current = get_current_version()
    cur_str = f"{current[0]}.{current[1]}.{current[2]}"
    if args.dry_run:
        sample_candidates = [current, (current[0], current[1], current[2] + 1), (current[0], current[1] + 1, 0)]
        chosen_patch = select_target_version(current, sample_candidates, "patch", "")
        chosen_minor = select_target_version(current, sample_candidates, "minor", "")
        assert chosen_patch == (current[0], current[1], current[2] + 1)
        assert chosen_minor == (current[0], current[1] + 1, 0)
        print(f"DRY-RUN OK: current=v{cur_str}, simulated patch=v{'.'.join(map(str, chosen_patch))}, minor=v{'.'.join(map(str, chosen_minor))}")
        return 0

    candidates = fetch_moodle_tags()
    target = select_target_version(current, candidates, args.scope, args.series.strip())
    target_str = f"{target[0]}.{target[1]}.{target[2]}"

    if target == current:
        print(f"Moodle is already at the latest matching version (v{cur_str}) for scope='{args.scope}' series='{args.series}'.")
        return 0

    print(f"Updating Moodle from v{cur_str} to v{target_str}...")
    sha256_hex = compute_tarball_sha256(target_str)
    modified = apply_version_update(cur_str, target_str, sha256_hex)
    print(f"Updated {len(modified)} files with v{target_str} (SHA-256: {sha256_hex}): {modified}")

    github_output = os.environ.get("GITHUB_OUTPUT")
    if github_output:
        with open(github_output, "a", encoding="utf-8") as fh:
            fh.write(f"updated=true\nold_version=v{cur_str}\nnew_version=v{target_str}\nsha256={sha256_hex}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
