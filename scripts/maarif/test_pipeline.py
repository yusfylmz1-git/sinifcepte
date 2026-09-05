"""
SınıfCepte müfredat boru hattı testleri.

    python scripts/maarif/test_pipeline.py
"""

from __future__ import annotations

import datetime
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from academic_calendar import (  # noqa: E402
    TOTAL_WEEKS,
    CalendarError,
    build_calendar,
    default_start_monday,
    format_range,
    parse_academic_year,
)
from build_curriculum import rebuild, strip_stale_dates, validate  # noqa: E402
from turkish_text import detect_category, detect_subject_code, fold  # noqa: E402


class TurkishTextTests(unittest.TestCase):
    def test_dotted_capital_i_is_folded(self):
        """Python'un lower() metodu 'İ' için birleşen nokta bırakır."""
        self.assertEqual(fold("İNGİLİZCE"), "ingilizce")
        self.assertEqual(fold("İNGILIZCE"), "ingilizce")
        self.assertEqual(fold("T.C. İNKILAP TARİHİ"), "t.c. inkilap tarihi")

    def test_english_and_history_do_not_collapse(self):
        """Asıl hata: her ikisi de 'GENEL' koduna düşüp kimlik çakışması yaratıyordu."""
        english = detect_subject_code("İNGİLİZCE")
        history = detect_subject_code("T.C. İNKILAP TARİHİ VE ATATÜRKÇÜLÜK")
        self.assertEqual(english, "INGILIZCE")
        self.assertEqual(history, "INKILAP")
        self.assertNotEqual(english, history)

    def test_no_subject_falls_into_genel_bucket(self):
        names = [
            "TÜRKÇE", "MATEMATİK", "FEN BİLİMLERİ", "SOSYAL BİLGİLER",
            "HAYAT BİLGİSİ", "BİLİŞİM TEKNOLOJİLERİ VE YAZILIM",
            "BEDEN EĞİTİMİ VE SPOR", "GÖRSEL SANATLAR", "MÜZİK",
            "Türk Dili ve Edebiyatı", "Coğrafya", "Felsefe", "Biyoloji",
        ]
        for name in names:
            with self.subTest(name=name):
                self.assertNotEqual(detect_subject_code(name), "GENEL")

    def test_unknown_subject_gets_own_code(self):
        """Bilinmeyen dersler ortak kovaya değil kendi koduna gitmeli."""
        a = detect_subject_code("Zeka Oyunları Atölyesi")
        b = detect_subject_code("Drama ve Yaratıcılık")
        self.assertNotEqual(a, b)

    def test_philosophy_group_subjects_are_separate(self):
        """Sosyoloji, Mantık ve Psikoloji ayrı derslerdir; FELSEFE'ye toplanmaz."""
        codes = {
            detect_subject_code("Felsefe"),
            detect_subject_code("Sosyoloji"),
            detect_subject_code("Mantık"),
            detect_subject_code("Psikoloji"),
        }
        self.assertEqual(len(codes), 4, f"kodlar cakisiyor: {codes}")
        self.assertEqual(detect_subject_code("Felsefe"), "FELSEFE")
        self.assertEqual(detect_subject_code("Sosyoloji"), "SOSYOLOJI")

    def test_category_detection(self):
        self.assertEqual(detect_category("Seçmeli Zekâ Oyunları"), "elective")
        self.assertEqual(detect_category("DYK Kursu"), "course")
        self.assertEqual(detect_category("Kur'an-ı Kerim"), "iho")
        self.assertEqual(detect_category("Matematik"), "core")


class CalendarTests(unittest.TestCase):
    def test_rejects_malformed_year(self):
        for bad in ["2026", "2026/2027", "2026-2028", "", "abc"]:
            with self.subTest(bad=bad):
                with self.assertRaises(CalendarError):
                    parse_academic_year(bad)

    def test_all_weeks_start_on_monday(self):
        for year in ["2026-2027", "2027-2028", "2030-2031"]:
            calendar = build_calendar(year)
            self.assertEqual(len(calendar), TOTAL_WEEKS)
            for week, info in calendar.items():
                start = datetime.date.fromisoformat(info["start"])
                with self.subTest(year=year, week=week):
                    self.assertEqual(start.weekday(), 0, "hafta pazartesi başlamalı")

    def test_weeks_are_consecutive(self):
        calendar = build_calendar("2026-2027")
        previous = None
        for week in range(1, TOTAL_WEEKS + 1):
            start = datetime.date.fromisoformat(calendar[week]["start"])
            if previous is not None:
                self.assertEqual((start - previous).days, 7)
            previous = start

    def test_2026_matches_official_meb_dates(self):
        """Elle yazılmış eski tabloyla birebir uyum (regresyon koruması)."""
        calendar = build_calendar("2026-2027")
        self.assertEqual(calendar[1]["start"], "2026-09-14")
        self.assertEqual(calendar[39]["end"], "2027-06-11")
        self.assertTrue(calendar[10]["is_holiday"])
        self.assertTrue(calendar[19]["is_holiday"])
        self.assertTrue(calendar[20]["is_holiday"])
        self.assertTrue(calendar[28]["is_holiday"])
        self.assertTrue(calendar[8]["is_otp"])
        self.assertTrue(calendar[18]["is_social_event"])

    def test_holidays_do_not_consume_teaching_weeks(self):
        calendar = build_calendar("2026-2027")
        for info in calendar.values():
            if info["is_holiday"]:
                self.assertIsNone(info["teaching_week"])
        teaching = [i["teaching_week"] for i in calendar.values() if i["teaching_week"]]
        # 39 takvim haftası - 4 tatil haftası = 35 ders haftası
        self.assertEqual(max(teaching), 35)
        self.assertEqual(teaching, sorted(teaching))

    def test_second_monday_rule(self):
        self.assertEqual(default_start_monday(2026), datetime.date(2026, 9, 14))
        self.assertEqual(default_start_monday(2027), datetime.date(2027, 9, 13))

    def test_format_range_handles_month_and_year_rollover(self):
        self.assertEqual(
            format_range(datetime.date(2026, 9, 14), datetime.date(2026, 9, 18)),
            "14 - 18 Eylül 2026")
        self.assertEqual(
            format_range(datetime.date(2026, 9, 28), datetime.date(2026, 10, 2)),
            "28 Eylül - 2 Ekim 2026")
        self.assertEqual(
            format_range(datetime.date(2026, 12, 28), datetime.date(2027, 1, 1)),
            "28 Aralık 2026 - 1 Ocak 2027")


