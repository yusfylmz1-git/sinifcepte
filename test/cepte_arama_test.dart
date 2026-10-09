import 'package:flutter_test/flutter_test.dart';

import 'package:sinifcepte/features/assistant/data/cepte_arama.dart';
import 'package:sinifcepte/features/assistant/data/cepte_katalog.dart';
import 'package:sinifcepte/features/assistant/data/cepte_niyet.dart';

/// Cepte araması (9 Ekim 2026). Kullanıcı: "yazdıkça altta öneri gelsin;
/// senaryolar çeşitli değil". Sorgular öğretmenin yazacağı biçimde:
/// eksik, ekli, bitişik, Türkçe harfsiz.
void main() {
  final katalog = [
    ...cepteEkranHedefleri(),
    ...cepteSinifHedefleri([
      (id: 1, ad: '5-A', ders: 'Türkçe'),
      (id: 2, ad: '6-B', ders: 'Türkçe'),
    ]),
    ...cepteOgrenciHedefleri([
      (id: 10, classId: 1, ad: 'Ali YILMAZ', no: 7, sinifAdi: '5-A'),
      (id: 11, classId: 1, ad: 'Aydın KAYA', no: 12, sinifAdi: '5-A'),
      (id: 12, classId: 2, ad: 'Elif DEMİR', no: 341, sinifAdi: '6-B'),
      (id: 13, classId: 3, ad: 'Ayşe KARA', no: 15, sinifAdi: '5-B'),
    ]),
    ...cepteBelirliGunHedefleri([
      (ad: 'Ulusal Egemenlik ve Çocuk Bayramı', tarihMetni: '23 Nisan', etkinlikli: true),
      (ad: 'Kızılay Haftası', tarihMetni: '29 Ekim - 4 Kasım', etkinlikli: true),
      (ad: 'Atatürk Haftası', tarihMetni: '10-16 Kasım', etkinlikli: true),
    ]),
    ...cepteKulupHedefleri([
      (id: 3, ad: 'Kızılay ve Kan Bağışı Kulübü'),
      (id: 4, ad: 'Satranç Kulübü'),
    ]),
    ...cepteKazanimHedefleri([
      (sinif: 5, kod: 'TURKCE', ad: 'Türkçe', yayinci: ''),
      (sinif: 5, kod: 'DIN', ad: 'Din Kültürü ve Ahlak Bilgisi', yayinci: ''),
      (sinif: 6, kod: 'TURKCE', ad: 'Türkçe', yayinci: ''),
    ]),
  ];

  List<String> ara(String q) => cepteAra(q, katalog).map((s) => s.hedef.id).toList();
  String ilk(String q) {
    final s = ara(q);
    expect(s, isNotEmpty, reason: '"$q" hiçbir şey bulmadı');
    return s.first;
  }

  group('normalleştirme', () {
    test('Türkçe harf, noktalama, bitişik rakam-harf', () {
      expect(cepteNormalize('5-A'), '5 a');
      expect(cepteNormalize('5a'), '5 a');
      expect(cepteNormalize('23nisan'), '23 nisan');
      expect(cepteNormalize('5.Sınıf TÜRKÇE'), '5 sinif turkce');
      expect(cepteNormalize('İŞIK'), 'isik');
    });
  });

  group('KRITIK: öğretmenin sözleriyle doğru yer', () {
    final beklenen = <String, String>{
      'kroki': 'sinif:oturmaPlani:',
      'oturma planı 5a': 'sinif:oturmaPlani:1',
      'oturma planini 6-b': 'sinif:oturmaPlani:2',
      'yoklama': 'sinif:devamsizlik:',
      'devamsızlığı': 'sinif:devamsizlik:',
      'gelmeyenler': 'sinif:devamsizlik:',
      'yedek': 'ekran:veriYedekleme',
      'telefon değiştirdim': 'ekran:veriYedekleme',
      'geri yükle': 'ekran:geriYukleme',
      'veli toplantısı': 'ekran:donemSonuRaporlari',
      'karne yorumu': 'ekran:karneGorusleri',
      'zümre': 'ekran:kurulTutanaklari',
      'şök': 'ekran:kurulTutanaklari',
      'sözlü notu': 'ekran:quizSozlu',
      'sınav tarihi': 'ekran:sinavTakvimi',
      'takvim': 'ekran:calismaTakvimi',
      'ara tatil': 'ekran:calismaTakvimi',
      'bep': 'ekran:ozelEgitim',
      'kaynaştırma': 'ekran:ozelEgitim',
      'tahta şifresi': 'ekran:tahtaKilidi',
      'vesikalık': 'ekran:eokulFoto',
      'zil': 'ekran:dersSaatleri',
      'kura': 'ekran:dersIciKatilim',
      'artı eksi 5a': 'sinif:artiEksi:1',
      'veliye mesaj': 'sinif:veliPaneli:',
      'veli telefonu': 'sinif:veliIletisim:',
      'karanlık mod': 'ekran:ayarlar',
      'tayin': 'ekran:profilBilgileri',
      '23 nisan': 'gun:Ulusal Egemenlik ve Çocuk Bayramı',
      '23nisan': 'gun:Ulusal Egemenlik ve Çocuk Bayramı',
      'cocuk bayrami': 'gun:Ulusal Egemenlik ve Çocuk Bayramı',
      'satranc': 'kulup:4',
      'ali': 'ogrenci:10',
      'yilmaz': 'ogrenci:10',
      '341': 'ogrenci:12',
      '5 türkçe yıllık': 'yillik:5:TURKCE:',
      '6. sınıf türkçe günlük plan': 'gunluk:6:TURKCE:',
      '5 türkçe kazanım': 'kazanim:5:TURKCE:',
      'sinifim': 'ekran:sinifim',
      'ders programı': 'ekran:dersProgrami',
    };
    for (final e in beklenen.entries) {
      test('"${e.key}" → ${e.value}', () {
        expect(ilk(e.key), startsWith(e.value));
      });
    }
  });

  test('KRITIK: "5-A" yazınca o sınıfın ekranları, önce sınıfın kendisi', () {
    final s = ara('5-A');
    expect(s.first, 'sinif:sinifim:1');
    expect(s.take(9).every((id) => id.endsWith(':1') || id.startsWith('ogrenci:')), isTrue);
    // "a" şubedir: 5-B'deki Ayşe'nin baş harfi sayılırsa başka sınıfın
    // öğrencisi "5-A" aramasına karışırdı.
    expect(s, isNot(contains('ogrenci:13')));
  });

  test('KRITIK: "din" kelime başında arar; "Aydın" çıkmaz', () {
    final s = ara('din');
    expect(s, contains('kazanim:5:DIN:'));
    expect(s, isNot(contains('ogrenci:11')));
  });

  test('"kızılay" hem haftayı hem kulübü bulur', () {
    final s = ara('kızılay');
    expect(s, containsAll(['gun:Kızılay Haftası', 'kulup:3']));
  });

  test('rakam kelimenin tamamı: "5" 2025 ya da 15 aramaz, "7" Ali\'yi (No 7) bulur', () {
    expect(ara('7'), contains('ogrenci:10'));
    expect(ara('7'), isNot(contains('ogrenci:11')), reason: 'No 12');
  });

  test('her kelime bir yerde geçmeli: anlamsız ek kelime sonucu boşaltır', () {
    expect(ara('oturma zzzz'), isEmpty);
  });

  test('dolgu sözleri süzmez: "oturma planı nerede", "yoklamayı aç"', () {
    expect(ilk('oturma planı nerede'), startsWith('sinif:oturmaPlani:'));
    expect(ilk('yoklamayı aç'), startsWith('sinif:devamsizlik:'));
  });

  test('boş sorgu boş sonuç', () {
    expect(ara('   '), isEmpty);
  });

  group('cümleden hazırla önerisi', () {
    test('KRITIK: listede olmayan seviye de istenebilir', () {
      final h = cepteNiyetHedefi('7. sınıf fen yıllık plan')!;
      expect(h.kategori, CepteKategori.hazirla);
      expect(h.baslik, '7. sınıf Fen Bilimleri yıllık planı hazırla');
      final n = (h.eylem as PlanEylemi).niyet;
      expect((n.tur, n.sinif, n.dersKodu), (CepteNiyetTuru.yillikPlan, 7, 'FEN'));
    });

    test('eksik bilgi söyleniyor (Cepte sorar, tahmin etmez)', () {
      final h = cepteNiyetHedefi('yıllık plan')!;
      expect(h.yol, contains('sınıf ve ders sorulacak'));
      expect((h.eylem as PlanEylemi).niyet.hazir, isFalse);
    });

    test('plan ya da kazanım değilse öneri yok', () {
      expect(cepteNiyetHedefi('oturma planı'), isNull);
    });
  });
}
