# Content schema (version 1)

All documents are UTF-8 JSON with `schemaVersion` (int) and `kind`. Source of truth for exact shapes:
`SPECS` and `BLOCKS` in `tool/validate_content.py`.

| kind | file | key fields |
|---|---|---|
| `journeyIndex` | `content/journey_index.json` | `route[]`: `prefectureId`, `number`, `name`, `nameEn`, `map{x,y}` (0..1) |
| `packManifest` | `packs/<id>/manifest.json` | `packId`, `type` (prefecture/knowledge), `dependencies[]`, `unlock[]`, `completion[]`, `completionCriteria[]`, `chapters[]`, `reading{id,title,file,unlock}`, `knowledge{}`, `questionBank`, `tests[]` (`questionCount`, `passRatio`, `quotas{category:n}`, `unlock[]`), `assets[]`, `engineSchemaMin`, `contentVersion` |
| `chapter` | `chapters/*.json` | `id`, `name`, `lessons[]`, `unlock[]`, `lessonOrder` |
| `lesson` | `lessons/*.json`, `reading/*.json` | `id`, `status` (draft/final), `coreKanji[]`, `encounterKanji[]`, `cards[]` (`id`, `title`, `kind`, `scroll`, `blocks[]`), `completion` |
| `kanjiSet` `radicalSet` `vocabularySet` `grammarSet` `sentenceSet` `storySet` `questionBank` | `knowledge/*`, `tests/*` | `items[]` |

Questions carry `category` (used by test quotas) and `refs[]` (knowledge ids for targeted review).

**Ids:** `kanji_<char>`, `radical_*`, `vocab_*`, `grammar_*`, `sent_*`, `story_*`, `q_*`. Chapters, lessons,
cards and tests use any stable slug. Qualified refs: `packId/localId`. Old ids go in `previousIds`.

**Blocks:** `heading` `text` `display` `callout` `bullets` `divider` `kanjiRef` `kanjiRow` `radicalRef`
`vocabRef` `sentenceRef` `grammarRef` `readingLine`.

**Inline markup:** `{漢字|かんじ}` ruby, `**bold**`.

**Unlock rules:** `{type, ref}` with `prefectureComplete` (ref `hokkaido`), `chapterComplete`
(`hokkaido/sapporo`), `lessonComplete` (`hokkaido/sapporo_l01`), `testPassed` (`hokkaido/hokkaido_final`).

## Evolving the schema

1. Bump `kCurrentSchemaVersion` in `lib/package_system/schema/schema_version.dart`.
2. Register `N -> N+1` in `SchemaMigrator` (the migration must return a valid N+1 document).
3. Update the specs in `tool/validate_content.py`; old-version documents then produce a `W-MIGRATE` warning
   until re-saved.
4. Raise `kMinReadableSchemaVersion` only when you are ready to drop old documents.
5. Add a test in `test/schema_migrator_test.dart`.

Additive changes (new optional fields, new block types) do **not** need a version bump; older apps ignore unknown fields and show a placeholder for unknown block types. Bump the version only when existing documents would become invalid.
