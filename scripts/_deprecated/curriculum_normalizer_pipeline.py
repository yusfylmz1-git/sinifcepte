"""
!!! KULLANIMDAN KALDIRILDI - CALISTIRMAYIN !!!
Ayrintilar icin: scripts/_deprecated/README.md
Yerine: python scripts/maarif/build_curriculum.py --year <yil>
"""
import sys

print(__doc__, file=sys.stderr)
raise SystemExit(
    "Bu script kullanimdan kaldirildi. "
    "Kullanin: python scripts/maarif/build_curriculum.py --year <yil>"
)

# --- Eski kod yalnizca referans icin asagida korunuyor ---

if False:  # noqa
    """
    SınıfCepte - Resmî MEB Maarif & Yıllık Çerçeve Planları Normalizer Boru Hattı (Pipeline)
    Bu script, masaüstündeki 57+ sekmeli TÜM_DERSLER_MERKEZ_STANDART_GUNCEL.xlsx dosyasını
    okuyarak zengin ve eksiksiz 'official_maarif_kazanimlar.json' dosyasını üretir.
    """

    import os
    import sys
    import re
    import json
    import openpyxl

    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')

    MASTER_EXCEL_PRIMARY = r"C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART_GUNCEL.xlsx"
    MASTER_EXCEL_FALLBACK = r"C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART.xlsx"
    OUTPUT_JSON = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "official_maarif_kazanimlar.json")

    # 2026-2027 Resmî MEB Akademik Takvimi Haftalık Tarih Dağılımı (39 Hafta)
    ACADEMIC_WEEKS_2026_2027 = {
        1: {"start": "2026-09-14", "end": "2026-09-18", "formatted": "14 - 18 Eylül 2026", "month": "Eylül", "term": 1},
        2: {"start": "2026-09-21", "end": "2026-09-25", "formatted": "21 - 25 Eylül 2026", "month": "Eylül", "term": 1},
        3: {"start": "2026-09-28", "end": "2026-10-02", "formatted": "28 Eylül - 2 Ekim 2026", "month": "Ekim", "term": 1},
        4: {"start": "2026-10-05", "end": "2026-10-09", "formatted": "5 - 9 Ekim 2026", "month": "Ekim", "term": 1},
        5: {"start": "2026-10-12", "end": "2026-10-16", "formatted": "12 - 16 Ekim 2026", "month": "Ekim", "term": 1},
        6: {"start": "2026-10-19", "end": "2026-10-23", "formatted": "19 - 23 Ekim 2026", "month": "Ekim", "term": 1},
        7: {"start": "2026-10-26", "end": "2026-10-30", "formatted": "26 - 30 Ekim 2026", "month": "Ekim", "term": 1},
        8: {"start": "2026-11-02", "end": "2026-11-06", "formatted": "2 - 6 Kasım 2026", "month": "Kasım", "term": 1, "is_otp": True},
        9: {"start": "2026-11-09", "end": "2026-11-13", "formatted": "9 - 13 Kasım 2026", "month": "Kasım", "term": 1},
        10: {"start": "2026-11-16", "end": "2026-11-20", "formatted": "16 - 20 Kasım 2026 (1. Dönem Ara Tatil)", "month": "Kasım", "term": 1, "is_holiday": True, "holiday_note": "1. Dönem Ara Tatili"},
        11: {"start": "2026-11-23", "end": "2026-11-27", "formatted": "23 - 27 Kasım 2026", "month": "Kasım", "term": 1},
        12: {"start": "2026-11-30", "end": "2026-12-04", "formatted": "30 Kasım - 4 Aralık 2026", "month": "Aralık", "term": 1},
        13: {"start": "2026-12-07", "end": "2026-12-11", "formatted": "7 - 11 Aralık 2026", "month": "Aralık", "term": 1},
        14: {"start": "2026-12-14", "end": "2026-12-18", "formatted": "14 - 18 Aralık 2026", "month": "Aralık", "term": 1},
        15: {"start": "2026-12-21", "end": "2026-12-25", "formatted": "21 - 25 Aralık 2026", "month": "Aralık", "term": 1},
        16: {"start": "2026-12-28", "end": "2027-01-01", "formatted": "28 Aralık 2026 - 1 Ocak 2027", "month": "Ocak", "term": 1},
        17: {"start": "2027-01-04", "end": "2027-01-08", "formatted": "4 - 8 Ocak 2027", "month": "Ocak", "term": 1, "is_otp": True},
        18: {"start": "2027-01-11", "end": "2027-01-15", "formatted": "11 - 15 Ocak 2027 (Sosyal Etkinlikler Haftası)", "month": "Ocak", "term": 1, "is_social_event": True},
        19: {"start": "2027-01-18", "end": "2027-01-22", "formatted": "18 - 22 Ocak 2027 (Yarıyıl Tatili 1. Hafta)", "month": "Ocak", "term": 1, "is_holiday": True, "holiday_note": "Yarıyıl Tatili (1. Hafta)"},
        20: {"start": "2027-01-25", "end": "2027-01-29", "formatted": "25 - 29 Ocak 2027 (Yarıyıl Tatili 2. Hafta)", "month": "Ocak", "term": 1, "is_holiday": True, "holiday_note": "Yarıyıl Tatili (2. Hafta)"},
        21: {"start": "2027-02-01", "end": "2027-02-05", "formatted": "1 - 5 Şubat 2027 (2. Dönem Başlangıcı)", "month": "Şubat", "term": 2},
        22: {"start": "2027-02-08", "end": "2027-02-12", "formatted": "8 - 12 Şubat 2027", "month": "Şubat", "term": 2},
        23: {"start": "2027-02-15", "end": "2027-02-19", "formatted": "15 - 19 Şubat 2027", "month": "Şubat", "term": 2},
        24: {"start": "2027-02-22", "end": "2027-02-26", "formatted": "22 - 26 Şubat 2027", "month": "Şubat", "term": 2},
        25: {"start": "2027-03-01", "end": "2027-03-05", "formatted": "1 - 5 Mart 2027", "month": "Mart", "term": 2},
        26: {"start": "2027-03-08", "end": "2027-03-12", "formatted": "8 - 12 Mart 2027", "month": "Mart", "term": 2},
        27: {"start": "2027-03-15", "end": "2027-03-19", "formatted": "15 - 19 Mart 2027", "month": "Mart", "term": 2},
        28: {"start": "2027-03-22", "end": "2027-03-26", "formatted": "22 - 26 Mart 2027 (2. Dönem Ara Tatil)", "month": "Mart", "term": 2, "is_holiday": True, "holiday_note": "2. Dönem Ara Tatili"},
        29: {"start": "2027-03-29", "end": "2027-04-02", "formatted": "29 Mart - 2 Nisan 2027", "month": "Nisan", "term": 2, "is_otp": True},
        30: {"start": "2027-04-05", "end": "2027-04-09", "formatted": "5 - 9 Nisan 2027", "month": "Nisan", "term": 2},
        31: {"start": "2027-04-12", "end": "2027-04-16", "formatted": "12 - 16 Nisan 2027", "month": "Nisan", "term": 2},
        32: {"start": "2027-04-19", "end": "2027-04-23", "formatted": "19 - 23 Nisan 2027 (23 Nisan Ulusal Egemenlik)", "month": "Nisan", "term": 2},
        33: {"start": "2027-04-26", "end": "2027-04-30", "formatted": "26 - 30 Nisan 2027", "month": "Nisan", "term": 2},
        34: {"start": "2027-05-03", "end": "2027-05-07", "formatted": "3 - 7 Mayıs 2027", "month": "Mayıs", "term": 2},
        35: {"start": "2027-05-10", "end": "2027-05-14", "formatted": "10 - 14 Mayıs 2027", "month": "Mayıs", "term": 2},
        36: {"start": "2027-05-17", "end": "2027-05-21", "formatted": "17 - 21 Mayıs 2027 (19 Mayıs Atatürk'ü Anma)", "month": "Mayıs", "term": 2},
        37: {"start": "2027-05-24", "end": "2027-05-28", "formatted": "24 - 28 Mayıs 2027 (Yıl Sonu Sosyal Etkinlik)", "month": "Mayıs", "term": 2, "is_social_event": True},
        38: {"start": "2027-05-31", "end": "2027-06-04", "formatted": "31 Mayıs - 4 Haziran 2027", "month": "Haziran", "term": 2},
        39: {"start": "2027-06-07", "end": "2027-06-11", "formatted": "7 - 11 Haziran 2027 (Kapanış & Karne Haftası)", "month": "Haziran", "term": 2}
    }

    def clean_str(val):
        if val is None:
            return ""
        text = str(val).strip()
        return re.sub(r"\s+", " ", text)

    def detect_subject_code(subject_name):
        lower = subject_name.lower()
        if "türkçe" in lower or "turkce" in lower or "edebiyat" in lower:
            return "TURKCE"
        if "matematik" in lower:
            return "MAT"
        if "fen" in lower or "fizik" in lower or "kimya" in lower or "biyoloji" in lower:
            return "FEN"
        if "sosyal" in lower:
            return "SOSYAL"
        if "inkılap" in lower or "inkilap" in lower or "inkılâp" in lower:
            return "INKILAP"
        if "hayat" in lower:
            return "HAYAT"
        if "ingilizce" in lower or "english" in lower:
            return "INGILIZCE"
        if "almanca" in lower:
            return "ALMANCA"
        if "bilişim" in lower or "bilisim" in lower or "yazılım" in lower:
            return "BILISIM"
        if "din" in lower or "ahlak" in lower:
            return "DIN"
        if "beden" in lower or "spor" in lower:
            return "BEDEN"
        if "müzik" in lower or "muzik" in lower:
            return "MUZIK"
        if "görsel" in lower or "resim" in lower:
            return "GORSEL"
        if "teknoloji" in lower or "tasarım" in lower:
            return "TEKNO_TASARIM"
        if "rehberlik" in lower:
            return "REHBERLIK"
        if "arapça" in lower or "arapca" in lower:
            return "ARAPCA"
        if "harezmi" in lower:
            return "HAREZMI"
        return "GENEL"

    def detect_category(subject_name, subject_code):
        lower = subject_name.lower()
        if "seçmeli" in lower or "secmeli" in lower or "masal" in lower or "zeka" in lower or "hukuk" in lower or "yazarlık" in lower:
            return "elective"
        if "kurs" in lower or "dyk" in lower:
            return "course"
        if "arapça" in lower or "arapca" in lower or "kur'an" in lower or "kuran" in lower or "siyer" in lower or "peygamber" in lower or "temel dini" in lower:
            return "iho"
        if "harezmi" in lower or "proje" in lower or "bütünleşik" in lower:
            return "harezmi"
        return "core"

    def extract_outcome_code(text):
        m = re.search(r"\b([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.[0-9IVX]+\.[0-9a-z.]+)\b", text)
        if m:
            return m.group(1).rstrip('.')
        return None

    def normalize_publisher(publisher_raw, sheet_name):
        pub = clean_str(publisher_raw)
        s_lower = sheet_name.lower()

        if "özgün" in s_lower or "ozgun" in s_lower or "özgün" in pub.lower():
            return "Özgün Yayınları"
        if "hecce" in s_lower or "hecce" in pub.lower():
            return "Hecce Yayınları"
        if "anıt" in s_lower or "anittepe" in s_lower or "anıt" in pub.lower():
            return "Anıttepe Yayınları"
        if "koza" in s_lower or "koza" in pub.lower():
            return "Koza Yayınları"
        if "ada" in s_lower or "ada" in pub.lower():
            return "Ada Yayınları"
        if "ilke" in s_lower or "ilke" in pub.lower():
            return "İlke Yayınları"
        if "çydem" in s_lower or "cydem" in s_lower or "çydem" in pub.lower():
            return "ÇYDEM (Maarif Modeli)"
        if "tymm" in s_lower or "tymm" in pub.lower() or "maarif" in pub.lower():
            return "TYMM (Maarif Modeli)"
        if not pub or pub == "None" or pub == "Ders":
            return "MEB Yayınları"
        return pub

    def process_excel_file(excel_path):
        print(f"📖 Excel dosyası açılıyor: {excel_path}")
        wb = openpyxl.load_workbook(excel_path, read_only=True)
        all_outcomes = []
        seen_ids = set()

        for sheet_name in wb.sheetnames:
            if sheet_name == "TÜM DERSLER BİRLEŞİK" or sheet_name.startswith("~"):
                continue

            sheet = wb[sheet_name]
            rows = list(sheet.iter_rows(values_only=True))
            if not rows or len(rows) < 2:
                continue

            # Başlık satırını bul (row 0 veya row 1)
            header_row_idx = -1
            for r_i in range(min(3, len(rows))):
                r_texts = [clean_str(c).lower() for c in rows[r_i] if c is not None]
                if any("kazanım" in t or "kazanim" in t or "ünite" in t or "unite" in t or "hafta" in t or "branş" in t or "brans" in t for t in r_texts):
                    header_row_idx = r_i
                    break

            if header_row_idx == -1:
                header_row_idx = 0

            header = [clean_str(c).lower() for c in rows[header_row_idx] if c is not None]

            col_plan_order = -1
            col_ders_tipi = -1
            col_brans = -1
            col_sinif = -1
            col_yayin = -1
            col_unite = -1
            col_hafta = -1
            col_kazanim = -1

            for idx, col_name in enumerate(header):
                if "sıra" in col_name or "order" in col_name:
                    col_plan_order = idx
                elif "ders tipi" in col_name or "tipi" in col_name:
                    col_ders_tipi = idx
                elif "branş" in col_name or "brans" in col_name or "ders" in col_name:
                    col_brans = idx
                elif "sınıf" in col_name or "sinif" in col_name:
                    col_sinif = idx
                elif "yayın" in col_name or "program" in col_name or "yayin" in col_name:
                    col_yayin = idx
                elif "ünite" in col_name or "tema" in col_name or "unite" in col_name:
                    col_unite = idx
                elif "hafta" in col_name or "week" in col_name:
                    col_hafta = idx
                elif "kazanım" in col_name or "konu" in col_name or "kazanim" in col_name:
                    col_kazanim = idx

            if col_kazanim == -1 and len(rows[header_row_idx]) >= 6:
                col_kazanim = len(rows[header_row_idx]) - 2 if col_hafta != -1 else len(rows[header_row_idx]) - 1

            grade_match = re.search(r"^(\d+)", sheet_name)
            default_grade = int(grade_match.group(1)) if grade_match else 5

            cleaned_sheet = re.sub(r"^\d+[\s\-_]*", "", sheet_name)
            default_subject = cleaned_sheet.split('-')[0].strip()

            sheet_outcomes = []
            for r_idx, row in enumerate(rows[header_row_idx + 1:], start=header_row_idx + 1):
                if not any(row):
                    continue

                grade_val = row[col_sinif] if col_sinif != -1 and col_sinif < len(row) else None
                grade = int(grade_val) if grade_val and str(grade_val).isdigit() else default_grade

                subject_name_val = clean_str(row[col_brans]) if col_brans != -1 and col_brans < len(row) else ""
                if not subject_name_val:
                    subject_name_val = default_subject

                publisher_raw = clean_str(row[col_yayin]) if col_yayin != -1 and col_yayin < len(row) else ""
                publisher = normalize_publisher(publisher_raw, sheet_name)

                unit_title = clean_str(row[col_unite]) if col_unite != -1 and col_unite < len(row) else ""
                kazanim_text = clean_str(row[col_kazanim]) if col_kazanim != -1 and col_kazanim < len(row) else ""

                week_val = clean_str(row[col_hafta]) if col_hafta != -1 and col_hafta < len(row) else ""
                week_match = re.search(r"(\d+)", week_val)

                if week_match:
                    week_number = int(week_match.group(1))
                else:
                    week_number = min(r_idx - header_row_idx, 39)

                if week_number < 1 or week_number > 39:
                    continue

                if not kazanim_text and not unit_title:
                    continue

                subject_code = detect_subject_code(subject_name_val)
                category = detect_category(subject_name_val, subject_code)

                is_maarif = (
                    "maarif" in publisher.lower() or
                    "tymm" in publisher.lower() or
                    "çydem" in publisher.lower() or
                    "maarif" in unit_title.lower() or
                    "maarif" in kazanim_text.lower() or
                    grade in [1, 2, 5, 6]
                )

                cal_info = ACADEMIC_WEEKS_2026_2027.get(week_number, {})
                is_otp_week = cal_info.get("is_otp", False) or "okul temelli" in kazanim_text.lower() or "okul temelli" in unit_title.lower() or week_number in (8, 17, 29)
                is_social_event_week = cal_info.get("is_social_event", False) or "sosyal etkinlik" in kazanim_text.lower() or week_number in (18, 37)
                is_holiday_week = cal_info.get("is_holiday", False) or "ara tatil" in unit_title.lower() or "yarıyıl" in unit_title.lower()

                outcome_code = extract_outcome_code(kazanim_text)

                pub_slug = re.sub(r"[^a-zA-Z0-9]", "_", publisher.lower())
                doc_id = f"plan_2026_{grade}_{subject_code}_{pub_slug}_w{week_number}"

                if doc_id in seen_ids:
                    # İkinci alternatif şube / varyant
                    doc_id = f"{doc_id}_v2"
                    if doc_id in seen_ids:
                        continue

                seen_ids.add(doc_id)

                full_title = f"{grade}. Sınıf - {subject_name_val} - {publisher}"

                item = {
                    "id": doc_id,
                    "gradeLevel": grade,
                    "subjectCode": subject_code,
                    "subjectName": subject_name_val,
                    "publisher": publisher,
                    "fullTitle": full_title,
                    "category": category,
                    "weekNumber": week_number,
                    "teachingWeekNumber": week_number if not is_holiday_week else None,
                    "unitTitle": unit_title or f"{(week_number // 5) + 1}. Ünite",
                    "topicTitle": unit_title or f"{subject_name_val} {week_number}. Hafta",
                    "outcomeCode": outcome_code,
                    "outcomeDescription": kazanim_text or f"{subject_name_val} {week_number}. hafta MEB Maarif kazanımı ve etkinlikleri.",
                    "academicYear": "2026-2027",
                    "isMaarif": is_maarif,
                    "isOtpWeek": is_otp_week,
                    "isSocialEventWeek": is_social_event_week,
                    "isHolidayWeek": is_holiday_week,
                    "holidayNote": cal_info.get("holiday_note"),
                    "dateRange": {
                        "startDate": cal_info.get("start", ""),
                        "endDate": cal_info.get("end", ""),
                        "formatted": cal_info.get("formatted", "")
                    }
                }
                sheet_outcomes.append(item)

            all_outcomes.extend(sheet_outcomes)

        return all_outcomes

    def main():
        print("=" * 60)
        print("🚀 SınıfCepte - MEB Maarif Modeli JSON Boru Hattı (Pipeline)")
        print("=" * 60)

        excel_path = MASTER_EXCEL_PRIMARY if os.path.exists(MASTER_EXCEL_PRIMARY) else MASTER_EXCEL_FALLBACK
        if not os.path.exists(excel_path):
            print(f"❌ Hata: Excel dosyası bulunamadı! ({excel_path})")
            return

        outcomes = process_excel_file(excel_path)
        print(f"\n✅ Toplam Üretilen Resmî Maarif Kazanım Sayısı: {len(outcomes)}")

        # JSON Olarak Kaydet
        os.makedirs(os.path.dirname(OUTPUT_JSON), exist_ok=True)
        with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
            json.dump(outcomes, f, ensure_ascii=False, indent=2)

        print(f"🎉 Başarıyla Kaydedildi: {OUTPUT_JSON}")
        print("=" * 60)

    if __name__ == "__main__":
        main()
