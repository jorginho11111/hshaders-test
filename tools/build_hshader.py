#!/usr/bin/env python3
"""Builds the repo's .hshader zips deterministically into dist/.

- dist/mellow-<version>.hshader from mellow/ (only the files the manifest names:
  its shared + stage .wgsl, plus README.md and LICENSE).
- dist/probe-<name>.hshader from each probes/probe-<name>/ folder.

Deterministic: sorted entries, fixed timestamp (2026-01-01), fixed permissions,
ZIP_DEFLATED. Same tree in -> same bytes out (sha256-stable for release notes).
"""
import hashlib, os, re, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")


def zip_dir(out_path, base_dir, names):
    names = sorted(names)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as z:
        for n in names:
            zi = zipfile.ZipInfo(n, date_time=(2026, 1, 1, 0, 0, 0))
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            with open(os.path.join(base_dir, n), "rb") as f:
                z.writestr(zi, f.read())
    h = hashlib.sha256(open(out_path, "rb").read()).hexdigest()
    print(f"{os.path.basename(out_path)}: {len(names)} files, "
          f"{os.path.getsize(out_path)} B, sha256 {h}")


def build_mellow():
    src = os.path.join(ROOT, "mellow")
    toml = open(os.path.join(src, "horizon-shaders.toml")).read()
    version = re.search(r'^version = "([^"]+)"', toml, re.M).group(1)
    wgs = set(re.findall(r'^shared = (.+)$', toml, re.M)[0].replace('"', '').
              replace('[', '').replace(']', '').split(','))
    for m in re.findall(r'^file(?:s)? = (.+)$', toml, re.M):
        wgs |= set(re.findall(r'"([^"]+)"', m))
    names = ["horizon-shaders.toml", "README.md", "LICENSE"] + sorted(wgs)
    missing = [n for n in names if not os.path.isfile(os.path.join(src, n))]
    if missing:
        sys.exit(f"mellow/: missing {missing}")
    zip_dir(os.path.join(DIST, f"mellow-{version}.hshader"), src, names)


def build_probes():
    probes = os.path.join(ROOT, "probes")
    for d in sorted(os.listdir(probes)):
        full = os.path.join(probes, d)
        if not os.path.isdir(full) or not d.startswith("probe-"):
            continue
        names = [n for n in os.listdir(full) if os.path.isfile(os.path.join(full, n))]
        zip_dir(os.path.join(DIST, f"{d}.hshader"), full, names)


if __name__ == "__main__":
    os.makedirs(DIST, exist_ok=True)
    build_mellow()
    build_probes()
