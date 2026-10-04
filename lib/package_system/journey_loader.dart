import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/json_reader.dart';
import '../knowledge/grammar/grammar.dart';
import '../knowledge/kanji/kanji.dart';
import '../knowledge/knowledge_repository.dart';
import '../knowledge/radicals/radical.dart';
import '../knowledge/sentences/sentence.dart';
import '../knowledge/vocabulary/vocabulary.dart';
import '../lessons/lesson_models.dart';
import '../stories/story.dart';
import '../tests/question.dart';
import 'journey_catalog.dart';
import 'pack_models.dart';
import 'pack_source.dart';
import 'schema/schema_migrator.dart';
import 'schema/schema_version.dart';

/// Reads the route index and every installed pack from a [PackSource].
///
/// Principle: an incomplete or partly broken Journey is still a valid
/// Journey. A pack that fails to load (bad schema, missing dependency, ...) is
/// skipped with a [LoadDiagnostic]; one broken lesson/knowledge file drops
/// only that file. Only a missing/invalid route index is fatal.
///
/// NOTE (phase 1): each pack is loaded eagerly, lessons included. Loading is
/// already per-pack and async, so lazy per-chapter loading can be added later
/// without changing this API.
class JourneyLoader {
  JourneyLoader(this.source, {SchemaMigrator? migrator})
      : migrator = migrator ?? SchemaMigrator();

  final PackSource source;
  final SchemaMigrator migrator;

  Future<Map<String, dynamic>> _readDoc(String path, String kind) async {
    final decoded = jsonDecode(await source.readString(path));
    final doc = migrator.migrate(asMap(decoded, path), where: path);
    if (doc['kind'] != kind) {
      throw ContentFormatException('$path: expected kind "$kind", found "${doc['kind']}"');
    }
    return doc;
  }

  Future<JourneyCatalog> load() async {
    final diags = <LoadDiagnostic>[];
    final index = JourneyIndex.fromJson(await _readDoc(kIndexPath, 'journeyIndex'));

    final manifests = <String, PackManifest>{};
    for (final id in await source.listPackIds()) {
      try {
        final m = PackManifest.fromJson(await _readDoc('$kPacksRoot/$id/manifest.json', 'packManifest'));
        if (m.packId != id) {
          throw ContentFormatException('packId "${m.packId}" does not match folder "$id"');
        }
        if (m.engineSchemaMin > kCurrentSchemaVersion) {
          throw ContentFormatException(
              'needs engine schema ${m.engineSchemaMin} (this app reads $kCurrentSchemaVersion)');
        }
        manifests[id] = m;
      } catch (e) {
        diags.add(LoadDiagnostic(id, 'pack skipped: $e'));
      }
    }

    final loaded = <String, LoadedPack>{};
    final failed = <String>{};

    Future<bool> ensure(String id, List<String> stack) async {
      if (loaded.containsKey(id)) return true;
      if (failed.contains(id)) return false;
      final m = manifests[id];
      if (m == null) return false;
      if (stack.contains(id)) {
        diags.add(LoadDiagnostic(id, 'pack skipped: dependency cycle ${[...stack, id].join(' -> ')}'));
        failed.add(id);
        return false;
      }
      for (final dep in m.dependencies) {
        if (!await ensure(dep, [...stack, id])) {
          diags.add(LoadDiagnostic(id, 'pack skipped: dependency "$dep" is not available'));
          failed.add(id);
          return false;
        }
      }
      try {
        loaded[id] = await _loadPack(m, diags);
        return true;
      } catch (e) {
        diags.add(LoadDiagnostic(id, 'pack skipped: $e'));
        failed.add(id);
        return false;
      }
    }

    for (final id in manifests.keys.toList()..sort()) {
      await ensure(id, const []);
    }

    final routeIds = index.route.map((r) => r.prefectureId).toSet();
    for (final p in loaded.values) {
      if (p.manifest.type == 'prefecture' && !routeIds.contains(p.id)) {
        diags.add(LoadDiagnostic(p.id, 'installed but not in journey_index.json - it is unreachable'));
      }
    }

    final repoDiags = <String>[];
    final knowledge = InMemoryKnowledgeRepository(loaded.values, diagnostics: repoDiags);
    diags.addAll(repoDiags.map((m) => LoadDiagnostic('knowledge', m)));
    if (kDebugMode && diags.isNotEmpty) {
      debugPrint('Journey load diagnostics:\n${diags.join('\n')}');
    }
    return JourneyCatalog(index: index, packs: loaded, knowledge: knowledge, diagnostics: diags);
  }

