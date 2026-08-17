# Okul dizini

CI canlı MEB HTTP çağırmaz.

## Shard üret

```
python scripts/schools/build_shards.py
```

İsteğe bağlı büyük ham kaynak:

```
set SINIFCEPTE_SCHOOL_SOURCE=C:\path\Tüm Okullar.json
python scripts/schools/build_shards.py
```

Çıktı: `assets/data/schools/tr_01.json` … `tr_81.json` + `schools_manifest.json`.

## Operatör çekimi

`scripts/schools/fetch_meb_okullar.py` yalnızca geliştirici makinesinde çalışır.

Elle CSV/JSON bırakmak için: `scripts/schools/fixtures/`.
