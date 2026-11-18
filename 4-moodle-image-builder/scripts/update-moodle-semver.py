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
"""Coordinated updater for Moodle release tags (SemVer) and the Alpine base image.

The script applies both updates to the working tree together so that the
`Moodle SemVer Auto-Updater` workflow opens a single pull request for them:

1. Moodle: selects the newest `moodle/moodle` tag allowed by the SemVer policy
   (`patch`, `minor`, `major`, or an explicit series), downloads the release
   tarball, computes its SHA-256 digest, and rewrites `MOODLE_URL`,
   `MOODLE_SHA256`, and `MOODLE_SITENAME` in every ConfigMap manifest/template.
2. Alpine: selects the newest supported (non-EOL) Alpine release branch whose
   `main` and `community` repositories still provide every package installed
   by `Dockerfile.nginx` and `scripts/build-gnu-libiconv.sh` (for example all
   `php83-*` extensions), and rewrites the `FROM alpine:X.Y` lines. Branches
   that dropped a required package are skipped instead of breaking the image.
"""

import argparse
import datetime
import hashlib
import io
import json
import os
import pathlib
import re
import sys
import tarfile
import urllib.error
import urllib.request
import uuid
from typing import Callable

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
CONFIGMAP_SAMPLE = REPO_ROOT / "5a-deployment-no-helm/moodle-configmap-nginx.yaml"
DOCKERFILE = REPO_ROOT / "4-moodle-image-builder/Dockerfile.nginx"
APK_SOURCES = [
    DOCKERFILE,
    REPO_ROOT / "4-moodle-image-builder/scripts/build-gnu-libiconv.sh",
]
USER_AGENT = "moodle-on-gcp-semver-updater"

SEMVER_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
ALPINE_FROM_RE = re.compile(r"^(\s*FROM\s+alpine:)(\d+)\.(\d+)(?=[\s@]|$)", re.MULTILINE | re.IGNORECASE)
APK_ADD_RE = re.compile(r"\bapk\s+add\b([^;&|\n]*)")
ALPINE_RELEASES_URL = "https://alpinelinux.org/releases.json"
ALPINE_MIRROR = "https://dl-cdn.alpinelinux.org/alpine"
ALPINE_REPOSITORIES = ("main", "community")
ALPINE_ARCH = "x86_64"
# Packages whose resolved versions are reported in the pull request body.
ALPINE_REPORTED_PACKAGES = ("php83", "nginx", "gnu-libiconv-libs")

MOODLE_TARGET_FILES = [
    "5a-deployment-no-helm/moodle-configmap-nginx.yaml",
    "5a-deployment-no-helm/moodle-configmap-nginx-sample.yaml",
    "5a-deployment-no-helm/moodle-configmap-nginx-uploads.yaml",
    "5a-deployment-no-helm/deployment-templates/moodle-configmap-nginx-template.yaml",
    "5a-deployment-no-helm/deployment-templates/moodle-configmap-nginx-uploads-template.yaml",
    "AGENTS.md",
    "docs/repository-organization.md",
]
# Documentation that states the Alpine release of the image (OpenWiki pages are
# refreshed by OpenWiki runs, and `.jules/sentinel.md` is an append-only journal).
ALPINE_DOC_FILES = ["AGENTS.md"]

Version = tuple[int, int, int]
AlpineVersion = tuple[int, int]
IndexLoader = Callable[[str, str], dict[str, str]]


def http_get(url: str, timeout: int = 60, headers: dict[str, str] | None = None) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def warn(message: str) -> None:
    """Print a warning that GitHub Actions also renders as an annotation."""
    print(f"::warning::{message}")


# ---------------------------------------------------------------------------
# Moodle (SemVer tags)
# ---------------------------------------------------------------------------
def get_current_version() -> Version:
    content = CONFIGMAP_SAMPLE.read_text(encoding="utf-8")
    match = re.search(
        r"https://github\.com/moodle/moodle/archive/refs/tags/v(\d+)\.(\d+)\.(\d+)\.tar\.gz",
        content,
    )
    if not match:
        raise RuntimeError(f"Could not detect current Moodle version in {CONFIGMAP_SAMPLE}")
    return int(match.group(1)), int(match.group(2)), int(match.group(3))


