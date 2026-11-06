#!/usr/bin/env python3
"""Validates every pack manifest in the repo against Horizon Android 0.7.7's
rules (crates/horizon-shader-api/src/manifest.rs `Manifest::parse` + `RawOption::check`).

Run from the repo root: python3 tools/validate_manifests.py
Exit 0 = every manifest the app would accept.
"""
import os, re, glob, sys, tomllib

API = "0.1"            # exact match ("this Horizon serves 0.1")
SCHEMA = "1"
STAGE_FIELDS = {"file", "files", "name", "fog", "clouds", "sun", "stars", "scale", "output"}
STAGES = ("sky", "material", "weather", "post")
POST_SCALES = (1.0, 0.5, 0.25)
RESERVED_OUTPUTS = {
    "frame", "scene_color", "scene_depth", "previous", "linear_sampler",
    "nearest_sampler", "shadow_map", "shadow_sampler", "history",
    "shadow_map_translucent", "shadow_color", "scene_surface",
}


def sections(toml):
    out, cur = [], None
    for line in toml.splitlines():
        m = re.match(r'^\[\[?(\w+)\]\]?\s*$', line)
        if m:
            cur = (m.group(1), [])
            out.append(cur)
        elif cur is not None and line.strip() and not line.startswith('#'):
            cur[1].append(line)
    return out


def field(body, name):
    for line in body:
        m = re.match(rf'^{name} = (.+?)\s*$', line)
        if m:
            return m.group(1).strip().strip('"')
    return None


def check(manifest, base):
    text = open(manifest).read()
    errs = []
    name = os.path.relpath(manifest)

    # Strict TOML parse first — same rejection the app does (duplicate keys,
    # bad syntax). This is what caught v0.1.5's duplicate [sky].
    try:
        data = tomllib.loads(text)
    except tomllib.TOMLDecodeError as e:
        errs.append(f'TOML parse error: {e}')
        print(f"FAIL {name}")
        for e2 in errs:
            print(f"   - {e2}")
        return False

    # Duplicate [[options]] ids are legal TOML (array of tables) but collide in
    # the app's override pipeline — check them here.
    opt_ids = [o.get("id") for o in data.get("options", [])]
    dup = sorted({i for i in opt_ids if opt_ids.count(i) > 1})
    if dup:
        errs.append(f'duplicate option ids: {dup}')

    api = field(text.splitlines(), 'api') if False else re.search(r'^api = "([^"]*)"', text, re.M)
    api = api.group(1) if api else None
    if api != API:
        errs.append(f'api {api!r} must be exactly {API!r}')
    mid = re.search(r'^id = "([^"]*)"', text, re.M)
    mid = mid.group(1) if mid else ""
    if not re.fullmatch(r'[a-z0-9_]{1,64}', mid):
        errs.append(f'id {mid!r} must match [a-z0-9_]{{1,64}}')
    if (re.search(r'^schema = "?(\d+)"?', text, re.M) or [None, SCHEMA])[1] != SCHEMA:
        errs.append(f'schema must be {SCHEMA}')

    secs = sections(text)
    if not any(s in STAGES for s, _ in secs):
        errs.append('no stage ([sky]/[material]/[weather]/[[post]])')

    files, post = [], []
    for sname, body in secs:
        if sname not in STAGES:
            continue
        keys = {re.match(r'^(\w+) =', l).group(1) for l in body if re.match(r'^\w+ =', l)}
        unknown = keys - STAGE_FIELDS
        if unknown:
            errs.append(f'[{sname}] unknown fields {sorted(unknown)}')
        if field(body, 'file') is None:
            errs.append(f'[{sname}] missing required field `file`')
        if 'fog' in keys and sname != 'material':
            errs.append(f'[{sname}] `fog` is a [material] key')
        if ('scale' in keys or 'output' in keys) and sname != 'post':
            errs.append(f'[{sname}] `scale`/`output` are [[post]] keys')
        if keys & {'clouds', 'sun', 'stars'} and sname != 'sky':
            errs.append(f'[{sname}] `clouds`/`sun`/`stars` are [sky] keys')
        for l in body:
            m = re.match(r'^files? = (.+)', l)
            if m:
                files += re.findall(r'"([^"]+)"', m.group(1))
        if sname == 'post':
            post.append(body)

    # Field names the app's serde structs accept (deny_unknown_fields everywhere).
    TOP_FIELDS = {
        "schema", "id", "name", "version", "api", "description", "authors",
        "license", "shared", "sky", "material", "weather", "post", "options",
        "pages", "tags", "materials", "textures", "lights", "budget",
        "reflection", "shadow",
    }
    first_sec = re.search(r'^\[\[?[\w]+\]?\]\s*$', text, re.M)
    head = text[:first_sec.start()] if first_sec else text
    top_keys = {m.group(1) for m in re.finditer(r'^(\w+) =', head, re.M)}
    unknown = top_keys - TOP_FIELDS
    if unknown:
        errs.append(f'top-level unknown fields {sorted(unknown)}')

    SECTION_KEYS = {
        "budget": {"gpu_ms"},
        "reflection": {"option"},
        "shadow": {"resolution", "distance", "solid_materials"},
    }
    for sname, body in secs:
        if sname not in SECTION_KEYS:
            continue
        keys = {m.group(1) for m in (re.match(r'^(\w+) =', l) for l in body) if m}
        unknown = keys - SECTION_KEYS[sname]
        if unknown:
            errs.append(f'[{sname}] unknown fields {sorted(unknown)} (app takes only {sorted(SECTION_KEYS[sname])})')
        if sname == 'budget' and 'gpu_ms' in keys:
            try:
                ms = float(field(body, 'gpu_ms'))
                if not (0.0 < ms <= 16.0):
                    errs.append(f'budget.gpu_ms {ms} must be in (0, 16]')
            except (TypeError, ValueError):
                errs.append('budget.gpu_ms must be a number')

    # post chain rules (check_post_targets)
    for i, body in enumerate(post):
        scale = float(field(body, 'scale') or 1.0)
        out = field(body, 'output')
        pfile = field(body, 'file')
        if scale not in POST_SCALES:
            errs.append(f'[[post]] {pfile}: scale {scale} not in {POST_SCALES}')
        if i + 1 == len(post) and (out is not None or scale != 1.0):
            errs.append(f'[[post]] {pfile}: last pass draws the picture - no `output`/`scale`')
        if out is None and scale != 1.0:
            errs.append(f'[[post]] {pfile}: a scaled pass writes an `output`')
        if out is not None and (out in RESERVED_OUTPUTS or not re.fullmatch(r'[a-z][a-z0-9_]{0,31}', out)):
            errs.append(f'[[post]] {pfile}: output {out!r} not a free WGSL name')

    for m in re.findall(r'^shared = (.+)$', text, re.M):
        files += re.findall(r'"([^"]+)"', m)
    for f in files:
        if f != os.path.normpath(f) or not f.endswith('.wgsl') \
                or not os.path.isfile(os.path.join(base, f)):
            errs.append(f'bad file path {f!r}')

    # options
    opt_ids = []
    for block in text.split("[[options]]\n")[1:]:
        body = [l for l in block.splitlines() if l.strip() and not l.startswith('#')]
        oid = field(body, 'id')
        opt_ids.append(oid)
        if not re.fullmatch(r'[A-Za-z]\w{0,63}', oid or '') or oid.startswith('horizon_'):
            errs.append(f'option id {oid!r} not a WGSL identifier (or starts with horizon_)')
        typ = field(body, 'type')
        if typ not in ('bool', 'float', 'int', 'choice'):
            errs.append(f'option {oid}: bad type {typ!r}')
        if typ == 'float':
            lo, hi = float(field(body, 'min')), float(field(body, 'max'))
            dv = float(field(body, 'default'))
            step = float(field(body, 'step')) if field(body, 'step') else (hi - lo) / 100.0
            if not (lo < hi and lo <= dv <= hi):
                errs.append(f'option {oid}: needs min < max and default in [{lo}, {hi}]')
            if not (0.0 < step <= hi - lo):
                errs.append(f'option {oid}: step {step} not in (0, {hi - lo}]')
        if typ == 'int':
            lo, hi = int(field(body, 'min')), int(field(body, 'max'))
            dv = int(field(body, 'default'))
            if not (lo < hi and lo <= dv <= hi):
                errs.append(f'option {oid}: needs min < max and default in [{lo}, {hi}]')
        if typ == 'choice':
            values = re.findall(r'"([^"]*)"', field(body, 'values') or '')
            if field(body, 'default') not in values:
                errs.append(f'option {oid}: default {field(body, "default")!r} not in values')
    if len(opt_ids) != len(set(opt_ids)):
        errs.append('duplicate option ids')

    # [[pages]] (tabs/topics): known ids, each page id once, items are option or
    # page ids only, and every page + option is reached from the first page.
    check_pages(data, opt_ids, errs, name)

    used = set()
    for f in files:
        if not f.endswith(('shared.wgsl', 'common.wgsl')):
            used |= set(re.findall(r'^override (\w+)', open(os.path.join(base, f)).read(), re.M))
    if used != set(opt_ids):
        errs.append(f'options {sorted(set(opt_ids))} != overrides {sorted(used)}')

    print(("OK  " if not errs else "FAIL") + f" {name}: id={mid} options={len(opt_ids)}")
    for e in errs:
        print("   -", e)
    return not errs



