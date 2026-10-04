#!/usr/bin/env python3
"""Journey content validator.

Runs in CI before Flutter is even installed. It checks everything in
content/ that the app would otherwise discover only at runtime:

  E-JSON        file is missing / not valid JSON
  E-SCHEMA      wrong shape: missing field, wrong type, bad enum value
  E-VERSION     schemaVersion newer than the engine reads, or below the floor
  E-ID-FORMAT   id has bad characters / wrong prefix
  E-DUP-ID      duplicate id (within a file, a pack, or across packs)
  E-REF         reference to something that does not exist / is not visible
  E-FILE        referenced file or asset is missing
  E-DEP         dependency missing, self-referencing or cyclic
  E-ROUTE       pack / route mismatch
  E-UNLOCK      unlock rule cycle or malformed rule
  E-MARKUP      malformed furigana / bold markup
  E-ASSET-SYNC  pubspec.yaml asset list is out of date (run --sync-assets)
  E-ENGINE      validator and Dart engine disagree on the schema version

Warnings (W-*) never fail the build unless --strict is given.

Usage:
  python3 tool/validate_content.py                 # validate
  python3 tool/validate_content.py --sync-assets   # rewrite pubspec asset block
  python3 tool/validate_content.py --strict        # warnings fail too
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

ASSET_BEGIN = "    # BEGIN GENERATED CONTENT ASSETS (tool/validate_content.py --sync-assets)"
ASSET_END = "    # END GENERATED CONTENT ASSETS"
SCHEMA_DART = "lib/package_system/schema/schema_version.dart"

# --- schema DSL -------------------------------------------------------------
# 's' string, 'i' int, 'n' number, 'b' bool, 'any', 'id' valid id, 'rel' safe
# relative path, 'enum:a|b'. [spec] = list of spec, {..} = object. A trailing
# '?' on a key marks it optional.
RULE = {"type": "enum:prefectureComplete|chapterComplete|lessonComplete|testPassed", "ref": "s"}
HEADER = {"schemaVersion": "i", "kind": "s"}
POS = {"x": "n", "y": "n"}


def doc(extra):
    return {**HEADER, **extra}


SPECS = {
    "journeyIndex": doc({
        "journeyId": "id", "title": "s", "contentVersion": "i",
        "route": [{"prefectureId": "id", "number": "i", "name": "s", "nameEn": "s",
                   "nameReading?": "s", "map": POS}]}),
    "packManifest": doc({
        "packId": "id", "type": "enum:prefecture|knowledge", "contentVersion": "i",
        "engineSchemaMin": "i", "title": "s", "titleEn?": "s", "cover?": "rel",
        "dependencies": ["id"], "unlock?": [RULE], "completion?": [RULE],
        "chapters?": [{"id": "id", "file": "rel", "map?": POS}],
        "knowledge?": {"kanji?": "rel", "radicals?": "rel", "vocabulary?": "rel",
                       "grammar?": "rel", "sentences?": "rel", "stories?": "rel"},
        "questionBank?": "rel",
        "tests?": [{"id": "id", "title": "s", "questionCount": "i", "passRatio": "n", "tags?": ["s"],
                    "quotas?": "any", "unlock?": [RULE]}],
        "reading?": {"id": "id", "title": "s", "file": "rel", "unlock?": [RULE]},
        "completionCriteria?": ["s"],
        "assets?": ["rel"]}),
    "chapter": doc({
        "id": "id", "name": "s", "nameEn?": "s", "reading?": "s", "summary?": "s",
        "previousIds?": ["id"], "unlock?": [RULE], "lessonOrder?": "enum:sequential|free",
        "lessons": [{"id": "id", "file": "rel", "previousIds?": ["id"]}]}),
    "lesson": doc({
        "id": "id", "number": "i", "title": "s", "goal?": "s", "estimatedMinutes?": "i",
        "coreKanji?": ["id"], "encounterKanji?": ["id"], "previousIds?": ["id"],
        "status?": "enum:draft|final",
        "cards": [{"id": "id", "title": "s", "kind?": "enum:intro|content|review|summary|practice|story",
                   "scroll?": "b", "blocks": ["any"]}],
        "completion?": {"title": "s", "nextText?": "s", "nextChapter?": "s"}}),
    "kanjiSet": doc({"items": [{
        "id": "id", "char": "s", "meanings": ["s"], "onyomi?": ["s"], "kunyomi?": ["s"],
        "components?": [{"radical": "id", "role": "enum:meaning|sound|classifier|shape|unknown", "note?": "s"}],
        "relatedKanji?": ["id"], "notes?": "s", "previousIds?": ["id"]}]}),
    "radicalSet": doc({"items": [{
        "id": "id", "char": "s", "name": "s", "nameRomaji?": "s", "meanings": ["s"],
        "note?": "s", "exampleKanji?": ["id"], "previousIds?": ["id"]}]}),
    "vocabularySet": doc({"items": [{
        "id": "id", "word": "s", "reading": "s", "meanings": ["s"], "pos?": "s",
        "kanji?": ["id"], "exampleSentences?": ["id"], "previousIds?": ["id"]}]}),
    "grammarSet": doc({"items": [{
        "id": "id", "title": "s", "pattern?": "s", "explanation": "s", "previousIds?": ["id"]}]}),
    "sentenceSet": doc({"items": [{
        "id": "id", "jp": "s", "en": "s", "romaji?": "s",
        "tokens?": [{"text": "s", "reading?": "s", "gloss?": "s", "vocab?": "id", "grammar?": "id"}],
        "grammar?": ["id"], "kanji?": ["id"], "previousIds?": ["id"]}]}),
    "storySet": doc({"items": [{
        "id": "id", "title": "s", "placeholder?": "b",
        "pages": [{"text": "s", "en?": "s"}], "kanji?": ["id"], "previousIds?": ["id"]}]}),
    "questionBank": doc({"items": [{
        "id": "id", "type": "enum:multipleChoice", "prompt": "s",
        "choices": [{"id": "id", "text": "s"}], "answer": "id", "tags?": ["s"],
        "refs?": ["id"], "explanation?": "s", "category?": "s", "previousIds?": ["id"]}]}),
}

BLOCKS = {
    "heading": {"text": "s", "level?": "i"},
    "text": {"text": "s"},
    "display": {"jp": "s", "reading?": "s", "romaji?": "s", "gloss?": "s"},
    "callout": {"text": "s", "title?": "s", "tone?": "enum:info|tip|warning|quote"},
    "bullets": {"items": ["s"]},
    "divider": {},
    "kanjiRef": {"id": "id", "show?": ["s"]},
    "kanjiRow": {"ids": ["id"], "show?": ["s"]},
    "radicalRef": {"id": "id"},
    "vocabRef": {"id": "id"},
    "sentenceRef": {"id": "id", "showBreakdown?": "b"},
    "grammarRef": {"id": "id"},
    "readingLine": {"jp": "s", "en?": "s"},
}
# block type -> [(field, namespace)] (single id or list of ids)
BLOCK_REFS = {"kanjiRef": [("id", "kanji")], "kanjiRow": [("ids", "kanji")],
              "radicalRef": [("id", "radical")], "vocabRef": [("id", "vocab")],
              "sentenceRef": [("id", "sentence")], "grammarRef": [("id", "grammar")]}
MARKUP_BLOCK_FIELDS = {"heading": ["text"], "text": ["text"], "display": ["jp"],
                       "callout": ["text"], "bullets": ["items"], "readingLine": ["jp"]}

# namespace -> (document kind, id prefix, manifest knowledge key)
NAMESPACES = {
    "kanji": ("kanjiSet", "kanji_", "kanji"),
    "radical": ("radicalSet", "radical_", "radicals"),
    "vocab": ("vocabularySet", "vocab_", "vocabulary"),
    "grammar": ("grammarSet", "grammar_", "grammar"),
    "sentence": ("sentenceSet", "sent_", "sentences"),
    "story": ("storySet", "story_", "stories"),
    "question": ("questionBank", "q_", None),
}
PREFIX_TO_NS = {p: ns for ns, (_, p, _) in NAMESPACES.items()}
ID_RE = re.compile(r"^[\w\-]+$")  # unicode word chars: kanji ids like kanji_北 are fine


class Report:
    def __init__(self):
        self.errors, self.warnings = [], []

    def err(self, code, file, msg):
        self.errors.append((code, str(file), msg))

    def warn(self, code, file, msg):
        self.warnings.append((code, str(file), msg))

    def codes(self):
        return {c for c, _, _ in self.errors}


# --- generic helpers --------------------------------------------------------
def schema_constants(root: Path):
    p = root / SCHEMA_DART
    if not p.exists():
        return None
    t = p.read_text(encoding="utf-8")
    cur = re.search(r"kCurrentSchemaVersion\s*=\s*(\d+)", t)
    low = re.search(r"kMinReadableSchemaVersion\s*=\s*(\d+)", t)
    if not (cur and low):
        return None
    return int(cur.group(1)), int(low.group(1))


def is_num(v):
    return isinstance(v, (int, float)) and not isinstance(v, bool)


def check_shape(v, spec, loc, file, rep):
    if isinstance(spec, dict):
        if not isinstance(v, dict):
            rep.err("E-SCHEMA", file, f"{loc}: expected object")
            return
        keys = {k.rstrip("?"): (s, not k.endswith("?")) for k, s in spec.items()}
        for k, (s, required) in keys.items():
            if k not in v:
                if required:
                    rep.err("E-SCHEMA", file, f"{loc}: missing required field '{k}'")
                continue
            check_shape(v[k], s, f"{loc}.{k}", file, rep)
        for k in v:
            if k not in keys and k != "type" and not k.startswith(("x-", "$", "_")):
                rep.warn("W-UNKNOWN-FIELD", file, f"{loc}: unknown field '{k}' (typo?)")
    elif isinstance(spec, list):
        if not isinstance(v, list):
            rep.err("E-SCHEMA", file, f"{loc}: expected list")
            return
        for i, item in enumerate(v):
            check_shape(item, spec[0], f"{loc}[{i}]", file, rep)
    else:
        scalar(v, spec, loc, file, rep)


def scalar(v, spec, loc, file, rep):
    ok = True
    if spec == "s":
        ok = isinstance(v, str)
    elif spec == "i":
        ok = isinstance(v, int) and not isinstance(v, bool)
    elif spec == "n":
        ok = is_num(v)
    elif spec == "b":
        ok = isinstance(v, bool)
    elif spec == "any":
        ok = True
    elif spec == "id":
        if not isinstance(v, str) or not v:
            ok = False
        elif not ID_RE.match(v):
            rep.err("E-ID-FORMAT", file, f"{loc}: '{v}' has characters not allowed in ids")
    elif spec == "rel":
        if not isinstance(v, str) or not v:
            ok = False
        elif v.startswith("/") or ".." in Path(v).parts or "\\" in v:
            rep.err("E-FILE", file, f"{loc}: '{v}' must be a relative path inside the pack")
    elif spec.startswith("enum:"):
        if v not in spec[5:].split("|"):
            rep.err("E-SCHEMA", file, f"{loc}: '{v}' is not one of {spec[5:]}")
    if not ok:
        rep.err("E-SCHEMA", file, f"{loc}: expected {spec}, got {type(v).__name__}")


def load(path: Path, rep: Report, kind: str, consts):
    """Parse a JSON document and check its header + shape. Returns dict or None."""
    if not path.exists():
        rep.err("E-FILE", path, "file does not exist")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, UnicodeDecodeError) as e:
        rep.err("E-JSON", path, f"cannot parse: {e}")
        return None
    if not isinstance(data, dict):
        rep.err("E-SCHEMA", path, "top level must be an object")
        return None
    if data.get("kind") != kind:
        rep.err("E-SCHEMA", path, f"kind should be '{kind}', found {data.get('kind')!r}")
    ver = data.get("schemaVersion")
    if isinstance(ver, int) and consts:
        cur, low = consts
        if ver > cur:
            rep.err("E-VERSION", path, f"schemaVersion {ver} is newer than the engine reads ({cur})")
        elif ver < low:
            rep.err("E-VERSION", path, f"schemaVersion {ver} is below the minimum readable ({low})")
        elif ver < cur:
            rep.warn("W-MIGRATE", path, f"schemaVersion {ver} will be migrated on load (current {cur})")
    check_shape(data, SPECS[kind], "$", path, rep)
    return data


def check_markup(s, loc, file, rep):
    if s.count("**") % 2:
        rep.err("E-MARKUP", file, f"{loc}: unbalanced ** in {s[:40]!r}")
    depth = 0
    for ch in s:
        if ch == "{":
            depth += 1
            if depth > 1:
                break
        elif ch == "}":
            depth -= 1
            if depth < 0:
                break
    if depth != 0:
        rep.err("E-MARKUP", file, f"{loc}: unbalanced {{ }} in {s[:40]!r}")
    for m in re.finditer(r"\{([^{}]*)\}", s):
        if m.group(1).count("|") != 1 or not all(m.group(1).split("|")):
            rep.err("E-MARKUP", file, f"{loc}: ruby must look like {{base|reading}}: {m.group(0)!r}")


def find_cycle(graph):
    """graph: node -> iterable of nodes. Returns a cycle (list) or None."""
    state, stack = {}, []

    def visit(n):
        state[n] = 1
        stack.append(n)
        for m in graph.get(n, ()):
            if state.get(m) == 1:
                return stack[stack.index(m):] + [m]
            if m not in state:
                c = visit(m)
                if c:
                    return c
        stack.pop()
        state[n] = 2
        return None

    for n in list(graph):
        if n not in state:
            c = visit(n)
            if c:
                return c
    return None


# --- the validator ------------------------------------------------------------
class Pack:
    def __init__(self, pid, dirpath):
        self.id, self.dir = pid, dirpath
        self.manifest = None
        self.referenced = set()      # files referenced by the pack (relative to dir)
        self.chapters = {}           # chapter id -> doc
        self.lessons = {}            # lesson id -> doc
        self.lesson_files = {}       # lesson id -> Path
        self.entities = {ns: {} for ns in NAMESPACES}   # ns -> id -> item
        self.tests = {}
        self.deps_closure = set()


def validate(root: Path, strict=False, check_assets=True) -> Report:
    rep = Report()
    content = root / "content"
    consts = schema_constants(root)
    if consts is None:
        rep.err("E-ENGINE", root / SCHEMA_DART, "cannot read kCurrentSchemaVersion / kMinReadableSchemaVersion")
    index = load(content / "journey_index.json", rep, "journeyIndex", consts)
    route = {}
    if index:
        last = 0
        for e in index.get("route", []):
            if not isinstance(e, dict):
                continue
            pid = e.get("prefectureId")
            if pid in route:
                rep.err("E-DUP-ID", "journey_index.json", f"duplicate prefectureId '{pid}'")
            route[pid] = e
            n = e.get("number")
            if isinstance(n, int):
                if n <= last:
                    rep.err("E-SCHEMA", "journey_index.json", f"route numbers must strictly increase (at '{pid}')")
                last = n
            m = e.get("map", {})
            for ax in ("x", "y"):
                if is_num(m.get(ax)) and not 0 <= m[ax] <= 1:
                    rep.err("E-SCHEMA", "journey_index.json", f"'{pid}' map.{ax} must be within 0..1")

    # ---- discover packs + manifests
    packs = {}
    packs_dir = content / "packs"
    for d in sorted(p for p in packs_dir.iterdir() if p.is_dir()) if packs_dir.exists() else []:
        pack = Pack(d.name, d)
        pack.manifest = load(d / "manifest.json", rep, "packManifest", consts)
        if not pack.manifest:
            continue
        if pack.manifest.get("packId") != d.name:
            rep.err("E-ROUTE", d / "manifest.json", f"packId '{pack.manifest.get('packId')}' must equal folder name '{d.name}'")
        packs[d.name] = pack

    # ---- dependencies
    graph = {}
    for pid, pack in packs.items():
        m = pack.manifest
        mf = pack.dir / "manifest.json"
        deps = [d for d in m.get("dependencies", []) if isinstance(d, str)]
        graph[pid] = deps
        for d in deps:
            if d == pid:
                rep.err("E-DEP", mf, "pack depends on itself")
            elif d not in packs:
                rep.err("E-DEP", mf, f"dependency '{d}' is not an installed pack")
        if consts and isinstance(m.get("engineSchemaMin"), int) and m["engineSchemaMin"] > consts[0]:
            rep.err("E-VERSION", mf, f"pack needs engine schema {m['engineSchemaMin']} but engine reads {consts[0]}")
        if m.get("type") == "prefecture" and index and pid not in route:
            rep.err("E-ROUTE", mf, f"prefecture pack '{pid}' is not in journey_index.json route (unreachable)")
    cyc = find_cycle(graph)
    if cyc:
        rep.err("E-DEP", "content/packs", "dependency cycle: " + " -> ".join(cyc))
    for pid, pack in packs.items():
        seen, todo = set(), list(graph.get(pid, []))
        while todo:
            d = todo.pop()
            if d in seen or d not in packs:
                continue
            seen.add(d)
            todo.extend(graph.get(d, []))
        pack.deps_closure = seen

    # ---- phase A: load everything and register every definition
    owners = {ns: {} for ns in NAMESPACES}     # ns -> id -> pack id
    aliases = {ns: {} for ns in NAMESPACES}    # ns -> previous id -> pack id
    for pid, pack in packs.items():
        m, base = pack.manifest, pack.dir
        files = m.get("knowledge", {}) if isinstance(m.get("knowledge"), dict) else {}
        pack.referenced.add("manifest.json")
        for ns, (kind, prefix, mkey) in NAMESPACES.items():
            rel = m.get("questionBank") if ns == "question" else files.get(mkey)
            if not rel:
                continue
            pack.referenced.add(rel)
            d = load(base / rel, rep, kind, consts)
            for it in (d or {}).get("items", []):
                if not isinstance(it, dict) or not isinstance(it.get("id"), str):
                    continue
                i = it["id"]
                if not i.startswith(prefix):
                    rep.err("E-ID-FORMAT", base / rel, f"id '{i}' must start with '{prefix}'")
                if ns == "kanji" and isinstance(it.get("char"), str) and i != prefix + it["char"]:
                    rep.err("E-ID-FORMAT", base / rel, f"kanji id '{i}' must be 'kanji_' + its character '{it['char']}'")
                if i in pack.entities[ns] or i in owners[ns]:
                    other = pid if i in pack.entities[ns] else owners[ns][i]
                    rep.err("E-DUP-ID", base / rel, f"duplicate {ns} id '{i}' (already defined in pack '{other}')")
                else:
                    owners[ns][i] = pid
                pack.entities[ns][i] = it
                for old in it.get("previousIds", []):
                    aliases[ns].setdefault(old, pid)
        for c in m.get("chapters", []) or []:
            if not isinstance(c, dict) or not isinstance(c.get("id"), str):
                continue
            cid = c["id"]
            if cid in pack.chapters:
                rep.err("E-DUP-ID", base / "manifest.json", f"duplicate chapter id '{cid}'")
            pack.referenced.add(c.get("file", ""))
            cd = load(base / c.get("file", "-"), rep, "chapter", consts)
            if not cd:
                continue
            pack.chapters[cid] = cd
            if cd.get("id") != cid:
                rep.err("E-ID-FORMAT", base / c["file"], f"chapter file id '{cd.get('id')}' does not match manifest id '{cid}'")
            for l in cd.get("lessons", []) or []:
                if not isinstance(l, dict) or not isinstance(l.get("id"), str):
                    continue
                lid = l["id"]
                if lid in pack.lessons:
                    rep.err("E-DUP-ID", base / c["file"], f"duplicate lesson id '{lid}' in pack '{pid}'")
                pack.referenced.add(l.get("file", ""))
                ld = load(base / l.get("file", "-"), rep, "lesson", consts)
                if ld:
                    pack.lessons[lid] = ld
                    pack.lesson_files[lid] = base / l["file"]
                    if ld.get("id") != lid:
                        rep.err("E-ID-FORMAT", base / l["file"], f"lesson file id '{ld.get('id')}' does not match chapter id '{lid}'")
                    seen_cards = set()
                    for cdx in ld.get("cards", []) or []:
                        if isinstance(cdx, dict) and isinstance(cdx.get("id"), str):
                            if cdx["id"] in seen_cards:
                                rep.err("E-DUP-ID", base / l["file"], f"duplicate card id '{cdx['id']}' in lesson '{lid}'")
                            seen_cards.add(cdx["id"])
        rd = m.get("reading")
        if isinstance(rd, dict) and isinstance(rd.get("id"), str) and isinstance(rd.get("file"), str):
            pack.referenced.add(rd["file"])
            if rd["id"] in pack.lessons:
                rep.err("E-DUP-ID", base / "manifest.json", f"reading id '{rd['id']}' collides with a lesson id")
            ld = load(base / rd["file"], rep, "lesson", consts)
            if ld:
                pack.lessons[rd["id"]] = ld
                pack.lesson_files[rd["id"]] = base / rd["file"]
                if ld.get("id") != rd["id"]:
                    rep.err("E-ID-FORMAT", base / rd["file"], f"reading file id '{ld.get('id')}' does not match manifest id '{rd['id']}'")
        for t in m.get("tests", []) or []:
            if isinstance(t, dict) and isinstance(t.get("id"), str):
                if t["id"] in pack.tests:
                    rep.err("E-DUP-ID", base / "manifest.json", f"duplicate test id '{t['id']}'")
                pack.tests[t["id"]] = t
        if m.get("cover"):
            pack.referenced.add(m["cover"])
        for a in m.get("assets", []) or []:
            pack.referenced.add(a)

    # alias collisions
    for ns, amap in aliases.items():
        for old, pid in amap.items():
            if old in owners[ns]:
                rep.err("E-DUP-ID", f"pack {pid}", f"previousId '{old}' collides with a live {ns} id")

    # ---- phase B: references
    def visible(pack, ns):
        s = set(pack.entities[ns])
        for d in pack.deps_closure:
            s |= set(packs[d].entities[ns])
        return s

    def need(pack, ns, i, file, where):
        if not isinstance(i, str):
            return
        if i not in visible(pack, ns):
            hint = ""
            if i in owners[ns]:
                hint = f" (defined in pack '{owners[ns][i]}' - add it to dependencies)"
            rep.err("E-REF", file, f"{where}: unknown {ns} id '{i}'{hint}")

    def ref_any(pack, i, file, where):
        for prefix, ns in PREFIX_TO_NS.items():
            if isinstance(i, str) and i.startswith(prefix):
                need(pack, ns, i, file, where)
                return
        rep.err("E-REF", file, f"{where}: '{i}' does not look like any known id")

    for pid, pack in packs.items():
        base = pack.dir
        kfile = lambda ns: base / (pack.manifest.get("questionBank") if ns == "question" else (pack.manifest.get("knowledge") or {}).get(NAMESPACES[ns][2], "-"))
        for i, it in pack.entities["kanji"].items():
            for c in it.get("components", []) or []:
                need(pack, "radical", c.get("radical"), kfile("kanji"), f"{i}.components")
            for r in it.get("relatedKanji", []) or []:
                need(pack, "kanji", r, kfile("kanji"), f"{i}.relatedKanji")
        for i, it in pack.entities["radical"].items():
            for r in it.get("exampleKanji", []) or []:
                need(pack, "kanji", r, kfile("radical"), f"{i}.exampleKanji")
        for i, it in pack.entities["vocab"].items():
            for r in it.get("kanji", []) or []:
                need(pack, "kanji", r, kfile("vocab"), f"{i}.kanji")
            for r in it.get("exampleSentences", []) or []:
                need(pack, "sentence", r, kfile("vocab"), f"{i}.exampleSentences")
        for i, it in pack.entities["sentence"].items():
            f = kfile("sentence")
            check_markup(it.get("jp", ""), f"{i}.jp", f, rep)
            for t in it.get("tokens", []) or []:
                if "vocab" in t:
                    need(pack, "vocab", t["vocab"], f, f"{i}.tokens")
                if "grammar" in t:
                    need(pack, "grammar", t["grammar"], f, f"{i}.tokens")
            for r in it.get("grammar", []) or []:
                need(pack, "grammar", r, f, f"{i}.grammar")
            for r in it.get("kanji", []) or []:
                need(pack, "kanji", r, f, f"{i}.kanji")
        for i, it in pack.entities["story"].items():
            f = kfile("story")
            for n, pg in enumerate(it.get("pages", []) or []):
                check_markup(pg.get("text", ""), f"{i}.pages[{n}]", f, rep)
            for r in it.get("kanji", []) or []:
                need(pack, "kanji", r, f, f"{i}.kanji")
        for i, it in pack.entities["question"].items():
            f = kfile("question")
            ids = [c.get("id") for c in it.get("choices", []) if isinstance(c, dict)]
            if len(ids) < 2 or len(set(ids)) != len(ids):
                rep.err("E-SCHEMA", f, f"{i}: needs >= 2 choices with unique ids")
            if it.get("answer") not in ids:
                rep.err("E-REF", f, f"{i}: answer '{it.get('answer')}' is not one of the choice ids")
            for r in it.get("refs", []) or []:
                ref_any(pack, r, f, f"{i}.refs")

        # lessons
        core_seen = {}
        for lid, ld in pack.lessons.items():
            f = pack.lesson_files.get(lid, base / "lessons" / f"{lid}.json")
            if ld.get("status") == "draft":
                rep.warn("W-DRAFT", f, f"lesson '{lid}' is a draft stub - replace it with the real lesson")
            for ns, key in (("kanji", "coreKanji"), ("kanji", "encounterKanji")):
                for r in ld.get(key, []) or []:
                    need(pack, ns, r, f, f"{lid}.{key}")
            for r in ld.get("coreKanji", []) or []:
                core_seen.setdefault(r, []).append(lid)
            for card in ld.get("cards", []) or []:
                if not isinstance(card, dict):
                    continue
                cid = card.get("id", "?")
                blocks = card.get("blocks", [])
                if isinstance(blocks, list) and not blocks:
                    rep.err("E-SCHEMA", f, f"card '{cid}': has no blocks")
                for n, b in enumerate(blocks if isinstance(blocks, list) else []):
                    where = f"{lid}/{cid}.blocks[{n}]"
                    t = b.get("type") if isinstance(b, dict) else None
                    if t not in BLOCKS:
                        rep.err("E-SCHEMA", f, f"{where}: unknown block type {t!r}")
                        continue
                    check_shape(b, BLOCKS[t], where, f, rep)
                    for fld in MARKUP_BLOCK_FIELDS.get(t, []):
                        v = b.get(fld)
                        for s in (v if isinstance(v, list) else [v]):
                            if isinstance(s, str):
                                check_markup(s, f"{where}.{fld}", f, rep)
                    for fld, ns in BLOCK_REFS.get(t, []):
                        v = b.get(fld)
                        for r in (v if isinstance(v, list) else [v]):
                            need(pack, ns, r, f, f"{where}.{fld}")
            nxt = (ld.get("completion") or {}).get("nextChapter")
            if nxt:
                p_, _, c_ = nxt.partition("/")
                if p_ not in packs or c_ not in packs[p_].chapters:
                    rep.err("E-REF", f, f"{lid}.completion.nextChapter '{nxt}' does not exist")
        for r, lessons in core_seen.items():
            if len(lessons) > 1:
                rep.warn("W-CORE-DUP", pid, f"{r} is a core kanji of several lessons: {', '.join(lessons)}")

        # files + assets
        for rel in sorted(pack.referenced):
            if rel and not (base / rel).is_file():
                rep.err("E-FILE", base / "manifest.json", f"referenced file '{rel}' does not exist")
        for fp in sorted(base.rglob("*")):
            if fp.is_file() and fp.relative_to(base).as_posix() not in pack.referenced:
                rep.warn("W-ORPHAN", fp, "file is not referenced by the pack manifest")

        # tests
        tests = pack.manifest.get("tests") or []
        if tests and not pack.manifest.get("questionBank"):
            rep.err("E-REF", base / "manifest.json", "tests declared but no questionBank")
        for t in tests:
            if not isinstance(t, dict):
                continue
            if isinstance(t.get("passRatio"), (int, float)) and not 0 < t["passRatio"] <= 1:
                rep.err("E-SCHEMA", base / "manifest.json", f"test '{t.get('id')}': passRatio must be in (0, 1]")
            tags = set(t.get("tags", []) or [])
            pool = [q for q in pack.entities["question"].values() if not tags or tags & set(q.get("tags", []) or [])]
            quotas = t.get("quotas")
            if quotas is not None:
                if not isinstance(quotas, dict) or not all(isinstance(k, str) and isinstance(v, int) and not isinstance(v, bool) and v > 0 for k, v in quotas.items()):
                    rep.err("E-SCHEMA", base / "manifest.json", f"test '{t.get('id')}': quotas must map category -> positive integer")
                else:
                    if isinstance(t.get("questionCount"), int) and sum(quotas.values()) != t["questionCount"]:
                        rep.err("E-SCHEMA", base / "manifest.json", f"test '{t.get('id')}': quotas add up to {sum(quotas.values())}, questionCount is {t['questionCount']}")
                    for cat, need_n in quotas.items():
                        have = sum(1 for q in pool if q.get("category") == cat)
                        if have < need_n:
                            rep.err("E-SCHEMA", base / "manifest.json", f"test '{t.get('id')}': category '{cat}' needs {need_n} questions but the bank has {have}")
                    for q in pool:
                        if q.get("category") not in quotas:
                            rep.warn("W-CATEGORY", base / "manifest.json", f"question '{q.get('id')}' has category {q.get('category')!r} which no quota uses")
            if isinstance(t.get("questionCount"), int) and len(pool) < t["questionCount"]:
                rep.warn("W-TEST-POOL", base / "manifest.json", f"test '{t.get('id')}' wants {t['questionCount']} questions but the bank only has {len(pool)} matching")

    # ---- unlock rules
    pref_graph = {}
    for pid, pack in packs.items():
        rule_sets = [("manifest", pack.manifest.get("unlock", []) or [], pack.dir / "manifest.json"),
                     ("completion", pack.manifest.get("completion", []) or [], pack.dir / "manifest.json")]
        rdm = pack.manifest.get("reading")
        if isinstance(rdm, dict):
            rule_sets.append(("reading", rdm.get("unlock", []) or [], pack.dir / "manifest.json"))
        for tdef in pack.manifest.get("tests", []) or []:
            if isinstance(tdef, dict):
                rule_sets.append((f"test {tdef.get('id')}", tdef.get("unlock", []) or [], pack.dir / "manifest.json"))
        chap_graph = {}
        for cid, cd in pack.chapters.items():
            rs = cd.get("unlock", []) or []
            rule_sets.append((f"chapter {cid}", rs, pack.dir / "chapters" / f"{cid}.json"))
            chap_graph[cid] = [r["ref"].partition("/")[2] for r in rs
                               if isinstance(r, dict) and r.get("type") == "chapterComplete"
                               and str(r.get("ref", "")).partition("/")[0] == pid]
        cyc = find_cycle(chap_graph)
        if cyc:
            rep.err("E-UNLOCK", pack.dir, "chapter unlock cycle: " + " -> ".join(cyc))
        for label, rules, f in rule_sets:
            for r in rules:
                if not isinstance(r, dict) or not isinstance(r.get("ref"), str):
                    continue
                t, ref = r.get("type"), r["ref"]
                target = ref if t == "prefectureComplete" else ref.partition("/")[0]
                if t != "prefectureComplete" and "/" not in ref:
                    rep.err("E-UNLOCK", f, f"{label}: '{ref}' must look like packId/id")
                    continue
                if target not in route and target not in packs:
                    rep.err("E-REF", f, f"{label}: rule points at unknown prefecture '{target}'")
                    continue
                if target not in packs:
                    rep.warn("W-UNLOCK-NOT-INSTALLED", f, f"{label}: '{target}' is not installed, so this stays locked until it is")
                    continue
                tp, rest = packs[target], ref.partition("/")[2]
                ok = {"prefectureComplete": True, "chapterComplete": rest in tp.chapters,
                      "lessonComplete": rest in tp.lessons, "testPassed": rest in tp.tests}.get(t, True)
                if not ok:
                    rep.err("E-REF", f, f"{label}: {t} '{ref}' does not exist")
                if label == "manifest" and target != pid:
                    pref_graph.setdefault(pid, set()).add(target)
    cyc = find_cycle({k: list(v) for k, v in pref_graph.items()})
    if cyc:
        rep.err("E-UNLOCK", "content/packs", "prefecture unlock cycle: " + " -> ".join(cyc))

    # ---- pubspec asset list
    if check_assets:
        expected = asset_block(root)
        ps = root / "pubspec.yaml"
        if not ps.exists():
            rep.err("E-ASSET-SYNC", ps, "pubspec.yaml not found")
        else:
            m = re.search(re.escape(ASSET_BEGIN) + r"\n(.*?)" + re.escape(ASSET_END), ps.read_text(encoding="utf-8"), re.S)
            if not m:
                rep.err("E-ASSET-SYNC", ps, "generated asset block markers not found")
            elif m.group(1).rstrip("\n") != "\n".join(expected):
                rep.err("E-ASSET-SYNC", ps, "asset list is out of date - run: python3 tool/validate_content.py --sync-assets")
    if strict:
        rep.errors.extend(rep.warnings)
        rep.warnings = []
    return rep


def asset_block(root: Path):
    """Flutter asset entries are NOT recursive: list every directory holding files."""
    content = root / "content"
    dirs = sorted({p.parent.relative_to(root).as_posix() + "/" for p in content.rglob("*") if p.is_file()})
    return [f"    - {d}" for d in dirs]


def sync_assets(root: Path):
    ps = root / "pubspec.yaml"
    text = ps.read_text(encoding="utf-8")
    block = ASSET_BEGIN + "\n" + "\n".join(asset_block(root)) + "\n" + ASSET_END
    new, n = re.subn(re.escape(ASSET_BEGIN) + r".*?" + re.escape(ASSET_END), lambda _: block, text, flags=re.S)
    if n != 1:
        sys.exit("pubspec.yaml must contain exactly one generated-assets block")
    ps.write_text(new, encoding="utf-8")
    print(f"pubspec.yaml asset list updated ({len(asset_block(root))} directories)")


def emit(rep: Report):
    gh = os.environ.get("GITHUB_ACTIONS") == "true"
    for level, items in (("error", rep.errors), ("warning", rep.warnings)):
        for code, file, msg in items:
            if gh:
                print(f"::{level} file={file},title={code}::{msg}")
            print(f"{level.upper():7} {code:22} {file}: {msg}")
    print(f"\nContent validation: {len(rep.errors)} error(s), {len(rep.warnings)} warning(s)")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--strict", action="store_true", help="treat warnings as errors")
    ap.add_argument("--sync-assets", action="store_true", help="rewrite the pubspec asset block")
    a = ap.parse_args()
    root = Path(a.root)
    if a.sync_assets:
        sync_assets(root)
    rep = validate(root, strict=a.strict)
    emit(rep)
    sys.exit(1 if rep.errors else 0)


if __name__ == "__main__":
    main()
