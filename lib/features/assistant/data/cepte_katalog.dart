/// Cepte'nin bildiği her şey.
///
/// ## Anahtarlar öğretmenin sözleri
/// Ekranın adı değil öğretmenin aklındaki söz aranır: "kroki" (oturma
/// planı), "yoklama" (devamsızlık), "telefon değiştirdim" (yedekleme),
/// "veli toplantısı" (dönem sonu raporu, veli kılavuzu PDF'i). Kullanıcı
/// eski Cepte için "senaryolar çeşitli değil" dedi (9 Ekim 2026); liste
/// buna göre genişletildi. Yeni bir ekran eklenince buraya da eklenmeli
/// (`cepte_katalog_test` her `CepteEkran`ın burada olduğunu denetliyor).
library;

import 'cepte_arama.dart';
import 'cepte_niyet.dart';

/// Boş ekranda ve "bulamadım" cevabında gösterilen örnek aramalar.
///
/// Kullanıcı seçti (10 Ekim 2026): öğretmenin aklına ilk gelen sözler.
/// "kroki" gibi az kullanılan eş anlamlılar örnek değil, yalnız anahtar.
const List<String> cepteOrnekAramalar = [
  'kazanım',
  'veli',
  'oturma planı',
  'yıllık plan',
  'günlük plan',
  'zümre',
  'ŞÖK',
];

CepteHedef _ekran(
  CepteEkran ekran,
  String baslik,
  String yol,
  List<String> anahtarlar, {
  CepteKategori kategori = CepteKategori.ekran,
  int oncelik = 0,
}) =>
    CepteHedef(
      id: 'ekran:${ekran.name}',
      baslik: baslik,
      yol: yol,
      kategori: kategori,
      anahtarlar: anahtarlar,
      eylem: EkranEylemi(ekran),
      oncelik: oncelik,
    );

