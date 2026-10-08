import 'package:fl_place_autocomplete_web/src/session_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same id shares the token and predictions; remove drops them', () {
    var n = 0;
    final cache = SessionCache<String, String>(() => 'tok${n++}');
    final a = cache.entry('s1');
    cache.cachePrediction('s1', 'p1', 'pred1');
    expect(cache.entry('s1').token, a.token);
    expect(cache.prediction('s1', 'p1'), 'pred1');
    cache.remove('s1');
    expect(cache.prediction('s1', 'p1'), isNull);
    expect(cache.entry('s1').token, isNot(a.token));
  });
  test('predictions from different sessions do not mix', () {
    final cache = SessionCache<String, String>(() => 't');
    cache.cachePrediction('a', 'p', 'A');
    cache.cachePrediction('b', 'p', 'B');
    expect(cache.prediction('a', 'p'), 'A');
    expect(cache.prediction('b', 'p'), 'B');
  });
}
