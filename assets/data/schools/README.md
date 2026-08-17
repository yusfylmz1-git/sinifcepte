# Okul dizini (paket içi)

`schools_manifest.json` + `tr_01.json` … `tr_81.json`

- Kamu kurum adları / il / ilçe / kurum kodu. Öğrenci veya veli PII yok.
- Kaynak: MEB kamu okul listesinin derlenmiş kopyası (ticari olmayan eğitim aracı).
- Kaldırma talebi: destek@sinifcepte.app
- Canlı MEB HTTP uygulama içinde çağrılmaz.

Yeniden üretmek: `python scripts/schools/build_shards.py`
