import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_fonts.dart';
import '../../auth_profile/providers/teacher_profile_provider.dart';
import '../../auth_profile/providers/user_role_provider.dart';
import '../../schedule/models/schedule_settings.dart';
import '../data/okul_config_service.dart';
import '../data/school_board_repository.dart';
import '../data/tahta_anahtar_deposu.dart';
import '../data/tahta_ogretmen_deposu.dart';
import '../models/okul_config_model.dart';

/// Tahta Yönetimi — idarecinin etkileşimli tahtaları yapılandırdığı ekran.
///
/// ## Neden ayrı ekran (kullanıcı kararı)
///
/// `SchoolAdminPanelView` içine sekme eklemek yerine ayrı sayfa: nöbetçi
/// takvimi ve duyuru formu geniş alan istiyor, panelin iki sekmesi
/// (öğretmen onayı, şikâyetler) ise farklı bir işe hizmet ediyor.
///
/// ## Üç bölüm
///
/// 1. **Anahtar** — imzalama anahtarı durumu ve yedeği. En üstte, çünkü
///    anahtar yoksa hiçbir yapılandırma üretilemez.
/// 2. **Pano içeriği** — nöbetçi ve duyuru (buluta yazılır, tahta
///    doğrudan okumaz).
/// 3. **Tahta kurulumu** — `okul_config` üretip flash belleğe aktarma.
///
/// ## Yetki
///
/// Yalnızca onaylı okul yöneticisi. Kapsam custom claim'den okunur
/// (`UserRoleState.adminSchoolId`), yerel profilden değil: profil bir
/// tercihtir ve claim ile ayrışabilir.
class TahtaYonetimiScreen extends ConsumerStatefulWidget {
  const TahtaYonetimiScreen({super.key});

  @override
  ConsumerState<TahtaYonetimiScreen> createState() =>
      _TahtaYonetimiScreenState();
}

class _TahtaYonetimiScreenState extends ConsumerState<TahtaYonetimiScreen> {
  final _anahtarDeposu = TahtaAnahtarDeposu();
  final _panoDeposu = SchoolBoardRepository();
  final _ogretmenDeposu = TahtaOgretmenDeposu();

  bool _yukleniyor = true;
  bool _anahtarVar = false;
  DateTime? _anahtarTarihi;

  // Pano içeriği
  final _duyuruBaslikCtrl = TextEditingController();
  final _duyuruMetinCtrl = TextEditingController();
  final _nobetciAdCtrl = TextEditingController();
  final _nobetciKatCtrl = TextEditingController();
  final _ogretmenAdCtrl = TextEditingController();

  /// Tahtanın beklediği gün adları — `ekran.py::_GUNLER` ile aynı sıra
  /// ve aynı yazım (aksansız, küçük harf).
  ///
  /// Kullanıcıya `_gunEtiketleri` gösterilir, dosyaya bu değerler
  /// yazılır. Aksanlı yazım da tahtada eşleşiyor ama kanonik biçimi
  /// göndermek, sahada tek bir belirsizlik bırakmıyor.
  static const _gunler = [
    'pazartesi',
    'sali',
    'carsamba',
    'persembe',
    'cuma',
    'cumartesi',
    'pazar',
  ];

  static const _gunEtiketleri = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  String _nobetciGunu = _gunler.first;

  List<PanoOgretmeni> _ogretmenListesi = const [];

  bool _isliyor = false;

  @override
  void initState() {
    super.initState();
    _durumYukle();
  }

  @override
  void dispose() {
    _duyuruBaslikCtrl.dispose();
    _duyuruMetinCtrl.dispose();
    _nobetciAdCtrl.dispose();
    _nobetciKatCtrl.dispose();
    _ogretmenAdCtrl.dispose();
    super.dispose();
  }

  Future<void> _durumYukle() async {
    final varMi = await _anahtarDeposu.anahtarVarMi();
    final tarih = await _anahtarDeposu.uretimTarihi();
    final liste = await _ogretmenDeposu.oku();
    if (!mounted) return;
    setState(() {
      _anahtarVar = varMi;
      _anahtarTarihi = tarih;
      _ogretmenListesi = liste;
      _yukleniyor = false;
    });
  }

