import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/auth_profile/data/models/teacher_profile_model.dart';
import 'package:sinifcepte/features/documents/utils/daily_plan_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const teacher = TeacherProfileModel(
    id: 'test_teacher',
    firstName: 'Ahmet',
    lastName: 'Yılmaz',
    gender: 'Erkek',
    branch: 'Kimya',
    schoolName: 'Atatürk Anadolu Lisesi',
    schoolPrincipalName: 'Mehmet Demir',
    email: 'ahmet@meb.k12.tr',
  );

  final samplePlanData = {
    'meta': {
      'ders': 'Kimya',
      'sinif': '9. Sınıf',
      'hafta': '1. Hafta',
      'tarih_araligi': '14 - 18 Eylül 2026',
      'ders_saati': '2',
      'tema_unite': '1. Tema: Etkileşim',
    },
    'kazanimlar_ve_surec': {
      'ogrenme_ciktilari': [
        'KİM.9.1.1. Kimya biliminin günlük hayata katkısına ilişkin bilimsel çıkarım yapabilme'
      ],
      'surec_bilesenleri': [
        'a) Evde kullanılan kimyasal ürünlerin niteliklerini gözlemleyebileceği ortamlar oluşturur.',
        'b) Kimyasal ürünlerin niteliklerindeki farklılıkları kimya bilimiyle ilişkilendirir.',
      ],
    },
    'ozel_alanlar': {
      'belirli_gun_ve_haftalar': 'İlköğretim Haftası',
      'alan_becerileri': 'FBAB8. Bilimsel Çıkarım Yapma',
      'kavramsal_beceriler': 'KB2.4. Çözümleme',
      'sosyal_duygusal_ogrenme_becerileri': 'SDB1.1. Kendini Tanıma, SDB2.1. İletişim',
      'okuryazarlik_becerileri': 'OB1. Bilgi Okuryazarlığı, OB7. Veri Okuryazarlığı',
      'degerler': 'D19. Vatanseverlik, D13. Sağlıklı Yaşam',
      'disiplinler_arasi_iliskiler': 'Biyoloji, Fizik',
      'beceriler_arasi_iliskiler': 'KB2.10. Çıkarım Yapma',
    },
    'ogretim_sureci': {
      'temel_kabuller': 'Öğrencilerin temel laboratuvar güvenlik kurallarını bildikleri kabul edilir.',
      'on_degerlendirme_sureci': 'Soru-cevap ve beyin fırtınası yöntemi uygulanır.',
      'kopru_kurma': 'Evdeki temizlik malzemelerinin kimya bilimiyle ilişkisi tartışılır.',
      'farklilastirma': {
        'genel_aciklama': 'Bireysel farklılıklara uygun etkinlikler düzenlenir.',
        'zenginlestirme': 'Çevre dostu temizlik ürünleri projesi hazırlanır.',
        'destekleme': 'Somut görsel modeller ve bilgi kartları sunulur.',
      },
      'ogrenme_ogretme_uygulamalari': 'Öğretmen günlük hayatımızda yer alan temizlik ürünlerini tanıtır...',
    },
  };

  test('DailyPlanPdfGenerator tekil TYMM günlük plan PDF baytlarını başarıyla üretir', () async {
    final bytes = await DailyPlanPdfGenerator.generate(
      planData: samplePlanData,
      teacher: teacher,
      academicYear: '2024-2025 Eğitim-Öğretim Yılı',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1000));

    // PDF sihirli başlığı: %PDF- (0x25, 0x50, 0x44, 0x46, 0x2D)
    expect(bytes[0], 0x25); // %
    expect(bytes[1], 0x50); // P
    expect(bytes[2], 0x44); // D
    expect(bytes[3], 0x46); // F
  });

  test('DailyPlanPdfGenerator toplu 36 haftalık plan kitapçığını başarıyla üretir', () async {
    final haftalar = List.generate(
      3, // Test hızını korumak için 3 haftalık veriyle kapak + çoklu sayfa doğrulaması
      (i) => {
        ...samplePlanData,
        'meta': {
          ...(samplePlanData['meta'] as Map<String, dynamic>),
          'hafta': '${i + 1}. Hafta',
        },
      },
    );

    final bytes = await DailyPlanPdfGenerator.generateFullYearPdf(
      allWeeksPlanData: haftalar,
      teacher: teacher,
      ders: 'Kimya',
      sinif: '9. Sınıf',
      academicYear: '2024-2025',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(2000));
    expect(bytes[0], 0x25); // %
    expect(bytes[1], 0x50); // P
    expect(bytes[2], 0x44); // D
    expect(bytes[3], 0x46); // F
  });

  test('DailyPlanPdfGenerator BTY 5. Sınıf TYMM planını eksiksiz üretir', () async {
    final btyPlanData = {
      'meta': {
        'ders': 'Bilişim Teknolojileri ve Yazılım',
        'sinif': '5. Sınıf',
        'hafta': '1. Hafta',
        'tarih_araligi': '14 - 18 Eylül 2026',
        'ders_saati': '2 Ders Saati',
        'tema_unite': 'Bilişim Teknolojilerinin Hayatımızdaki Yeri',
      },
      'kazanimlar_ve_surec': {
        'ogrenme_ciktilari': [
          'BTY.5.1.1. Günlük yaşamda kullanılan bilişim teknolojilerini sınıflandırabilme'
        ],
        'surec_bilesenleri': [
          'a) Bilişim teknolojilerine ilişkin temel kavramları belirler.',
          'b) Geçmişten günümüze bilişim teknolojilerindeki benzerlikleri ve farklılıkları ilişkilendirir.',
          'c) Bilişim teknolojilerini kullanım alanlarına göre gruplandırır.',
        ],
      },
      'ozel_alanlar': {
        'alan_becerileri': 'Alan Becerileri ve Dijital Üretim',
        'kavramsal_beceriler': 'Kavramsal Çözümleme ve Bilgi Toplama',
        'sosyal_duygusal_ogrenme_becerileri': 'SDB1.1. Kendini Tanıma, SDB1.2. Kendini Düzenleme, SDB2.1. İletişim',
        'okuryazarlik_becerileri': 'OB1. Bilgi Okuryazarlığı, OB2. Dijital Okuryazarlık, OB4. Görsel Okuryazarlık',
        'degerler': 'D3. Çalışkanlık, D4. Dostluk, D6. Dürüstlük, D8. Mahremiyet, D14. Saygı, D16. Sorumluluk',
        'disiplinler_arasi_iliskiler': 'Türkçe, Matematik, Fen Bilimleri',
      },
      'ogretim_sureci': {
        'dikkat_cekme': 'Bilişim teknolojileri deyince aklınıza neler geliyor?',
        'guduleme': 'Bu derste bilişim kavramını açıklayacak duruma geleceksiniz.',
        'derse_gecis': 'Öğrencilerin dikkati çekildikten ve hazırbulunuşlukları yoklandıktan sonra konunun işlenişine geçilir.',
        'etkinlikler': [
          'Öğretim yılının ilk dersi olduğu için öğrencilerle tanışılır.',
          'Dersin içeriği hakkında bilgi verilir.',
          'BT sınıfında uyulması gereken kurallar beyin fırtınası yöntemi kullanılarak belirlenir.',
          '“Neden Bilişim” sunusu yardımıyla bilgi, iletişim, bilişim, teknoloji, BİT kavramları anlatılır.',
          '“BİT Kullanım Alanları” alıştırması ve “Sağlıklı Bilgisayar Kullanımı” incelemesi yapılır.',
        ],
        'bireysel_etkinlikler': 'Açık uçlu sorular, doğru-yanlış, boşluk doldurma, eşleştirme alıştırmaları, çalışma yaprakları.',
        'grupla_etkinlikler': 'İşbirlikli çalışma, beyin fırtınası, istasyon tekniği ve akran öğrenmesi.',
        'ozet': 'Öğrencilerin bireysel farklılıkları göz ardı edilmemelidir. Öğrenilen kavramların günlük hayat deneyimleriyle pekiştirilmesi sağlanır.',
        'farklilastirma': {
          'genel_aciklama': 'Öğrencilerin ilgi ve ihtiyaçlarına göre esnek öğretim uyarlamaları uygulanır.',
          'zenginlestirme': 'İleri düzeydeki öğrenciler için araştırma, blok kodlama ve proje görevleri verilir.',
          'destekleme': 'Somut modeller, görsel materyaller ve basamaklandırılmış çalışma yaprakları ile desteklenir.',
        },
      },
    };

    final bytes = await DailyPlanPdfGenerator.generate(
      planData: btyPlanData,
      teacher: teacher,
      academicYear: '2026-2027 Eğitim-Öğretim Yılı',
    );

    expect(bytes, isA<Uint8List>());
    expect(bytes.length, greaterThan(1500));
    expect(bytes[0], 0x25); // %
    expect(bytes[1], 0x50); // P
    expect(bytes[2], 0x44); // D
    expect(bytes[3], 0x46); // F
  });
}
