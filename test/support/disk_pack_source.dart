import 'dart:io';

import 'package:n5_kanji_journey/package_system/pack_source.dart';

/// Reads the real `content/` folder from disk (tests run from the project
/// root), so tests exercise the exact files that ship.
class DiskPackSource implements PackSource {
  DiskPackSource([this.root = '.']);
  final String root;

  File _f(String path) => File('$root/$path');

  @override
  Future<List<String>> listPackIds() async {
    final dir = Directory('$root/$kPacksRoot');
    if (!dir.existsSync()) return [];
    final ids = <String>[];
    for (final e in dir.listSync()) {
      if (e is Directory && File('${e.path}/manifest.json').existsSync()) {
        ids.add(e.uri.pathSegments.where((s) => s.isNotEmpty).last);
      }
    }
    ids.sort();
    return ids;
  }

  @override
  Future<String> readString(String path) => _f(path).readAsString();

  @override
  Future<bool> exists(String path) async => _f(path).existsSync();
}

/// Every text file under content/ as a path -> text map (to build a
/// MemoryPackSource that can then be edited per test).
Map<String, String> readAllContent([String root = '.']) {
  final out = <String, String>{};
  final base = Directory('$root/content');
  for (final e in base.listSync(recursive: true)) {
    if (e is File && e.path.endsWith('.json')) {
      final rel = e.path.substring(root.length + 1).replaceAll('\\', '/');
      out[rel] = e.readAsStringSync();
    }
  }
  return out;
}