/// Sınıf seçmeden açılan ekranlar.
List<CepteHedef> cepteEkranHedefleri() => [
      _ekran(CepteEkran.dersProgrami, 'Ders programım', 'Alt menü › Program', [
        'ders programı', 'program', 'haftalık program', 'bugünkü dersler',
        'hangi derse giriyorum', 'boş ders', 'ders ekle', 'programa ders ekle',
        'çizelge',
      ], oncelik: 3),
      _ekran(CepteEkran.dersSaatleri, 'Ders saatleri', 'Program › Saatleri göster', [
        'zil saatleri', 'zil', 'ders saati', 'teneffüs', 'öğle arası',
        'ders kaçta bitiyor', 'kaçıncı ders',
      ]),
      _ekran(CepteEkran.dersIciKatilim, 'Ders içi katılım', 'Ana sayfa › Ders içi katılım', [
        'katılım', 'söz hakkı', 'yıldız', 'kura', 'sırada kim', 'rastgele öğrenci',
        'öğrenci seç', 'ödev kontrolü', 'ödev yaptı mı', 'kitap defter',
        'araç gereç', 'artı eksi', 'performans', 'derse katılım', 'ders değerlendirme',
      ], oncelik: 4),
      _ekran(CepteEkran.donemSonuRaporlari, 'Dönem sonu raporları',
          'Ders içi katılım › Raporlar', [
        'dönem sonu', 'yıl sonu', 'katılım raporu', 'katılım çizelgesi',
        'idareye rapor', 'veli toplantısı', 'veli toplantısı kılavuzu',
        'öğrenci gelişim kartı', 'gelişim raporu', 'performans raporu',
        'artı eksi raporu',
      ]),
      _ekran(CepteEkran.karneGorusleri, 'Karne görüşleri', 'Raporlar › Karne görüşleri', [
        'karne', 'karne yorumu', 'karne görüşü', 'öğretmen görüşü',
        'öğrenci hakkında görüş', 'yorum yaz',
      ]),
      _ekran(CepteEkran.kazanimlar, 'Kazanımlar', 'Alt menü › Kazanımlar', [
        'kazanım', 'müfredat', 'konu', 'bu hafta ne işlenecek', 'ne işleyeceğim',
        'öğrenme çıktısı', 'maarif', 'tymm', 'ünite', 'haftalık konu',
      ], oncelik: 3),
      _ekran(CepteEkran.yillikPlanlar, 'Yıllık planlar', 'Belgeler › Yıllık planlar', [
        'yıllık plan', 'çerçeve plan', 'ünitelendirilmiş plan', 'yıllık ders planı',
      ], oncelik: 2),
      _ekran(CepteEkran.gunlukPlanlar, 'Günlük planlar', 'Belgeler › Günlük planlar', [
        'günlük plan', 'ders planı', 'işleniş planı', 'haftalık plan', 'ders işleniş',
      ], oncelik: 2),
      _ekran(CepteEkran.belirliGunler, 'Belirli gün ve haftalar', 'Belgeler › Belirli günler', [
        'belirli gün', 'belirli hafta', 'pano', 'tören', 'anma', 'kutlama',
        'etkinlik planı', 'çalışma raporu', 'bugün ne var', 'yaklaşan günler',
      ], oncelik: 2),
      _ekran(CepteEkran.sosyalKulupler, 'Sosyal kulüpler', 'Belgeler › Sosyal kulüpler', [
        'kulüp', 'sosyal kulüp', 'ek-4', 'ek 4', 'kulüp planı', 'kulüp üyeleri',
        'faaliyet raporu', 'toplum hizmeti',
      ]),
      _ekran(CepteEkran.zumreTutanagi, 'Zümre tutanağı', 'Belgeler › Kurul tutanakları', [
        'zümre', 'zümre toplantısı', 'zümre öğretmenler kurulu', 'zümre tutanağı',
        'sene başı zümre', 'dönem sonu zümre',
      ], oncelik: 2),
      _ekran(CepteEkran.sokTutanagi, 'ŞÖK tutanağı', 'Belgeler › Kurul tutanakları', [
        'şök', 'şube öğretmenler kurulu', 'şube kurulu', 'şök tutanağı',
        'sınıf geçme kurulu',
      ], oncelik: 2),
      _ekran(CepteEkran.kurulTutanaklari, 'Kurul tutanakları', 'Belgeler › Kurul tutanakları', [
        'öğretmenler kurulu', 'tutanak', 'kurul', 'toplantı tutanağı',
      ], oncelik: 1),
      _ekran(CepteEkran.ogretmenDosyasi, 'Öğretmen dosyası', 'Belgeler › Öğretmen dosyası', [
        'öğretmen dosyası', 'dosya kapağı', 'atatürk köşesi', 'istiklal marşı',
        'gençliğe hitabe', 'özlük', 'künye', 'dosya',
      ]),
      _ekran(CepteEkran.digerEvraklar, 'Belgeler', 'Ana sayfa › Diğer evraklar', [
        'evrak', 'belge', 'diğer evraklar', 'resmi yazı', 'çıktı', 'pdf',
      ]),
      _ekran(CepteEkran.sinavIslemleri, 'Sınav işlemleri', 'Ana sayfa › Sınav işlemleri', [
        'sınav', 'yazılı', 'not', 'not girişi', 'notlar',
      ], oncelik: 1),
      _ekran(CepteEkran.sinavTakvimi, 'Sınav takvimi', 'Sınav işlemleri › Takvim', [
        'sınav tarihi', 'yazılı tarihi', 'sınav takvimi', 'ortak sınav',
        'yazılı ne zaman', 'sınav ekle',
      ]),
      _ekran(CepteEkran.projeOdev, 'Proje ve ödev değerlendirme', 'Sınav işlemleri › Proje', [
        'proje', 'proje ödevi', 'ödev notu', 'performans görevi', 'proje notu',
      ]),
      _ekran(CepteEkran.quizSozlu, 'Quiz ve sözlü not çizelgesi', 'Sınav işlemleri › Quiz', [
        'quiz', 'sözlü', 'sözlü notu', 'kısa sınav', 'performans notu',
        'ders etkinliklerine katılım notu',
      ]),
      _ekran(CepteEkran.sinavAnalizleri, 'Sınav analizleri', 'Raporlar › Sınav analizleri', [
        'sınav analizi', 'soru analizi', 'kazanım analizi', 'madde analizi',
        'istatistik', 'başarı analizi', 'soru bazlı',
      ]),
      _ekran(CepteEkran.rehberlik, 'Rehberlik', 'Ana sayfa › Rehberlik', [
        'rehberlik', 'sınıf rehberlik', 'rehberlik planı', 'rehberlik etkinliği',
        'orgm', 'rehber öğretmen', 'rehberlik çalışması',
      ]),
      _ekran(CepteEkran.ozelEgitim, 'Özel eğitim (BEP)', 'Rehberlik › Özel eğitim', [
        'bep', 'özel eğitim', 'kaynaştırma', 'bütünleştirme', 'ram',
        'bireyselleştirilmiş eğitim', 'kaba değerlendirme',
      ]),
      _ekran(CepteEkran.sinifim, 'Sınıfım', 'Ana sayfa › Sınıfım', [
        'sınıfım', 'sınıf yönetimi', 'sınıf evrakları', 'şubem', 'rehberlik sınıfım',
        'nöbetçi', 'nöbet', 'nöbetçi öğrenci', 'sınıf başkanı',
      ], oncelik: 2),
      _ekran(CepteEkran.siniflarim, 'Sınıflarım', 'Alt menü › Sınıflar', [
        'sınıflar', 'sınıf ekle', 'yeni sınıf', 'öğrenci ekle', 'öğrenci yükle',
        'e-okul listesi', 'öğrenci aktar', 'sınıf listesi', 'şube ekle',
      ], oncelik: 2),
      _ekran(CepteEkran.calismaTakvimi, 'MEB çalışma takvimi', 'Menü › Çalışma takvimi', [
        'takvim', 'tatil', 'ara tatil', 'karne günü', 'okul açılış', 'dönem başı',
        'resmi tatil', 'yarıyıl', 'yarıyıl tatili', 'bayram', 'hafta kaç',
      ]),
      _ekran(CepteEkran.eokulFoto, 'e-Okul foto', 'Menü › e-Okul foto', [
        'e-okul foto', 'fotoğraf', 'vesikalık', 'öğrenci fotoğrafı', '133x171',
        'fotoğraf çek', 'eokul resim',
      ]),
      _ekran(CepteEkran.tahtaKilidi, 'Tahta kilidi', 'Profil › Tahta kilidi', [
        'tahta', 'akıllı tahta', 'etkileşimli tahta', 'kilit', 'tahta şifresi',
        'tahta kodu', 'tahtayı aç', 'karekod',
      ]),
      _ekran(CepteEkran.topluDuyuru, 'Velilere toplu duyuru', 'Veli paneli › Toplu duyuru', [
        'veli duyuru', 'toplu duyuru', 'velilere mesaj', 'velilere duyuru',
        'veli bilgilendirme',
      ]),
      _ekran(CepteEkran.veriYedekleme, 'Veri yedekleme', 'Menü › Veri yedekleme',
          [
        'yedek', 'yedekleme', 'yedek al', 'telefon değiştirdim', 'yeni telefon',
        'verileri aktar', 'veri taşı', 'verilerim kaybolmasın',
      ], kategori: CepteKategori.ayar),
      _ekran(CepteEkran.geriYukleme, 'Yedekten geri yükle', 'Menü › Veri yedekleme',
          [
        'geri yükle', 'yedeği yükle', 'yedekten dön', 'eski verilerim',
      ], kategori: CepteKategori.ayar),
      _ekran(CepteEkran.ayarlar, 'Ayarlar', 'Menü › Ayarlar', [
        'tema', 'karanlık mod', 'gece modu', 'koyu tema', 'bildirim', 'bildirimler',
      ], kategori: CepteKategori.ayar),
      _ekran(CepteEkran.profil, 'Profil', 'Alt menü › Profil', [
        'profilim', 'hesabım', 'okulum', 'çıkış yap', 'hesap',
      ], kategori: CepteKategori.ayar),
      _ekran(CepteEkran.profilBilgileri, 'Öğretmen bilgileri', 'Profil › Öğretmen profili', [
        'ad soyad', 'branş', 'branşım', 'okul değiştir', 'tayin', 'okul müdürü',
        'müdür adı', 'imza', 'okul adı',
      ], kategori: CepteKategori.ayar),
    ];

