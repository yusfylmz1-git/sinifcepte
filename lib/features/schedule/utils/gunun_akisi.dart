import '../models/lesson_model.dart';
import '../models/schedule_settings.dart';

/// Özet'teki günün akışında gösterilecek dersler (saf hesap, test edilir).
///
/// ## Neden (26 Ekim 2026)
/// Eskiden günün İLK dört dersi gösteriliyor, ilki saate bakılmadan "şu
/// an" diye vurgulanıyordu. 4. dersten sonra sıradaki ders hiç
/// görünmüyordu; sabahın ilk dersi gün boyu "şu an" duruyordu. Kullanıcı:
/// "bazen bir sonraki ders gözükmüyor, bir karışıklık var". Dört ders de
/// çok yer kaplıyordu; artık en çok iki.
class GununAkisi {
  /// Bitmemiş dersler, saat sırasıyla, en çok iki.
  final List<LessonModel> dersler;

  /// İlk ders şu an işleniyor mu (değilse "sıradaki").
  final bool ilkiSuAn;

  /// Bugün ders vardı ama hepsi bitti.
  final bool bitti;

  /// Bugünkü ders sayısı.
  final int toplam;

  const GununAkisi({
    required this.dersler,
    required this.ilkiSuAn,
    required this.bitti,
    required this.toplam,
  });
}

GununAkisi gununAkisi(
  List<LessonModel> bugunkuDersler,
  ScheduleSettings ayar,
  DateTime simdi, {
  int enCok = 2,
}) {
  final sirali = [...bugunkuDersler]..sort((a, b) => a.lessonHourIndex.compareTo(b.lessonHourIndex));
  final dakika = simdi.hour * 60 + simdi.minute;
  final kalan = [
    for (final d in sirali)
      if (ayar.dersDakikalari(d.lessonHourIndex).bit > dakika) d,
  ];
  if (kalan.isEmpty) {
    return GununAkisi(dersler: const [], ilkiSuAn: false, bitti: sirali.isNotEmpty, toplam: sirali.length);
  }
  return GununAkisi(
    dersler: kalan.take(enCok).toList(),
    ilkiSuAn: ayar.dersDakikalari(kalan.first.lessonHourIndex).bas <= dakika,
    bitti: false,
    toplam: sirali.length,
  );
}

/// Özet'teki katılım kartının dersi ne durumda.
enum KartDersDurumu { suAn, azOnceBitti, siradaki }

/// Özet'teki katılım kartında hangi ders gösterilecek (saf hesap, test edilir).
///
/// ## Neden (29 Ekim 2026)
/// Kart kendi saat hesabını yapıyordu. Günün dersleri bitince hiçbir ders
/// bulamıyor, 1. saatin dersine düşüyordu: altta "Bugünkü 6 dersiniz
/// bitti" yazarken üstte "SIRADAKİ DERS · 1. Ders Saati" duruyordu.
/// Ayrıca ders başlamadan önce de "şu an derstesiniz" diyordu. Artık
/// [gununAkisi] ile aynı saatleri ([ScheduleSettings.dersDakikalari])
/// kullanıyor.
///
/// Ders bitince [pay] dakika daha "az önce bitti" diye kalır: öğretmen
/// katılımı çoğunlukla dersin sonunda girer. Son ders bittikten [pay]
/// dakika sonra kart kalkar.
({int index, KartDersDurumu durum})? kartDersi(
  Iterable<int> dersSaatleri,
  ScheduleSettings ayar,
  DateTime simdi, {
  int pay = 5,
}) {
  final sirali = dersSaatleri.toSet().toList()..sort();
  final dakika = simdi.hour * 60 + simdi.minute;
  for (final i in sirali) {
    final d = ayar.dersDakikalari(i);
    if (d.bas <= dakika && dakika < d.bit) {
      return (index: i, durum: KartDersDurumu.suAn);
    }
  }
  for (final i in sirali.reversed) {
    final d = ayar.dersDakikalari(i);
    if (d.bit <= dakika && dakika <= d.bit + pay) {
      return (index: i, durum: KartDersDurumu.azOnceBitti);
    }
  }
  for (final i in sirali) {
    if (dakika < ayar.dersDakikalari(i).bas) {
      return (index: i, durum: KartDersDurumu.siradaki);
    }
  }
  return null;
}