  /// Yöneticiliğin geçerli olduğu okul kimliği.
  ///
  /// Claim öncelikli: yetkiyi veren de kapsamı belirleyen de sunucudur.
  String _okulId(UserRoleState rol, String? profilOkulId) {
    if (rol.adminSchoolId.isNotEmpty) return rol.adminSchoolId;
    return profilOkulId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rol = ref.watch(userRoleProvider);
    final ogretmen = ref.watch(teacherProfileProvider);
    final okulId = _okulId(rol, ogretmen.schoolId);

    if (!rol.isSchoolAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tahta Yönetimi')),
        body: _yetkiYok(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tahta Yönetimi', style: AppFonts.outfit(fontSize: 17)),
            Text(
              ogretmen.schoolName,
              style: AppFonts.outfit(fontSize: 11.5, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _caydiriciUyarisi(isDark),
                const SizedBox(height: 16),
                _anahtarBolumu(isDark, ogretmen.schoolName),
                const SizedBox(height: 16),
                _ogretmenBolumu(isDark, okulId),
                const SizedBox(height: 16),
                _nobetciBolumu(isDark, okulId),
                const SizedBox(height: 16),
                _duyuruBolumu(isDark, okulId),
                const SizedBox(height: 16),
                _kurulumBolumu(isDark, okulId, ogretmen.schoolName),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // --- Dürüstlük uyarısı ---

  /// Kilidin ne olmadığını açıkça söyler.
  ///
  /// Panelin kaynak düğmesi kilidi atlıyor (MEB şartnamesi md. 1.11.3),
  /// ETAP yönetici ve BIOS şifreleri kamuya açık. Bu ekranı kullanan
  /// idareci "tahtam güvende" sanmamalı; yanlış beklenti sorumluluk
  /// doğurur.
  Widget _caydiriciUyarisi(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.14 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 19, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tahta kilidi bir caydırıcı katmandır, güvenlik kilidi '
              'değildir. Panelin kaynak (HDMI/VGA) düğmesi kilidi atlar '
              've bu yazılımla engellenemez.',
              style: AppFonts.outfit(fontSize: 11.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Anahtar ---

  Widget _anahtarBolumu(bool isDark, String okulAdi) {
    return _kart(
      isDark,
      baslik: '🔑 İmzalama Anahtarı',
      aciklama: _anahtarVar
          ? 'Tahtaya gönderdiğiniz dosyalar bu anahtarla imzalanır.'
          : 'Yapılandırma üretmek için önce anahtar oluşturulmalı.',
      cocuklar: [
        if (_anahtarVar) ...[
          _bilgiSatiri(
            Icons.check_circle_outline_rounded,
            'Anahtar hazır',
            _anahtarTarihi == null
                ? ''
                : '${_anahtarTarihi!.day}.${_anahtarTarihi!.month}.'
                    '${_anahtarTarihi!.year} tarihinde oluşturuldu',
            Colors.green,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isliyor ? null : () => _yedegiGoster(okulAdi),
                  icon: const Icon(Icons.shield_outlined, size: 17),
                  label: Text('Yedeğini Al',
                      style: AppFonts.outfit(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isliyor ? null : _anahtariDegistir,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.autorenew_rounded, size: 17),
                  label: Text('Yenile',
                      style: AppFonts.outfit(fontSize: 12.5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Anahtarı kaybederseniz yeni yapılandırma yayımlayamazsınız '
            've her tahtaya elden yeni anahtar kurmanız gerekir. '
            'Yedeğini güvenli bir yere kaydedin.',
            style: AppFonts.outfit(
              fontSize: 10.5,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ] else
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isliyor ? null : _anahtarOlustur,
              icon: const Icon(Icons.key_rounded, size: 18),
              label: Text('Anahtar Oluştur',
                  style: AppFonts.outfit(fontSize: 13)),
            ),
          ),
      ],
    );
  }

  Future<void> _anahtarOlustur() async {
    setState(() => _isliyor = true);
    final anahtar = await _anahtarDeposu.anahtarHazirla();
    if (!mounted) return;
    setState(() => _isliyor = false);

    if (anahtar == null) {
      _mesaj('Anahtar oluşturulamadı. Cihaz güvenli deposuna '
          'erişilemiyor olabilir.', hata: true);
      return;
    }
    await _durumYukle();
    if (!mounted) return;
    _mesaj('Anahtar oluşturuldu. Şimdi yedeğini almanız önerilir.');
  }

  Future<void> _yedegiGoster(String okulAdi) async {
    final metin = await _anahtarDeposu.yedekMetniUret(okulAdi: okulAdi);
    if (!mounted || metin == null) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anahtar Yedeği',
            style: AppFonts.outfit(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: SelectableText(
            metin,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: metin));
              Navigator.pop(ctx);
              _mesaj('Yedek panoya kopyalandı. Güvenli bir yere kaydedin.');
            },
            child: const Text('Kopyala'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _anahtariDegistir() async {
    // Yenileme dağıtılmış TÜM tahtaları geçersiz kılar; onay şart.
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anahtarı yenilemek istiyor musunuz?',
            style: AppFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Yeni anahtar oluşturulunca, hâlihazırda kurulmuş tüm '
          'tahtalar yeni yapılandırmayı REDDEDER. Her tahtaya elden '
          'yeni doğrulama anahtarı kurmanız gerekir.\n\n'
          'Bunu yalnızca anahtarınızın başkasının eline geçtiğini '
          'düşünüyorsanız yapın.',
          style: AppFonts.outfit(fontSize: 12.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yenile'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    setState(() => _isliyor = true);
    final yeni = await _anahtarDeposu.anahtariDegistir();
    if (!mounted) return;
    setState(() => _isliyor = false);

    if (yeni == null) {
      _mesaj('Anahtar yenilenemedi.', hata: true);
      return;
    }
    await _durumYukle();
    if (!mounted) return;
    _mesaj('Anahtar yenilendi. Tüm tahtalara yeni yapılandırma '
        'götürmeniz gerekiyor.');
  }

  // --- 2. Öğretmenler ---

  /// Tahtayı açabilecek öğretmenler.
  ///
  /// Liste boşsa `okul_config` üretilse bile tahtada kimse kilidi
  /// açamaz — bu yüzden bölüm nöbetçi ve duyurudan önce geliyor.
  Widget _ogretmenBolumu(bool isDark, String okulId) {
    return _kart(
      isDark,
      baslik: '👤 Tahtayı Açabilecek Öğretmenler',
      aciklama: 'Her öğretmen için bir kod üretilir. Öğretmen kendi '
          'telefonunda QR\'ı okutup kaydeder.',
      cocuklar: [
        if (_ogretmenListesi.isEmpty)
          _bilgiSatiri(
            Icons.warning_amber_rounded,
            'Henüz öğretmen yok',
            'Listesi boş dosyayla tahtada kimse açamaz',
            Colors.orange,
          )
        else
          ..._ogretmenListesi.map((o) => _ogretmenSatiri(isDark, o, okulId)),
        const SizedBox(height: 10),
        TextField(
          controller: _ogretmenAdCtrl,
          maxLength: 60,
          decoration: _girdi('Öğretmen adı', 'A. Yılmaz'),
          style: AppFonts.outfit(fontSize: 13),
        ),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isliyor ? null : () => _ogretmenEkle(okulId),
            icon: const Icon(Icons.person_add_alt_rounded, size: 18),
            label: Text('Öğretmen Ekle',
                style: AppFonts.outfit(fontSize: 13)),
          ),
        ),
        if (_ogretmenListesi.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Öğretmen ekledikten veya çıkardıktan sonra kurulum '
            'dosyasını yeniden üretip tahtalara götürmeniz gerekir.',
            style: AppFonts.outfit(
              fontSize: 10.5,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _ogretmenSatiri(bool isDark, PanoOgretmeni o, String okulId) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(o.ad,
                    style: AppFonts.outfit(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('Kod: ${o.kod}',
                    style: AppFonts.outfit(
                        fontSize: 10.5, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kurulum QR\'ı',
            icon: const Icon(Icons.qr_code_2_rounded, size: 20),
            onPressed:
                _isliyor ? null : () => _kurulumQrGoster(o, okulId),
          ),
          IconButton(
            tooltip: 'Çıkar',
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: Colors.redAccent),
            onPressed: _isliyor ? null : () => _ogretmenCikar(o),
          ),
        ],
      ),
    );
  }

  Future<void> _ogretmenEkle(String okulId) async {
    final ad = _ogretmenAdCtrl.text.trim();
    if (ad.isEmpty) {
      _mesaj('Öğretmen adı boş olamaz.', hata: true);
      return;
    }

    setState(() => _isliyor = true);
    final sonuc = await _ogretmenDeposu.ekle(ad: ad);
    if (!mounted) return;

    // Liste doğrudan sonuçtan geliyor; `_ogretmenleriYukle()`
    // çağırmıyoruz. O çağrı güvenli depoya ÜÇÜNCÜ turu yapıyordu ve
    // yavaş Keystore'lu cihazlarda toplam süre ANR eşiğini (5 sn)
    // aşıp "uygulama yanıt vermiyor" veriyordu.
    setState(() {
      _isliyor = false;
      _ogretmenListesi = sonuc.liste;
    });

    if (!sonuc.basarili) {
      // Sebebi depo söylüyor; arayüz artık tahmin etmiyor.
      _mesaj(sonuc.hata ?? 'Öğretmen eklenemedi.', hata: true);
      return;
    }

    _ogretmenAdCtrl.clear();

    // Ekledikten sonra QR'ı hemen göster: idareci öğretmeni karşısında
    // bulmuşken okutması en pratik an.
    await _kurulumQrGoster(sonuc.kayit!, okulId);
  }

  Future<void> _ogretmenCikar(PanoOgretmeni o) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${o.ad} çıkarılsın mı?',
            style: AppFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Bu öğretmen yeni kurulum dosyasında yer almaz. Ama '
          'tahtalardaki MEVCUT dosya hâlâ geçerli: yeni dosyayı '
          'tahtalara götürene kadar açmaya devam edebilir.',
          style: AppFonts.outfit(fontSize: 12.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );

    if (onay != true) return;

    setState(() => _isliyor = true);
    await _ogretmenDeposu.sil(o.kod);
    if (!mounted) return;
    setState(() => _isliyor = false);
    await _ogretmenleriYukle();
    if (!mounted) return;
    _mesaj('${o.ad} çıkarıldı. Kurulum dosyasını yeniden üretin.');
  }

  /// Öğretmenin telefonuna okutulacak QR.
  ///
  /// Secret bu QR ile gidiyor; ekran görüntüsü alınıp paylaşılmaması
  /// gerektiği açıkça yazılıyor.
  Future<void> _kurulumQrGoster(PanoOgretmeni o, String okulId) async {
    if (okulId.isEmpty) {
      _mesaj('Okul bilgisi okunamadı.', hata: true);
      return;
    }

    final yuk = TahtaOgretmenDeposu.kurulumQrYuku(
      okulId: okulId,
      ogretmen: o,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(o.ad,
            style: AppFonts.outfit(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: QrImageView(
                data: yuk,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Öğretmen SınıfCepte > Profil > Tahta Kilidi ekranından '
              'bu kodu okutmalı.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 8),
            Text(
              'Bu QR öğretmenin açma yetkisini taşır. Ekran görüntüsü '
              'alıp paylaşmayın.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 10.5,
                color: Colors.redAccent,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _ogretmenleriYukle() async {
    final liste = await _ogretmenDeposu.oku();
    if (!mounted) return;
    setState(() => _ogretmenListesi = liste);
  }

  // --- 3. Nöbetçi ---

  Widget _nobetciBolumu(bool isDark, String okulId) {
    return _kart(
      isDark,
      baslik: '🧑‍🏫 Nöbetçi Öğretmen',
      aciklama: 'Tahtada teneffüste görünür. Liste haftalık tekrar eder — '
          'her ay yeniden girmeniz gerekmez.',
      cocuklar: [
        // Gün seçimi, tarih seçimi DEĞİL.
        //
        // Tarih bazlı yapıda nöbet listesi her ay yenilenmek zorundaydı
        // ve yeni dosyayı her tahtaya elden götürmek gerekiyordu —
        // 20 tahtalı bir okulda bu yapılmaz. Haftalık döngü bir kez
        // girilir, kendini tekrar eder.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < _gunler.length; i++)
              ChoiceChip(
                label: Text(
                  _gunEtiketleri[i],
                  style: AppFonts.outfit(fontSize: 12),
                ),
                selected: _nobetciGunu == _gunler[i],
                onSelected: _isliyor
                    ? null
                    : (_) => setState(() => _nobetciGunu = _gunler[i]),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nobetciAdCtrl,
          maxLength: 60,
          decoration: _girdi('Öğretmen adı', 'A. Yılmaz'),
          style: AppFonts.outfit(fontSize: 13),
        ),
        TextField(
          controller: _nobetciKatCtrl,
          maxLength: 40,
          decoration: _girdi('Kat / bölge', '1. Kat'),
          style: AppFonts.outfit(fontSize: 13),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isliyor ? null : () => _nobetciKaydet(okulId),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text('Nöbetçiyi Kaydet',
                style: AppFonts.outfit(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Future<void> _nobetciKaydet(String okulId) async {
    final ad = _nobetciAdCtrl.text.trim();
    if (ad.isEmpty) {
      _mesaj('Öğretmen adı boş olamaz.', hata: true);
      return;
    }
    if (okulId.isEmpty) {
      _mesaj('Okul bilgisi okunamadı. Çıkış yapıp tekrar girin.',
          hata: true);
      return;
    }

    setState(() => _isliyor = true);
    final basarili = await _panoDeposu.setDuty(
      schoolId: okulId,
      nobetci: NobetciKaydi(
        gun: _nobetciGunu,
        kat: _nobetciKatCtrl.text.trim(),
        ad: ad,
      ),
    );
    if (!mounted) return;
    setState(() => _isliyor = false);

    if (basarili) {
      _nobetciAdCtrl.clear();
      _nobetciKatCtrl.clear();
      _mesaj('Nöbetçi kaydedildi.');
    } else {
      _mesaj('Kaydedilemedi. Bağlantınızı kontrol edin.', hata: true);
    }
  }

  // --- 3. Duyuru ---

  Widget _duyuruBolumu(bool isDark, String okulId) {
    return _kart(
      isDark,
      baslik: '📢 İdare Duyurusu',
      aciklama: 'Tahtada teneffüste görünür. Sınıf duyurusundan farklıdır: '
          'bu duyuru tüm okula gider, veliye değil tahtaya.',
      cocuklar: [
        TextField(
          controller: _duyuruBaslikCtrl,
          maxLength: 100,
          decoration: _girdi('Başlık', 'Veli toplantısı'),
          style: AppFonts.outfit(fontSize: 13),
        ),
        TextField(
          controller: _duyuruMetinCtrl,
          maxLength: 2000,
          maxLines: 4,
          decoration: _girdi('Metin', 'Cuma 15:00, konferans salonu'),
          style: AppFonts.outfit(fontSize: 13),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isliyor ? null : () => _duyuruYayimla(okulId),
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: Text('Duyuruyu Yayımla',
                style: AppFonts.outfit(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Future<void> _duyuruYayimla(String okulId) async {
    final baslik = _duyuruBaslikCtrl.text.trim();
    if (baslik.isEmpty) {
      _mesaj('Duyuru başlığı boş olamaz.', hata: true);
      return;
    }
    if (okulId.isEmpty) {
      _mesaj('Okul bilgisi okunamadı. Çıkış yapıp tekrar girin.',
          hata: true);
      return;
    }

    setState(() => _isliyor = true);
    final basarili = await _panoDeposu.publishNotice(
      schoolId: okulId,
      duyuru: PanoDuyurusu(
        id: SchoolBoardRepository.newNoticeId(),
        baslik: baslik,
        metin: _duyuruMetinCtrl.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _isliyor = false);

    if (basarili) {
      _duyuruBaslikCtrl.clear();
      _duyuruMetinCtrl.clear();
      _mesaj('Duyuru yayımlandı.');
    } else {
      _mesaj('Yayımlanamadı. Bağlantınızı kontrol edin.', hata: true);
    }
  }

  // --- 4. Tahta kurulumu ---

  Widget _kurulumBolumu(bool isDark, String okulId, String okulAdi) {
    final hazir = _anahtarVar && okulId.isNotEmpty;

    return _kart(
      isDark,
      baslik: '💾 Tahta Kurulum Dosyası',
      aciklama: 'Tahta internete bağlanmaz. Bu iki dosyayı flash belleğe '
          'kopyalayıp tahtaya götürün.',
      cocuklar: [
        if (!_anahtarVar)
          _bilgiSatiri(
            Icons.warning_amber_rounded,
            'Önce anahtar oluşturun',
            'Dosya imzalanmadan tahta kabul etmez',
            Colors.orange,
          )
        else if (okulId.isEmpty)
          _bilgiSatiri(
            Icons.warning_amber_rounded,
            'Okul bilgisi okunamadı',
            'Çıkış yapıp tekrar girin',
            Colors.orange,
          )
        else
          _bilgiSatiri(
            Icons.check_circle_outline_rounded,
            'Üretime hazır',
            okulAdi,
            Colors.green,
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (!hazir || _isliyor)
                ? null
                : () => _configUret(okulId, okulAdi),
            icon: const Icon(Icons.download_rounded, size: 18),
            label: Text('Dosyayı Üret ve Paylaş',
                style: AppFonts.outfit(fontSize: 13)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Zil saatleri ders programı ayarlarınızdan alınır. Tahtada '
          'kurulum sırasında yalnızca "hangi sınıf/şube" sorulur.',
          style: AppFonts.outfit(
            fontSize: 10.5,
            color: Colors.grey,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Future<void> _configUret(String okulId, String okulAdi) async {
    setState(() => _isliyor = true);

    try {
      final anahtar = await _anahtarDeposu.ozelAnahtarOku();
      if (anahtar == null) {
        if (!mounted) return;
        setState(() => _isliyor = false);
        _mesaj('Anahtar okunamadı.', hata: true);
        return;
      }

      // Zil saatleri öğretmenin kendi ayarlarından; uydurulmuyor.
      final zil = await ScheduleSettings.load();

      // Sürüm zaman damgasından: her üretimde artar ve tahtanın geri
      // sarma koruması çalışır. Sabit sayı kullanılsaydı ikinci dosya
      // reddedilirdi.
      final surum = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // Öğretmen listesi ŞART: boş giderse tahtada hiç kimse TOTP veya
      // PIN ile kilidi açamaz. Bir süre tam bu hata vardı — liste
      // modelde tanımlıydı ama hiçbir yerden doldurulmuyordu.
      final ogretmenListesi = await _ogretmenDeposu.oku();
      if (ogretmenListesi.isEmpty) {
        if (!mounted) return;
        setState(() => _isliyor = false);
        _mesaj(
          'Önce en az bir öğretmen ekleyin. Listesi boş bir dosyayla '
          'tahtada kimse kilidi açamaz.',
          hata: true,
        );
        return;
      }

      final config = OkulConfigModel(
        surum: surum,
        okulId: okulId,
        okulAdi: okulAdi,
        uretimZamani: DateTime.now().toIso8601String(),
        // Okul yılı sonuna kadar geçerli: unutulmuş bir tahta eski
        // veriyle çalışmasın.
        gecerlilikBitis: DateTime(DateTime.now().year + 1, 8, 31)
            .toIso8601String(),
        zil: zil,
        ogretmenler: ogretmenListesi,
      );

      final sonuc = await OkulConfigService.uret(
        config: config,
        ozelAnahtar: anahtar,
      );

      if (!mounted) return;
      setState(() => _isliyor = false);

      if (!sonuc.basarili) {
        _mesaj(sonuc.hataMesaji, hata: true);
        return;
      }

      await OkulConfigService.paylas(sonuc);
      if (!mounted) return;
      _mesaj('Dosya üretildi (${sonuc.baytSayisi} bayt). İki dosyayı '
          'birlikte flash belleğe kopyalayın.');
    } catch (e, stackTrace) {
      debugPrint('Config üretim hatası: $e\n$stackTrace');
      if (!mounted) return;
      setState(() => _isliyor = false);
      _mesaj('Beklenmeyen hata: $e', hata: true);
    }
  }

  // --- Ortak parçalar ---

  Widget _kart(
    bool isDark, {
    required String baslik,
    required String aciklama,
    required List<Widget> cocuklar,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.grey.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(baslik,
              style: AppFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            aciklama,
            style: AppFonts.outfit(
                fontSize: 11.5, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 12),
          ...cocuklar,
        ],
      ),
    );
  }

  Widget _bilgiSatiri(
      IconData ikon, String baslik, String alt, Color renk) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 18, color: renk),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  style: AppFonts.outfit(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
              if (alt.isNotEmpty)
                Text(alt,
                    style: AppFonts.outfit(
                        fontSize: 11, color: Colors.grey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _girdi(String etiket, String ipucu) {
    return InputDecoration(
      labelText: etiket,
      hintText: ipucu,
      labelStyle: AppFonts.outfit(fontSize: 12.5),
      hintStyle: AppFonts.outfit(fontSize: 12.5, color: Colors.grey),
      isDense: true,
      border: const OutlineInputBorder(),
    );
  }

  Widget _yetkiYok() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 44, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              'Bu ekran yalnızca onaylı okul yöneticilerine açıktır',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _mesaj(String metin, {bool hata = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(metin, style: AppFonts.outfit(fontSize: 12.5)),
        backgroundColor: hata ? Colors.redAccent : AppColors.primary,
        duration: Duration(seconds: hata ? 5 : 3),
      ),
    );
  }

}
