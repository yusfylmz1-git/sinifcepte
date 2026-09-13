import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cepte sohbet ekrani sozlesmeleri.
///
/// ## Neden kaynak okuyan test
/// Ekranin kendisi veritabani ve Riverpod saglayicilarina baglidir;
/// widget testinde ayaga kaldirmak icin sqflite ve profil sahtesi
/// gerekir. Buradaki kilitler DAVRANIS SOZLESMELERIDIR: yanlislikla
/// geri alinirsa ogretmen yanlis evrak basar ya da ekran iki kez acilir.
///
/// Niyet cozumleyici ve belge servisi kendi dosyalarinda tam test
/// altinda; burada yalnizca ekranin onlari DOGRU KULLANDIGI dogrulanir.
void main() {
  String oku(String yol) => File(yol).readAsStringSync();

  const sohbet =
      'lib/features/assistant/presentation/views/cepte_sohbet_view.dart';
  const anaSayfa = 'lib/features/dashboard/screens/dashboard_screen.dart';

  group('Ekran acma', () {
    test('KRITIK: ekran kendiliginden acilmaz, butonla acilir', () {
      // Once hem buton konup hem dogrudan push cagrilmisti: ekran iki
      // kez aciliyor ve ogretmen geri tusuna iki kez basmak zorunda
      // kaliyordu.
      final kod = oku(sohbet);
      final ekranAc = kod.substring(kod.indexOf('void _ekranAc'));
      final govde = ekranAc.substring(0, ekranAc.indexOf('\n  @override'));

      final pushSayisi = RegExp(r'Navigator\.of\(context\)\.push')
          .allMatches(govde)
          .length;
      expect(pushSayisi, 1,
          reason: 'tek yonlendirme olmali (butonun icinde)');
      expect(govde, contains('eylem:'),
          reason: 'yonlendirme butonla yapilmali');
    });

    test('KRITIK: sinifa bagli ekranlar Sinifim`a goturulur', () {
      // Oturma plani, nobetci listesi, devamsizlik ekranlari
      // `classModel` zorunlu tutuyor; sinif secimi Sinifim ekraninda
      // yapilir. Dogrudan acilsalardi parametresiz cagri derlenmezdi.
      final kod = oku(sohbet);
      for (final ekran in [
        'CepteEkran.oturmaPlani',
        'CepteEkran.nobetciListesi',
        'CepteEkran.devamsizlik',
        'CepteEkran.ogrenciListesi',
        'CepteEkran.ogretmenKadrosu',
      ]) {
        expect(kod, contains(ekran), reason: '$ekran eslenmeli');
      }
      expect(kod, contains('MyClassHubScreen()'));
    });
  });

  group('Belge uretimi', () {
    test('KRITIK: PDF PdfPreviewScreen uzerinden acilir', () {
      // Dogrudan `Printing.sharePdf` cagrisi o ekranin 45 sn zaman
      // asimini, gorunur hata ekranini ve tani logunu ATLIYORDU;
      // sessiz donmaya yol acmisti.
      final kod = oku(sohbet);
      expect(kod, contains('PdfPreviewScreen.open'));
      expect(kod.contains('Printing.sharePdf'), isFalse);
    });

    test('KRITIK: belge TASLAK oldugu yaziliyor', () {
      // Yontem/arac/olcme sutunlarinin bir kismi sablon; belge zumre
      // onayindan gecmeden resmi degildir.
      expect(oku(sohbet), contains('TASLAKTIR'));
    });

    test('Gunluk ve yillik ureticiler ayri cagriliyor', () {
      final kod = oku(sohbet);
      expect(kod, contains('DailyPlanPdfGenerator.generateFullYearPdf'));
      expect(kod, contains('AnnualPlanPdfGenerator.generate'));
    });
  });

  group('Tahmin etmeme', () {
    test('KRITIK: belirsiz cumlede is uydurulmaz', () {
      final kod = oku(sohbet);
      final belirsiz = kod.substring(kod.indexOf('CepteNiyetTuru.belirsiz:'));
      expect(belirsiz, contains('anlayamadım'),
          reason: 'anlasilmayan cumlede ogretmene sorulmali');
    });

    test('KRITIK: secim gerektiginde secenekler gosterilir', () {
      // Lisede ayni ders uc okul turuyle gelir; Cepte secmez, sorar.
      expect(oku(sohbet), contains('CepteBelgeDurumu.secimGerekli'));
      expect(oku(sohbet), contains('secenekler: sonuc.secenekler'));
    });
  });

  group('Ana sayfa karti', () {
    test('KRITIK: Cepte karti ana sayfada', () {
      final kod = oku(anaSayfa);
      expect(kod, contains("'title': 'Cepte'"));
      expect(kod, contains('CepteSohbetView'));
    });

    test('Kazanimlar karti hala duruyor', () {
      // Cepte, Kurullar kartindan bosalan yere geldi; mevcut isler
      // yerinden edilmedi.
      expect(oku(anaSayfa), contains("'title': 'Kazanımlar'"));
    });
  });
}