def _sample_records() -> list[dict]:
    """İki dersin 39 haftası; ders adları eski hatayı tetikleyen biçimde."""
    records = []
    for name in ["İNGİLİZCE", "T.C. İNKILAP TARİHİ VE ATATÜRKÇÜLÜK"]:
        for week in range(1, TOTAL_WEEKS + 1):
            records.append({
                "gradeLevel": 8,
                "subjectName": name,
                "publisher": "MEB Yayınları",
                "weekNumber": week,
                "unitTitle": f"{week}. Ünite",
                "topicTitle": f"{week}. Konu",
                "outcomeDescription": f"{name} {week}. hafta kazanımı",
            })
    return records


class RebuildTests(unittest.TestCase):
    def test_rebuild_produces_unique_ids(self):
        rebuilt = rebuild(_sample_records(), "2026-2027")
        ids = [r["id"] for r in rebuilt]
        self.assertEqual(len(ids), len(set(ids)), "doküman kimlikleri çakışmamalı")

    def test_rebuild_passes_validation(self):
        rebuilt = rebuild(_sample_records(), "2026-2027")
        self.assertEqual(validate(rebuilt), [])

    def test_validate_catches_duplicate_ids(self):
        rebuilt = rebuild(_sample_records(), "2026-2027")
        rebuilt[1]["id"] = rebuilt[0]["id"]
        problems = validate(rebuilt)
        self.assertTrue(any("çakışan doküman kimliği" in p for p in problems))

    def test_validate_catches_missing_weeks(self):
        rebuilt = rebuild(_sample_records(), "2026-2027")
        problems = validate(rebuilt[:-1])
        self.assertTrue(any("39 haftanın tamamı yok" in p for p in problems))

    def test_year_change_rewrites_dates_and_year(self):
        rebuilt = rebuild(_sample_records(), "2027-2028")
        self.assertTrue(all(r["academicYear"] == "2027-2028" for r in rebuilt))
        week1 = next(r for r in rebuilt if r["weekNumber"] == 1)
        self.assertEqual(week1["dateRange"]["startDate"], "2027-09-13")

    def test_holiday_weeks_get_holiday_content(self):
        rebuilt = rebuild(_sample_records(), "2026-2027")
        holiday = next(r for r in rebuilt if r["weekNumber"] == 10)
        self.assertTrue(holiday["isHolidayWeek"])
        self.assertEqual(holiday["outcomeCode"], "TATIL")
        self.assertIsNone(holiday["teachingWeekNumber"])
        self.assertIn("ara verilmiştir", holiday["maarifSummary"])

    def test_every_record_has_pedagogical_fields(self):
        rebuilt = rebuild(_sample_records(), "2026-2027")
        for record in rebuilt:
            for field in ("maarifSummary", "maarifValues", "maarifSkills", "differentiation"):
                self.assertTrue(record.get(field), f"{record['id']} -> {field} boş")

    def test_rebuild_is_idempotent(self):
        """Boru hattını iki kez çalıştırmak çıktıyı değiştirmemeli."""
        once = rebuild(_sample_records(), "2026-2027")
        twice = rebuild(once, "2026-2027")
        self.assertEqual(once, twice)


class StaleDateTests(unittest.TestCase):
    def test_removes_previous_year_week_headers(self):
        cases = [
            ("Week 1: 8-12 September | School-based planning",
             "School-based planning"),
            ("3.Week: 22-26 September | ENG.2.1.R1. Pupils can read",
             "ENG.2.1.R1. Pupils can read"),
            ("1. Week: 8-12 September | Describing what people do",
             "Describing what people do"),
        ]
        for raw, expected in cases:
            with self.subTest(raw=raw):
                self.assertEqual(strip_stale_dates(raw), expected)

    def test_preserves_commemorative_weeks(self):
        """'Orman Haftası (21-26 Mart)' takvim değil müfredat içeriğidir."""
        for text in [
            "Orman Haftası (21-26 Mart) Dünya Su Günü (22 Mart)",
            "Temel Hareket | Atatürk Haftası (10-16 Kasım) Afet Eğitimi",
            "MAT.1.1.3. Nesnelerin sıra sayısını gösterebilme",
        ]:
            with self.subTest(text=text):
                self.assertEqual(strip_stale_dates(text), text)

    def test_never_empties_a_description(self):
        """Metnin tamamı tarihse orijinal korunur; boş kazanım üretilmez."""
        for text in ["Week 2 15-19 September", "27. Hafta: 6-10 Nisan"]:
            with self.subTest(text=text):
                self.assertTrue(strip_stale_dates(text).strip())