def fetch_moodle_tags() -> list[Version]:
    req_headers = {"Accept": "application/vnd.github+json"}
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if token:
        req_headers["Authorization"] = f"Bearer {token}"
    versions: list[Version] = []
    for page in (1, 2):
        url = f"https://api.github.com/repos/moodle/moodle/tags?per_page=100&page={page}"
        items = json.loads(http_get(url, timeout=30, headers=req_headers).decode("utf-8"))
        if not items:
            break
        for item in items:
            m = SEMVER_RE.match(item.get("name", ""))
            if m:
                versions.append((int(m.group(1)), int(m.group(2)), int(m.group(3))))
    return sorted(set(versions))


def select_target_version(current: Version, candidates: list[Version], scope: str, series: str) -> Version:
    cur_maj, cur_min, _ = current
    filtered: list[Version] = []
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
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    digest = hashlib.sha256()
    with urllib.request.urlopen(req, timeout=120) as resp:
        while True:
            chunk = resp.read(65536)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def apply_moodle_update(old_ver: str, new_ver: str, sha256_hex: str) -> list[str]:
    modified: list[str] = []
    for rel_path in MOODLE_TARGET_FILES:
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
            updated = re.sub(r"(MOODLE_SHA256:\s*)'[^']*'", rf"\g<1>'{sha256_hex}'", updated)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            modified.append(rel_path)
    return modified


# ---------------------------------------------------------------------------
# Alpine base image (compatibility-gated)
# ---------------------------------------------------------------------------
def get_current_alpine(dockerfile_text: str) -> AlpineVersion:
    versions = {(int(m.group(2)), int(m.group(3))) for m in ALPINE_FROM_RE.finditer(dockerfile_text)}
    if not versions:
        raise RuntimeError(f"No 'FROM alpine:X.Y' line found in {DOCKERFILE}")
    if len(versions) > 1:
        raise RuntimeError(f"Mixed Alpine base images in {DOCKERFILE}: {sorted(versions)}; align them first.")
    return versions.pop()


def parse_apk_packages(text: str) -> set[str]:
    """Return the package names installed by every `apk add` command in a Dockerfile or shell script."""
    text = re.sub(r"(?m)^\s*#.*$", "", text)  # ignore comment lines that merely mention `apk add`
    joined = re.sub(r"\\\r?\n", " ", text)  # join shell line continuations
    packages: set[str] = set()
    for match in APK_ADD_RE.finditer(joined):
        skip_next = False
        for token in match.group(1).split():
            if skip_next:
                skip_next = False
                continue
            if token in ("--virtual", "-t", "--repository", "-X"):
                skip_next = True
                continue
            if token.startswith("-") or token.startswith("#") or "$" in token:
                continue
            name = re.split(r"[<>=~]", token, maxsplit=1)[0]
            if name:
                packages.add(name)
    return packages


def collect_required_packages() -> set[str]:
    packages: set[str] = set()
    for path in APK_SOURCES:
        packages |= parse_apk_packages(path.read_text(encoding="utf-8"))
    if not packages:
        raise RuntimeError("No 'apk add' packages found; refusing to evaluate Alpine compatibility.")
    return packages


def parse_apkindex(content: str) -> dict[str, str]:
    """Map package names and their `provides` aliases (e.g. `envsubst`) to versions."""
    names: dict[str, str] = {}
    for block in content.split("\n\n"):
        pkg, version, provides = "", "", []
        for line in block.splitlines():
            if line.startswith("P:"):
                pkg = line[2:].strip()
            elif line.startswith("V:"):
                version = line[2:].strip()
            elif line.startswith("p:"):
                provides.extend(line[2:].split())
        if not pkg:
            continue
        names.setdefault(pkg, version)
        for alias in provides:
            names.setdefault(re.split(r"[<>=~]", alias, maxsplit=1)[0], version)
    return names


