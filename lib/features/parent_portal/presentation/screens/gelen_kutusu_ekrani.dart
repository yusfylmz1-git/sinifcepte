import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cloud/cloud_ids.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../../../shared/widgets/liste_arama_kutusu.dart';
import '../../../auth_profile/data/services/teacher_identity.dart';
import '../../../auth_profile/providers/teacher_profile_provider.dart';
import '../../data/gelen_kutusu.dart';
import '../../providers/gelen_kutusu_provider.dart';
import '../widgets/parent_teacher_chat_modal.dart';
import 'sinif_velileri_ekrani.dart';

/// Gelen kutusunda gösterilenler.
enum GelenKutusuSuzgeci {
  tumu('Tümü'),
  mesajlar('Mesajlar'),
  randevular('Randevular'),
  bildirimler('Bildirimler');

  const GelenKutusuSuzgeci(this.ad);
  final String ad;
}

/// Veli gelen kutusu: bütün sınıflardan mesaj, randevu talebi ve veli
/// bildirimleri tek listede (18 Ekim 2026).
///
/// Branş öğretmeni kadrosunda olduğu sınıfların velilerinin kendisine
/// yazdıklarını da burada görür; eskiden bu mesajlar hiçbir ekrana
/// düşmüyordu. Tek sekme katmanı: süzgeç çipleri, iç içe sekme yok.
class GelenKutusuEkrani extends ConsumerStatefulWidget {
  /// Doluysa yalnız bu sınıf (Veliler sayfasından açılınca).
  final String? sinif;

  const GelenKutusuEkrani({super.key, this.sinif});

  static Future<void> ac(BuildContext context, {String? sinif}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GelenKutusuEkrani(sinif: sinif)),
    );
  }

  @override
  ConsumerState<GelenKutusuEkrani> createState() => _GelenKutusuEkraniState();
}

class _GelenKutusuEkraniState extends ConsumerState<GelenKutusuEkrani> {
  GelenKutusuSuzgeci _suzgec = GelenKutusuSuzgeci.tumu;
  late String? _sinif = widget.sinif;

  /// Öğrenci ya da veli adıyla arama.
  String _arama = '';

