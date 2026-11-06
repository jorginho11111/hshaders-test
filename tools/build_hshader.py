#!/usr/bin/env python3
"""Builds the repo's .hshader zips deterministically into dist/.

- dist/mellow-<version>.hshader from mellow/ (only the files the manifest names:
  its shared + stage .wgsl, plus README.md and LICENSE).
- With --preset batata|editavel: a mellow-<preset>-<version>.hshader variant whose
  [[options]] defaults (and an optional [shadow] section) are swapped to the preset's
  values, so the user gets exactly two ready-made packs plus the plain one.
- dist/probe-<name>.hshader from each probes/probe-<name>/ folder.

Deterministic: sorted entries, fixed timestamp (2026-01-01), fixed permissions,
ZIP_DEFLATED. Same tree in -> same bytes out (sha256-stable for release notes).
"""
import argparse, hashlib, os, re, sys, zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(ROOT, "dist")

# Exactly two presets, as the user asked: batata (everything heavy off, lag-free
# configuring) and editavel (the user's own normal-Mellow values as defaults).
# Keys that don't exist in the mellow manifest (border fog, dynamic shadows,
# handheld lights, motion blur, outline, puddles, rainbows, underwater fog,
# water normals, ...) are documented as unsupported in the release notes.
PRESETS = {
    "batata": {
        "options": {
            # heavy effects off so the user can tweak without lag
            "reflections": False,
            "reflection_strength": 0.0,
            "atmospheric_fog": 0.0,
            "aurora": False,
            "weather_opacity": 0.1,
            "bloom_strength": 0.0,
            "vignette_opacity": 0.0,
            "film_grain": False,
            "cloud_opacity": 0.0,
            "star_strength": 0.1,
        },
        "shadow": None,
    },
    "editavel": {
        "options": {
            # the user's actual normal-Mellow config, mapped to the keys this
            # port supports; the rest are unsupported and listed in the notes
            "atmospheric_fog": 0.0,   # ATMOSPHERIC_FOG=false
            "bloom_strength": 0.0,    # BLOOM=false
            "light_falloff": 1.8,     # LM_FALLOFF_CURVE=1.8
            "reflections": False,     # REFLECTIONS=0  (unconfirmed; user said OK)
            "star_strength": 1.75,    # STAR_STRENGTH=1.75
        },
        "shadow": {"distance": 64.0}, # shadowDistance=64.0
    },
}


def toml_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        return repr(float(v))
    return str(v)


def apply_preset(toml_text, preset_name):
    """Return the manifest text with the preset's defaults (and [shadow]) swapped in."""
    preset = PRESETS[preset_name]

    # Swap each [[options]] default whose id is in the preset.
    parts = toml_text.split("[[options]]\n")
    head = parts[0]
    out = [head]
    for block in parts[1:]:
        body_lines = block.splitlines()
        oid = None
        for l in body_lines:
            m = re.match(r'^id = "([^"]+)"', l)
            if m:
                oid = m.group(1)
                break
        if oid is not None and oid in preset["options"]:
            new = toml_value(preset["options"][oid])
            replaced = []
            done = False
            for l in body_lines:
                if not done and re.match(r'^default = ', l):
                    replaced.append(f"default = {new}")
                    done = True
                else:
                    replaced.append(l)
            block = "\n".join(replaced)
        out.append("[[options]]\n" + block)
    toml_text = "".join(out)

    # [shadow]: add or replace (only editavel sets one).
    shadow = preset["shadow"]
    if shadow is not None:
        kv = "\n".join(f"{k} = {toml_value(v)}" for k, v in shadow.items())
        block = f"[shadow]\n{kv}\n"
        if re.search(r'^\[shadow\]', toml_text, re.M):
            toml_text = re.sub(
                r'^\[shadow\].*?(?=^\[|^\[\[|$)',
                block,
                toml_text,
                flags=re.M | re.S,
            )
        else:
            toml_text = toml_text.rstrip() + "\n\n" + block
    return toml_text


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


def build_pack(folder, preset=None):
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

    content_overrides = None
    out_name = f"{folder}-{version}.hshader"
    if preset is not None:
        toml_text = apply_preset(toml_text, preset)
        content_overrides = {"horizon-shaders.toml": toml_text.encode("utf-8")}
        out_name = f"{folder}-{preset}-{version}.hshader"

    zip_dir(os.path.join(DIST, out_name), src, names, content_overrides)


def build_probes():
    probes = os.path.join(ROOT, "probes")
    for d in sorted(os.listdir(probes)):
        full = os.path.join(probes, d)
        if not os.path.isdir(full) or not d.startswith("probe-"):
            continue
        zip_dir(os.path.join(DIST, f"{d}.hshader"), full, all_files(full))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", choices=sorted(PRESETS), default=None,
                    help="build only one preset variant of mellow")
    args = ap.parse_args()
    os.makedirs(DIST, exist_ok=True)
    if args.preset:
        build_pack("mellow", preset=args.preset)
    else:
        build_pack("mellow")            # plain 0.1.8 pack
        for p in sorted(PRESETS):       # the two presets
            build_pack("mellow", preset=p)
    build_probes()
