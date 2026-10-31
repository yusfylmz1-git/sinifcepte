import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/core/firebase/crash_reporter.dart';

import '../tool/hata_denetimi.dart';

/// Hata denetimi kapısı (31 Ekim 2026).
///
/// `tool/hata_denetimi.dart` telefonda hata çıkarmış kalıpları tarar. Bu
/// test iki şey yapar:
///
///   1. **Kapı:** lib/ altında kapı kurallarında bulgu olmamalı. Yeni kod
///      sayfadan çıkınca setState, sıfıra bölme, Türkçe büyük harf hatası
///      getirirse burada kırılır. Bilerek yapılan yer satırına
///      `// denetim: <kural> — gerekçe` yazılır.
///   2. **Tarayıcının kendisi:** her kural bilinen kötü örneği yakalıyor,
///      doğru yazılmış örneği geçiriyor. Tarayıcı bozulup hiçbir şey
///      bulamaz hâle gelirse kapı boşuna yeşil yanmasın.
void main() {
  group('Kapı: lib/ temiz', () {
    final bulgular = denetle(Directory('lib'));

    for (final kural in kurallar.where((k) => k.derece == Derece.kapi)) {
      test('KRITIK: ${kural.kod} — ${kural.baslik}', () {
        final b = bulgular.where((x) => x.kural == kural.kod).toList();
        expect(
          b,
          isEmpty,
          reason: '${kural.neden}\n\n${b.join('\n')}\n\n'
              'Bilerek ise satırın üstüne: // denetim: ${kural.kod} — gerekçe',
        );
      });
    }
  });

  List<String> kurallariBul(String kaynak) =>
      denetleKaynak('ornek.dart', kaynak).map((b) => b.kural).toList();

  group('Tarayıcı: await-setstate', () {
    test('await sonrası denetimsiz setState yakalanır', () {
      expect(kurallariBul('''
class _S extends State<W> {
  Future<void> f() async {
    await yukle();
    setState(() => x = 1);
  }
}
'''), contains('await-setstate'));
    });

    test('mounted denetimi varsa geçer', () {
      expect(kurallariBul('''
class _S extends State<W> {
  Future<void> f() async {
    await yukle();
    if (!mounted) return;
    setState(() => x = 1);
  }
}
'''), isNot(contains('await-setstate')));
    });

    test('return ile biten bloktaki await sonrayı etkilemez', () {
      expect(kurallariBul('''
class _S extends State<W> {
  Future<void> f() async {
    if (!mounted) {
      await kapat();
      return;
    }
    setState(() => x = 1);
  }
}
'''), isNot(contains('await-setstate')));
    });

    test('if dalındaki await else dalını etkilemez', () {
      expect(kurallariBul('''
class _S extends State<W> {
  Future<void> f() async {
    if (a) {
      await yaz();
    } else {
      setState(() => x = 1);
      return;
    }
  }
}
'''), isNot(contains('await-setstate')));
    });

    test('then geri çağırmasında denetimsiz setState yakalanır', () {
      expect(kurallariBul('''
class _S extends State<W> {
  void f() {
    yukle().then((_) => setState(() => x = 1));
  }
}
'''), contains('await-setstate'));
    });

    test('yorum ve metin içindeki kalıp sayılmaz', () {
      expect(kurallariBul('''
class _S extends State<W> {
  Future<void> f() async {
    await yukle();
    // setState(() => x = 1);
    final s = 'setState(';
  }
}
'''), isNot(contains('await-setstate')));
    });
  });

  group('Tarayıcı: await-state', () {
    const sablon = '''
class N extends StateNotifier<int> {
  Future<void> yukle() async {
    final x = await oku();
    GOVDE
  }
}
''';
    test('denetimsiz state = yakalanır', () {
      expect(kurallariBul(sablon.replaceFirst('GOVDE', 'state = x;')),
          contains('await-state'));
    });
    test('if (mounted) state = geçer', () {
      expect(kurallariBul(sablon.replaceFirst('GOVDE', 'if (mounted) state = x;')),
          isNot(contains('await-state')));
    });
  });

  group('Tarayıcı: sifira-bolme', () {
    test('denetimsiz bölme round edilince yakalanır', () {
      expect(kurallariBul('int f(int a, int n) => (a / n * 100).round();'),
          contains('sifira-bolme'));
    });
    test('~/ değişkenle yakalanır', () {
      expect(kurallariBul('int f(int a, int n) => a ~/ n;'), contains('sifira-bolme'));
    });
    test('payda sıfıra karşı denetlenince geçer', () {
      expect(kurallariBul('''
int f(int a, int n) {
  if (n == 0) return 0;
  return (a / n * 100).round();
}
'''), isNot(contains('sifira-bolme')));
    });
    test('sabite bölme geçer', () {
      expect(kurallariBul('''
const int adim = 30;
int f(int a) => a ~/ adim + (a / 2).round();
'''), isNot(contains('sifira-bolme')));
    });
    test('max(1, …) ile atanmış payda geçer', () {
      expect(kurallariBul('''
int f(int a, int b) {
  final n = max(2, b * 2);
  return (a / n).ceil();
}
'''), isNot(contains('sifira-bolme')));
    });
  });

  group('Tarayıcı: diğer kapı kuralları', () {
    test('orElse olmadan firstWhere yakalanır, orElse ile geçer', () {
      expect(kurallariBul('final x = l.firstWhere((e) => e.id == 1);'),
          contains('orelse-yok'));
      expect(
          kurallariBul('final x = l.firstWhere((e) => e.id == 1, orElse: () => y);'),
          isNot(contains('orelse-yok')));
    });

    test('sınıf içinde Isolate.run kapanışı yakalanır, üst düzeyde geçer', () {
      expect(kurallariBul('''
class _S extends State<W> {
  Future<void> f() async { await Isolate.run(() => isle(veri)); }
}
'''), contains('isolate-kapanis'));
      expect(kurallariBul('Future<int> f(int v) => Isolate.run(() => isle(v));'),
          isNot(contains('isolate-kapanis')));
    });

    test('kapatılmayan Timer.periodic yakalanır, cancel ile geçer', () {
      const kaynak = '''
class _S extends State<W> {
  Timer? _t;
  void initState() { _t = Timer.periodic(d, (_) {}); }
  KAPAT
}
''';
      expect(kurallariBul(kaynak.replaceFirst('KAPAT', '')), contains('kapatilmayan'));
      expect(
          kurallariBul(kaynak.replaceFirst('KAPAT', 'void dispose() { _t?.cancel(); }')),
          isNot(contains('kapatilmayan')));
    });

    test('toUpperCase yakalanır, toUpperTr ve gerekçeli susturma geçer', () {
      expect(kurallariBul("final s = ad.toUpperCase();"), contains('turkce-buyuk'));
      expect(kurallariBul("final s = ad.toUpperTr();"), isNot(contains('turkce-buyuk')));
      expect(kurallariBul('''
// denetim: turkce-buyuk — ASCII kod
final s = kod.toUpperCase();
'''), isNot(contains('turkce-buyuk')));
    });

    test('susturma yalnız adı geçen kuralı susturur', () {
      expect(kurallariBul('''
// denetim: orelse-yok — başka kural
final s = kod.toUpperCase();
'''), contains('turkce-buyuk'));
    });
  });

  group('Çalışma anı: çökme kaydı', () {
    test('yığının baş satırları telefon günlüğüne yazılıyor', () {
      final yigin = StackTrace.fromString(
        '#0      ListBase.firstWhere (dart:collection/list.dart:132:5)\n'
        '#1      _S.build (package:sinifcepte/x.dart:10:3)\n'
        '#2      StatelessElement.build (package:flutter/src/widgets/framework.dart:1:1)\n',
      );
      final ilk = CrashReporter.ilkSatirlar(yigin);
      expect(ilk, contains('package:sinifcepte/x.dart:10'));
      expect(ilk, isNot(contains('package:flutter/')));
      expect(CrashReporter.ilkSatirlar(null), isEmpty);
    });
  });
}
