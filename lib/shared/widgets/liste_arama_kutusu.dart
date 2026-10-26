import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/turkish_text.dart';

/// Listelerin üstündeki arama kutusu.
///
/// Kullanıcı (26 Ekim 2026): "BEP raporunda ve artı-eksi listesinde
/// öğrenci arama yok… Herhangi bir liste varsa arama kutusu olması işleri
/// hızlandırır." Bütün listeler bu kutuyu kullanır: aynı görünüş, aynı
/// eşleşme ([aramayaUyar]).
class ListeAramaKutusu extends StatefulWidget {
  const ListeAramaKutusu({
    super.key,
    required this.onChanged,
    this.ipucu = 'Ad veya numara ara',
    this.alanAnahtari = const ValueKey('liste_arama'),
  });

  final ValueChanged<String> onChanged;
  final String ipucu;

  /// Testler kutuyu bununla bulur.
  final Key alanAnahtari;

  @override
  State<ListeAramaKutusu> createState() => _ListeAramaKutusuState();
}

class _ListeAramaKutusuState extends State<ListeAramaKutusu> {
  final _denetleyici = TextEditingController();

  @override
  void dispose() {
    _denetleyici.dispose();
    super.dispose();
  }

  void _degisti(String metin) {
    widget.onChanged(metin);
    // Temizle düğmesi yalnız yazı varken görünür.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final soluk = isDark ? Colors.white54 : Colors.black54;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
      ),
      child: TextField(
        key: widget.alanAnahtari,
        controller: _denetleyici,
        onChanged: _degisti,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.primary,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: widget.ipucu,
          hintStyle: TextStyle(fontSize: 13, color: soluk),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: soluk),
          suffixIcon: _denetleyici.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Aramayı temizle',
                  icon: Icon(Icons.close_rounded, size: 18, color: soluk),
                  onPressed: () {
                    _denetleyici.clear();
                    _degisti('');
                  },
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    );
  }
}

/// Satır aramaya uyuyor mu?
///
/// Türkçe harf yazılmasa da bulur ("isil" → "Işıl"); her sözcük ayrı
/// aranır ("yilmaz ali" → "Ali YILMAZ"); rakam okul numarasında da
/// aranır. Boş arama her satıra uyar.
bool aramayaUyar(String sorgu, Iterable<String> metinler, {int numara = 0}) {
  final parcalar = trFold(sorgu).split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parcalar.isEmpty) return true;
  final govde = metinler.map(trFold).join(' ');
  final no = numara > 0 ? '$numara' : '';
  return parcalar.every((p) => govde.contains(p) || no.contains(p));
}

/// Arama hiçbir satıra uymadığında listenin yerine çıkan yazı.
class AramaSonucuYok extends StatelessWidget {
  const AramaSonucuYok({super.key, this.metin = 'Aramaya uyan öğrenci yok.'});

  final String metin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      key: const ValueKey('arama_sonucu_yok'),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Text(
        metin,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.black54),
      ),
    );
  }
}

/// Uzun açılır liste yerine aranabilir seçim penceresi.
///
/// [bosSecenek] verilirse en üstte "seçmeden devam" satırı çıkar ve
/// `(oge: null)` döner. Pencere kapatılırsa `null` döner (vazgeçildi).
Future<({T? oge})?> aranabilirSec<T>(
  BuildContext context, {
  required String baslik,
  required List<T> ogeler,
  required String Function(T) etiket,
  int Function(T)? numara,
  String? bosSecenek,
}) {
  return showModalBottomSheet<({T? oge})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AranabilirSecim<T>(
      baslik: baslik,
      ogeler: ogeler,
      etiket: etiket,
      numara: numara,
      bosSecenek: bosSecenek,
    ),
  );
}

class _AranabilirSecim<T> extends StatefulWidget {
  const _AranabilirSecim({
    required this.baslik,
    required this.ogeler,
    required this.etiket,
    required this.numara,
    required this.bosSecenek,
  });

  final String baslik;
  final List<T> ogeler;
  final String Function(T) etiket;
  final int Function(T)? numara;
  final String? bosSecenek;

  @override
  State<_AranabilirSecim<T>> createState() => _AranabilirSecimState<T>();
}

class _AranabilirSecimState<T> extends State<_AranabilirSecim<T>> {
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    final gorunen = [
      for (final o in widget.ogeler)
        if (aramayaUyar(_arama, [widget.etiket(o)], numara: widget.numara?.call(o) ?? 0)) o,
    ];
    final yukseklik = MediaQuery.sizeOf(context).height * 0.75;
    return Padding(
      // Klavye açılınca liste klavyenin üstünde kalsın.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: yukseklik,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(widget.baslik, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListeAramaKutusu(onChanged: (v) => setState(() => _arama = v)),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView(
                children: [
                  if (widget.bosSecenek != null && _arama.trim().isEmpty)
                    ListTile(
                      key: const ValueKey('secim_bos'),
                      leading: const Icon(Icons.description_outlined),
                      title: Text(widget.bosSecenek!),
                      onTap: () => Navigator.of(context).pop((oge: null)),
                    ),
                  for (final o in gorunen)
                    ListTile(
                      title: Text(
                        widget.numara == null || widget.numara!(o) <= 0
                            ? widget.etiket(o)
                            : '${widget.numara!(o)} · ${widget.etiket(o)}',
                      ),
                      onTap: () => Navigator.of(context).pop((oge: o)),
                    ),
                  if (gorunen.isEmpty) const AramaSonucuYok(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
