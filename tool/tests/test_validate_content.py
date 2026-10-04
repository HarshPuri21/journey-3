"""Tests for tool/validate_content.py. Run: python3 -m unittest discover -s tool/tests -v"""
import json, shutil, sys, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tool"))
import validate_content as vc  # noqa: E402


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        shutil.copytree(ROOT / "content", self.tmp / "content")
        shutil.copy(ROOT / "pubspec.yaml", self.tmp / "pubspec.yaml")
        (self.tmp / "lib/package_system/schema").mkdir(parents=True)
        shutil.copy(ROOT / vc.SCHEMA_DART, self.tmp / vc.SCHEMA_DART)
        self.pack = self.tmp / "content/packs/hokkaido"

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def edit(self, rel, fn):
        p = self.tmp / rel
        d = json.loads(p.read_text(encoding="utf-8"))
        fn(d)
        p.write_text(json.dumps(d, ensure_ascii=False), encoding="utf-8")

    def run_v(self, **kw):
        return vc.validate(self.tmp, **kw)

    def assertCode(self, code, **kw):
        rep = self.run_v(**kw)
        self.assertIn(code, rep.codes(), msg=str(rep.errors))
        return rep


class RealContent(Base):
    def test_shipped_content_is_clean(self):
        rep = self.run_v()
        self.assertEqual(rep.errors, [])
        # Completed installed content must be clean, including future package additions.
        self.assertEqual(rep.warnings, [])

    def test_hokkaido_package_shape(self):
        m = json.loads((self.pack / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual([c["id"] for c in m["chapters"]],
                         ["sapporo", "hakodate", "chitose", "otaru", "asahikawa", "biei", "furano", "kushiro", "noboribetsu"])
        q = json.loads((self.pack / "tests/questions.json").read_text(encoding="utf-8"))["items"]
        self.assertEqual(len(q), 60)
        self.assertEqual(m["tests"][0]["questionCount"], 30)
        self.assertEqual(sum(m["tests"][0]["quotas"].values()), 30)
        self.assertEqual(len(m["completionCriteria"]), 23)
        self.assertTrue(all(x["refs"] for x in q), "every question links to knowledge ids")


class Failures(Base):
    def setUp(self):
        super().setUp()
        # Synthetic negative cases create their own second pack.
        for folder in (self.tmp / "content/packs").iterdir():
            if folder.is_dir() and folder.name != "hokkaido":
                shutil.rmtree(folder)
        vc.sync_assets(self.tmp)

    def test_duplicate_id(self):
        self.edit("content/packs/hokkaido/knowledge/kanji.json", lambda d: d["items"].append(dict(d["items"][0])))
        self.assertCode("E-DUP-ID")

    def test_dangling_block_reference(self):
        def f(d): d["cards"][0]["blocks"].append({"type": "kanjiRef", "id": "kanji_空"})
        self.edit("content/packs/hokkaido/lessons/sapporo_l01.json", f)
        self.assertCode("E-REF")

    def test_unknown_block_type(self):
        def f(d): d["cards"][0]["blocks"].append({"type": "hologram"})
        self.edit("content/packs/hokkaido/lessons/sapporo_l01.json", f)
        self.assertCode("E-SCHEMA")

    def test_missing_required_field(self):
        self.edit("content/packs/hokkaido/knowledge/kanji.json", lambda d: d["items"][0].pop("meanings"))
        self.assertCode("E-SCHEMA")

    def test_missing_lesson_file(self):
        (self.pack / "lessons/sapporo_l01.json").unlink()
        self.assertCode("E-FILE")

    def test_missing_asset(self):
        (self.pack / "assets/cover.png").unlink()
        self.assertCode("E-FILE")

    def test_future_schema_version(self):
        self.edit("content/packs/hokkaido/knowledge/grammar.json", lambda d: d.update(schemaVersion=99))
        self.assertCode("E-VERSION")

    def test_engine_constant_mismatch_detected(self):
        p = self.tmp / vc.SCHEMA_DART
        p.write_text(p.read_text().replace("kCurrentSchemaVersion = 1", "kCurrentSchemaVersion = 0"))
        self.assertCode("E-VERSION")

    def test_missing_dependency(self):
        self.edit("content/packs/hokkaido/manifest.json", lambda d: d.update(dependencies=["atlantis"]))
        self.assertCode("E-DEP")

    def test_dependency_cycle(self):
        other = self.tmp / "content/packs/aomori"
        other.mkdir()
        (other / "manifest.json").write_text(json.dumps({
            "schemaVersion": 1, "kind": "packManifest", "packId": "aomori", "type": "prefecture",
            "contentVersion": 1, "engineSchemaMin": 1, "title": "青森", "dependencies": ["hokkaido"]}))
        self.edit("content/packs/hokkaido/manifest.json", lambda d: d.update(dependencies=["aomori"]))
        self.assertCode("E-DEP")

    def test_cross_pack_reference_needs_dependency(self):
        other = self.tmp / "content/packs/aomori"
        (other / "lessons").mkdir(parents=True)
        (other / "chapters").mkdir()
        (other / "manifest.json").write_text(json.dumps({
            "schemaVersion": 1, "kind": "packManifest", "packId": "aomori", "type": "prefecture",
            "contentVersion": 1, "engineSchemaMin": 1, "title": "青森", "dependencies": [],
            "chapters": [{"id": "aomori_city", "file": "chapters/aomori_city.json"}]}))
        (other / "chapters/aomori_city.json").write_text(json.dumps({
            "schemaVersion": 1, "kind": "chapter", "id": "aomori_city", "name": "青森市",
            "lessons": [{"id": "aomori_l01", "file": "lessons/aomori_l01.json"}]}))
        (other / "lessons/aomori_l01.json").write_text(json.dumps({
            "schemaVersion": 1, "kind": "lesson", "id": "aomori_l01", "number": 1, "title": "t",
            "cards": [{"id": "c1", "title": "t", "blocks": [{"type": "kanjiRef", "id": "kanji_北"}]}]}))
        rep = self.assertCode("E-REF")
        self.assertTrue(any("dependencies" in m for _, _, m in rep.errors))
        # ...and declaring the dependency fixes it
        self.edit("content/packs/aomori/manifest.json", lambda d: d.update(dependencies=["hokkaido"]))
        self.assertNotIn("E-REF", self.run_v().codes())

    def test_unlock_cycle(self):
        def f(d): d["unlock"] = [{"type": "chapterComplete", "ref": "hokkaido/asahikawa"}]
        self.edit("content/packs/hokkaido/chapters/hakodate.json", lambda d: d.update(unlock=[{"type": "chapterComplete", "ref": "hokkaido/asahikawa"}]))
        self.assertCode("E-UNLOCK")

    def test_broken_unlock_target(self):
        self.edit("content/packs/hokkaido/chapters/otaru.json", lambda d: d.update(unlock=[{"type": "chapterComplete", "ref": "hokkaido/nowhere"}]))
        self.assertCode("E-REF")

    def test_pack_not_in_route(self):
        self.edit("content/journey_index.json", lambda d: d.update(route=[r for r in d["route"] if r["prefectureId"] != "hokkaido"]))
        self.assertCode("E-ROUTE")

    def test_bad_markup(self):
        def f(d): d["cards"][0]["blocks"].append({"type": "text", "text": "broken {北海道|"})
        self.edit("content/packs/hokkaido/lessons/sapporo_l01.json", f)
        self.assertCode("E-MARKUP")

    def test_question_answer_must_be_a_choice(self):
        self.edit("content/packs/hokkaido/tests/questions.json", lambda d: d["items"][0].update(answer="z"))
        self.assertCode("E-REF")

    def test_stale_pubspec_assets(self):
        (self.pack / "extra").mkdir()
        (self.pack / "extra/x.json").write_text("{}")
        self.assertCode("E-ASSET-SYNC")

    def test_id_alias_must_not_collide(self):
        self.edit("content/packs/hokkaido/knowledge/kanji.json", lambda d: d["items"][0].update(previousIds=["kanji_海"]))
        self.assertCode("E-DUP-ID")

    def test_quotas_must_add_up_to_question_count(self):
        def f(d): d["tests"][0]["quotas"]["kanji"] = 4
        self.edit("content/packs/hokkaido/manifest.json", f)
        self.assertCode("E-SCHEMA")

    def test_quota_category_needs_enough_questions(self):
        def f(d):
            d["tests"][0]["quotas"] = {"kanji": 5, "radical": 5, "numbers": 5, "vocabulary": 5, "grammar": 5, "reading": 4, "bonus": 1}
        self.edit("content/packs/hokkaido/manifest.json", f)
        self.assertCode("E-SCHEMA")

    def test_missing_reading_file(self):
        (self.pack / "reading/hokkaido_reading.json").unlink()
        self.assertCode("E-FILE")

    def test_reading_unlock_must_resolve(self):
        def f(d): d["reading"]["unlock"] = [{"type": "chapterComplete", "ref": "hokkaido/nowhere"}]
        self.edit("content/packs/hokkaido/manifest.json", f)
        self.assertCode("E-REF")

    def test_test_unlock_must_resolve(self):
        def f(d): d["tests"][0]["unlock"] = [{"type": "lessonComplete", "ref": "hokkaido/ghost"}]
        self.edit("content/packs/hokkaido/manifest.json", f)
        self.assertCode("E-REF")

    def test_question_ref_must_exist(self):
        self.edit("content/packs/hokkaido/tests/questions.json", lambda d: d["items"][0]["refs"].append("kanji_空"))
        self.assertCode("E-REF")

    def test_uncounted_category_warns(self):
        self.edit("content/packs/hokkaido/tests/questions.json", lambda d: d["items"][0].update(category="mystery"))
        rep = self.run_v()
        self.assertIn("W-CATEGORY", {c for c, _, _ in rep.warnings})

    def test_reading_line_markup_checked(self):
        def f(d): d["cards"][0]["blocks"].append({"type": "readingLine", "jp": "{北海道|"})
        self.edit("content/packs/hokkaido/reading/hokkaido_reading.json", f)
        self.assertCode("E-MARKUP")

    def test_strict_turns_warnings_into_errors(self):
        (self.pack / "assets/notes.txt").write_text("orphan")
        rep = self.run_v(check_assets=False)
        self.assertIn("W-ORPHAN", {c for c, _, _ in rep.warnings})
        self.assertTrue(self.run_v(strict=True, check_assets=False).errors)


if __name__ == "__main__":
    unittest.main()
