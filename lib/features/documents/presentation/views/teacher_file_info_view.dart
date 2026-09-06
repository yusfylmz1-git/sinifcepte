import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/custom_app_bar.dart';
import '../../data/teacher_file_model.dart';

/// Özlük bilgileri formu.
///
/// ## Neden profile eklenmedi
/// Profil buluta yazılıyor (okul dizini, veli ekranı). TC kimlik,
/// sicil ve göreve başlama **özlük verisi**; projenin veri sahipliği
/// kararı gereği cihazda kalır.
///
/// Ad, okul ve branş burada SORULMAZ — onlar profilde zaten var;
/// iki yerde tutulursa biri eskir.
class TeacherFileInfoView extends StatefulWidget {
  final TeacherFileInfo baslangic;

  const TeacherFileInfoView({super.key, required this.baslangic});

  @override
  State<TeacherFileInfoView> createState() => _TeacherFileInfoViewState();
}

class _TeacherFileInfoViewState extends State<TeacherFileInfoView> {
  late final TextEditingController _tc;
  late final TextEditingController _sicil;
  late final TextEditingController _mezuniyet;
  late final TextEditingController _gorevBas;
  late final TextEditingController _okulBas;
  late final TextEditingController _unvan;
  late final TextEditingController _kadro;
  late final TextEditingController _telefon;
  late final TextEditingController _kan;

  /// Kadro durumu ve kan grubu serbest metin yerine seçim:
  /// öğretmen her yıl aynı şeyi yazmasın, yazım da tutarlı olsun.
  static const _kadroSecenekleri = ['Kadrolu', 'Sözleşmeli', 'Ücretli'];
  static const _kanSecenekleri = [
    'A Rh+', 'A Rh-', 'B Rh+', 'B Rh-',
    'AB Rh+', 'AB Rh-', '0 Rh+', '0 Rh-',
  ];

  @override
  void initState() {
    super.initState();
    final b = widget.baslangic;
    _tc = TextEditingController(text: b.nationalId);
    _sicil = TextEditingController(text: b.registryNo);
    _mezuniyet = TextEditingController(text: b.graduation);
    _gorevBas = TextEditingController(text: b.startedDutyAt);
    _okulBas = TextEditingController(text: b.startedSchoolAt);
    _unvan = TextEditingController(text: b.title);
    _kadro = TextEditingController(text: b.employmentType);
    _telefon = TextEditingController(text: b.phone);
    _kan = TextEditingController(text: b.bloodType);
  }

  @override
  void dispose() {
    for (final c in [
      _tc, _sicil, _mezuniyet, _gorevBas, _okulBas,
      _unvan, _kadro, _telefon, _kan,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _kaydet() {
    Navigator.pop(
      context,
      TeacherFileInfo(
        nationalId: _tc.text.trim(),
        registryNo: _sicil.text.trim(),
        graduation: _mezuniyet.text.trim(),
        startedDutyAt: _gorevBas.text.trim(),
        startedSchoolAt: _okulBas.text.trim(),
        title: _unvan.text.trim(),
        employmentType: _kadro.text.trim(),
        phone: _telefon.text.trim(),
        bloodType: _kan.text.trim(),
      ),
    );
  }

  /// Tarih seçici — elle "15.09.2015" yazmak zahmetli ve hatalı.
  Future<void> _tarihSec(TextEditingController hedef) async {
    final simdi = DateTime.now();
    final secilen = await showDatePicker(
      context: context,
      initialDate: _coz(hedef.text) ?? DateTime(simdi.year - 5, 9),
      firstDate: DateTime(1960),
      lastDate: DateTime(simdi.year + 1, 12, 31),
      helpText: 'Tarih seçin',
    );
    if (secilen == null) return;
    String iki(int n) => n.toString().padLeft(2, '0');
    setState(() {
      hedef.text =
          '${iki(secilen.day)}.${iki(secilen.month)}.${secilen.year}';
    });
  }

  /// "gg.aa.yyyy" -> DateTime. Bozuk kayıt ekranı düşürmemeli.
  static DateTime? _coz(String ham) {
    final p = ham.trim().split('.');
    if (p.length != 3) return null;
    final g = int.tryParse(p[0]);
    final a = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (g == null || a == null || y == null) return null;
    if (a < 1 || a > 12 || g < 1 || g > 31) return null;
    return DateTime(y, a, g);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: const CustomAppBar(
        title: 'Özlük Bilgileri',
        subtitle: 'Yalnızca bu cihazda saklanır',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu bilgiler telefonunuzdan çıkmaz. Ad, okul ve '
                      'branş profilinizden gelir.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        color: isDark
                            ? Colors.white70
                            : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _alan(
              _tc,
              'T.C. Kimlik Numarası',
              tur: TextInputType.number,
              enCok: 11,
              yalnizRakam: true,
            ),
            _alan(_sicil, 'Sicil Numarası',
                tur: TextInputType.number, enCok: 20),
            _alan(_unvan, 'Unvanı / Görevi',
                ipucu: 'Örn. Sınıf Öğretmeni', enCok: 60),
            _secim(_kadro, 'Kadro Durumu', _kadroSecenekleri, isDark),
            _alan(_mezuniyet, 'Mezun Olduğu Okul / Bölüm',
                ipucu: 'Örn. Gazi Üniversitesi / Sınıf Öğretmenliği',
                enCok: 120,
                satir: 2),
            _tarihAlani(_gorevBas, 'Göreve Başlama Tarihi', isDark),
            _tarihAlani(_okulBas, 'Bu Okulda Göreve Başlama', isDark),
            _alan(_telefon, 'Telefon',
                tur: TextInputType.phone, enCok: 20),
            _secim(_kan, 'Kan Grubu', _kanSecenekleri, isDark),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _kaydet,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Kaydet'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Boş bıraktığınız alanlar belgede noktalı satır olarak '
              'basılır; kalemle doldurabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _alan(
    TextEditingController c,
    String etiket, {
    String? ipucu,
    TextInputType tur = TextInputType.text,
    int enCok = 80,
    int satir = 1,
    bool yalnizRakam = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        keyboardType: tur,
        maxLines: satir,
        maxLength: enCok,
        inputFormatters: [
          LengthLimitingTextInputFormatter(enCok),
          if (yalnizRakam) FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          labelText: etiket,
          hintText: ipucu,
          border: const OutlineInputBorder(),
          counterText: '',
        ),
      ),
    );
  }

  /// Tarih alanı — takvimden seçilir, elle de yazılabilir.
  Widget _tarihAlani(
      TextEditingController c, String etiket, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        readOnly: true,
        onTap: () => _tarihSec(c),
        decoration: InputDecoration(
          labelText: etiket,
          hintText: 'gg.aa.yyyy',
          border: const OutlineInputBorder(),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (c.text.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Temizle',
                  icon: const Icon(Icons.backspace_outlined, size: 18),
                  onPressed: () => setState(() => c.clear()),
                ),
              IconButton(
                icon: const Icon(Icons.event_outlined, size: 19),
                onPressed: () => _tarihSec(c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sabit seçenekli alan — yazım tutarlılığı için.
  Widget _secim(
    TextEditingController c,
    String etiket,
    List<String> secenekler,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiket,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in secenekler)
                ChoiceChip(
                  label: Text(s, style: const TextStyle(fontSize: 12)),
                  selected: c.text.trim() == s,
                  visualDensity: VisualDensity.compact,
                  // Seçili çipe tekrar basmak temizler: öğretmen
                  // yanlış seçtiğinde geri alabilmeli.
                  onSelected: (v) =>
                      setState(() => c.text = v ? s : ''),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
