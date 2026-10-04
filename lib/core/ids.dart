/// Stable, qualified identifiers: `packId/localId` (e.g. `hokkaido/sapporo_l01`).
/// Never build ids from list indexes.
class QualifiedId {
  const QualifiedId(this.packId, this.localId);
  final String packId;
  final String localId;

  static QualifiedId? tryParse(String s) {
    final i = s.indexOf('/');
    if (i <= 0 || i == s.length - 1) return null;
    return QualifiedId(s.substring(0, i), s.substring(i + 1));
  }

  @override
  String toString() => '$packId/$localId';

  @override
  bool operator ==(Object other) =>
      other is QualifiedId && other.packId == packId && other.localId == localId;

  @override
  int get hashCode => Object.hash(packId, localId);
}

String qualify(String packId, String localId) => '$packId/$localId';
