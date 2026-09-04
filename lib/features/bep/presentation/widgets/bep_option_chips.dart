import 'package:flutter/material.dart';

/// Bankadan çoklu seçim — BEP tablosunun seçimle dolan sütunları için.
///
/// ## Neden çip
/// Bu sütunlar virgülle ayrılmış üç-dört ifade taşıyor. Serbest metin
/// kutusunda öğretmen bunları telefon klavyesiyle her satır için
/// yeniden yazmak zorunda kalıyordu; pratikte kimse yazmıyor, sütun
/// sabit metinle dolduruluyordu.
///
/// Seçilen değerler virgülle birleştirilip tek metin olarak saklanır:
/// PDF hücresi zaten bu biçimi bekliyor ve eski kayıtlar (serbest
/// yazılmış metinler) bozulmadan okunmaya devam ediyor.
class BepOptionChips extends StatelessWidget {
  const BepOptionChips({
    super.key,
    required this.baslik,
    required this.banka,
    required this.secili,
    required this.onChanged,
    this.ipucu,
  });

  final String baslik;
  final List<String> banka;

  /// Virgülle ayrılmış seçim metni — modeldeki alanın ta kendisi.
  final String secili;

  final ValueChanged<String> onChanged;
  final String? ipucu;

  List<String> get _secililer => secili
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _degistir(String deger) {
    final liste = _secililer;
    if (liste.contains(deger)) {
      liste.remove(deger);
    } else {
      liste.add(deger);
    }
    onChanged(liste.join(', '));
  }

  /// Bankada olmayan, öğretmenin kendi yazdığı ifadeler.
  ///
  /// Eski kayıtlar serbest metindi; banka dışında kaldıkları için
  /// görünmez olmamalılar, yoksa öğretmen yazdığını kaybetti sanır.
  List<String> get _bankaDisi =>
      _secililer.where((e) => !banka.contains(e)).toList();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final koyu = tema.brightness == Brightness.dark;
    final secililer = _secililer;

    // Çip etiketine renk VERİLMEZSE tema devralıyor ve aydınlık
    // modda beyaz kalıp okunmuyordu. İki mod da açıkça ele alınır.
    final yaziRengi = koyu ? Colors.white : const Color(0xFF0F172A);
    final secilenRengi = koyu ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              baslik,
              style: tema.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 6),
            if (secililer.isNotEmpty)
              Text(
                '${secililer.length} seçili',
                style: tema.textTheme.labelSmall
                    ?.copyWith(color: tema.colorScheme.primary),
              ),
          ],
        ),
        if (ipucu != null) ...[
          const SizedBox(height: 2),
          Text(ipucu!, style: tema.textTheme.bodySmall),
        ],
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final d in _bankaDisi)
              InputChip(
                label: Text(d,
                    style: TextStyle(fontSize: 11.5, color: secilenRengi)),
                selected: true,
                onSelected: (_) => _degistir(d),
                onDeleted: () => _degistir(d),
                visualDensity: VisualDensity.compact,
              ),
            for (final d in banka)
              FilterChip(
                label: Text(
                  d,
                  style: TextStyle(
                    fontSize: 11.5,
                    color:
                        secililer.contains(d) ? secilenRengi : yaziRengi,
                  ),
                ),
                selected: secililer.contains(d),
                onSelected: (_) => _degistir(d),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    );
  }
}

/// Tek seçim çipi — ölçüt gibi tek değerli alanlar için.
class BepSingleChips extends StatelessWidget {
  const BepSingleChips({
    super.key,
    required this.baslik,
    required this.banka,
    required this.secili,
    required this.onChanged,
  });

  final String baslik;
  final List<String> banka;
  final String secili;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final koyu = tema.brightness == Brightness.dark;
    final yaziRengi = koyu ? Colors.white : const Color(0xFF0F172A);
    final mevcut = secili.trim();
    final bankaDisi = mevcut.isNotEmpty && !banka.contains(mevcut);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: tema.textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            if (bankaDisi)
              ChoiceChip(
                label: Text(mevcut,
                    style: TextStyle(fontSize: 11.5, color: yaziRengi)),
                selected: true,
                onSelected: (_) {},
                visualDensity: VisualDensity.compact,
              ),
            for (final d in banka)
              ChoiceChip(
                label: Text(d,
                    style: TextStyle(fontSize: 11.5, color: yaziRengi)),
                selected: mevcut == d,
                onSelected: (_) => onChanged(d),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ],
        ),
      ],
    );
  }
}