/// Sınıfa bağlı ekranların başlığı, yolu ve anahtarları.
const Map<CepteSinifEkrani, (String, String, List<String>)> _sinifEkranlari = {
  CepteSinifEkrani.sinifim: ('Sınıfım', 'Sınıfım', [
    'sınıf yönetimi', 'sınıf evrakları', 'nöbetçi', 'nöbet', 'nöbetçi listesi',
  ]),
  CepteSinifEkrani.ogrenciListesi: ('Öğrenci listesi', 'Sınıflarım', [
    'öğrenciler', 'sınıf listesi', 'öğrenci ekle', 'öğrenci sil', 'numara',
    'sınıf mevcudu',
  ]),
  CepteSinifEkrani.oturmaPlani: ('Oturma planı', 'Sınıfım', [
    'oturma düzeni', 'kroki', 'sınıf krokisi', 'sıra düzeni', 'yerleşim',
    'kim nerede oturuyor',
  ]),
  CepteSinifEkrani.devamsizlik: ('Devamsızlık takibi', 'Sınıfım', [
    'devamsızlık', 'yoklama', 'gelmeyenler', 'gelmeyen öğrenci', 'özürsüz',
    'raporlu', 'okula gelmiyor',
  ]),
  CepteSinifEkrani.veliIletisim: ('Veli iletişim', 'Sınıfım', [
    'veli telefonu', 'veli numarası', 'veli rehberi', 'veliyi ara',
    'veli bilgileri', 'anne baba telefon',
  ]),
  CepteSinifEkrani.veliPaneli: ('Veli paneli', 'Sınıfım', [
    'veli', 'veliler', 'veli mesajı', 'veliye mesaj', 'veli kodu',
    'veli uygulaması', 'veli bağla',
  ]),
  CepteSinifEkrani.islenenDersler: ('İşlenen dersler', 'Ders içi katılım', [
    'geçmiş dersler', 'ders geçmişi', 'hangi dersi işledim', 'eski dersler',
  ]),
  CepteSinifEkrani.artiEksi: ('Artı-eksi listesi', 'Ders içi katılım', [
    'artı eksi', 'artı', 'eksi', 'artı ver', 'eksi ver', 'performans listesi',
  ]),
  CepteSinifEkrani.eokulFoto: ('e-Okul foto', 'e-Okul foto', [
    'fotoğraf', 'vesikalık', 'öğrenci fotoğrafı', 'fotoğraf çek',
  ]),
};

