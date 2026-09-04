import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Hukuki belgeler ve gizlilik metni (Faz 1.3 / menu duzenlemesi).
///
/// ## Neden kaynak duzeyinde test
/// Kullanim Kosullari ve Gizlilik Politikasi uygulamanin HICBIR yerinde
/// gorunmuyordu. Play Store gizlilik politikasini zorunlu tutuyor.
///
/// Daha onemlisi: veli profilindeki eski metin "ogrenci bilgileri buluta
/// aktarilmaz" diyordu ama `studentName` en az uc koleksiyonda buluta
/// gidiyor. **Yanlis beyan hukuki risk tasir.** Bu testler o iddianin
/// geri gelmemesini garantiler.
void main() {
  String oku(String yol) {
    final f = File(yol);
    return f.existsSync() ? f.readAsStringSync() : '';
  }

  group('Belgeler erisilebilir', () {
    test('KRITIK: Hakkinda ekrani var', () {
      expect(File('lib/features/profile/screens/about_screen.dart').existsSync(),
          isTrue);
    });

    test('KRITIK: hukuki belge ekrani var', () {
      expect(
        File('lib/features/profile/screens/legal_document_screen.dart')
            .existsSync(),
        isTrue,
      );
    });

    test('KRITIK: Hakkinda profil menusune bagli', () {
      final s = oku('lib/features/profile/screens/profile_screen.dart');
      expect(s, contains('AboutScreen'),
          reason: 'ekran yazilip baglanmazsa kullanici ulasamaz');
    });

    test('KRITIK: uc belge de Hakkinda ekraninda listeleniyor', () {
      final s = oku('lib/features/profile/screens/about_screen.dart');
      expect(s, contains('Kullanım Koşulları'));
      expect(s, contains('Gizlilik Politikası'));
      expect(s, contains('Sıkça Sorulan Sorular'));
    });
  });

  group('Yanlis gizlilik beyani geri gelmemeli', () {
    test('KRITIK: "buluta aktarilmaz" iddiasi kodda yok', () {
      // Bu ifade `studentName` buluta gittigi icin YANLISTI.
      final dizinler = ['lib/features', 'lib/core'];
      final bulunanlar = <String>[];

      for (final d in dizinler) {
        final dir = Directory(d);
        if (!dir.existsSync()) continue;
        for (final f in dir.listSync(recursive: true).whereType<File>()) {
          if (!f.path.endsWith('.dart')) continue;
          // Aciklama satirlari haric: yalnizca kullaniciya GOSTERILEN
          // metinde olmamali.
          final satirlar = f.readAsLinesSync();
          for (final satir in satirlar) {
            final kirpik = satir.trimLeft();
            if (kirpik.startsWith('//') || kirpik.startsWith('///')) continue;
            if (satir.contains('buluta aktarılmaz')) {
              bulunanlar.add('${f.path}: ${satir.trim()}');
            }
          }
        }
      }

      expect(bulunanlar, isEmpty,
          reason: 'ogrenci adi buluta gidiyor; bu ifade yanlis beyandir');
    });

    test('KRITIK: veli KVKK metni ogrenci adinin buluta gittigini soyluyor',
        () {
      final s = oku(
          'lib/features/parent_portal/presentation/views/parent_profile_view.dart');
      expect(s, contains('öğrencinin adı ve soyadı'),
          reason: 'hangi verinin buluta gittigi acikca yazilmali');
    });
  });

  group('Gizlilik politikasi icerigi', () {
    test('KRITIK: cihazda kalan veriler tek tek sayiliyor', () {
      final s = oku('lib/features/profile/screens/legal_document_screen.dart');
      for (final alan in [
        'Sınav notları',
        'Devamsızlık',
        'Veli telefon',
      ]) {
        expect(s, contains(alan), reason: '$alan listede olmali');
      }
    });

    test('KRITIK: buluta giden veriler tek tek sayiliyor', () {
      final s = oku('lib/features/profile/screens/legal_document_screen.dart');
      // Metin "adı ve soyadı" iken "adı, soyadı ve okul numarası" oldu:
      // bagimsiz denetim, studentNumber'in da buluta gittigini yakaladi.
      expect(s, contains('adı, soyadı'));
      expect(s, contains('okul numarası'));
      expect(s, contains('Mesaj ve duyuru'));
    });

    test('KRITIK: KVKK madde 11 haklari ve silme yolu var', () {
      final s = oku('lib/features/profile/screens/legal_document_screen.dart');
      expect(s, contains('KVKK'));
      expect(s, contains('silinmesini'));
    });

    test('destek adresi belgelerde geciyor', () {
      final s = oku('lib/features/profile/screens/legal_document_screen.dart');
      expect(s, contains('SupportRepository.supportEmail'),
          reason: 'adres sabit kodlanmamali, tek kaynaktan gelmeli');
    });

    test('MEB ile bagi olmadigi belirtiliyor', () {
      final s = oku('lib/features/profile/screens/legal_document_screen.dart');
      expect(s, contains('resmî bir ürünü'),
          reason: 'MEB urunu sanilmasi yaniltici olur');
    });
  });

  group('SSS kullanicinin gercek sorularini kapsiyor', () {
    test('KRITIK: denetimde belirlenen dort soru var', () {
      final s = oku('lib/features/profile/screens/legal_document_screen.dart');

      expect(s, contains('Referans kodu çalışmıyor'));
      expect(s, contains('Öğretmenimi listede göremiyorum'));
      expect(s, contains('Mesajım gitmiyor'));
      expect(s, contains('Çocuğumu nasıl eklerim'));
    });

    test('notlarin neden gorunmedigi aciklaniyor', () {
      final s = oku('lib/features/profile/screens/legal_document_screen.dart');
      expect(s, contains('Notları ve devamsızlığı neden göremiyorum'));
    });
  });
}