  Future<void> _sohbetiAc(SohbetOzeti o, GelenKutusuDurumu d) async {
    final teacher = ref.read(teacherProfileProvider);
    final uid = TeacherIdentity.resolve(teacher);
    if (!CloudIds.isValidUid(uid)) return;
    await ParentTeacherChatModal.show(
      context,
      classCloudId: o.classCloudId,
      studentCloudId: o.studentCloudId,
      studentName: o.studentName.isEmpty ? 'Öğrenci' : o.studentName,
      parentUserId: o.parentUserId,
      selfName: teacher.fullName,
      selfUid: uid,
      asTeacher: true,
      counterpartName: o.parentName.isEmpty ? 'Veli' : o.parentName,
      teacherUid: uid,
    );
    // Sohbet görüldü; öğretmenin bu sırada yazdıkları da bir sonraki
    // delta okumasıyla özete işlenir.
    await GelenKutusuDeposu(uid).gorulduIsaretle(o.anahtar);
    ref.invalidate(gelenKutusuProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(gelenKutusuProvider);
    final d = async.valueOrNull;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: CustomAppBar(
        title: 'Veli gelen kutusu',
        subtitle: d == null
            ? 'Yükleniyor…'
            : (d.okunmamisMesaj == 0 ? 'Okunmamış mesaj yok' : '${d.okunmamisMesaj} okunmamış mesaj'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => gelenKutusunuTazele(ref, kadroDahil: true),
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => ListView(
              children: [_bilgi(isDark, 'Gelen kutusu okunamadı. İnternet bağlantınızı kontrol edin.')],
            ),
            data: (d) => _liste(isDark, d),
          ),
        ),
      ),
    );
  }

  Widget _liste(bool isDark, GelenKutusuDurumu d) {
    if (!d.bulutVar) {
      return ListView(children: [
        _bilgi(isDark, 'Veli mesajları velilerle paylaşılan buluta bağlıdır; Google ile giriş yaptığınızda açılır.'),
      ]);
    }

    bool sinifta(String cls) => _sinif == null || _sinif == cls;
    final mesajlar = _suzgec == GelenKutusuSuzgeci.tumu || _suzgec == GelenKutusuSuzgeci.mesajlar;
    final randevu = _suzgec == GelenKutusuSuzgeci.tumu || _suzgec == GelenKutusuSuzgeci.randevular;
    final bildirim = _suzgec == GelenKutusuSuzgeci.tumu || _suzgec == GelenKutusuSuzgeci.bildirimler;

    bool uyar(String ogrenci, String veli) => aramayaUyar(_arama, [ogrenci, veli]);
    final sohbetler = [
      for (final o in d.sohbetler)
        if (sinifta(o.classCloudId) && uyar(o.studentName, o.parentName)) o,
    ];
    final randevular = [
      for (final r in d.randevular)
        if (sinifta(r.classCloudId) && uyar(r.randevu.studentName, r.randevu.parentName)) r,
    ];
    final bildirimler = [
      for (final b in d.bildirimler)
        if (sinifta(b.classCloudId) && uyar(b.bildirim.studentName, b.bildirim.parentName)) b,
    ];
    final aranabilir = d.sohbetler.isNotEmpty || d.randevular.isNotEmpty || d.bildirimler.isNotEmpty;

    final ogeler = <Widget>[
      _cipler(isDark, d),
      if (d.siniflar.isNotEmpty) _sinifNotu(isDark),
      if (aranabilir)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ListeAramaKutusu(
            ipucu: 'Öğrenci veya veli adı ara',
            onChanged: (v) => setState(() => _arama = v),
          ),
        ),
      if (d.eksik)
        _bilgi(isDark, 'Bazı sınıflar güncellenemedi. Aşağı çekip yeniden deneyin.', uyari: true),
      // Satırlar Veliler sayfasında gruplu listenin içinde, zeminsiz
      // (DEG-9); burada her biri kendi kartında durur.
      if (bildirim)
        for (final b in bildirimler)
          _kart(isDark, BildirimKarti(rapor: b.bildirim, classCloudId: b.classCloudId)),
      if (randevu)
        for (final r in randevular)
          _kart(isDark, RandevuKarti(randevu: r.randevu, classCloudId: r.classCloudId)),
      if (mesajlar)
        for (final o in sohbetler) _sohbetSatiri(isDark, o, d),
    ];

    final bos = (!mesajlar || sohbetler.isEmpty) &&
        (!randevu || randevular.isEmpty) &&
        (!bildirim || bildirimler.isEmpty);
    if (bos) {
      ogeler.add(_bilgi(
        isDark,
        d.siniflar.isEmpty
            ? 'Henüz veli bağlantısı olan sınıfınız yok. Rehberlik sınıfınızda veli kodu dağıtın; '
                'kadrosunda olduğunuz sınıfların velileri size yazınca da burada görünür.'
            : _arama.trim().isNotEmpty
                ? 'Aramaya uyan yazışma yok.'
                : 'Burada gösterilecek bir şey yok.',
      ));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: ogeler,
    );
  }

  Widget _cipler(bool isDark, GelenKutusuDurumu d) {
    Widget cip(String ad, bool secili, VoidCallback onTap, {Key? key}) => Padding(
          padding: const EdgeInsets.only(right: 6, bottom: 6),
          child: ChoiceChip(
            key: key,
            label: Text(ad),
            selected: secili,
            onSelected: (_) => onTap(),
            selectedColor: AppColors.primary,
            labelStyle: AppFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: secili ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
            ),
            showCheckmark: false,
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(children: [
            for (final s in GelenKutusuSuzgeci.values)
              cip(s.ad, _suzgec == s, () => setState(() => _suzgec = s), key: ValueKey('gk_suzgec_${s.name}')),
          ]),
          if (d.siniflar.length > 1)
            Wrap(children: [
              cip('Bütün sınıflar', _sinif == null, () => setState(() => _sinif = null)),
              for (final s in d.siniflar)
                cip(s.kendi ? '⭐ ${s.ad}' : s.ad, _sinif == s.classCloudId,
                    () => setState(() => _sinif = s.classCloudId)),
            ]),
        ],
      ),
    );
  }

  /// Hangi sınıfların burada olduğu (26 Ekim 2026): öğretmen derse
  /// girdiği bütün sınıfları görmeyi bekliyordu; listede yalnız velilerin
  /// ona yazabildiği sınıflar var.
  Widget _sinifNotu(bool isDark) {
    final renk = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    return Padding(
      key: const ValueKey('gk_sinif_notu'),
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.info_outline_rounded, size: 15, color: renk),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Burada velilerin size yazabildiği sınıflar var: rehberlik sınıfınız ve '
              'sizi kadrosuna ekleyen sınıflar. Derse girdiğiniz başka bir sınıf, '
              'rehber öğretmeni sizi kadroya ekleyince burada görünür.',
              style: AppFonts.outfit(fontSize: 11.5, height: 1.4, color: renk),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kart(bool isDark, Widget icerik) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: icerik,
        ),
      );

  Widget _sohbetSatiri(bool isDark, SohbetOzeti o, GelenKutusuDurumu d) {
    final sinif = d.sinifAdi(o.classCloudId);
    final ogrenci = o.studentName.isEmpty ? 'Öğrenci' : o.studentName;
    final veli = o.parentName.isEmpty ? 'Veli' : o.parentName;
    final okunmamis = o.okunmamis > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: ValueKey('gk_sohbet_${o.anahtar}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _sohbetiAc(o, d),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primary,
                  child: Text(ogrenci.characters.first,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sinif.isEmpty ? ogrenci : '$ogrenci · $sinif',
                        style: AppFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: okunmamis ? FontWeight.w800 : FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${o.sonYazanVeli ? veli : 'Siz'}: ${o.sonMesaj}',
                        style: AppFonts.outfit(
                          fontSize: 12,
                          color: okunmamis
                              ? (isDark ? Colors.white : const Color(0xFF1E293B))
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (okunmamis)
                  Container(
                    key: ValueKey('gk_okunmamis_${o.anahtar}'),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${o.okunmamis}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  )
                else
                  Icon(Icons.chevron_right_rounded, size: 18, color: isDark ? Colors.white38 : Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bilgi(bool isDark, String metin, {bool uyari = false}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: uyari
              ? Colors.orange.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          metin,
          style: AppFonts.outfit(
            fontSize: 12.5,
            height: 1.45,
            color: uyari
                ? Colors.orange.shade800
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      );
}