class ExcelImportTests(unittest.TestCase):
    """Excel içe aktarıcının ayrıştırma mantığı (dosya gerektirmez)."""

    def setUp(self):
        from import_excel import normalize_publisher, parse_sheet_name
        self.normalize_publisher = normalize_publisher
        self.parse_sheet_name = parse_sheet_name

    def test_sheet_name_parsing(self):
        self.assertEqual(self.parse_sheet_name("5-Matematik-TYMM"),
                         (5, "Matematik", "TYMM (Maarif Modeli)"))
        self.assertEqual(self.parse_sheet_name("8-İngilizce-MEB"),
                         (8, "İngilizce", "MEB Yayınları"))
        self.assertEqual(self.parse_sheet_name("3-Türkçe-İlke"),
                         (3, "Türkçe", "İlke Yayınları"))

    def test_variant_suffix_is_ignored(self):
        """'_2' eki aynı dersin kopyasıdır, ayrı ders sayılmamalı."""
        base = self.parse_sheet_name("5-İngilizce-ÇYDEM")
        variant = self.parse_sheet_name("5-İngilizce-ÇYDEM_2")
        self.assertEqual(base, variant)

    def test_publisher_aliases(self):
        self.assertEqual(self.normalize_publisher("TYMM"), "TYMM (Maarif Modeli)")
        self.assertEqual(self.normalize_publisher("ÇYDEM"), "ÇYDEM (Maarif Modeli)")
        self.assertEqual(self.normalize_publisher("MEB"), "MEB Yayınları")
        # Bilinmeyen yayınevi olduğu gibi korunur
        self.assertEqual(self.normalize_publisher("Yeni Yayınevi"), "Yeni Yayınevi")

    def test_imported_records_pass_pipeline(self):
        """İçe aktarıcı çıktısı doğrudan boru hattına verilebilmeli."""
        records = []
        for week in range(1, TOTAL_WEEKS + 1):
            records.append({
                "gradeLevel": 8,
                "subjectName": "İNGILIZCE",
                "publisher": "MEB Yayınları",
                "weekNumber": week,
                "unitTitle": "1 Friendship",
                "topicTitle": "1 Friendship",
                "outcomeDescription": f"Week {week}: kazanım metni",
                "sourceSheet": "8-İngilizce-MEB",
            })
        rebuilt = rebuild(records, "2026-2027")
        self.assertEqual(validate(rebuilt), [])
        self.assertEqual(rebuilt[0]["subjectCode"], "INGILIZCE")


class TymmPlanImportTests(unittest.TestCase):
    """MEB resmî taslak yıllık plan içe aktarıcısı."""

    def setUp(self):
        from import_tymm_plans import (
            detect_grade, detect_school_type, detect_variant, extract_code, parse_week,
        )
        self.detect_grade = detect_grade
        self.detect_school_type = detect_school_type
        self.detect_variant = detect_variant
        self.extract_code = extract_code
        self.parse_week = parse_week

    def test_week_parsing(self):
        self.assertEqual(self.parse_week("1. Hafta:  14-18 Eylül"), 1)
        self.assertEqual(self.parse_week("28. Hafta: 22-26 Mart"), 28)
        self.assertIsNone(self.parse_week("EYLÜL"))
        self.assertIsNone(self.parse_week(""))
        # 39 haftanın dışı kabul edilmez
        self.assertIsNone(self.parse_week("45. Hafta"))

    def test_grade_from_sheet_name(self):
        self.assertEqual(self.detect_grade("10. SINIF"), 10)
        self.assertEqual(self.detect_grade("9.SINIF "), 9)
        self.assertEqual(self.detect_grade("11. SINIF 2 SAAT"), 11)
        self.assertEqual(self.detect_grade("12. SINIF T.C. İNKILAP TAR."), 12)
        # Hazırlık sınıfı 1-12 dışıdır
        self.assertIsNone(self.detect_grade("HAZIRLIK SINIFI"))

    def test_school_type_from_filename(self):
        """Dosya adı Türkçe 'İ' içerir; fold() olmadan eşleşme kaçıyordu."""
        self.assertEqual(
            self.detect_school_type("2026-2027 ANADOLU LİSESİ FELSEFE.xlsx"),
            "Anadolu Lisesi")
        self.assertEqual(
            self.detect_school_type("2026-2027 FEN LİSESİ TASLAK.xlsx"),
            "Fen Lisesi")
        self.assertEqual(
            self.detect_school_type("2026-2027 SOSYAL BİLİMLER LİSESİ PLAN.xlsx"),
            "Sosyal Bilimler Lisesi")

    def test_course_hour_variant_is_kept(self):
        """Coğrafya 11'de 2 saat ve 4 saat planları ayrı gruplardır."""
        self.assertEqual(self.detect_variant("11. SINIF 2 SAAT"), "2 Saat")
        self.assertEqual(self.detect_variant("12.SINIF 4 SAAT"), "4 Saat")
        self.assertEqual(self.detect_variant("10. SINIF"), "")

    def test_outcome_code_extraction(self):
        self.assertEqual(
            self.extract_code("FEL.10.1.1. Felsefenin anlamını sorgulayabilme"),
            "FEL.10.1.1")
        self.assertEqual(
            self.extract_code("BİY.9.1.1. Biyolojideki dönüm noktaları"),
            "BİY.9.1.1")
        self.assertIsNone(self.extract_code("Serbest metin"))


