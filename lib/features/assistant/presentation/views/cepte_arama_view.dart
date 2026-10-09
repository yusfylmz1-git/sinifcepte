import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/database_helper.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/name_formatter.dart';
import '../../../../shared/screens/pdf_preview_screen.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../../classes/providers/class_provider.dart';
import '../../../documents/data/special_days_repository.dart';
import '../../../documents/utils/annual_plan_pdf_generator.dart';
import '../../../documents/utils/daily_plan_pdf_generator.dart';
import '../../../outcomes/data/repositories/curriculum_outcome_repository.dart';
import '../../../outcomes/utils/kazanim_ders_eslestirici.dart';
import '../../../attendance/providers/classroom_participation_provider.dart';
import '../../data/cepte_arama.dart';
import '../../data/cepte_belge_servisi.dart';
import '../../data/cepte_katalog.dart';
import '../../data/cepte_niyet.dart';
import '../../providers/cepte_provider.dart';
import '../cepte_hedef_acici.dart';

/// Cepte: yazdıkça uygulamanın her yerini bulan arama.
///
/// Kullanıcı (9 Ekim 2026): "kutu yukarıda olsun, yazdıkça altta öneri
/// gelsin". Eski sohbette öğretmen cümleyi bitirip gönderiyor, cevabı
/// okuyor, sonra düğmeye basıyordu. Sohbet havası Cepte'nin SORU sorması
/// gereken yerde kaldı (plan için sınıf, ders, okul türü): tahmin edilmez,
/// sorulur. Bu uygulamanın çıktısı teftişe gidiyor.
class CepteAramaView extends ConsumerStatefulWidget {
  const CepteAramaView({super.key, this.ilkSorgu = ''});

  final String ilkSorgu;

  @override
  ConsumerState<CepteAramaView> createState() => _CepteAramaViewState();
}

/// Cepte'nin konuşarak sorduğu adım (plan hazırlama).
class _Balon {
  const _Balon({required this.metin, this.secenekler = const [], this.eylem, this.eylemEtiketi});

  final String metin;
  final List<(String, VoidCallback)> secenekler;
  final VoidCallback? eylem;
  final String? eylemEtiketi;
}

class _CepteAramaViewState extends ConsumerState<CepteAramaView> {
  static const _sonAnahtar = 'cepte_son_acilanlar';
  static const _grupSiniri = 5;

  late final TextEditingController _girdi = TextEditingController(text: widget.ilkSorgu);
  String _sorgu = '';
  List<String> _sonIdler = const [];
  final Set<CepteKategori> _acikGruplar = {};
  _Balon? _balon;
  bool _calisiyor = false;

  @override
  void initState() {
    super.initState();
    _sorgu = widget.ilkSorgu;
    _sonuYukle();
  }

  @override
  void dispose() {
    _girdi.dispose();
    super.dispose();
  }

