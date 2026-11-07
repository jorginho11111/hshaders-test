#!/usr/bin/env python3
"""Builds the repo's .hshader zips deterministically into dist/.

- dist/water_walk-<version>.hshader from water_walk/ (only the files the manifest names:
  its shared + stage .wgsl, plus README.md and LICENSE).
- dist/probe-<name>.hshader from each probes/probe-<name>/ folder.

Deterministic: sorted entries, fixed timestamp (2026-01-01), fixed permissions,
ZIP_DEFLATED. Same tree in -> same bytes out (sha256-stable for release notes).
"""
import hashlib, os, re, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")


def zip_dir(out_path, base_dir, names, content_overrides=None):
    content_overrides = content_overrides or {}
    names = sorted(names)
    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as z:
        for n in names:
            zi = zipfile.ZipInfo(n, date_time=(2026, 1, 1, 0, 0, 0))
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = 0o644 << 16
            if n in content_overrides:
                data = content_overrides[n]
            else:
                with open(os.path.join(base_dir, n), "rb") as f:
                    data = f.read()
            z.writestr(zi, data)
    h = hashlib.sha256(open(out_path, "rb").read()).hexdigest()
    print(f"{os.path.basename(out_path)}: {len(names)} files, "
          f"{os.path.getsize(out_path)} B, sha256 {h}")


def all_files(base_dir):
    """Every file under base_dir, as sorted '/'-separated relative names."""
    out = []
    for root, _dirs, files in os.walk(base_dir):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), base_dir)
            out.append(rel.replace(os.sep, "/"))
    return sorted(out)


def build_pack(folder):
    src = os.path.join(ROOT, folder)
    toml_path = os.path.join(src, "horizon-shaders.toml")
    toml_text = open(toml_path).read()
    version = re.search(r'^version = "([^"]+)"', toml_text, re.M).group(1)
    wgs = set(re.findall(r'^shared = (.+)$', toml_text, re.M)[0].replace('"', '').\
              replace('[', '').replace(']', '').split(','))
    for m in re.findall(r'^file(?:s)? = (.+)$', toml_text, re.M):
        wgs |= set(re.findall(r'"([^"]+)"', m))
    names = ["horizon-shaders.toml", "README.md", "LICENSE"] + sorted(wgs)
    missing = [n for n in names if n != "horizon-shaders.toml"
               and not os.path.isfile(os.path.join(src, n))]
    if missing:
        sys.exit(f"{folder}/: missing {missing}")

    zip_dir(os.path.join(DIST, f"{folder}-{version}.hshader"), src, names)


def build_probes():
    probes = os.path.join(ROOT, "probes")
    for d in sorted(os.listdir(probes)):
        full = os.path.join(probes, d)
        if not os.path.isdir(full) or not d.startswith("probe-"):
            continue
        zip_dir(os.path.join(DIST, f"{d}.hshader"), full, all_files(full))


if __name__ == "__main__":
    os.makedirs(DIST, exist_ok=True)
    build_pack("water_walk")
    build_probes()