class MebYeniDuzenTests(unittest.TestCase):
    """MEB'in Eylül 2026 ilkokul/ortaokul dosya düzenleri.

    ## Neden bu testler var
    MEB bu ay ilkokul ve ortaokul için taslak yıllık planları
    yayımladı. Sayfa adları eski kalıba uymuyordu ve
    `read_sheet` kademeyi okuyamayınca **uyarı bile üretmeden**
    atlıyordu: Fen Bilimleri'nin tamamı, Türkçe'nin çoğu düştü.

    Ölçüm: 4610 -> 5500 kayıt (890 kurtarıldı), 129 -> 157 ders grubu.
    """

    def setUp(self):
        from import_tymm_plans import (
            detect_grade, detect_school_type, locate_header, parse_week,
        )
        self.detect_grade = detect_grade
        self.detect_school_type = detect_school_type
        self.locate_header = locate_header
        self.parse_week = parse_week

    def test_yeni_sayfa_adlarindan_kademe(self):
        """MEB'in yeni sekme adlarında kademe okunmalı."""
        # Bunların hepsi None dönüyordu ve sayfa sessizce düşüyordu.
        durumlar = [
            ("FEN BİLİMLERİ 3 (TYMM)", 3),
            ("FEN BİLİMLERİ 4", 4),
            ("TÜRKÇE 5 ÇERÇEVE YILLIK PLANLAR", 5),
            ("MÜZİK-1 (TYMM)", 1),
            ("BTY_5", 5),          # Bilişim Teknolojileri, alt çizgi
            ("TEK-TAS 7", 7),      # Teknoloji Tasarım, tire
        ]
        for sekme, beklenen in durumlar:
            with self.subTest(sekme=sekme):
                self.assertEqual(self.detect_grade(sekme, "x.xlsx"), beklenen)

    def test_eski_kaliplar_bozulmadi(self):
        """Yeni kalıp eklenirken mevcut korumalar korunmalı."""
        # "SBÇ 2" sınıf değil ders seviyesidir; sosyal bilimler
        # lisesinde 11. sınıfta okutulur. Sayıyı sınıf sanmak
        # 2. sınıf kaydı üretiyordu.
        self.assertEqual(self.detect_grade("SBÇ 2", "x.xlsx"), 11)
        self.assertEqual(self.detect_grade("Sosyoloji 1", "x.xlsx"), 11)
        self.assertEqual(self.detect_grade("9. SINIF", "x.xlsx"), 9)
        # Hazırlık sınıfı 1-12 dışı.
        self.assertIsNone(self.detect_grade("Hazırlık Sınıfı", "x.xlsx"))

    def test_adsiz_sekme_kademe_sanilmaz(self):
        """KRİTİK: "Sayfa1" 1. sınıf DEĞİLDİR."""
        # Sondaki sayı sekme numarasıdır. Önce 1. sınıf sanılıyordu ve
        # o dosyanın tamamı yanlış kademeye yazılıyordu — sessiz hata.
        for sekme in ("Sayfa1", "Sayfa2", "Sheet1", "Tablo1"):
            with self.subTest(sekme=sekme):
                self.assertIsNone(self.detect_grade(sekme, "hayat_bilgisi.xlsx"))

    def test_ingilizce_hafta_etiketi(self):
        """ÇYDEM planlarında hafta etiketi İngilizce."""
        # Türkçe kalıp sayıyı ÖNDE bekliyor ("1. Hafta"); İngilizce'de
        # sonda ("Week 1"). Başlıklar okunsa bile tek kayıt
        # üretilmiyordu.
        self.assertEqual(self.parse_week("Week 1:\n 14-18 September"), 1)
        self.assertEqual(self.parse_week("Week 4: 5-9 October"), 4)
        # Türkçe bozulmamalı.
        self.assertEqual(self.parse_week("1. Hafta\n\n 14-18 Eylül"), 1)

    def test_ingilizce_sutun_basliklari(self):
        """ÇYDEM planlarında sütun başlıkları İngilizce."""
        # locate_header aday satırı "hafta" sözcüğüyle buluyordu;
        # İngilizce sayfada "week" yazdığı için hiçbir satır aday
        # olmuyor ve ipuçlarına hiç bakılmıyordu.
        satirlar = [
            ("2026-2027 ACADEMIC YEAR", None, None, None, None, None, None),
            ("DURATION", None, None, "THEME AND CONTENT FRAME", None,
             "LEARNING OUTCOMES", None),
            ("MONTH", "WEEK", "CLASS HOUR", "THEME", "CONTENT FRAME",
             "LEARNING OUTCOMES", "ASSESSMENT AND EVALUATION"),
        ]
        index, mapping, duzen = self.locate_header(satirlar)
        self.assertNotEqual(index, -1, "İngilizce başlık satırı bulunamadı")
        self.assertIn("week", mapping)
        self.assertIn("outcome", mapping)
        # İngilizce de olsa bu bir Maarif planı.
        self.assertEqual(duzen, "maarif")

    def test_duzen_kaynagi_belirler(self):
        """KRİTİK: Maarif mi eski program mı, SÜTUN BAŞLIĞINDAN."""
        # Ölçüldü: MEB aynı dosyada iki programı birden veriyor.
        #   FEN BİLİMLERİ 3 (TYMM) -> "ÖĞRENME ÇIKTILARI VE SÜREÇ..."
        #   FEN BİLİMLERİ 4        -> "KAZANIM" + "KAZANIM AÇIKLAMASI"
        # Sayfa adındaki "(TYMM)" işareti tek başına yetmez: lise
        # dosyalarında hiç yok, oysa içerikleri Maarif düzeninde.
        maarif = [
            ("AY", "HAFTA", "DERS SAATİ", "ÜNİTE/TEMA", "KONU",
             "ÖĞRENME ÇIKTILARI", "SÜREÇ BİLEŞENLERİ"),
        ]
        _, _, duzen = self.locate_header(maarif)
        self.assertEqual(duzen, "maarif")

        eski = [
            ("AY", "HAFTA", "DERS SAATİ", "ÜNİTE", "KONU",
             "KAZANIM", "KAZANIM AÇIKLAMASI"),
        ]
        _, _, duzen = self.locate_header(eski)
        self.assertEqual(duzen, "legacy")

    def test_okul_turu_bulunamazsa_bos(self):
        """KRİTİK: "MEB Yayınları" bir okul türü DEĞİLDİR."""
        # Önce bulunamayınca "MEB Yayınları" yazılıyordu; bu bir okul
        # türü değil "bilinmiyor" demekti ve kaynak alanıyla karışıp
        # Maarif rozetinin yanlış basılmasına yol açıyordu (ölçüm:
        # 89 ders rozet alması gerekirken almıyordu).
        self.assertEqual(self.detect_school_type("matematik.xlsx"), "")
        self.assertEqual(
            self.detect_school_type("FIZIK ANADOLU LISESI.xlsx"),
            "Anadolu Lisesi",
        )