def fetch_alpine_index(branch: str, repository: str) -> dict[str, str]:
    data = http_get(f"{ALPINE_MIRROR}/{branch}/{repository}/{ALPINE_ARCH}/APKINDEX.tar.gz", timeout=120)
    # APKINDEX.tar.gz concatenates a signature tarball and the index tarball.
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz", ignore_zeros=True) as archive:
        member = archive.extractfile("APKINDEX")
        if member is None:
            raise RuntimeError(f"APKINDEX missing from {branch}/{repository}")
        return parse_apkindex(member.read().decode("utf-8", errors="replace"))


def fetch_alpine_branches() -> list[dict]:
    """Return Alpine release branches (newest first) as dicts with version, eol, and supported flag."""
    data = json.loads(http_get(ALPINE_RELEASES_URL, timeout=30).decode("utf-8"))
    today = datetime.date.today()
    branches = []
    for branch in data.get("release_branches", []):
        m = re.fullmatch(r"v(\d+)\.(\d+)", branch.get("rel_branch", ""))
        if not m or not branch.get("releases"):
            continue  # skips `edge` and branches without a published release
        if ALPINE_ARCH not in branch.get("arches", [ALPINE_ARCH]):
            continue
        eol = branch.get("eol_date") or ""
        supported = not eol or datetime.date.fromisoformat(eol) > today
        branches.append({"version": (int(m.group(1)), int(m.group(2))), "eol": eol, "supported": supported})
    return sorted(branches, key=lambda b: b["version"], reverse=True)


def select_alpine_target(
    current: AlpineVersion,
    branches: list[dict],
    required: set[str],
    index_loader: IndexLoader,
) -> tuple[dict | None, dict[str, str], list[str]]:
    """Pick the newest supported branch newer than `current` that provides every required package.

    Returns (chosen branch or None, merged package index of the chosen branch, skip notes).
    """
    notes: list[str] = []
    for branch in branches:
        if branch["version"] <= current:
            break
        name = "v{}.{}".format(*branch["version"])
        if not branch["supported"]:
            notes.append(f"Alpine {name}: skipped (end of life since {branch['eol']}).")
            continue
        available: dict[str, str] = {}
        for repository in ALPINE_REPOSITORIES:
            for pkg, ver in index_loader(name, repository).items():
                available.setdefault(pkg, ver)
        missing = sorted(p for p in required if p not in available)
        if missing:
            notes.append(f"Alpine {name}: skipped (missing packages: {', '.join(missing)}).")
            continue
        return branch, available, notes
    return None, {}, notes


def replace_alpine_references(text: str, old: AlpineVersion, new: AlpineVersion) -> str:
    old_s, new_s = "{}.{}".format(*old), "{}.{}".format(*new)
    text = ALPINE_FROM_RE.sub(
        lambda m: f"{m.group(1)}{new_s}" if (int(m.group(2)), int(m.group(3))) == old else m.group(0),
        text,
    )
    # Rewrite "alpine:3.21", "Alpine 3.21", "Alpine `3.21`", or "Alpine Linux 3.21" but never
    # a longer version such as "3.21.3" or "3.210".
    doc_re = re.compile(rf"(?i)\b(alpine(?:\s+linux)?(?::|\s+)`?){re.escape(old_s)}(?!\.?[0-9])")
    return doc_re.sub(rf"\g<1>{new_s}", text)


def apply_alpine_update(old: AlpineVersion, new: AlpineVersion) -> list[str]:
    modified: list[str] = []
    for path in [DOCKERFILE] + [REPO_ROOT / rel for rel in ALPINE_DOC_FILES]:
        if not path.exists():
            continue
        original = path.read_text(encoding="utf-8")
        updated = replace_alpine_references(original, old, new)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            modified.append(str(path.relative_to(REPO_ROOT)))
    return modified