def check_pages(data, opt_ids, errs, name):
    pages = data.get("pages") or []
    page_ids = [p.get("id") for p in pages]
    if len(page_ids) != len(set(page_ids)):
        dups = sorted(i for i in page_ids if page_ids.count(i) > 1)
        errs.append(f'[[pages]] duplicate page ids: {dups}')
        return
    if not pages:
        return
    page_id_set = set(page_ids)
    opt_id_set = set(opt_ids)
    reached_pages = set()
    reached_opts = set()
    stack = [pages[0].get("id")]
    while stack:
        pid = stack.pop()
        if pid in reached_pages:
            continue
        reached_pages.add(pid)
        page = next(p for p in pages if p.get("id") == pid)
        for item in page.get("items") or []:
            if item in page_id_set and item not in reached_pages:
                stack.append(item)
            elif item in opt_id_set:
                reached_opts.add(item)
            else:
                errs.append(f'[[pages]] {pid}: unknown item {item!r} (not an option or page id)')
    unreached_pages = page_id_set - reached_pages
    if unreached_pages:
        errs.append(f'[[pages]] pages not reached from the first page: {sorted(unreached_pages)}')
    unreached_opts = opt_id_set - reached_opts
    if unreached_opts:
        errs.append(f'[[pages]] options not listed on any page: {sorted(unreached_opts)}')


if __name__ == "__main__":
    ok = check("mellow/horizon-shaders.toml", "mellow")
    for d in sorted(glob.glob("probes/probe-*/")):
        ok &= check(os.path.join(d, "horizon-shaders.toml"), d.rstrip("/"))
    sys.exit(0 if ok else 1)