class ShippedDataTests(unittest.TestCase):
    """Depoya işlenmiş gerçek veri paketini doğrular."""

    @classmethod
    def setUpClass(cls):
        import json
        path = os.path.join(
            os.path.dirname(os.path.abspath(__file__)),
            "..", "..", "assets", "data", "official_maarif_kazanimlar.json",
        )
        if not os.path.exists(path):
            raise unittest.SkipTest("Veri paketi bulunamadı")
        with open(path, "r", encoding="utf-8") as handle:
            cls.records = json.load(handle)

    def test_shipped_data_is_valid(self):
        self.assertEqual(validate(self.records), [])

    def test_no_outcome_is_unreadably_long(self):
        """Kart üzerinde okunamayacak kadar uzun kazanım kalmamalı.

        Kaynak Excel'lerde bazı hücreler dönemin tüm kelime listesini
        taşıyor (7. sınıf İngilizce'de 30.672 karakter) ve kart o metni
        olduğu gibi basıyordu.
        """
        from build_curriculum import MAX_DESCRIPTION
        too_long = [
            (r["id"], len(r["outcomeDescription"]))
            for r in self.records
            if len(r.get("outcomeDescription") or "") > MAX_DESCRIPTION + 20
        ]
        self.assertEqual(too_long[:3], [],
                         f"{len(too_long)} kayıt çok uzun")

    def test_outcome_codes_are_not_split(self):
        """Kazanım kodu ortadan bölünmüş olmamalı.

        Ünite kazanım listesini haftalara dağıtırken kullanılan bölme,
        '10.1.1.1.' kodunun içindeki '1.1.1.' alt dizisiyle de eşleşip
        kodu ortadan kesiyordu: 'A RP. 1 0.1.1.' / '0. 1.1.2.'.

        DİKKAT: '9.1.1.' MEB'in geçerli kod biçimidir (sınıf.ünite.kazanım)
        ve bölünme SAYILMAZ. Aranan şey, kodun ortasından kesildiğine
        işaret eden kalıplardır.
        """
        split_marks = (
            # Harf ile nokta arasında boşluk: 'A RP.' / 'ARP . 10'
            re.compile(r"\b[A-ZÇĞİÖŞÜ]\s+[A-ZÇĞİÖŞÜ]{1,5}\s*\.\s*\d"),
            # Rakamlar arasında boşluk: '1 0.1.1'
            re.compile(r"\b\d\s+\d+\.\d"),
            # Nokta ile rakam arasında boşluk: '10. 1.1.2'
            re.compile(r"\d\.\s+\d+\.\d"),
        )
        broken = []
        for record in self.records:
            text = record.get("outcomeDescription") or ""
            if any(pattern.search(text) for pattern in split_marks):
                broken.append((record["id"], text[:60]))

        self.assertEqual(broken[:3], [], f"{len(broken)} kayıtta kod bölünmüş")

    def test_no_genel_bucket_remains(self):
        leftovers = [r["id"] for r in self.records if r["subjectCode"] == "GENEL"]
        self.assertEqual(leftovers, [], "GENEL çöp kovası temizlenmiş olmalı")

    def test_subject_code_maps_to_single_subject(self):
        # Ders adları kaynağa göre farklı yazılabiliyor ("T.C. İNKILAP..."
        # Excel'den büyük harfle, MEB planından başlık düzeninde gelir).
        # Karşılaştırma Türkçe'ye uygun katlanmış biçimde yapılır; asıl
        # aranan, tek kodun gerçekten farklı DERSLERİ toplamaması.
        mapping: dict[str, set[str]] = {}
        for record in self.records:
            mapping.setdefault(record["subjectCode"], set()).add(
                fold(record["subjectName"])
            )
        for code, names in mapping.items():
            with self.subTest(code=code):
                self.assertEqual(len(names), 1,
                                 f"{code} birden fazla derse eşleniyor: {names}")


class OutcomePartsTests(unittest.TestCase):
    """Bir haftaya birden fazla kazanım düştüğünde ayrıştırma."""

    def setUp(self):
        from outcome_parts import outcome_codes, parse_outcomes
        self.parse = parse_outcomes
        self.codes = outcome_codes

    def test_two_outcomes_in_one_week_are_separated(self):
        """MEB bazı haftalara hem 5.1.2 hem 5.1.3 koyuyor; ayrılmalı."""
        text = ("Temel Geometrik Çizimler | MAT.5.1.2. Çizim yapabilme "
                "a) Nokta tanır. b) Araç belirler. "
                "MAT.5.1.3. Yansıtabilme a) Gözden geçirir.")
        blocks = self.parse(text)
        self.assertEqual([b["code"] for b in blocks],
                         ["MAT.5.1.2", "MAT.5.1.3"])
        self.assertEqual(blocks[0]["steps"],
                         ["a) Nokta tanır.", "b) Araç belirler."])
        self.assertEqual(blocks[1]["steps"], ["a) Gözden geçirir."])

    def test_unit_title_is_kept_separate(self):
        text = "Geometrik Şekiller | MAT.5.1.2. Çizim yapabilme a) Tanır."
        blocks = self.parse(text)
        self.assertEqual(blocks[0].get("lead"), "Geometrik Şekiller")

    def test_code_is_not_split_in_the_middle(self):
        """'10.1.1.1.' içindeki '1.1.1.' bir kod başlangıcı DEĞİLDİR."""
        self.assertEqual(self.codes("ARP.10.1.1.1. Dinleme yapabilme"),
                         ["ARP.10.1.1.1"])

    def test_turkish_step_letters(self):
        """Süreç bileşenleri 'ç)' ve 'ğ)' gibi Türkçe harfler de içerir."""
        blocks = self.parse("MAT.5.1.2. Test a) Bir. ç) İki. b) Üç.")
        self.assertEqual(len(blocks[0]["steps"]), 3)

    def test_text_without_codes_still_returns_block(self):
        blocks = self.parse("Kodsuz düz açıklama a) Madde bir.")
        self.assertEqual(len(blocks), 1)
        self.assertIsNone(blocks[0]["code"])
        self.assertEqual(blocks[0]["steps"], ["a) Madde bir."])

    def test_shipped_data_has_parsed_parts(self):
        """Yayın verisindeki çok kazanımlı kayıtlar ayrıştırılmış olmalı."""
        import json
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "..", "assets", "data",
                            "official_maarif_kazanimlar.json")
        if not os.path.exists(path):
            self.skipTest("veri paketi yok")
        with open(path, encoding="utf-8") as handle:
            records = json.load(handle)

        multi = [r for r in records if len(r.get("outcomeCodes") or []) > 1]
        self.assertGreater(len(multi), 100,
                           "çok kazanımlı kayıtlar ayrıştırılmamış")
        for record in multi[:20]:
            parts = record.get("outcomeParts") or []
            coded = [p for p in parts if p.get("code")]
            self.assertGreaterEqual(
                len(coded), 2,
                f"{record['id']} -> {len(coded)} blok, beklenen >= 2")


