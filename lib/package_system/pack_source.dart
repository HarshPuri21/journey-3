import 'package:flutter/services.dart';

/// Where content files come from. The engine never touches rootBundle or
/// dart:io directly, so tests (and a future downloader) can swap sources.
/// Paths are relative to the project root, e.g.
/// `content/packs/hokkaido/manifest.json`.
abstract class PackSource {
  Future<List<String>> listPackIds();
  Future<String> readString(String path);
  Future<bool> exists(String path);
}

const String kContentRoot = 'content';
const String kPacksRoot = 'content/packs';
const String kIndexPath = 'content/journey_index.json';

final RegExp _manifestPath = RegExp(r'^content/packs/([^/]+)/manifest\.json$');

/// Reads packs bundled as Flutter assets. Pack discovery uses the asset
/// manifest, so dropping a new folder into content/packs/ (and running
/// `tool/validate_content.py --sync-assets`) is all it takes to install one.
class AssetPackSource implements PackSource {
  AssetPackSource({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;
  Set<String>? _assets;

  Future<Set<String>> _list() async {
    final cached = _assets;
    if (cached != null) return cached;
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    return _assets = manifest.listAssets().toSet();
  }

  @override
  Future<List<String>> listPackIds() async {
    final ids = <String>[];
    for (final a in await _list()) {
      final m = _manifestPath.firstMatch(a);
      if (m != null) ids.add(m.group(1)!);
    }
    ids.sort();
    return ids;
  }

  @override
  Future<String> readString(String path) => _bundle.loadString(path);

  @override
  Future<bool> exists(String path) async => (await _list()).contains(path);
}

/// In-memory source: path -> file text. Used by tests to install fixture packs.
class MemoryPackSource implements PackSource {
  MemoryPackSource(Map<String, String> files) : files = {...files};
  final Map<String, String> files;

  @override
  Future<List<String>> listPackIds() async {
    final ids = <String>[];
    for (final p in files.keys) {
      final m = _manifestPath.firstMatch(p);
      if (m != null) ids.add(m.group(1)!);
    }
    ids.sort();
    return ids;
  }

  @override
  Future<String> readString(String path) async {
    final f = files[path];
    if (f == null) throw StateError('MemoryPackSource: no file $path');
    return f;
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);
}