  Future<void> _sonuYukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (mounted) setState(() => _sonIdler = p.getStringList(_sonAnahtar) ?? const []);
    } catch (_) {}
  }

  Future<void> _sonaEkle(String id) async {
    if (id.startsWith('niyet:')) return; // cümleye özel, katalogda yok
    final yeni = [id, ..._sonIdler.where((x) => x != id)].take(6).toList();
    setState(() => _sonIdler = yeni);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_sonAnahtar, yeni);
    } catch (_) {}
  }

  void _yaz(String metin) {
    _girdi.value = TextEditingValue(
      text: metin,
      selection: TextSelection.collapsed(offset: metin.length),
    );
    setState(() {
      _sorgu = metin;
      _acikGruplar.clear();
    });
  }

  Future<void> _ac(CepteHedef h) async {
    await _sonaEkle(h.id);
    if (!mounted) return;
    if (h.eylem case PlanEylemi(:final niyet)) {
      FocusScope.of(context).unfocus();
      await _planAdimi(niyet);
      return;
    }
    await cepteHedefiAc(context, ref, h);
  }

  // ---------------------------------------------------------------------------
  // Plan hazırlama: eksik bilgi SORULUR (sınıf, ders, okul türü).
  // ---------------------------------------------------------------------------

  CepteBelgeServisi get _servis => CepteBelgeServisi(
        dersleriGetir: (sinif) => DatabaseHelper.instance.mevcutDersleriGetir(sinif),
        kazanimlariGetir: ({
          required int gradeLevel,
          required String subjectCode,
          required String publisher,
        }) =>
            DatabaseHelper.instance.kazanimlariGetir(
          gradeLevel: gradeLevel,
          subjectCode: subjectCode,
          publisher: publisher,
        ),
        takvimdenTarih: AppDateFormatter.getWeekDateRangeText,
      );

  CepteNiyet _niyet(CepteNiyet n, {int? sinif, String? kod, String? ad}) => CepteNiyet(
        tur: n.tur,
        sinif: sinif ?? n.sinif,
        dersKodu: kod ?? n.dersKodu,
        dersAdi: ad ?? n.dersAdi,
        hafta: n.hafta,
      );

  void _sor(String metin, List<(String, VoidCallback)> secenekler) =>
      setState(() => _balon = _Balon(metin: metin, secenekler: secenekler));

  Future<void> _planAdimi(CepteNiyet n, {String? yayinci}) async {
    if (n.sinif == null) {
      final siniflar = ref.read(classListProvider).valueOrNull ?? const [];
      final seviyeler = {for (final c in siniflar) ?cepteSinifSeviyesi(c.name)}.toList()..sort();
      final secilecek = seviyeler.isEmpty ? List.generate(12, (i) => i + 1) : seviyeler;
      _sor('Hangi sınıf için?', [
        for (final s in secilecek) ('$s. sınıf', () => _planAdimi(_niyet(n, sinif: s))),
      ]);
      return;
    }
    if (n.dersKodu == null) {
      setState(() => _calisiyor = true);
      final dersler = await CurriculumOutcomeRepository().getAvailableSubjects(n.sinif!);
      if (!mounted) return;
      setState(() => _calisiyor = false);
      if (dersler.isEmpty) {
        setState(() => _balon = _Balon(metin: '${n.sinif}. sınıf için kazanım verisi bulunamadı.'));
        return;
      }
      _sor('${n.sinif}. sınıfta hangi ders?', [
        for (final d in dersler.take(18))
          (
            '${d['subject_name']}${'${d['publisher'] ?? ''}'.trim().isEmpty ? '' : ' (${d['publisher']})'}',
            () => _planAdimi(
                  _niyet(n, kod: '${d['subject_code']}', ad: '${d['subject_name']}'),
                  yayinci: '${d['publisher'] ?? ''}'.trim().isEmpty ? null : '${d['publisher']}'.trim(),
                ),
          ),
      ]);
      return;
    }

    // Kazanım sorusu: bilgiler tamsa kazanım sekmesi o derste açılır.
    if (n.tur == CepteNiyetTuru.kazanimSor) {
      final dersler = await CurriculumOutcomeRepository().getAvailableSubjects(n.sinif!);
      final d = kazanimDersiBul(dersler, n.dersKodu!);
      if (!mounted) return;
      if (d == null) {
        setState(() => _balon = _Balon(metin: '${n.sinif}. sınıfta bu ders bulunamadı.'));
        return;
      }
      await cepteHedefiAc(
        context,
        ref,
        CepteHedef(
          id: 'kazanim',
          baslik: '',
          kategori: CepteKategori.kazanim,
          eylem: KazanimEylemi(
            sinif: n.sinif!,
            dersKodu: '${d['subject_code']}',
            dersAdi: '${d['subject_name']}',
            yayinci: '${d['publisher'] ?? ''}'.trim(),
          ),
        ),
      );
      return;
    }

    final gunluk = n.tur == CepteNiyetTuru.gunlukPlan;
    setState(() => _calisiyor = true);
    await DatabaseHelper.instance.seedCurriculumOutcomesFromAssets();
    final sonuc = await _servis.planHazirla(n, ayrintili: gunluk, yayinci: yayinci);
    if (!mounted) return;
    setState(() => _calisiyor = false);

    switch (sonuc.durum) {
      case CepteBelgeDurumu.secimGerekli:
        _sor(sonuc.mesaj ?? 'Biraz daha bilgiye ihtiyacım var.', [
          for (final s in sonuc.secenekler) (s, () => _planAdimi(n, yayinci: s)),
        ]);
      case CepteBelgeDurumu.yapilamaz:
        setState(() => _balon = _Balon(metin: sonuc.mesaj ?? 'Bu belge hazırlanamadı.'));
      case CepteBelgeDurumu.hazir:
        _planHazir(sonuc, gunluk: gunluk);
    }
  }

  void _planHazir(CepteBelgeSonucu sonuc, {required bool gunluk}) {
    final teacher = ref.read(teacherProfileProvider);
    final yil = '${AppDateFormatter.academicYearLabel()} Eğitim-Öğretim Yılı';
    final ders = sonuc.dersAdi ?? 'Ders';
    final sinifAdi = '${sonuc.sinif}. Sınıf';
    final planlar = sonuc.planlar;
    setState(() => _balon = _Balon(
          metin: '$ders · $sinifAdi\n${planlar.length} haftalık '
              '${gunluk ? 'günlük' : 'yıllık'} plan hazır.\n\n'
              'Belge TASLAKTIR; zümre onayından geçmelidir.',
          eylemEtiketi: 'PDF olarak aç',
          // PDF daima önizleme ekranından: zaman aşımı ve hata ekranı orada.
          eylem: () => PdfPreviewScreen.open(
            context,
            title: gunluk ? '$ders Günlük Planlar' : '$ders Yıllık Çerçeve Planı',
            subtitle: '$sinifAdi • ${planlar.length} Hafta • $yil',
            fileName: '${ders}_${sinifAdi}_${gunluk ? 'Gunluk' : 'Yillik'}_Plan.pdf',
            documentBuilder: (format) => gunluk
                ? DailyPlanPdfGenerator.generateFullYearPdf(
                    allWeeksPlanData: planlar,
                    teacher: teacher,
                    ders: ders,
                    sinif: sinifAdi,
                    academicYear: yil,
                    format: format,
                  )
                : AnnualPlanPdfGenerator.generate(
                    allWeeksPlanData: planlar,
                    teacher: teacher,
                    ders: ders,
                    sinif: sinifAdi,
                    academicYear: yil,
                    format: format,
                  ),
          ),
        ));
  }

  // ---------------------------------------------------------------------------
  // Ekran
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final katalog = ref.watch(cepteKatalogProvider).valueOrNull;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('cepte_arama'),
          controller: _girdi,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() {
            _sorgu = v;
            _acikGruplar.clear();
          }),
          onSubmitted: (_) {
            final sonuclar = _sonuclar(katalog ?? const []);
            if (sonuclar.isNotEmpty) _ac(sonuclar.first);
          },
          decoration: InputDecoration(
            hintText: 'Ne arıyorsunuz? Örn: kroki, 23 nisan, Ali',
            border: InputBorder.none,
            suffixIcon: _sorgu.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Temizle',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _yaz(''),
                  ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            if (_calisiyor) const LinearProgressIndicator(minHeight: 2),
            if (_balon != null) _balonKarti(_balon!, isDark),
            if (katalog == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sorgu.trim().isEmpty)
              ..._bosEkran(katalog, isDark)
            else
              ..._sonucEkrani(katalog, isDark),
          ],
        ),
      ),
    );
  }

  List<CepteHedef> _sonuclar(List<CepteHedef> katalog) {
    final niyet = cepteNiyetHedefi(_sorgu);
    return [
      ?niyet,
      for (final s in cepteAra(_sorgu, katalog, sinir: 80)) s.hedef,
    ];
  }

  List<Widget> _sonucEkrani(List<CepteHedef> katalog, bool isDark) {
    final sonuclar = _sonuclar(katalog);
    if (sonuclar.isEmpty) {
      return [
        _balonKarti(
          _Balon(
            metin: '"${_sorgu.trim()}" için bir şey bulamadım. Şöyle yazabilirsiniz:',
            secenekler: [
              for (final o in _ornekler) (o, () => _yaz(o)),
            ],
          ),
          isDark,
        ),
      ];
    }
    final gruplar = <CepteKategori, List<CepteHedef>>{};
    for (final h in sonuclar) {
      (gruplar[h.kategori] ??= []).add(h);
    }
    return [
      for (final k in CepteKategori.values)
        if (gruplar[k] case final liste?) ...[
          _grupBasligi(k.baslik, isDark),
          for (final h in _acikGruplar.contains(k) ? liste : liste.take(_grupSiniri))
            _sonucSatiri(h, isDark),
          if (!_acikGruplar.contains(k) && liste.length > _grupSiniri)
            TextButton(
              onPressed: () => setState(() => _acikGruplar.add(k)),
              child: Text('${liste.length - _grupSiniri} sonuç daha'),
            ),
        ],
    ];
  }

  static const _ornekler = [
    'kroki',
    'yoklama',
    '23 nisan',
    'veli toplantısı',
    'karne yorumu',
    '5. sınıf türkçe yıllık plan',
  ];

  List<Widget> _bosEkran(List<CepteHedef> katalog, bool isDark) {
    final kimlik = {for (final h in katalog) h.id: h};
    final ad = ref.watch(teacherProfileProvider).fullName.trim().split(' ').first;
    final son = [for (final id in _sonIdler) ?kimlik[id]];
    final bugun = _bugunIcin(katalog, kimlik);

    return [
      _balonKarti(
        _Balon(
          metin: 'Merhaba${ad.isEmpty ? '' : ' $ad'} Hocam 👋\n'
              'Ne arıyorsanız yazın: ekran, belge, sınıf, öğrenci, belirli gün, kulüp, kazanım.',
          secenekler: [for (final o in _ornekler) (o, () => _yaz(o))],
        ),
        isDark,
      ),
      if (son.isNotEmpty) ...[
        _grupBasligi('Son açtıklarınız', isDark),
        for (final h in son) _sonucSatiri(h, isDark),
      ],
      if (bugun.isNotEmpty) ...[
        _grupBasligi('Bugün işinize yarayabilecekler', isDark),
        for (final h in bugun) _sonucSatiri(h, isDark),
      ],
    ];
  }

  /// Bugünkü ilk dersin kazanımı, yaklaşan belirli günler, sık işler.
  List<CepteHedef> _bugunIcin(List<CepteHedef> katalog, Map<String, CepteHedef> kimlik) {
    final liste = <CepteHedef>[];
    final ders = ref.watch(activeTimetableLessonProvider).valueOrNull;
    if (ders != null) {
      final seviye = cepteSinifSeviyesi('${ders['class_name'] ?? ''}');
      if (seviye != null) {
        final kazanim = cepteAra('$seviye ${ders['subject_name'] ?? ''} kazanım', katalog)
            .map((s) => s.hedef)
            .where((h) => h.eylem is KazanimEylemi)
            .firstOrNull;
        if (kazanim != null) liste.add(kazanim);
      }
    }
    final yaklasan = ref.watch(_yaklasanGunlerProvider).valueOrNull ?? const [];
    for (final ad in yaklasan.take(2)) {
      final h = kimlik['gun:$ad'];
      if (h != null) liste.add(h);
    }
    for (final id in const ['ekran:dersIciKatilim', 'ekran:dersProgrami', 'ekran:yillikPlanlar']) {
      final h = kimlik[id];
      if (h != null) liste.add(h);
    }
    return liste;
  }

  Widget _grupBasligi(String metin, bool isDark) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(
          // `toUpperCase` Türkçe i'yi I yapıyor ("BELIRLI"); trUpper doğru.
          trUpper(metin),
          style: AppFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
      );

  Widget _sonucSatiri(CepteHedef h, bool isDark) {
    return Card(
      key: ValueKey('cepte_${h.id}'),
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 0,
      color: isDark ? AppColors.darkCardBackground : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: () => _ac(h),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.10),
          child: Icon(_ikon(h), size: 19, color: isDark ? Colors.white : AppColors.primary),
        ),
        title: Text(h.baslik, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: h.yol.isEmpty
            ? null
            : Text(h.yol, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  static IconData _ikon(CepteHedef h) => switch (h.eylem) {
        PlanEylemi() => Icons.auto_awesome_rounded,
        KazanimEylemi() => Icons.menu_book_rounded,
        OgrenciEylemi() => Icons.person_rounded,
        BelirliGunEylemi() => Icons.celebration_rounded,
        KulupEylemi() => Icons.groups_rounded,
        SinifEkraniEylemi(:final ekran) => switch (ekran) {
            CepteSinifEkrani.oturmaPlani => Icons.event_seat_rounded,
            CepteSinifEkrani.devamsizlik => Icons.person_off_rounded,
            CepteSinifEkrani.veliIletisim || CepteSinifEkrani.veliPaneli => Icons.family_restroom_rounded,
            CepteSinifEkrani.artiEksi => Icons.exposure_rounded,
            CepteSinifEkrani.eokulFoto => Icons.badge_rounded,
            _ => Icons.class_rounded,
          },
        EkranEylemi() => h.kategori == CepteKategori.ayar ? Icons.settings_rounded : Icons.apps_rounded,
      };

  /// Cepte'nin konuşan kartı. Çip renkleri temaya BIRAKILMAZ: uygulamanın
  /// `chipTheme`'i açık temada beyaz üstüne beyaz veriyordu (cihazda
  /// ölçüldü).
  Widget _balonKarti(_Balon b, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCardBackground : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primary,
                child: Text('C', style: AppFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b.metin,
                  style: AppFonts.outfit(
                    fontSize: 13.5,
                    height: 1.45,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (identical(b, _balon))
                IconButton(
                  tooltip: 'Kapat',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _balon = null),
                ),
            ],
          ),
          if (b.eylem != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: b.eylem,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text(b.eylemEtiketi ?? 'Aç'),
              ),
            ),
          ],
          if (b.secenekler.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final (etiket, eylem) in b.secenekler) _cip(etiket, eylem, isDark)],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cip(String metin, VoidCallback eylem, bool isDark) {
    return InkWell(
      onTap: eylem,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.18)
              : AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withValues(alpha: isDark ? 0.45 : 0.28)),
        ),
        child: Text(
          metin,
          style: AppFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.primary,
          ),
        ),
      ),
    );
  }
}

/// Önümüzdeki iki haftanın belirli günleri (adları).
final _yaklasanGunlerProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final y = await SpecialDaysRepository().upcoming(gunSayisi: 14);
    return [for (final g in y) g.madde.ad];
  } catch (_) {
    return const [];
  }
});