class SuggestedActivityTests(unittest.TestCase):
    """OTP / sosyal etkinlik haftası etkinlik önerileri."""

    def setUp(self):
        from pedagogy import build_meta, suggested_activities
        self.build_meta = build_meta
        self.suggested = suggested_activities

    def test_otp_activities_differ_by_subject(self):
        """Her branş kendi etkinliğini almalı; tek kalıp değil."""
        codes = ["MAT", "BILISIM", "BEDEN", "TURKCE", "FEN"]
        sets = {tuple(self.suggested(c, is_otp=True)) for c in codes}
        self.assertEqual(len(sets), len(codes),
                         "branşlar aynı öneri setini paylaşıyor")

    def test_unknown_subject_gets_generic_fallback(self):
        items = self.suggested("BILINMEYEN_DERS", is_otp=True)
        self.assertTrue(items, "yedek öneri listesi boş olmamalı")

    def test_normal_week_has_no_activities(self):
        """Sıradan ders haftasında öneri gösterilmez."""
        self.assertEqual(self.suggested("MAT"), [])
        meta = self.build_meta("MAT", "Ünite", "Konu")
        self.assertNotIn("suggestedActivities", meta)

    def test_otp_meta_carries_activities(self):
        meta = self.build_meta("BILISIM", is_otp=True)
        self.assertTrue(meta.get("suggestedActivities"))

    def test_shipped_otp_records_have_varied_activities(self):
        """Yayın verisinde OTP haftaları branşa göre çeşitlenmeli."""
        import json
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "..", "assets", "data",
                            "official_maarif_kazanimlar.json")
        if not os.path.exists(path):
            self.skipTest("veri paketi yok")
        with open(path, encoding="utf-8") as handle:
            records = json.load(handle)

        otp = [r for r in records if r.get("isOtpWeek")]
        self.assertTrue(otp, "OTP kaydı yok")
        with_items = [r for r in otp if r.get("suggestedActivities")]
        self.assertEqual(len(with_items), len(otp),
                         "bazı OTP kayıtlarında öneri yok")
        variants = {tuple(r["suggestedActivities"]) for r in otp}
        self.assertGreater(len(variants), 5,
                           f"yalnızca {len(variants)} farklı öneri seti var")


class WeekSummaryTests(unittest.TestCase):
    """Haftaya özgü özet üretimi ve çok haftalık kazanım işareti."""

    def setUp(self):
        from pedagogy import week_focus
        self.focus = week_focus

    def test_same_unit_different_weeks_get_different_focus(self):
        """Aynı ünitenin farklı haftaları aynı özeti taşımamalı.

        Özet eskiden yalnızca ünite adından üretiliyordu; bir ünite 4-5
        hafta sürünce o haftaların özeti kelimesi kelimesine aynı çıkıyordu.
        """
        unit = "Bilişim Teknolojilerinin Hayatımızdaki Yeri"
        first = self.focus(
            "Bilişim Teknolojilerinin Sınıflandırılması | BTY.5.1.1. Sınıflandırabilme",
            unit, unit)
        second = self.focus(
            "Bilişim Teknolojilerinin Etkileri ve Dijital Sağlık | BTY.5.1.2. Özetleyebilme",
            unit, unit)
        self.assertNotEqual(first, second)
        self.assertEqual(first, "Bilişim Teknolojilerinin Sınıflandırılması")

    def test_code_prefix_is_stripped(self):
        focus = self.focus("MAT.5.3.2. Temel geometrik çizimleri yansıtabilme", "GEOMETRİ")
        self.assertFalse(focus.startswith("MAT."))
        self.assertIn("geometrik", focus.lower())

    def test_step_only_text_falls_back_to_topic(self):
        """Metin 'a) ...' ile başlıyorsa bu konu başlığı değildir."""
        self.assertEqual(
            self.focus("a) Nokta tanır. b) Araç belirler.", "GEOMETRİK ŞEKİLLER"),
            "GEOMETRİK ŞEKİLLER")

    def test_empty_description_falls_back(self):
        self.assertEqual(self.focus("", "", "ÜNİTE 1"), "ÜNİTE 1")

    def test_multi_week_spans_are_annotated(self):
        """Aynı kazanım arka arkaya tekrar ediyorsa işaretlenmeli."""
        from build_curriculum import annotate_multi_week_spans
        records = [
            {"gradeLevel": 2, "subjectCode": "TURKCE", "publisher": "MEB",
             "weekNumber": w, "outcomeDescription": "Aynı kazanım"}
            for w in (1, 2, 3)
        ]
        records.append({"gradeLevel": 2, "subjectCode": "TURKCE",
                        "publisher": "MEB", "weekNumber": 4,
                        "outcomeDescription": "Farklı kazanım"})
        annotate_multi_week_spans(records)
        self.assertEqual([r.get("spanIndex") for r in records[:3]], [1, 2, 3])
        self.assertTrue(all(r.get("spanTotal") == 3 for r in records[:3]))
        self.assertIsNone(records[3].get("spanTotal"))

    def test_shipped_summaries_are_more_varied(self):
        """Yayın verisinde özet çeşitliliği kabul edilebilir olmalı."""
        import json
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "..", "assets", "data",
                            "official_maarif_kazanimlar.json")
        if not os.path.exists(path):
            self.skipTest("veri paketi yok")
        with open(path, encoding="utf-8") as handle:
            records = json.load(handle)

        lessons = [r for r in records
                   if not (r.get("isHolidayWeek") or r.get("isOtpWeek")
                           or r.get("isSocialEventWeek"))]
        unique = len({r.get("maarifSummary") for r in lessons})
        self.assertGreater(unique, 2000,
                           f"yalnızca {unique} benzersiz özet var")


