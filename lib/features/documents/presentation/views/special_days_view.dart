import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/turkish_text.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../data/special_days_repository.dart';
import '../widgets/pano_content_sheet.dart';

/// MEB Belirli Gün ve Haftalar çizelgesi.
///
/// ## Neden bu ekran
/// Öğretmen "önümüzdeki hafta hangi belirli gün var" sorusunu her ay
/// soruyor ve cevabı bir PDF'te arıyor. Çizelge 60 madde; hepsini
/// listelemek yetmez, YAKLAŞANI öne çıkarmak gerekir.
class SpecialDaysView extends ConsumerStatefulWidget {
  const SpecialDaysView({super.key});

  @override
  ConsumerState<SpecialDaysView> createState() => _SpecialDaysViewState();
}

class _SpecialDaysViewState extends ConsumerState<SpecialDaysView>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _arama = TextEditingController();
  final _repo = SpecialDaysRepository();
  final _panoRepo = PanoContentRepository();

  List<SpecialDay> _etkinlikli = const [];

  /// İçeriği hazır olan gün adları — karta rozet basmak için.
  Set<String> _icerikliler = const {};

  List<({SpecialDay madde, DateTime tarih})> _yaklasan = const [];
  Map<int, List<SpecialDay>> _aylara = const {};
  bool _yukleniyor = true;

  static const _ayAdlari = [
    '',
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  /// Öğretim yılı sırası — Eylül'den başlar.
  static const _sira = [9, 10, 11, 12, 1, 2, 3, 4, 5, 6, 7, 8, 0];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _yukle();
  }

  @override
  void dispose() {
    _tab.dispose();
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final y = await _repo.upcoming(gunSayisi: 45);
    final a = await _repo.byMonth();
    final e = await _repo.withActivities();
    final i = await _panoRepo.availableDays();
    if (!mounted) return;
    setState(() {
      _yaklasan = y;
      _aylara = a;
      _etkinlikli = e;
      _icerikliler = i;
      _yukleniyor = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Belirli Gün ve Haftalar',
        subtitle: 'MEB Çizelgesi',
        showProfileAvatar: false,
      ),
      body: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _sekmeCubugu(isDark),
                  Expanded(
                    child: TabBarView(
                      controller: _tab,
                      children: [
                        _panoSekmesi(isDark),
                        ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                          children: [
                            if (_yaklasan.isNotEmpty) ...[
                              _baslik(isDark, 'Yaklaşanlar', '45 gün içinde'),
                              const SizedBox(height: 8),
                              for (final y in _yaklasan)
                                _yaklasanKart(isDark, y),
                              const SizedBox(height: 20),
                            ],
                            _baslik(
                              isDark,
                              'Tam Çizelge',
                              '${_toplam()} madde',
                            ),
                            const SizedBox(height: 4),
                            for (final ay in _sira)
                              if (_aylara[ay] != null) ..._ayBolumu(isDark, ay),
                            const SizedBox(height: 14),
                            _kaynakNotu(isDark),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sekmeCubugu(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
        labelStyle: AppFonts.outfit(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: AppFonts.outfit(fontSize: 12.5),
        padding: const EdgeInsets.all(4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: const [
          Tab(text: 'Pano & Etkinlikler'),
          Tab(text: 'Çizelge'),
        ],
      ),
    );
  }

  /// Pano/tören çalışması yapılan günler.
  ///
  /// ## Neden ayrı sekme
  /// Çizelgedeki 61 maddenin hepsi için pano hazırlanmaz — "Dünya
  /// Fikrî Mülkiyet Günü" anılır ama sınıf çalışma yapmaz. Öğretmenin
  /// fiilen hazırlık yaptığı günler ayrı listede durur.
  ///
  /// Liste yalnızca içeriği hazır günleri gösterir; boş karta basıp
  /// "içerik yok" görmesin.
  Widget _panoSekmesi(bool isDark) {
    final q = _arama.text.trim();
    final sirali = [
      ..._etkinlikli.where((m) => _icerikliler.contains(m.ad)),
    ]..sort((a, b) {
        int k(int? ay) {
          final i = _sira.indexOf(ay ?? 0);
          return i < 0 ? 99 : i;
        }

        final f = k(a.ay).compareTo(k(b.ay));
        if (f != 0) return f;
        return (a.baslangicGun ?? 99).compareTo(b.baslangicGun ?? 99);
      });
    final gorunen = q.isEmpty
        ? sirali
        : sirali
            .where((m) =>
                trContains(m.ad, q) || trContains(m.tarihMetni, q))
            .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          controller: _arama,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Gün veya hafta ara',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _arama.clear();
                      setState(() {});
                    },
                  ),
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          q.isEmpty
              ? 'Okulda pano veya tören yapılan ${sirali.length} gün. '
                  'Çizelgenin tamamı ikinci sekmede.'
              : '${gorunen.length} sonuç',
          style: AppFonts.outfit(
            fontSize: 12,
            height: 1.45,
            color: isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 12),
        if (gorunen.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              'Eşleşen gün bulunamadı.',
              textAlign: TextAlign.center,
              style: AppFonts.outfit(
                fontSize: 13,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
          )
        else
          for (final m in gorunen) _panoKart(isDark, m),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.04,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            'Etkinlik planı kürsüde okunan programdır. Çalışma raporu '
            'uygulama sonrası doldurulup okula verilir. Konuşma ve şiir '
            'örnek taslaktır; adlar ve sıra okuluna göre değişir.',
            style: AppFonts.outfit(
              fontSize: 11,
              height: 1.45,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  Widget _panoKart(bool isDark, SpecialDay m) {
    final icerikVar = _icerikliler.contains(m.ad);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _acGun(m),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_outlined,
                    size: 18,
                    color: Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.ad,
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.tarihMetni,
                        style: AppFonts.outfit(
                          fontSize: 11.5,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                // İçeriği hazır olan günler işaretlenir; boş kartı açıp
                // hayal kırıklığı yaşamasın.
                if (icerikVar)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'İçerik',
                      style: AppFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _toplam() => _aylara.values.fold<int>(0, (a, b) => a + b.length);

  Widget _baslik(bool isDark, String metin, String ek) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          metin,
          style: AppFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ek,
          style: AppFonts.outfit(
            fontSize: 11.5,
            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Future<void> _acGun(SpecialDay m) async {
    final icerik = await _panoRepo.forDay(m.ad);
    if (!mounted) return;
    final profil = ref.read(teacherProfileProvider);
    final sinif = ref.read(homeroomClassProvider);
    await PanoContentSheet.show(
      context,
      gun: m,
      icerik: icerik,
      schoolName: profil.schoolName,
      className: sinif?.name ?? '',
      teacherName: profil.fullName,
      academicYear: AppDateFormatter.academicYearLabel(),
    );
  }

  Widget _yaklasanKart(bool isDark, ({SpecialDay madde, DateTime tarih}) y) {
    final bugun = DateTime.now();
    final fark = DateTime(
      y.tarih.year,
      y.tarih.month,
      y.tarih.day,
    ).difference(DateTime(bugun.year, bugun.month, bugun.day)).inDays;
    final buGun = fark == 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: y.madde.etkinlikli ? () => _acGun(y.madde) : null,
        child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: buGun
              ? AppColors.primary
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          width: buGun ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: buGun ? 0.18 : 0.09),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              children: [
                Text(
                  '${y.tarih.day}',
                  style: AppFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  _ayAdlari[y.tarih.month].substring(0, 3),
                  style: AppFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  y.madde.ad,
                  style: AppFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  buGun ? 'Bugün' : (fark == 1 ? 'Yarın' : '$fark gün sonra'),
                  style: AppFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: buGun ? FontWeight.w700 : FontWeight.w400,
                    color: buGun
                        ? AppColors.primary
                        : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  List<Widget> _ayBolumu(bool isDark, int ay) {
    final maddeler = _aylara[ay]!;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          ay == 0 ? 'Tarihi değişken' : _ayAdlari[ay],
          style: AppFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: AppColors.primary,
          ),
        ),
      ),
      for (final m in maddeler) _satir(isDark, m),
    ];
  }

  Widget _satir(bool isDark, SpecialDay m) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        onTap: m.etkinlikli ? () => _acGun(m) : null,
        child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 6, right: 9),
            decoration: BoxDecoration(
              color: isDark ? Colors.white38 : const Color(0xFFCBD5E1),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.ad,
                  style: AppFonts.outfit(
                    fontSize: 13,
                    height: 1.3,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  m.tarihMetni,
                  style: AppFonts.outfit(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// Değişken tarihli maddeler hakkında dürüst not.
  Widget _kaynakNotu(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Kaynak: MEB Belirli Gün ve Haftalar Çizelgesi. '
        '"Eylül ayının 3. haftası" gibi değişken tarihli maddeler '
        'yaklaşanlar listesinde çıkmaz; tam çizelgede tarih ifadesiyle '
        'birlikte görünür.',
        style: AppFonts.outfit(
          fontSize: 11,
          height: 1.45,
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