# ---------------------------------------------------------------------------
# Pull request metadata
# ---------------------------------------------------------------------------
def build_pr_metadata(moodle: dict | None, alpine: dict | None, identity_mode: str) -> tuple[str, str, str]:
    """Return (title, commit message, markdown body) for the coordinated update."""
    if moodle and alpine:
        title = (
            f"chore(deps): update Moodle {moodle['old']} to {moodle['new']} "
            f"and Alpine {alpine['old']} to {alpine['new']}"
        )
    elif moodle:
        title = f"chore(moodle): update Moodle from {moodle['old']} to {moodle['new']}"
    else:
        title = f"chore(deps): update Alpine base image from {alpine['old']} to {alpine['new']}"

    rows, details = [], []
    if moodle:
        rows.append(
            f"| Moodle LMS (`MOODLE_URL`) | `{moodle['old']}` | `{moodle['new']}` | "
            f"`MOODLE_SHA256`: `{moodle['sha256']}` |"
        )
        details.append(f"- Moodle {moodle['old']} -> {moodle['new']} (SHA-256 {moodle['sha256']})")
    if alpine:
        versions = ", ".join(f"`{p}` `{v}`" for p, v in alpine["packages"].items() if v)
        old_eol = f" (EOL {alpine['old_eol']})" if alpine.get("old_eol") else ""
        rows.append(
            f"| Alpine base image (`Dockerfile.nginx`) | `{alpine['old']}`{old_eol} | "
            f"`{alpine['new']}` (EOL {alpine['new_eol'] or 'n/a'}) | "
            f"all {alpine['required_count']} `apk` packages verified in `main`/`community` "
            f"(`{ALPINE_ARCH}`); {versions} |"
        )
        details.append(f"- Alpine {alpine['old']} -> {alpine['new']} ({alpine['required_count']} apk packages verified)")
    commit_message = title + "\n\n" + "\n".join(details)

    body = [
        "## Summary",
        "",
        "Coordinated dependency update generated by `.github/workflows/moodle-semver-updater.yml` "
        "(`4-moodle-image-builder/scripts/update-moodle-semver.py`).",
        "",
        "| Component | From | To | Notes |",
        "| :--- | :--- | :--- | :--- |",
        *rows,
        "",
        "## Verification",
        "",
        "- `./tests/verify-scripts-and-configs.sh` passed before this pull request was opened.",
    ]
    if alpine:
        body.append(
            "- `./tests/smoke-test-container-image.sh` built `Dockerfile.nginx` on the new Alpine release "
            "and verified PHP extensions, GNU libiconv `//TRANSLIT`, `nginx -t`, and `php-fpm83 -t`."
        )
        for note in alpine.get("notes", []):
            body.append(f"- {note}")
    if identity_mode != "maintainer-token":
        body += [
            "",
            "> [!NOTE]",
            "> This pull request was opened with the default `GITHUB_TOKEN`, so the Google CLA check "
            "(`cla/google`) reports the pull request opener `github-actions[bot]` as not covered. "
            "Configure the optional `MOODLE_UPDATER_TOKEN` repository secret (see "
            "`docs/install-moodle-nginx.md`) or close this pull request and re-open it from the "
            "`chore/moodle-semver-update` branch as a maintainer.",
        ]
    return title, commit_message, "\n".join(body) + "\n"


def write_github_outputs(values: dict[str, str]) -> None:
    github_output = os.environ.get("GITHUB_OUTPUT")
    if not github_output:
        return
    with open(github_output, "a", encoding="utf-8") as fh:
        for key, value in values.items():
            if "\n" in value:
                delimiter = f"EOF_{uuid.uuid4().hex}"
                fh.write(f"{key}<<{delimiter}\n{value}\n{delimiter}\n")
            else:
                fh.write(f"{key}={value}\n")