class PdfActivityTests(unittest.TestCase):
    """TYMM öğretim programı PDF'lerinden çıkarılan resmî ders anlatımları."""

    def test_extractor_pairs_code_with_body(self):
        from extract_pdf_activities import extract_activities
        text = ("Öğrenme-Öğretme Uygulamaları "
                "BTY.5.1.1. Sınıflandırabilme " + ("Öğrencilere beyin fırtınası yapılır. " * 12) +
                "BTY.5.1.2. Özetleyebilme " + ("Öğrencilerden çözümleme istenir. " * 12))
        found = extract_activities(text)
        self.assertIn("BTY.5.1.1", found)
        self.assertIn("BTY.5.1.2", found)
        self.assertIn("beyin fırtınası", found["BTY.5.1.1"])

    def test_hyphenation_is_repaired(self):
        """PDF dizgisi kelimeleri bölüyor: 'tar - tışma' -> 'tartışma'.

        Gerçek okuma fonksiyonu üzerinden doğrulanır.
        """
        import extract_pdf_activities as mod

        class _FakePage:
            def __init__(self, text):
                self._text = text

            def extract_text(self):
                return self._text

        class _FakeReader:
            def __init__(self, _path):
                self.pages = [_FakePage("tar - tışma ve sınıflandır- ma")]

        original = mod.pypdf.PdfReader
        mod.pypdf.PdfReader = _FakeReader
        try:
            result = mod.read_pdf_text("yok.pdf")
        finally:
            mod.pypdf.PdfReader = original

        self.assertEqual(result, "tartışma ve sınıflandırma")

    def test_short_blocks_are_rejected(self):
        """Kısa parçalar ders anlatımı sayılmaz."""
        from extract_pdf_activities import extract_activities
        found = extract_activities("Öğrenme-Öğretme Uygulamaları BTY.5.1.1. Kısa.")
        self.assertEqual(found, {})

    def test_shipped_records_carry_official_activity(self):
        """Yayın verisinde resmî anlatım kazanım koduyla eşleşmeli."""
        import json
        base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
        data_path = os.path.join(base, "assets", "data",
                                 "official_maarif_kazanimlar.json")
        acts_path = os.path.join(base, "data_sources", "pdf_activities.json")
        if not (os.path.exists(data_path) and os.path.exists(acts_path)):
            self.skipTest("veri paketi yok")

        with open(data_path, encoding="utf-8") as handle:
            records = json.load(handle)
        with open(acts_path, encoding="utf-8") as handle:
            activities = json.load(handle)

        enriched = [r for r in records if r.get("officialActivity")]
        self.assertGreater(len(enriched), 1000,
                           f"yalnızca {len(enriched)} kayıt zenginleştirilmiş")

        # Eşleşen metin gerçekten o kazanıma ait olmalı.
        for record in enriched[:30]:
            codes = record.get("outcomeCodes") or []
            self.assertTrue(
                any(c in activities for c in codes),
                f"{record['id']} kodu PDF'te yok: {codes}")


class OutcomeCodeFormatTests(unittest.TestCase):
    """Kazanım kodu biçimleri kaynaktan kaynağa değişiyor."""

    def setUp(self):
        from outcome_parts import outcome_codes
        self.codes = outcome_codes

    def test_all_known_code_formats_are_detected(self):
        """Sondaki nokta ZORUNLU değildir.

        'MARP11.1.1' (DÖGM Mesleki Arapça) ve 'BEO.1.1.4' gibi kodlar
        son noktasız gelir. Deseni noktaya bağlamak bu kayıtları
        görünmez yapıyordu: ünite bloğu bölünemiyor, aynı metin 5 hafta
        boyunca tekrar ediyordu.
        """
        cases = {
            "MAT.5.1.2. Çizim yapabilme": "MAT.5.1.2",
            "BTY.5.1.1. Sınıflandırabilme": "BTY.5.1.1",
            "MARP11.1.1 İslam İnancı metinleri": "MARP11.1.1",
            "BEO.1.1.4 Hareket becerileri": "BEO.1.1.4",
            "KK.7.4.1. Kalkaleyi telaffuz edebilme": "KK.7.4.1",
            "9.1.1. Kimya biliminin katkısı": "9.1.1",
            "ARP.10.1.1.1. Dinleme yapabilme": "ARP.10.1.1.1",
        }
        for text, expected in cases.items():
            with self.subTest(text=text):
                self.assertEqual(self.codes(text), [expected])

    def test_importer_and_parser_share_one_pattern(self):
        """İki ayrı kopya tutmak, kodun yalnızca bir tarafta tanınmasına
        yol açıyordu."""
        import import_tymm_plans as importer
        import outcome_parts
        self.assertIs(importer.find_code_positions,
                      outcome_parts.find_code_positions)

    def test_multi_outcome_block_is_split(self):
        """379 karakterlik ünite bloğu haftalara bölünebilmeli."""
        from outcome_parts import parse_outcomes
        text = ("MARP11.1.1 “İslam İnancı” metinleriyle ilgili okumaya hazırlık "
                "yapabilme MARP11.1.2 “İslam İnancı” metinleriyle ilgili bilgileri "
                "bir araya getirebilme MARP11.1.3 “İslam İnancı” metinlerini tahlil "
                "edebilme")
        blocks = parse_outcomes(text)
        self.assertEqual([b["code"] for b in blocks],
                         ["MARP11.1.1", "MARP11.1.2", "MARP11.1.3"])

    def test_shipped_iho_is_varied_enough(self):
        """İHÖ kayıtları haftalara dağıtılmış olmalı."""
        import collections
        import json
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "..", "assets", "data",
                            "official_maarif_kazanimlar.json")
        if not os.path.exists(path):
            self.skipTest("veri paketi yok")
        with open(path, encoding="utf-8") as handle:
            records = json.load(handle)

        iho = [r for r in records
               if r.get("category") == "iho"
               and not (r.get("isHolidayWeek") or r.get("isOtpWeek")
                        or r.get("isSocialEventWeek"))]
        groups = collections.defaultdict(list)
        for record in iho:
            groups[(record["gradeLevel"], record["subjectName"],
                    record["publisher"])].append(record["outcomeDescription"])

        ratios = [len(set(v)) / len(v) for v in groups.values() if v]
        average = sum(ratios) / len(ratios)
        self.assertGreater(average, 0.6,
                           f"İHÖ çeşitliliği yalnızca %{average * 100:.0f}")