/// Her sınıf için sınıfa bağlı ekranlar: "Oturma planı · 5-A".
List<CepteHedef> cepteSinifHedefleri(
  List<({int id, String ad, String ders})> siniflar,
) =>
    [
      for (final s in siniflar)
        for (final e in _sinifEkranlari.entries)
          CepteHedef(
            id: 'sinif:${e.key.name}:${s.id}',
            baslik: '${e.value.$1} · ${s.ad}',
            yol: '${e.value.$2} › ${s.ad}${s.ders.isEmpty ? '' : ' ${s.ders}'}',
            kategori: CepteKategori.sinif,
            anahtarlar: [...e.value.$3, s.ders, s.ad],
            eylem: SinifEkraniEylemi(e.key, s.id),
            // Sınıfın kendisi ("5-A" yazınca) en üstte.
            oncelik: e.key == CepteSinifEkrani.sinifim ? 2 : 0,
          ),
    ];

/// Öğrenciler: ad, soyad ya da numarayla.
List<CepteHedef> cepteOgrenciHedefleri(
  List<({int id, int classId, String ad, int no, String sinifAdi})> ogrenciler,
) =>
    [
      for (final o in ogrenciler)
        CepteHedef(
          id: 'ogrenci:${o.id}',
          baslik: o.ad,
          yol: '${o.sinifAdi} · No ${o.no}',
          kategori: CepteKategori.ogrenci,
          anahtarlar: ['${o.no}', o.sinifAdi],
          eylem: OgrenciEylemi(o.id, o.classId),
        ),
    ];

/// MEB çizelgesindeki belirli gün ve haftalar. Öğretmen adı değil tarihi
/// yazar ("23 nisan"); tarih metni anahtardır.
List<CepteHedef> cepteBelirliGunHedefleri(
  List<({String ad, String tarihMetni, bool etkinlikli})> gunler,
) =>
    [
      for (final g in gunler)
        CepteHedef(
          id: 'gun:${g.ad}',
          baslik: g.ad,
          yol: 'Belirli günler · ${g.tarihMetni}',
          kategori: CepteKategori.belirliGun,
          anahtarlar: [
            g.tarihMetni,
            if (g.etkinlikli) ...['pano', 'tören', 'konuşma', 'şiir', 'etkinlik'],
          ],
          eylem: BelirliGunEylemi(g.ad, etkinlikli: g.etkinlikli),
        ),
    ];

/// EK-4 çizelgesindeki kulüpler. "Kızılay" yazan hem haftayı hem kulübü
/// görür; ikisi ayrı gruplarda.
///
/// `id` null ise katalogdaki kurulmamış kulüp.
List<CepteHedef> cepteKulupHedefleri(List<({int? id, String ad})> kulupler) => [
      for (final k in kulupler)
        CepteHedef(
          id: 'kulup:${k.id ?? k.ad}',
          baslik: k.ad,
          yol: 'Sosyal kulüpler',
          kategori: CepteKategori.kulup,
          anahtarlar: const ['kulüp', 'yıllık çalışma planı', 'üye listesi', 'faaliyet raporu'],
          eylem: KulupEylemi(k.id),
        ),
    ];

