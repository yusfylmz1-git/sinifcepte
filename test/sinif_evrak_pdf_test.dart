import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:sinifcepte/data/models/class_model.dart';
import 'package:sinifcepte/data/models/student_model.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/classes/utils/classroom_documents_pdf_generator.dart';

/// Sınıf evraklarının resmî belge niteliği.
///
/// ## Neden bu testler var
/// Öğretmen istedi: *"MEB'e uygun resmî evrak niteliğinde olsun…
/// PDF'lerde Türkçe karakter problemi olmasın… eğitim öğretim yılı,
/// okul adı, öğretmen adı hatalı olmasın — hepsi değişken sonuçta."*
///
/// Ölçüm iki gerçek kusur buldu:
///
/// **1. Türkçe harfler basılamıyordu.** `PdfTrFonts.document()` gömülü
/// Noto Sans temasını kuruyor, ama üreticiler hemen ardından
/// `MultiPage(theme: ThemeData.withFont(Roboto))` ile o temayı
/// eziyordu. Deneyle doğrulandı:
///
///     Unable to find a font to draw "ş" (U+15f)
///     Unable to find a font to draw "ı" (U+131)
///
/// PDF sessizce üretiliyor; o harflerin yerinde kutu kalıyordu.
/// Üstelik `PdfGoogleFonts` fontu **ağdan indiriyor** — çevrimdışı
/// öğretmende belge ya hata veriyor ya Türkçesiz çıkıyordu.
///
/// **2. Öğretim yılı 13 yerde `'2024-2025'` sabitti** (şu an
/// 2026-2027).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Gömülü font asset'ten okunur; testte ağ yok.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final f = File(utf8.decode(message!.buffer.asUint8List()));
      return f.existsSync()
          ? Uint8List.fromList(f.readAsBytesSync()).buffer.asByteData()
          : null;
    });
  });

  const profil = TeacherProfileModel(
    id: 't1',
    firstName: 'Ayşe',
    lastName: 'Çağrışgil',
    branch: 'Sınıf Öğretmenliği',
    schoolName: 'Şehit Öğretmen İlkokulu',
    schoolPrincipalName: 'Muğdat Şıhoğlu',
    email: 'ogretmen@example.com',
  );

  const sinif = ClassModel(
    id: 1,
    name: '5-A',
    subject: 'Matematik',
    academicYear: '2026-2027',
    isHomeroom: true,
  );

  final ogrenciler = [
    const StudentModel(
      id: 1,
      classId: 1,
      schoolNumber: 101,
      firstName: 'Işıl',
      lastName: 'Çağrı',
      gender: 'Kız',
      parentPhone: '5551112233',
    ),
    const StudentModel(
      id: 2,
      classId: 1,
      schoolNumber: 102,
      firstName: 'Оğuz',
      lastName: 'Şahin',
      gender: 'Erkek',
    ),
  ];

  /// PDF metnini aranabilir hâle getirir.
  ///
  /// Syncfusion her hücreyi ayrı satıra koyuyor; satır sonları
  /// boşluğa çevrilmezse çok kelimeli ifade bulunamaz.
  String duz(String ham) => ham.replaceAll(RegExp(r'\s+'), ' ').trim();

  Future<String> metin(Uint8List bayt) async {
    final doc = PdfDocument(inputBytes: bayt);
    final t = duz(PdfTextExtractor(doc).extractText());
    doc.dispose();
    return t;
  }

  group('Turkce karakter', () {
    test('KRITIK: ogrenci listesinde Turkce harfler basiliyor', () async {
      final b = await ClassroomDocumentsPdfGenerator.generateStudentListPdfBytes(
        classModel: sinif,
        students: ogrenciler,
        teacherProfile: profil,
      );
      final t = await metin(b);

      // Önce bu harfler basılamıyordu (kutu çıkıyordu).
      //
      // Tablo hücreleri BÜYÜK harfe çevriliyor ve Syncfusion her
      // hücreyi ayrı satıra koyuyor; ad ile soyad bitişik aranmaz.
      expect(t.contains('IŞIL'), isTrue, reason: '"ı"/"Ş" basılamamış');
      expect(t.contains('ŞAHİN'), isTrue, reason: '"Ş"/"İ" basılamamış');
      expect(t.contains('MİLLÎ'), isTrue,
          reason: 'MEB başlığındaki "İ" basılamamış');
      expect(t.contains('BAKANLIĞI'), isTrue, reason: '"Ğ" basılamamış');

      // Ölçüm: sağlam bir belgede 60+ Türkçe özel harf bulunuyor.
      final trHarf = t.split('').where((c) => 'ışğüöçİŞĞÜÖÇ'.contains(c));
      expect(trHarf.length, greaterThan(30),
          reason: 'Türkçe harfler kayıp: ${trHarf.length} adet');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: okul ve mudur adindaki Turkce harfler', () async {
      final b = await ClassroomDocumentsPdfGenerator.generateStudentListPdfBytes(
        classModel: sinif,
        students: ogrenciler,
        teacherProfile: profil,
      );
      final t = await metin(b);

      // Okul adı büyük harfe çevriliyor; kelimeler ayrı satırda.
      expect(t.contains('ŞEHIT'), isTrue, reason: 'okul adı bozuk');
      expect(t.contains('ÖĞRETMEN'), isTrue, reason: '"Ö"/"Ğ" bozuk');
      expect(t.contains('İLKOKULU'), isTrue, reason: '"İ" bozuk');
      expect(t.contains('Muğdat'), isTrue, reason: 'müdür adı bozuk');
      expect(t.contains('Şıhoğlu'), isTrue, reason: 'müdür soyadı bozuk');
      expect(t.contains('Ayşe'), isTrue, reason: 'öğretmen adı bozuk');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: kaynakta PdfGoogleFonts KULLANILMIYOR', () {
      // Ağdan font indiriyor; çevrimdışı öğretmende Türkçe harfler
      // basılamıyor ve ANR üretiyor. Gömülü Noto Sans yeterli.
      final bulunan = <String>[];
      for (final d in Directory('lib').listSync(recursive: true)) {
        if (d is! File || !d.path.endsWith('.dart')) continue;
        final s = d.readAsStringSync();
        // pdf_tr_fonts.dart bunu YORUMDA anlatıyor, o sayılmaz.
        if (d.uri.pathSegments.last == 'pdf_tr_fonts.dart') continue;
        if (s.contains('PdfGoogleFonts')) bulunan.add(d.path);
      }
      expect(bulunan, isEmpty,
          reason: 'ağ bağımlılığı geri gelmiş: ${bulunan.join(", ")}');
    });

    test('KRITIK: tema EZILMIYOR (ThemeData.withFont)', () {
      // PdfTrFonts.document() dört stili kuruyor; withFont onu
      // eziyordu ve Türkçe harfler kayboluyordu.
      final bulunan = <String>[];
      for (final d in Directory('lib').listSync(recursive: true)) {
        if (d is! File || !d.path.endsWith('.dart')) continue;
        // pdf_tr_fonts.dart withFont'u MEŞRU kullanıyor: Türkçe
        // temayı kuran yer orası. Kusur, üreticilerin O TEMAYI
        // ezmesiydi.
        if (d.uri.pathSegments.last == 'pdf_tr_fonts.dart') continue;
        if (d.readAsStringSync().contains('ThemeData.withFont')) {
          bulunan.add(d.path);
        }
      }
      expect(bulunan, isEmpty,
          reason: 'tema ezme geri gelmiş: ${bulunan.join(", ")}');
    });
  });

  group('Ogretim yili degisken', () {
    test('KRITIK: sinifin KENDI yili basiliyor', () async {
      final b = await ClassroomDocumentsPdfGenerator.generateStudentListPdfBytes(
        classModel: sinif,
        students: ogrenciler,
        teacherProfile: profil,
      );
      final t = await metin(b);

      expect(t.contains('2026-2027'), isTrue,
          reason: 'sınıfın yılı belgeye çıkmıyor');
      expect(t.contains('2024-2025'), isFalse,
          reason: 'sabit yıl hâlâ basılıyor');
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: gecen yilin sinifi ARSIV yilini gosterir', () async {
      // Geçen yılın sınıfının evrakı açılırsa o yılı göstermeli;
      // bugünden hesaplamak arşiv belgesini yanlış kılardı.
      const eski = ClassModel(
        id: 2,
        name: '4-B',
        subject: 'Türkçe',
        academicYear: '2025-2026',
        isHomeroom: true,
      );
      final b = await ClassroomDocumentsPdfGenerator.generateStudentListPdfBytes(
        classModel: eski,
        students: ogrenciler,
        teacherProfile: profil,
      );
      final t = await metin(b);
      expect(t.contains('2025-2026'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('yil bos ise takvimden hesaplanir', () {
      const yilsiz = ClassModel(
        id: 3,
        name: '6-C',
        subject: 'Fen',
        academicYear: '',
        isHomeroom: false,
      );
      final satir = ClassroomDocumentsPdfGenerator.ogretimYili(yilsiz);
      // Belge yılsız kalmamalı.
      expect(satir.contains('EĞİTİM-ÖĞRETİM YILI'), isTrue);
      expect(RegExp(r'20\d{2}-20\d{2}').hasMatch(satir), isTrue,
          reason: 'yıl hesaplanmamış: $satir');
    });

    test('KRITIK: kaynakta sabit yil KALMADI', () {
      final bulunan = <String>[];
      for (final d in Directory('lib/features').listSync(recursive: true)) {
        if (d is! File || !d.path.endsWith('_pdf_generator.dart')) continue;
        for (final satir in d.readAsLinesSync()) {
          // Yorum satırları sayılmaz: neden değiştiğini anlatıyorlar.
          final t = satir.trimLeft();
          if (t.startsWith('//') || t.startsWith('///')) continue;
          if (RegExp(r"'20\d{2}-20\d{2} EĞİTİM").hasMatch(satir)) {
            bulunan.add('${d.path}: ${satir.trim()}');
          }
        }
      }
      expect(bulunan, isEmpty,
          reason: 'sabit yıl geri gelmiş:\n${bulunan.join("\n")}');
    });
  });

  group('Resmi evrak nitelig i', () {
    test('KRITIK: "Taslak" ve cekince ibaresi YOK', () async {
      final b = await ClassroomDocumentsPdfGenerator.generateStudentListPdfBytes(
        classModel: sinif,
        students: ogrenciler,
        teacherProfile: profil,
      );
      final t = await metin(b);

      // Bu ibareler belgeyi idarenin gözünde geçersiz gösteriyordu.
      expect(t.contains('Taslak'), isFalse);
      expect(t.contains('TASLAK'), isFalse);
      expect(t.contains('yerine geçmez'), isFalse);
      expect(t.contains('resmî ürünü değildir'), isFalse);
      expect(t.contains('resmî evrakı değildir'), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('KRITIK: resmi kunye tam', () async {
      final b = await ClassroomDocumentsPdfGenerator.generateStudentListPdfBytes(
        classModel: sinif,
        students: ogrenciler,
        teacherProfile: profil,
      );
      final t = await metin(b);

      // Resmî evrakın olmazsa olmazları.
      expect(t.contains('T.C.'), isTrue);
      expect(t.contains('MİLLÎ EĞİTİM BAKANLIĞI'), isTrue);
      expect(t.contains('MÜDÜRLÜĞÜ'), isTrue);
      expect(t.contains('UYGUNDUR'), isTrue, reason: 'müdür onayı yok');
      expect(t.contains('Sınıf Rehber Öğretmeni'), isTrue);
      expect(t.contains('Okul Müdürü'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('okul adi bos ise noktali satir basilir', () async {
      const profilsiz = TeacherProfileModel(
        id: 't2',
        firstName: '',
        lastName: '',
        branch: '',
        schoolName: '',
        schoolPrincipalName: '',
        email: '',
      );
      final b = await ClassroomDocumentsPdfGenerator.generateStudentListPdfBytes(
        classModel: sinif,
        students: ogrenciler,
        teacherProfile: profilsiz,
      );
      final t = await metin(b);
      // Elle doldurulacak yer belli olmalı; boş kalmamalı.
      expect(t.contains('...'), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