# ---------------------------------------------------------------------------
# Offline self-test (used by tests/verify-scripts-and-configs.sh)
# ---------------------------------------------------------------------------
def run_self_test() -> int:
    current = get_current_version()
    cur_str = "{}.{}.{}".format(*current)
    samples = [current, (current[0], current[1], current[2] + 1), (current[0], current[1] + 1, 0)]
    chosen_patch = select_target_version(current, samples, "patch", "")
    chosen_minor = select_target_version(current, samples, "minor", "")
    assert chosen_patch == (current[0], current[1], current[2] + 1)
    assert chosen_minor == (current[0], current[1] + 1, 0)

    alpine = get_current_alpine(DOCKERFILE.read_text(encoding="utf-8"))
    required = collect_required_packages()
    assert {"php83", "php83-fpm", "nginx", "build-base"} <= required, sorted(required)
    assert parse_apk_packages("RUN apk add --no-cache --virtual .deps a b=1.0 \\\n  c && apk del .deps") == {"a", "b", "c"}
    assert parse_apk_packages("# apk add ignored\nRUN apk add d") == {"d"}

    newest = (alpine[0], alpine[1] + 2)
    middle = (alpine[0], alpine[1] + 1)
    full_index = {pkg: "1.0-r0" for pkg in required}
    without_php = {pkg: ver for pkg, ver in full_index.items() if pkg != "php83"}
    indexes = {"v{}.{}".format(*newest): without_php, "v{}.{}".format(*middle): full_index}
    branches = [
        {"version": newest, "eol": "2099-01-01", "supported": True},
        {"version": middle, "eol": "2099-01-01", "supported": True},
        {"version": alpine, "eol": "2000-01-01", "supported": False},
    ]
    chosen, _, notes = select_alpine_target(
        alpine, branches, required, lambda branch, repo: indexes[branch] if repo == "main" else {}
    )
    assert chosen is not None and chosen["version"] == middle, (chosen, notes)
    assert any("missing packages: php83" in note for note in notes), notes
    eol_only = [{"version": newest, "eol": "2000-01-01", "supported": False}]
    assert select_alpine_target(alpine, eol_only, required, lambda b, r: full_index)[0] is None

    sample = (
        "FROM alpine:3.21 AS builder\nFROM alpine:3.21\nMulti-stage Alpine `3.21` + PHP 8.3.21, alpine:3.210, "
        "Alpine 3.21.3, on Alpine 3.21."
    )
    replaced = replace_alpine_references(sample, (3, 21), (3, 24))
    expected = (
        "FROM alpine:3.24 AS builder\nFROM alpine:3.24\nMulti-stage Alpine `3.24` + PHP 8.3.21, alpine:3.210, "
        "Alpine 3.21.3, on Alpine 3.24."
    )
    assert replaced == expected, replaced

    title, _, body = build_pr_metadata(
        {"old": "v5.2.4", "new": "v5.2.5", "sha256": "0" * 64},
        {"old": "3.21", "new": "3.24", "old_eol": "2026-11-01", "new_eol": "2028-06-01",
         "required_count": len(required), "packages": {"php83": "8.3.36-r0"}, "notes": []},
        "github-token",
    )
    assert title.startswith("chore(deps): update Moodle v5.2.4 to v5.2.5 and Alpine 3.21 to 3.24"), title
    assert "MOODLE_UPDATER_TOKEN" in body
    print(
        f"DRY-RUN OK: Moodle v{cur_str} (patch=v{'.'.join(map(str, chosen_patch))}, "
        f"minor=v{'.'.join(map(str, chosen_minor))}); Alpine {alpine[0]}.{alpine[1]} with "
        f"{len(required)} required apk packages"
    )
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument(
        "--scope",
        choices=["patch", "minor", "major"],
        default=os.environ.get("SEMVER_SCOPE", "patch") or "patch",
        help="Moodle SemVer update scope: patch (5.2.x), minor (5.y.z), or major (X.Y.Z).",
    )
    parser.add_argument(
        "--series",
        default=os.environ.get("CUSTOM_SERIES", ""),
        help="Optional explicit Moodle target series (e.g. '5.3' or '5.2.5').",
    )
    parser.add_argument(
        "--alpine",
        choices=["latest", "none"],
        default=os.environ.get("ALPINE_POLICY", "latest") or "latest",
        help="Alpine policy: 'latest' bumps to the newest supported release that provides every "
        "required apk package; 'none' leaves the base image unchanged.",
    )
    parser.add_argument(
        "--pr-body-path",
        default=os.environ.get("PR_BODY_PATH", ""),
        help="Optional path where the pull request body (Markdown) is written.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run the offline self-test (version selection, apk parsing, Alpine gating) without network or writes.",
    )
    args = parser.parse_args()

    if args.dry_run:
        return run_self_test()

    moodle: dict | None = None
    current = get_current_version()
    cur_str = "{}.{}.{}".format(*current)
    target = select_target_version(current, fetch_moodle_tags(), args.scope, args.series.strip())
    if target == current:
        print(f"Moodle is already at the latest matching version (v{cur_str}) for scope='{args.scope}' series='{args.series}'.")
    else:
        target_str = "{}.{}.{}".format(*target)
        print(f"Updating Moodle from v{cur_str} to v{target_str}...")
        sha256_hex = compute_tarball_sha256(target_str)
        modified = apply_moodle_update(cur_str, target_str, sha256_hex)
        print(f"Updated {len(modified)} files with v{target_str} (SHA-256: {sha256_hex}): {modified}")
        moodle = {"old": f"v{cur_str}", "new": f"v{target_str}", "sha256": sha256_hex}

    alpine: dict | None = None
    if args.alpine == "latest":
        try:
            cur_alpine = get_current_alpine(DOCKERFILE.read_text(encoding="utf-8"))
            required = collect_required_packages()
            branches = fetch_alpine_branches()
            chosen, available, notes = select_alpine_target(cur_alpine, branches, required, fetch_alpine_index)
            for note in notes:
                print(note)
            cur_branch = next((b for b in branches if b["version"] == cur_alpine), None)
            old_s = "{}.{}".format(*cur_alpine)
            if chosen is None:
                print(f"Alpine {old_s} is already the newest compatible release.")
                if cur_branch and not cur_branch["supported"]:
                    warn(
                        f"Alpine {old_s} reached end of life on {cur_branch['eol']} and no supported newer "
                        "release provides every required apk package; migrate the PHP package series manually."
                    )
            else:
                new_s = "{}.{}".format(*chosen["version"])
                modified = apply_alpine_update(cur_alpine, chosen["version"])
                print(f"Updated Alpine base image from {old_s} to {new_s}: {modified}")
                alpine = {
                    "old": old_s,
                    "new": new_s,
                    "old_eol": cur_branch["eol"] if cur_branch else "",
                    "new_eol": chosen["eol"],
                    "required_count": len(required),
                    "packages": {p: available.get(p, "") for p in ALPINE_REPORTED_PACKAGES},
                    "notes": notes,
                }
        except (urllib.error.URLError, OSError, ValueError, RuntimeError, tarfile.TarError) as exc:
            warn(f"Skipping the Alpine base image check: {exc}")

    outputs = {
        "updated": "true" if (moodle or alpine) else "false",
        "moodle_updated": "true" if moodle else "false",
        "alpine_updated": "true" if alpine else "false",
    }
    if moodle:
        outputs.update(old_version=moodle["old"], new_version=moodle["new"], sha256=moodle["sha256"])
    if alpine:
        outputs.update(old_alpine=alpine["old"], new_alpine=alpine["new"])
    if moodle or alpine:
        title, commit_message, body = build_pr_metadata(moodle, alpine, os.environ.get("PR_IDENTITY_MODE", ""))
        outputs.update(pr_title=title, commit_message=commit_message)
        if args.pr_body_path:
            pathlib.Path(args.pr_body_path).write_text(body, encoding="utf-8")
        print(f"Pull request title: {title}")
    write_github_outputs(outputs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