/// Öğretmenin sınıflarının seviyelerindeki dersler: kazanım, yıllık plan,
/// günlük plan.
List<CepteHedef> cepteKazanimHedefleri(
  List<({int sinif, String kod, String ad, String yayinci})> dersler,
) {
  final liste = <CepteHedef>[];
  for (final d in dersler) {
    final ek = d.yayinci.isEmpty ? '' : ' (${d.yayinci})';
    final ad = '${d.sinif}. sınıf ${d.ad}$ek';
    final yol = 'Kazanımlar › ${d.sinif}. sınıf';
    liste.addAll([
      CepteHedef(
        id: 'kazanim:${d.sinif}:${d.kod}:${d.yayinci}',
        baslik: '$ad kazanımları',
        yol: yol,
        kategori: CepteKategori.kazanim,
        anahtarlar: const ['kazanım', 'bu hafta', 'konu', 'müfredat', 'ne işlenecek'],
        eylem: KazanimEylemi(sinif: d.sinif, dersKodu: d.kod, dersAdi: d.ad, yayinci: d.yayinci),
      ),
      for (final gunluk in [false, true])
        CepteHedef(
          id: '${gunluk ? 'gunluk' : 'yillik'}:${d.sinif}:${d.kod}:${d.yayinci}',
          baslik: '$ad ${gunluk ? 'günlük' : 'yıllık'} planı',
          yol: '${gunluk ? 'Günlük' : 'Yıllık'} planlar · PDF hazırlanır',
          kategori: CepteKategori.kazanim,
          anahtarlar: gunluk
              ? const ['günlük plan', 'ders planı', 'işleniş planı']
              : const ['yıllık plan', 'çerçeve plan', 'ünitelendirilmiş plan'],
          eylem: PlanEylemi(CepteNiyet(
            tur: gunluk ? CepteNiyetTuru.gunlukPlan : CepteNiyetTuru.yillikPlan,
            sinif: d.sinif,
            dersKodu: d.kod,
            dersAdi: d.ad,
          )),
        ),
    ]);
  }
  return liste;
}

/// Yazılan cümle bir plan ya da kazanım isteğiyse en üste konan öneri.
///
/// Öğretmenin sınıflarında olmayan bir seviye de istenebilir ("7. sınıf
/// fen yıllık plan"). Eksik bilgi varsa Cepte üretmez, sorar.
CepteHedef? cepteNiyetHedefi(String sorgu) {
  final n = CepteCozumleyici.coz(sorgu);
  final String tur;
  switch (n.tur) {
    case CepteNiyetTuru.yillikPlan:
      tur = 'yıllık planı hazırla';
    case CepteNiyetTuru.gunlukPlan:
      tur = 'günlük planı hazırla';
    case CepteNiyetTuru.kazanimSor:
      tur = 'kazanımlarını göster';
    case CepteNiyetTuru.ekranAc:
    case CepteNiyetTuru.belirsiz:
      return null;
  }
  final sinif = n.sinif == null ? '' : '${n.sinif}. sınıf ';
  final ders = n.dersKodu == null ? '' : '${_dersAdi(n.dersKodu!)} ';
  final hafta = n.hafta == null ? '' : ' (${n.hafta}. hafta)';
  final eksik = n.eksikler.isEmpty
      ? ''
      : ' — ${n.eksikler.map((e) => e == 'sinif' ? 'sınıf' : e).join(' ve ')} sorulacak';
  return CepteHedef(
    id: 'niyet:$sorgu',
    baslik: '${(sinif + ders).isEmpty ? '' : sinif + ders}$tur$hafta'.trim(),
    yol: 'Cepte hazırlar$eksik',
    kategori: CepteKategori.hazirla,
    eylem: PlanEylemi(n),
  );
}

String _dersAdi(String kod) => const {
      'TURKCE': 'Türkçe',
      'MAT': 'Matematik',
      'FEN': 'Fen Bilimleri',
      'SOSYAL': 'Sosyal Bilgiler',
      'HAYAT': 'Hayat Bilgisi',
      'INGILIZCE': 'İngilizce',
      'DIN': 'Din Kültürü',
      'BILISIM': 'Bilişim Teknolojileri',
      'INKILAP': 'İnkılap Tarihi',
    }[kod] ??
    kod;