class UnplannedWeekTests(unittest.TestCase):
    """Kaynakta içerik olmayan haftalar."""

    def setUp(self):
        from build_curriculum import is_unplanned
        self.unplanned = is_unplanned

    def test_date_only_cells_are_detected(self):
        """Hücrede yalnızca tarih varsa gerçek kazanım yoktur."""
        for text in [
            "Week 4: 29 September - 3 October",   # iki ay adı
            "Week 6: 13-17 October",
            "3. Hafta: 28 Eylül - 2 Ekim",
            "1. Hafta: 14-18 Eylül",
        ]:
            with self.subTest(text=text):
                self.assertTrue(self.unplanned(text))

    def test_title_only_cells_are_detected(self):
        self.assertTrue(self.unplanned("SCHOOL-BASED PLANNING"))

    def test_filler_text_is_detected(self):
        """Eski üretimin uydurduğu dolgu metin kazanım sayılmaz."""
        self.assertTrue(self.unplanned(
            "THEME 1 SCHOOL LIFE ünitesi kapsamında haftalık MEB müfredat "
            "kazanımları, kavram tahlili ve öğrenme süreçleri."))

    def test_real_outcomes_are_kept(self):
        """Gerçek kazanımlar yanlışlıkla elenmemeli."""
        for text in [
            "ENG.5.1.L1. Students can get ready for the listening",
            "MAT.5.1.2. Çizim yapabilme a) Nokta tanır.",
            "Week 1: 8-12 September | ENG.2.1.L1. Pupils can prepare",
        ]:
            with self.subTest(text=text):
                self.assertFalse(self.unplanned(text))

    def test_no_fabricated_codes_in_shipped_data(self):
        """'GENEL.5.4' gibi uydurma kodlar yayın verisinde olmamalı.

        Bu kodlar MEB'in değildi; kart üzerinde gerçek kazanım koduymuş
        gibi görünüp öğretmeni yanıltıyordu.
        """
        import json
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "..", "assets", "data",
                            "official_maarif_kazanimlar.json")
        if not os.path.exists(path):
            self.skipTest("veri paketi yok")
        with open(path, encoding="utf-8") as handle:
            records = json.load(handle)

        fabricated = [r["id"] for r in records
                      if (r.get("outcomeCode") or "").upper().startswith("GENEL")]
        self.assertEqual(fabricated[:3], [],
                         f"{len(fabricated)} kayıtta uydurma kod var")

    def test_unplanned_records_have_no_code(self):
        """İçeriği olmayan haftaya kazanım kodu yazılmaz."""
        import json
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "..", "assets", "data",
                            "official_maarif_kazanimlar.json")
        if not os.path.exists(path):
            self.skipTest("veri paketi yok")
        with open(path, encoding="utf-8") as handle:
            records = json.load(handle)

        bad = [r["id"] for r in records
               if r.get("isPlaceholder") and r.get("outcomeCode")]
        self.assertEqual(bad[:3], [], f"{len(bad)} planlanmamış kayıtta kod var")


class DataAuditTests(unittest.TestCase):
    """Tüm sınıf ve derslerde sistematik kalite denetimi.

    Gözle yakalanan hataların (uydurma 'GENEL.5.4' kodu, 'Week 4:
    29 September' tarih-metinleri, aynı kazanımın 7 hafta tekrarı)
    hiçbir ders grubunda kalmadığını doğrular.
    """

    @classmethod
    def setUpClass(cls):
        import json
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "..", "..", "assets", "data",
                            "official_maarif_kazanimlar.json")
        if not os.path.exists(path):
            raise unittest.SkipTest("veri paketi yok")
        with open(path, encoding="utf-8") as handle:
            cls.records = json.load(handle)

        from audit_data import build_reports
        cls.reports = build_reports(cls.records)

    def test_no_group_has_blocking_errors(self):
        """Hiçbir ders grubunda yayına engel hata olmamalı."""
        broken = [(r.grade, r.subject, r.problems())
                  for r in self.reports if r.status() == "HATA"]
        self.assertEqual(broken[:5], [], f"{len(broken)} grupta hata var")

    def test_every_group_covers_all_39_weeks(self):
        missing = [(r.grade, r.subject, len(r.missing_weeks))
                   for r in self.reports if r.missing_weeks]
        self.assertEqual(missing[:5], [], f"{len(missing)} grupta hafta eksik")

    def test_no_stale_calendar_dates_remain(self):
        """Kaynaktan gelen eski yıl tarihleri metinde kalmamalı.

        'Week 30: 27 April' ifadesi bizim takvimimizde 33. haftaya
        düşüyordu; öğretmen için yanıltıcıydı.
        """
        stale = [(r.grade, r.subject, len(r.stale))
                 for r in self.reports if r.stale]
        self.assertEqual(stale[:5], [], f"{len(stale)} grupta tarih artığı var")

    def test_no_broken_outcome_codes(self):
        broken = [(r.grade, r.subject) for r in self.reports if r.broken]
        self.assertEqual(broken[:5], [], f"{len(broken)} grupta bölünmüş kod var")

    def test_no_oversized_text(self):
        long_ones = [(r.grade, r.subject) for r in self.reports if r.too_long]
        self.assertEqual(long_ones[:5], [], f"{len(long_ones)} grupta aşırı uzun metin")

    def test_every_grade_has_subjects(self):
        """1'den 12'ye her sınıfta ders bulunmalı."""
        grades = {r.grade for r in self.reports}
        self.assertEqual(sorted(grades), list(range(1, 13)))

    def test_estimated_groups_are_flagged(self):
        """Resmî planı OLMAYAN seçmeli dersler tahminî işaretli olmalı.

        Önce "kategori seçmeli ise takvim tahminî" deniyordu; MEB
        seçmeliler için yıllık plan yayımlamadığı sürece doğruydu.

        Artık bazı seçmelileri de yayımlıyor (Çoklu Yabancı Dil,
        İnsan Hakları ve Yurttaşlık). Onların takvimi MEB'in kendi
        dağılımı; tahminî işaretlemek yanlış olurdu. Ölçüt kaynağa
        bağlandı.
        """
        for report in self.reports:
            if report.category != "elective":
                continue
            resmi = any(r.get("sourcePortal") for r in report.records)
            if resmi:
                continue
            with self.subTest(subject=report.subject):
                self.assertTrue(
                    report.estimated,
                    f"{report.grade}. {report.subject} tahminî işareti yok")


if __name__ == "__main__":
    unittest.main(verbosity=2)
