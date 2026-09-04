import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kazanim tohumlamasi ANA IS PARCACIGINI bloke etmemeli.
///
/// ## Neden bu test var
/// 9087 kazanim JSON'dan ayristirilip modele ceviriliyor; bu is
/// telefonda ~2 saniye suruyor. Ana is parcaciginda yapildiginda
/// arayuz o sure boyunca donuyordu — logda arka arkaya
/// "DONMA: ana is parcacigi 1359 ms bloke" satirlari cikiyordu.
///
/// En gorunur sonucu, ilk acilista PDF ekraninin "Belge Hazirlaniyor"
/// asamasinda takili kalmasiydi: belge 1.5 saniyede uretiliyor ama
/// ekrani cizecek is parcacigi tohumlamayla mesgul oldugu icin sonuc
/// gorunmuyordu. Kullanici bunu "PDF'ler acilmiyor" olarak yasadi.
///
/// Bu testler duzeltmenin geri alinmadigini dogrular.
void main() {
  final kod =
      File('lib/core/database/database_helper.dart').readAsStringSync();

  test('KRITIK: JSON ayristirma compute() ile izolatta', () {
    expect(kod, contains('compute(_kazanimSatirlariniHazirla'),
        reason: 'ayristirma ana is parcacigina geri alinmis');
  });

  test('KRITIK: izolat fonksiyonu UST DUZEY', () {
    // `compute` yalnizca ust duzey (veya static) fonksiyon kabul eder;
    // sinif icine tasinirsa calisma aninda hata verir, derleyici
    // yakalamaz.
    expect(
      RegExp(r'^List<Map<String, dynamic>> _kazanimSatirlariniHazirla',
              multiLine: true)
          .hasMatch(kod),
      isTrue,
      reason: 'fonksiyon ust duzeyde olmali',
    );
  });

  test('KRITIK: tohumlama govdesinde json.decode KALMADI', () {
    // Ayristirma izolata tasindi; govdede kalirsa is iki kez yapilir
    // ve donma geri gelir.
    final i = kod.indexOf('seedCurriculumOutcomesFromAssets');
    final j = kod.indexOf('resmî kazanım assets üzerinden', i);
    expect(i, greaterThan(-1));
    expect(j, greaterThan(i));
    final govde = kod.substring(i, j);
    expect(govde.contains('json.decode'), isFalse,
        reason: 'ayristirma hala ana is parcaciginda');
  });

  test('toplu yazma korunuyor', () {
    // 9087 ayri insert yerine tek batch.
    final i = kod.indexOf('seedCurriculumOutcomesFromAssets');
    final j = kod.indexOf('resmî kazanım assets üzerinden', i);
    final govde = kod.substring(i, j);
    expect(govde, contains('batch.commit(noResult: true)'));
  });
}
