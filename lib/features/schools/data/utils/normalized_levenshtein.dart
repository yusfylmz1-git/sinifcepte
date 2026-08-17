import '../repositories/school_repository.dart';

/// normalizeTr sonrası Levenshtein; skor = 1 - d/max(len).
class NormalizedLevenshtein {
  NormalizedLevenshtein._();

  static double score(String a, String b) {
    final left = SchoolRepository.normalizeTr(a);
    final right = SchoolRepository.normalizeTr(b);
    if (left.isEmpty && right.isEmpty) return 1;
    if (left.isEmpty || right.isEmpty) return 0;
    final dist = _distance(left, right);
    final maxLen = left.length > right.length ? left.length : right.length;
    return 1 - (dist / maxLen);
  }

  static int _distance(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);
    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        var best = del < ins ? del : ins;
        if (sub < best) best = sub;
        curr[j] = best;
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }
}
