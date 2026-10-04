# Prefecture package blueprint

`content/packs/hokkaido/` is the reference package. Every later prefecture (Aomori, Iwate, ...) is built the
same way: **copy the folder, change the data, run the validator.** A package contains data only - never code.

```
content/packs/<id>/
  manifest.json              identity, dependencies, unlock/completion rules, chapters, reading, tests
  chapters/<city>.json       one per city/location (sequential unlock chain)
  lessons/<city>_l01.json    the lesson(s) of that location: ordered cards made of blocks
  reading/<id>_reading.json  the cumulative Reading Journey (a lesson document)
  knowledge/                 NEW entities only: kanji, radicals, vocabulary, grammar, sentences
  tests/questions.json       the question bank (60 questions)
  assets/                    cover image etc.
```

## Making the next package (e.g. Aomori)

1. **Route.** Make sure the prefecture is in `content/journey_index.json` (`prefectureId`, `number`, names, map x/y).
2. **Copy** `content/packs/hokkaido` to `content/packs/aomori`. Delete the Hokkaido lessons, chapters, questions and
   all *entities* (see rule 5) - keep the structure.
3. **manifest.json**
   * `packId` = folder name = route `prefectureId`.
   * `dependencies: ["hokkaido"]` whenever you reuse a Hokkaido kanji/radical/vocabulary/grammar id.
   * `unlock: [{"type":"prefectureComplete","ref":"hokkaido"}]` - this is what makes Aomori appear after Hokkaido.
   * `completion: [{"type":"testPassed","ref":"aomori/aomori_final"}]`.
   * `chapters`: city ids in route order, each with a `map` position (0..1) on the prefecture mini-map. Keep roughly
     0.25 apart horizontally and 0.2 vertically so nodes do not overlap.
   * `reading` and `tests` exactly like Hokkaido (the reading unlocks after the last chapter, the test after the reading).
   * `completionCriteria`: the "after this prefecture you can..." list.
4. **Each city** = a chapter file (`unlock` = previous chapter complete) + a lesson file. A city lesson follows
   the Hokkaido pattern (see `lessons/sapporo_l01.json`): content cards, then **the city-name card**.
5. **Entities.** Define each id exactly once in the whole journey. If Hokkaido already defines `kanji_北`, `radical_sanzui`
   or `grammar_particle_wa`, just *reference* it (and declare the dependency). Define only what is new.
6. **Reading** - cards of `readingLine` blocks (Japanese with `{漢字|かんじ}` ruby + English), a vocabulary `bullets`
   list per card, an "Assisted Reading Mode" card, and a final scrollable "Things to Remember" card.
7. **Test** - 60 questions, each with `category` and `refs`. The test draws 30 per attempt, 5 from each of the
   categories in `quotas`, preferring questions not seen last time.
8. **Validate and sync**
   ```
   python3 tool/validate_content.py --sync-assets
   ```
   Fix every error. `W-DRAFT` warnings list lessons that are still placeholders. Push; CI re-checks everything.

## The city-name card (every city lesson has one)

Each city's kanji get their components explained, using reusable blocks only:

```json
{"id": "inside_hakodate", "title": "Inside 函館", "kind": "content", "scroll": true, "blocks": [
  {"type": "text", "text": "Look inside the name of {函館|はこだて}. Each kanji can be broken into parts - and parts are clues."},
  {"type": "kanjiRef", "id": "kanji_函", "show": ["meaning", "readings", "components"]},
  {"type": "kanjiRef", "id": "kanji_館", "show": ["meaning", "readings", "components"]},
  {"type": "radicalRef", "id": "radical_ukebako"},
  {"type": "radicalRef", "id": "radical_shoku"},
  {"type": "callout", "tone": "tip", "text": "One sentence that links the parts to the meaning. Components are clues, not magic definitions."}
]}
```
The component lines come from the **kanji entity** (`components: [{radical, role, note}]`, role = meaning / sound /
classifier / shape), and the radical tile shows "Seen in:" automatically - so the same radical links to every kanji
that uses it, in any installed package.

## Draft lessons

`"status": "draft"` marks a placeholder lesson. It still plays (so unlocking can be tested), shows "(draft)" in the
chapter list and raises a `W-DRAFT` validator warning. Delete the field when the lesson is final.

## Block reference

| type | fields |
|---|---|
| `heading` | `text`, `level` (1-3) |
| `text` | `text` |
| `display` | `jp`, `reading`, `romaji`, `gloss` - big centred word |
| `callout` | `text`, `title`, `tone` (info / tip / warning / quote) |
| `bullets` | `items[]` |
| `divider` | - |
| `kanjiRef` | `id`, `show` (meaning, readings, components) |
| `kanjiRow` | `ids[]`, `show` - compact tiles |
| `radicalRef` `vocabRef` `grammarRef` | `id` |
| `sentenceRef` | `id`, `showBreakdown` |
| `readingLine` | `jp` (with ruby), `en` - one line of a reading passage |

Text fields use `{base|reading}` for furigana and `**bold**`. A card with `"scroll": true` (use it for the last
"Things to Remember" card) starts at the top and scrolls; other cards are centred when they fit.

## Ids

| thing | pattern |
|---|---|
| kanji | `kanji_` + the character (`kanji_海`) |
| radical | `radical_` + romaji name (`radical_sanzui`) |
| vocabulary | `vocab_` + the word (`vocab_北海道`) |
| grammar | `grammar_` + slug |
| sentence | `sent_` + slug |
| question | `q_001` ... |
| chapter / lesson / card / test | any stable slug; lessons are `<city>_l01`; never use a list position |

Renamed something? Add the old id to `previousIds`; saved progress follows it.

## Checklist before pushing a package

- [ ] validator: 0 errors; every remaining warning understood
- [ ] route entry + `unlock` rule point at the previous prefecture
- [ ] every city lesson has its city-name card; no lesson is left `draft` unless intended
- [ ] 60 questions, 6 categories with at least 5 each, `refs` on every question, `quotas` adding up to `questionCount`
- [ ] reading cards have ruby on every kanji word, English on every sentence
- [ ] kanji/radicals already defined by an earlier package are referenced, not redefined