  Future<List<T>> _items<T>(PackManifest m, String? rel, String kind,
      T Function(Map<String, dynamic>) parse, List<LoadDiagnostic> diags) async {
    if (rel == null) return <T>[];
    try {
      final doc = await _readDoc('$kPacksRoot/${m.packId}/$rel', kind);
      final out = <T>[];
      for (final raw in asList(doc['items'], rel)) {
        try {
          out.add(parse(asMap(raw, rel)));
        } catch (e) {
          diags.add(LoadDiagnostic(m.packId, '$rel: item skipped: $e'));
        }
      }
      return out;
    } catch (e) {
      diags.add(LoadDiagnostic(m.packId, '$rel skipped: $e'));
      return <T>[];
    }
  }

  Future<LoadedPack> _loadPack(PackManifest m, List<LoadDiagnostic> diags) async {
    final base = '$kPacksRoot/${m.packId}';
    final k = m.knowledge;

    final chapters = <Chapter>[];
    final lessons = <String, Lesson>{};
    for (final ref in m.chapters) {
      try {
        final cd = await _readDoc('$base/${ref.file}', 'chapter');
        final lessonRefs = objList(cd, 'lessons')
            .map((l) => LessonRef(reqStr(l, 'id', 'lesson ref'), reqStr(l, 'file', 'lesson ref')))
            .toList(growable: false);
        chapters.add(Chapter(
          packId: m.packId,
          id: reqStr(cd, 'id', ref.file),
          name: reqStr(cd, 'name', ref.file),
          nameEn: optStr(cd, 'nameEn'),
          reading: optStr(cd, 'reading'),
          summary: optStr(cd, 'summary'),
          sequential: (optStr(cd, 'lessonOrder') ?? 'sequential') != 'free',
          lessonRefs: lessonRefs,
          unlock: UnlockRule.list(cd, 'unlock'),
          map: ref.map,
        ));
        for (final lr in lessonRefs) {
          try {
            final ld = await _readDoc('$base/${lr.file}', 'lesson');
            lessons[lr.id] = Lesson.fromJson(m.packId, ld);
          } catch (e) {
            diags.add(LoadDiagnostic(m.packId, 'lesson "${lr.id}" skipped: $e'));
          }
        }
      } catch (e) {
        diags.add(LoadDiagnostic(m.packId, 'chapter "${ref.id}" skipped: $e'));
      }
    }

    final rd = m.reading;
    if (rd != null) {
      try {
        final lesson = Lesson.fromJson(m.packId, await _readDoc('$base/${rd.file}', 'lesson'));
        lessons[lesson.id] = lesson;
      } catch (e) {
        diags.add(LoadDiagnostic(m.packId, 'reading "${rd.id}" skipped: $e'));
      }
    }

    return LoadedPack(
      manifest: m,
      chapters: chapters,
      lessons: lessons,
      kanji: await _items(m, k['kanji'], 'kanjiSet', Kanji.fromJson, diags),
      radicals: await _items(m, k['radicals'], 'radicalSet', Radical.fromJson, diags),
      vocabulary: await _items(m, k['vocabulary'], 'vocabularySet', Vocabulary.fromJson, diags),
      grammar: await _items(m, k['grammar'], 'grammarSet', GrammarPoint.fromJson, diags),
      sentences: await _items(m, k['sentences'], 'sentenceSet', Sentence.fromJson, diags),
      stories: await _items(m, k['stories'], 'storySet', Story.fromJson, diags),
      questions: await _items(m, m.questionBank, 'questionBank', Question.fromJson, diags),
    );
  }
}
