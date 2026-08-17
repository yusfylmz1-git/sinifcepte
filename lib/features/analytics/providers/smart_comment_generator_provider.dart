import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SınıfCepte - Akıllı e-Okul Karne Görüşü ve Ders İçi Katılım Puanlayıcı
final smartCommentGeneratorProvider = Provider<SmartCommentGenerator>((ref) {
  return SmartCommentGenerator();
});

class SmartCommentGenerator {
  /// 1. Gerçek Verilere Dayalı 100 Üzerinden Katılım Puanı Hesaplama
  /// - Ödev Sorumluluğu & Teslimi: %40
  /// - Ders İçi Aktif Katılım & Yıldız Puanı: %40
  /// - Ders Araç-Gereç & Hazırlık Uyumu: %20
  static double calculateParticipationGrade({
    required int totalSessions,
    required int homeworkDone,
    required int homeworkPartial,
    required int materialsReady,
    required double averageStars,
  }) {
    if (totalSessions <= 0) return 100.0;

    final hwScore = ((homeworkDone + (homeworkPartial * 0.5)) / totalSessions * 100).clamp(0.0, 100.0);
    final matScore = (materialsReady / totalSessions * 100).clamp(0.0, 100.0);
    final starsScore = ((averageStars / 3.0) * 100).clamp(0.0, 100.0);

    final total = (hwScore * 0.40) + (starsScore * 0.40) + (matScore * 0.20);
    return double.parse(total.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  /// 2. İsimsiz, Özgün ve e-Okul Uyumlu Pedagojik Karne Görüşü Üretici
  /// `seed`: Öğrencinin okul no veya ID'si (Her öğrenciye varsayılan olarak FARKLI cümle atanmasını sağlar!)
  /// `variationIndex`: Kullanıcı "Farklı Görüş"e bastıkça dönen sayaç
  String generateEOkulComment({
    required double calculatedGrade,
    double? homeworkRate,
    double? avgStars,
    List<String> tags = const [],
    int seed = 0,
    int variationIndex = 0,
  }) {
    try {
      final cleanTags = tags
          .map((t) => t.replaceAll(RegExp(r'[^\w\sğüşıöçĞÜŞİÖÇ]'), '').trim())
          .where((t) => t.isNotEmpty)
          .toList();
      String? tagHighlight;
      if (cleanTags.isNotEmpty) {
        tagHighlight = cleanTags.first;
      }

      final combinedIndex = (seed.abs() + variationIndex);

      // 90 - 100 Puan (Üstün Başarılı / Örnek Katılım) -> 12 Farklı Varyasyon
      if (calculatedGrade >= 90) {
        final variations = [
          tagHighlight != null
              ? 'Ders içi katılımı, $tagHighlight tutumu ve ödev sorumluluğuyla örnek bir performans sergilemiştir. Tebrik eder, başarılarının devamını dilerim.'
              : 'Ders içi katılımı, sorumluluk bilinci ve ödev istikrarıyla dönem boyunca örnek bir performans sergilemiştir. Tebrik eder, başarılarının devamını dilerim.',
          'Dersi büyük bir dikkatle takip etmekte, verilen tüm görevleri eksiksiz ve özenle yerine getirmektedir. Üstün gayretinden ötürü tebrik ederim.',
          'Ders etkinliklerindeki yüksek motivasyonu, olumlu davranışları ve sorumluluk bilinciyle harika bir dönem geçirdi. Başarılarının artarak devamını dilerim.',
          'Planlı çalışma disiplini, derse aktif katılımı ve sorulara getirdiği özgün yaklaşımlarla takdir toplamıştır. Başarılarının devamını dilerim.',
          'Ödev sorumluluğunu titizlikle yerine getirmekte, ders içi tartışma ve etkinliklerde aktif rol almaktadır. Başarılarının daim olmasını temenni ederim.',
          'Derse hazırlıklı gelişi, güçlü odaklanma becerisi ve çalışma azmiyle dönem boyunca çok başarılı bir grafik çizmiştir. Tebrikler.',
          'Ders içi süreçlerdeki gayreti, arkadaşlarına örnek olan çalışma ahlakı ve ödev teslimindeki hassasiyeti takdire şayandır.',
          'Ders kazanımlarını kavramada gösterdiği üstün başarı ve derse olan yüksek ilgisi için teşekkür eder, başarılarının devamını dilerim.',
          'Dönem boyunca sergilediği istikrarlı çalışma, yüksek görev bilinci ve ders içi aktifliğiyle takdir toplamıştır.',
          'Ders içi katılımı ve sorumluluk bilinci en üst düzeydedir. Aynı azim, merak ve istikrarla çalışmaya devam etmesini dilerim.',
          'Ödevlerini eksiksiz tamamlaması, dersi can kulağıyla dinlemesi ve öğrenme merakıyla çok verimli bir dönem tamamlamıştır.',
          'Akademik başarısını ders içi olumlu tutum ve yüksek sorumluluk bilinciyle taçlandırmıştır. Başarılarının katlanarak sürmesini dilerim.',
        ];
        return variations[combinedIndex % variations.length];
      }

      // 75 - 89 Puan (Başarılı / Düzenli) -> 10 Farklı Varyasyon
      if (calculatedGrade >= 75) {
        final variations = [
          tagHighlight != null
              ? 'Dersi dikkatle takip etmekte ve $tagHighlight yönüyle öne çıkmaktadır. Düzenli çalışma disipliniyle başarısını daha da artıracağına inanıyorum.'
              : 'Ders içi katılımı ve ödev bilinci olumlu düzeydedir. Düzenli çalışma disipliniyle başarısını çok daha yukarılara taşıyacağına inanıyorum.',
          'Ders etkinliklerine düzenli olarak katılmakta ve sorumluluklarını yerine getirmektedir. Gayretli çalışmalarının devamını dilerim.',
          'Ders içi odaklanması ve ödev takibi başarılıdır. Detaylara göstereceği küçük bir özenle çok daha büyük başarılara ulaşacaktır.',
          'Sorumluluk bilinci gelişmiş olup ders süreçlerine olumlu katkı sağlamaktadır. İstikrarlı çalışmasını sürdürmesini dilerim.',
          'Dersi dikkatle dinlemekte ve verilen çalışmaları zamanında yapmaktadır. Merak ve soru sorma cesaretini artırırsa başarısı daha da parlayacaktır.',
          'Dönem boyunca sergilediği düzenli çalışma ve olumlu ders içi tutumu memnuniyet vericidir. Aynı gayretle devam etmesini dilerim.',
          'Ders içi katılımı dengeli ve istikrarlıdır. Ev çalışmalarındaki konu tekrarlarını pekiştirerek başarısını zirveye taşıyabilir.',
          'Ders materyallerini eksiksiz getirmekte ve görevlerini yerine getirmektedir. Kendine olan güvenini artırarak çok daha ileri gidecektir.',
          'Ders içi etkinliklerde istekli ve sorumluluk sahibidir. Başarı çıtasını daha da yükseltme potansiyeline fazlasıyla sahiptir.',
          'Gayretli ve uyumlu bir dönem geçirmiştir. Planlı çalışma alışkanlığını devam ettirdiğinde başarıları katlanarak artacaktır.',
        ];
        return variations[combinedIndex % variations.length];
      }

      // 60 - 74 Puan (Orta / Geliştirilmeli) -> 8 Farklı Varyasyon
      if (calculatedGrade >= 60) {
        final variations = [
          'Ders içi motivasyonunu ve ev çalışmalarındaki düzenini biraz daha artırması durumunda yüksek potansiyelini çok daha iyi yansıtacaktır.',
          'Ders katılımı olumlu olmakla birlikte ödev teslimi ve ders hazırlıklarında daha planlı olması başarısını önemli ölçüde artıracaktır.',
          'Dersi daha aktif dinlemesi, derse hazırlıklı gelmesi ve eksik konularını zamanında tamamlaması durumunda başarısı yükselecektir.',
          'Potansiyeli yüksek bir öğrencimizdir. Evde düzenli konu tekrarı ve ödev takibiyle çok daha başarılı bir seviyeye ulaşacaktır.',
          'Ders içi dikkatini daha uzun süre koruduğunda ve ödevlerine gereken titizliği gösterdiğinde başarısı belirgin şekilde artacaktır.',
          'Derse katılım gösterme isteği mevcuttur. Ancak ev çalışmalarını aksatmadan yürütmesi başarısının kalıcı olması için şarttır.',
          'Ders araç-gereç hazırlığına ve günlük ödev takibine daha fazla özen göstermesi durumunda çok daha iyi bir konuma gelecektir.',
          'Ders esnasında soru sorma ve sürece dahil olma gayretini artırması, akademik başarısına doğrudan olumlu yansıyacaktır.',
        ];
        return variations[combinedIndex % variations.length];
      }

      // < 60 Puan (Desteklenmeli / Riskli) -> 6 Farklı Varyasyon
      final variations = [
        'Ders içi odaklanma, ödev takibi ve düzenli çalışma alışkanlığı kazanma konusunda aile desteğine ve planlı bir takibe ihtiyaç duymaktadır.',
        'Ders araç-gereçlerini düzenli getirmesi ve verilen ödevleri zamanında tamamlaması ders başarısını ve motivasyonunu artıracaktır.',
        'Dersi dikkatle dinlemesi, ders içi etkinliklere katılım göstermesi ve evde düzenli ders çalışması için desteklenmesi gerekmektedir.',
        'Planlı ve disiplinli bir çalışma programı uygulandığında potansiyelini ortaya çıkararak çok daha başarılı olacaktır.',
        'Ders içi dikkatini toplaması, ödevlerini aksatmaması ve eksik olduğu konuları veli desteğiyle tamamlaması önem arz etmektedir.',
        'Ders sürecine daha aktif katılması ve evde günlük ders tekrarı yapması durumunda başarısını belirgin şekilde yükseltebilir.',
      ];
      return variations[combinedIndex % variations.length];
    } catch (e, stackTrace) {
      debugPrint('generateEOkulComment hatası: $e\n$stackTrace');
      return 'Ders içi katılımı ve gayretleri için teşekkür eder, verimli ve güzel bir tatil dilerim.';
    }
  }

  /// Eski geriye dönük uyumluluk metodu
  String generateReportCardComment({
    required String studentName,
    required double averageGrade,
    int positiveStarsCount = 0,
    double? homeworkCompletionRate,
    List<String> observationTags = const [],
  }) {
    return generateEOkulComment(
      calculatedGrade: averageGrade,
      homeworkRate: homeworkCompletionRate,
      tags: observationTags,
    );
  }
}
