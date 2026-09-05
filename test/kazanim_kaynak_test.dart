import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/outcomes/data/models/curriculum_outcome_model.dart';

/// Kazanım verisinin kaynak bilgisi ve Maarif rozeti.
///
/// ## Neden bu testler var
/// Öğretmen uyardı: *"MEB'in sistemlerinde varsa eğer TYMM olmayan
/// kazanımları belirleyip onların yanına TYMM yazmamalıyız çünkü bu
/// insanları yanıltır."*
///
/// Ölçüm bunu doğruladı: rozet metin aramasıyla veriliyordu
/// (`publisher`'da "maarif" geçiyor mu) ve `isMaarif` 9087 kaydın
/// hepsinde `true` idi — Maarif'in yürürlükte olmadığı 4, 8 ve 12.
/// sınıflar dahil. 89 ders rozet alması gerekirken almıyor, 2 ders
/// yanlış alıyordu.
///
/// Kök neden: `publisher` üç işi birden yapıyordu — kaynak, okul türü
/// ve "bilinmiyor" için "MEB Yayınları".
void main() {
  group('Kaynak alani rozeti belirler', () {
    test('KRITIK: Maarif rozeti sourceProgram alanindan gelir', () {
      const maarif = CurriculumOutcomeModel(
        docId: 'x',
        gradeLevel: 5,
        subjectCode: 'MAT',
        subjectName: 'Matematik',
        weekNumber: 1,
        unitTitle: 'Sayılar',
        topicTitle: 'Sayılar',
        outcomeDescription: 'Doğal sayıları okuyabilme',
        academicYear: '2026-2027',
        sourcePortal: 'tymm',
        sourceProgram: 'maarif',
      );
      expect(maarif.isMaarif, isTrue);

      const eski = CurriculumOutcomeModel(
        docId: 'y',
        gradeLevel: 12,
        subjectCode: 'MAT',
        subjectName: 'Matematik',
        weekNumber: 1,
        unitTitle: 'Türev',
        topicTitle: 'Türev',
        outcomeDescription: 'Türev alabilme',
        academicYear: '2026-2027',
        sourcePortal: 'tymm',
        sourceProgram: 'legacy',
      );
      // 12. sınıf hâlâ eski programda; rozet BASILMAMALI.
      expect(eski.isMaarif, isFalse);
    });

    test('KRITIK: publisher metni rozeti ETKILEMEZ', () {
      // Eskiden publisher'da "Maarif" geçmesi rozeti veriyordu.
      // Publisher artık yalnızca okul türü; kaynak ayrı alanda.
      const yaniltici = CurriculumOutcomeModel(
        docId: 'z',
        gradeLevel: 8,
        subjectCode: 'TURKCE',
        subjectName: 'Türkçe',
        publisher: 'TYMM (Maarif Modeli)',
        fullTitle: '8. Sınıf - Türkçe - Maarif',
        weekNumber: 1,
        unitTitle: 'Okuma',
        topicTitle: 'Okuma',
        outcomeDescription: 'Metni anlayabilme',
        academicYear: '2026-2027',
        sourceProgram: 'legacy',
      );
      expect(yaniltici.isMaarif, isFalse,
          reason: 'metinde "Maarif" geçtiği için rozet basılmış');
    });

    test('KRITIK: DOGM kaynagi TYMM diye gosterilmez', () {
      // İmam hatip dersleri TYMM portalında YOK; DÖGM yayımlıyor.
      // İkisi de resmî MEB ama farklı genel müdürlük.
      const dogm = CurriculumOutcomeModel(
        docId: 'k',
        gradeLevel: 5,
        subjectCode: 'KURAN',
        subjectName: 'Kur\'an-ı Kerim',
        weekNumber: 1,
        unitTitle: 'Tecvid',
        topicTitle: 'Tecvid',
        outcomeDescription: 'Med kurallarını uygulayabilme',
        academicYear: '2026-2027',
        sourcePortal: 'dogm',
        sourceProgram: 'maarif',
      );
      expect(dogm.sourceLabel, 'MEB DÖGM');
      expect(dogm.isMaarif, isTrue, reason: 'resmî MEB kaynağı');
    });

    test('kaynak bilgisi SQLite donusumunde korunur', () {
      const model = CurriculumOutcomeModel(
        docId: 'm',
        gradeLevel: 5,
        subjectCode: 'MAT',
        subjectName: 'Matematik',
        weekNumber: 3,
        unitTitle: 'Kesirler',
        topicTitle: 'Kesirler',
        outcomeDescription: 'Kesirleri sıralayabilme',
        academicYear: '2026-2027',
        sourcePortal: 'tymm',
        sourceProgram: 'maarif',
      );
      final geri = CurriculumOutcomeModel.fromMap(model.toMap());
      expect(geri.sourcePortal, 'tymm');
      expect(geri.sourceProgram, 'maarif');
      expect(geri.isMaarif, isTrue);
      // Rozet SQLite sütununa da yazılmalı: liste sorgusu oradan okuyor.
      expect(model.toMap()['is_maarif'], 1);
    });

    test('kaynaksiz kayit rozet ALMAZ', () {
      // MEB'in resmî planı olmayan seçmeli dersler. İçerik
      // uydurulmadığı gibi rozet de basılmaz.
      const plansiz = CurriculumOutcomeModel(
        docId: 'p',
        gradeLevel: 6,
        subjectCode: 'BILIM_UYG',
        subjectName: 'Bilim Uygulamaları',
        weekNumber: 1,
        unitTitle: '',
        topicTitle: '',
        outcomeDescription: 'Planlanmamış hafta',
        academicYear: '2026-2027',
      );
      expect(plansiz.isMaarif, isFalse);
      expect(plansiz.sourceLabel, '');
    });
  });

  group('Yayin verisi', () {
    late List<dynamic> kayitlar;

    setUpAll(() {
      final f = File('assets/data/official_maarif_kazanimlar.json');
      kayitlar = json.decode(f.readAsStringSync()) as List<dynamic>;
    });

    test('KRITIK: isMaarif artik HEPSINDE true DEGIL', () {
      // Başlangıçta 9087 kaydın hepsi true idi.
      final maarif = kayitlar.where((e) => e['isMaarif'] == true).length;
      final eski = kayitlar.length - maarif;
      expect(maarif, greaterThan(0), reason: 'hiç Maarif kaydı yok');
      expect(eski, greaterThan(0),
          reason: 'her kayıt Maarif işaretli — eski durum geri gelmiş');
    });

    test('KRITIK: 12. sinifta Maarif kaydi YOK', () {
      // Ölçüm: MEB 12. sınıf için hâlâ eski programı yayımlıyor.
      // Rozet basmak öğretmeni yanıltır.
      final onikinci = kayitlar.where((e) => e['gradeLevel'] == 12);
      expect(onikinci, isNotEmpty);
      expect(onikinci.every((e) => e['isMaarif'] == false), isTrue,
          reason: '12. sınıfta Maarif rozeti basılıyor');
    });

    test('KRITIK: her kayitta kaynak alani VAR', () {
      final eksik = kayitlar.where((e) =>
          !e.containsKey('sourcePortal') || !e.containsKey('sourceProgram'));
      expect(eksik, isEmpty, reason: 'kaynak alanı taşınmamış');
    });

    test('KRITIK: bir brans kodu TEK derse eslenir', () {
      // Aynı kod birden çok derse eşlenirse benzersizlik anahtarı
      // (grade, subject_code, publisher, week) bozulur ve dersler
      // birbirini ezer. Ölçüm: 6 çakışma vardı.
      final esleme = <String, Set<String>>{};
      for (final e in kayitlar) {
        esleme
            .putIfAbsent(e['subjectCode'] as String, () => <String>{})
            .add(e['subjectName'] as String);
      }
      final cakisan = esleme.entries.where((e) => e.value.length > 1);
      expect(cakisan, isEmpty,
          reason: 'çakışan kodlar: '
              '${cakisan.map((e) => "${e.key}=${e.value}").join(", ")}');
    });

    test('KRITIK: CYDEM dersleri ayirt edilir', () {
      // Çoklu Yabancı Dil Eğitim Modeli seçilmiş okullara özgü;
      // normal ortaokulda bu ders yok. Adı ayırt edilmezse öğretmen
      // kendi okulunda olmayan bir dersi arar.
      final cydem = kayitlar.where(
          (e) => (e['subjectName'] as String).contains('Çoklu Yabancı Dil'));
      expect(cydem, isNotEmpty, reason: 'ÇYDEM dersleri kaybolmuş');
      // Normal İngilizce de DURMALI.
      final normal = kayitlar.where((e) =>
          e['subjectName'] == 'İngilizce' || e['subjectName'] == 'Ingilizce');
      expect(normal, isNotEmpty, reason: 'normal İngilizce kaybolmuş');
    });

    test('KRITIK: publisher artik "MEB Yayinlari" uydurmuyor', () {
      // Bu bir okul türü değil "bilinmiyor" demekti ve kaynak alanıyla
      // karışıp rozeti bozuyordu.
      final uydurma =
          kayitlar.where((e) => e['publisher'] == 'MEB Yayınları');
      expect(uydurma, isEmpty,
          reason: '${uydurma.length} kayıtta "MEB Yayınları" yazıyor');
    });
  });
}
