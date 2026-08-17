import os
import sys
import re
import json
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

FOLDER = r"C:\Users\Okul\Desktop\Kazanımlar"
MASTER_EXCEL = r"C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART.xlsx"
OUTPUT_JSON = r"c:\Users\Okul\Desktop\Projelerim\sinifcepte\admin_portal\data\official_maarif_kazanimlar.json"
PRESETS_JS = r"c:\Users\Okul\Desktop\Projelerim\sinifcepte\admin_portal\js\curriculum_presets.js"

os.makedirs(os.path.dirname(OUTPUT_JSON), exist_ok=True)

def clean_text(val):
    if val is None:
        return ""
    text = str(val).strip()
    text = re.sub(r"\s+", " ", text)
    return text

def parse_grade(text):
    match = re.search(r"(\d+)\s*\.?\s*s[ıi]n[ıi]f", text, re.I)
    if match:
        return int(match.group(1))
    match2 = re.search(r"\b([1-9]|1[0-2])\b", text)
    if match2:
        return int(match2.group(1))
    return None

def detect_subject(filename, sheetname):
    combined = (filename + " " + sheetname).lower()
    if "matematik" in combined:
        return "MAT", "Matematik"
    if "fen" in combined:
        return "FEN", "Fen Bilimleri"
    if "türkçe" in combined or "turkce" in combined:
        return "TURKCE", "Türkçe"
    if "sosyal" in combined:
        return "SOSYAL", "Sosyal Bilgiler"
    if "inkılap" in combined or "inkilap" in combined or "inkılâp" in combined:
        return "INKILAP", "T.C. İnkılap Tarihi ve Atatürkçülük"
    if "hayat" in combined:
        return "HAYAT", "Hayat Bilgisi"
    if "ingilizce" in combined or "english" in combined:
        return "INGILIZCE", "İngilizce"
    if "bilişim" in combined or "bilisim" in combined:
        return "BILISIM", "Bilişim Teknolojileri ve Yazılım"
    if "din" in combined:
        return "DIN", "Din Kültürü ve Ahlak Bilgisi"
    if "beden" in combined:
        return "BEDEN", "Beden Eğitimi ve Spor"
    if "müzik" in combined or "muzik" in combined:
        return "MUZIK", "Müzik"
    if "görsel" in combined or "gorsel" in combined:
        return "GORSEL", "Görsel Sanatlar"
    if "almanca" in combined:
        return "ALMANCA", "Almanca"
    return "GENEL", "Genel Ders"

def parse_sheet_to_merkez_rows(sheet, filename, sheetname):
    sub_code, sub_name = detect_subject(filename, sheetname)
    grade = parse_grade(sheetname) or parse_grade(filename) or 5

    raw_items = []
    current_week = 0
    current_unit = "1. Ünite / Tema"

    for r in range(1, sheet.max_row + 1):
        row = sheet[r]
        row_vals = [clean_text(cell.value) for cell in row]
        if not any(row_vals):
            continue

        full_str = " ".join(row_vals)

        # Hafta numarasını bul
        found_week = None
        week_idx = None
        for idx, val in enumerate(row_vals[:4]):
            m = re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", val, re.I)
            if m:
                found_week = int(m.group(1))
                week_idx = idx
                break

        if found_week is not None:
            current_week = found_week

        if current_week == 0 or current_week > 38:
            continue

        potential_texts = [v for idx, v in enumerate(row_vals) if v and idx != week_idx and not re.match(r"^\d+$", v)]
        
        unit_cand = ""
        outcome_cand = ""

        for text in potential_texts:
            if "ÜNİTE" in text.upper() or "TEMA" in text.upper() or "THEME" in text.upper() or "ÖĞRENME ALANI" in text.upper():
                unit_cand = text
            elif re.search(r"([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+|\b[A-Z]\d\.\d\.\w+\b|Students will be able to)", text):
                outcome_cand = text

        if unit_cand:
            current_unit = unit_cand
        if not outcome_cand and potential_texts:
            outcome_cand = max(potential_texts, key=len)

        raw_items.append({
            "week": current_week,
            "unit": current_unit,
            "outcome": outcome_cand or f"{sub_name} {current_week}. Hafta MEB Kazanımı ve Etkinlikleri"
        })

    # Hafta 1-36 arası tekilleştir
    week_map = {}
    for item in raw_items:
        w = item["week"]
        if w not in week_map or len(item["outcome"]) > len(week_map[w]["outcome"]):
            week_map[w] = item

    merkez_rows = []
    plan_order = 1

    for w in range(1, 37):
        # Tatil kontrolleri
        if w == 9:
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Ara Tatil",
                "brans": sub_name.upper(),
                "sinif": grade,
                "unite": "1. DÖNEM ARA TATİLİ",
                "kazanim": "1. DÖNEM ARA TATİLİ: Kasım Ara Tatil Haftası",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": 9,
                "is_holiday": True
            })
            plan_order += 1
            continue
        elif w in (19, 20):
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Yarıyıl Tatili",
                "brans": sub_name.upper(),
                "sinif": grade,
                "unite": "YARIYIL (SÖMESTR) TATİLİ",
                "kazanim": f"YARIYIL TATİLİ: {w - 18}. Hafta Dinlenme",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": w,
                "is_holiday": True
            })
            plan_order += 1
            continue
        elif w == 28:
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Ara Tatil",
                "brans": sub_name.upper(),
                "sinif": grade,
                "unite": "2. DÖNEM ARA TATİLİ",
                "kazanim": "2. DÖNEM ARA TATİLİ: Nisan Ara Tatil Haftası",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": 28,
                "is_holiday": True
            })
            plan_order += 1
            continue

        item = week_map.get(w)
        unit_text = item["unit"] if item else f"{(w // 6) + 1}. Ünite"
        outcome_text = item["outcome"] if item else f"{sub_name} {w}. hafta MEB müfredat kazanımı ve etkinlikleri."

        merkez_rows.append({
            "plan_order": plan_order,
            "ders_tipi": "Ders",
            "brans": sub_name.upper(),
            "sinif": grade,
            "unite": unit_text,
            "kazanim": outcome_text,
            "hafta": str(w),
            "sub_code": sub_code,
            "week_num": w,
            "is_holiday": False
        })
        plan_order += 1

    return merkez_rows

def main():
    print("🚀 MERKEZ_BOT Otomasyon Motoru Başlatılıyor...")
    all_merkez_records = []
    sheet_collections = {}

    for root, dirs, files in os.walk(FOLDER):
        for f in files:
            if f.endswith('.xlsx') and not f.startswith('~$'):
                path = os.path.join(root, f)
                try:
                    wb = openpyxl.load_workbook(path, data_only=True)
                    for s in wb.sheetnames:
                        rows = parse_sheet_to_merkez_rows(wb[s], f, s)
                        if rows:
                            key = f"{rows[0]['sinif']}. Sınıf {rows[0]['brans']}"
                            if key not in sheet_collections:
                                sheet_collections[key] = rows
                                all_merkez_records.extend(rows)
                                print(f"  [+] {key} ({len(rows)} satır standart MERKEZ_BOT formatına dönüştürüldü)")
                except Exception as e:
                    print(f"  [-] Hata: {f} -> {e}")

    print(f"\n✅ Toplam {len(sheet_collections)} Branş/Kademe ve {len(all_merkez_records)} MERKEZ_BOT satırı üretildi.")

    # 1. Master Excel Dosyasını Oluştur (C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART.xlsx)
    create_master_excel(sheet_collections, all_merkez_records)

    # 2. JSON ve curriculum_presets.js Çıktılarını Üret
    create_json_and_presets(all_merkez_records)

def create_master_excel(sheet_collections, all_records):
    print("\n📊 Excel Master Dosyası Üretiliyor:", MASTER_EXCEL)
    wb = openpyxl.Workbook()
    
    # İlk sayfa: TÜM_DERSLER_BİRLEŞİK
    ws_all = wb.active
    ws_all.title = "TÜM DERSLER MERKEZ"

    headers = ["Plan Sırası", "Ders Tipi", "Branş", "Sınıf", "Ünite", "Kazanım", "Hafta"]
    
    header_fill = PatternFill(start_color="4F46E5", end_color="4F46E5", fill_type="solid")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    holiday_fill = PatternFill(start_color="FEF3C7", end_color="FEF3C7", fill_type="solid")
    border_thin = Border(
        left=Side(style='thin', color='E5E7EB'),
        right=Side(style='thin', color='E5E7EB'),
        top=Side(style='thin', color='E5E7EB'),
        bottom=Side(style='thin', color='E5E7EB')
    )

    def write_sheet(ws, rows):
        ws.append(headers)
        for col_num in range(1, 8):
            cell = ws.cell(row=1, column=col_num)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")

        for r_idx, r in enumerate(rows, start=2):
            ws.append([r["plan_order"], r["ders_tipi"], r["brans"], r["sinif"], r["unite"], r["kazanim"], r["hafta"]])
            for c_idx in range(1, 8):
                cell = ws.cell(row=r_idx, column=c_idx)
                cell.border = border_thin
                if r["is_holiday"]:
                    cell.fill = holiday_fill
                if c_idx in (1, 2, 4, 7):
                    cell.alignment = Alignment(horizontal="center", vertical="center")

        # Otomatik genişlik
        ws.column_dimensions['A'].width = 12
        ws.column_dimensions['B'].width = 14
        ws.column_dimensions['C'].width = 25
        ws.column_dimensions['D'].width = 10
        ws.column_dimensions['E'].width = 32
        ws.column_dimensions['F'].width = 65
        ws.column_dimensions['G'].width = 10

    write_sheet(ws_all, all_records)

    # Branşlara özel sayfalar
    for name, rows in list(sheet_collections.items())[:20]: # Excel sekme limiti için ilk 20 branş ayrı sekme
        safe_name = re.sub(r'[\\/*?:\[\]]', '', name)[:30]
        ws_sub = wb.create_sheet(title=safe_name)
        write_sheet(ws_sub, rows)

    wb.save(MASTER_EXCEL)
    print("✅ Master Excel Başarıyla Masaüstüne Kaydedildi!")

def create_json_and_presets(all_records):
    # JSON Çıktısı
    json_outcomes = []
    for r in all_records:
        if r["is_holiday"]:
            code = "TATIL"
        else:
            m = re.search(r"([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+(?:\.\d+)?|\b[A-Z]\d\.\d\.\w+\b)", r["kazanim"])
            code = m.group(1) if m else f"{r['sub_code']}.{r['sinif']}.{r['hafta']}"

        json_outcomes.append({
            "id": f"merkez_{r['sinif']}_{r['sub_code']}_w{r['week_num']}",
            "gradeLevel": r["sinif"],
            "subjectCode": r["sub_code"],
            "subjectName": r["brans"].title(),
            "weekNumber": r["week_num"],
            "unitTitle": r["unite"],
            "topicTitle": r["unite"],
            "outcomeCode": code,
            "outcomeDescription": r["kazanim"],
            "isHolidayWeek": r["is_holiday"],
            "holidayNote": r["unite"] if r["is_holiday"] else None
        })

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(json_outcomes, f, ensure_ascii=False, indent=2)

    # curriculum_presets.js
    presets_json_str = json.dumps(json_outcomes, ensure_ascii=False)
    
    js_content = f"""/**
 * SınıfCepte Web Admin Paneli - Resmî MEB / MERKEZ_BOT Standart Müfredat Kütüphanesi
 * MERKEZ_BOT formatında masaüstünüzdeki tüm çerçeve yıllık planlardan otomatik üretilmiştir.
 */
class CurriculumPresets {{
  static OFFICIAL_DATABASE = {presets_json_str};

  static PRESETS = {{
    'full_maarif_library': {{
      title: '🌟 Tüm Resmî MEB / Maarif Modeli Kütüphanesini Yükle (Full Kütüphane)',
      description: 'Masaüstünüzdeki tüm derslerin ({len(json_outcomes)} haftalık) 1-8. sınıf MERKEZ_BOT formatlı müfredatını tek tıkla yükler.',
      isFull: true,
    }},
    'ortaokul_matematik': {{
      title: '📐 Ortaokul Matematik Paketi (5, 6, 7, 8. Sınıf)',
      description: '5, 6, 7, 8. Sınıf 36 haftalık resmî MERKEZ_BOT Matematik çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'MAT' && [5,6,7,8].includes(o.gradeLevel),
    }},
    'ilkokul_matematik': {{
      title: '🔢 İlkokul Matematik Paketi (1, 2, 3, 4. Sınıf)',
      description: '1, 2, 3, 4. Sınıf 36 haftalık resmî MEB İlkokul Matematik planları.',
      filter: (o) => o.subjectCode === 'MAT' && [1,2,3,4].includes(o.gradeLevel),
    }},
    'ortaokul_fen': {{
      title: '🔬 Ortaokul Fen Bilimleri Paketi (5, 6, 7, 8. Sınıf)',
      description: '5, 6, 7, 8. Sınıf 36 haftalık resmî MEB Fen Bilimleri planları.',
      filter: (o) => o.subjectCode === 'FEN' && [5,6,7,8].includes(o.gradeLevel),
    }},
    'turkce_full': {{
      title: '📚 Türkçe Paketi (1-8. Sınıflar Tüm Kademeler)',
      description: '1, 2, 3, 4, 5, 6, 7, 8. Sınıf 36 haftalık resmî MEB Türkçe yıllık planları.',
      filter: (o) => o.subjectCode === 'TURKCE',
    }},
    'sosyal_inkilap': {{
      title: '🌍 Sosyal Bilgiler & T.C. İnkılap Tarihi (4-8. Sınıf)',
      description: '4, 5, 6, 7. Sınıf Sosyal Bilgiler ve 8. Sınıf İnkılap Tarihi resmî planları.',
      filter: (o) => ['SOSYAL', 'INKILAP'].includes(o.subjectCode),
    }},
    'ingilizce_full': {{
      title: '🇬🇧 İngilizce Paketi (2-8. Sınıflar Tüm Kademeler)',
      description: '2, 3, 4, 5, 6, 7, 8. Sınıf MEB ve İYDEM İngilizce çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'INGILIZCE',
    }},
    'hayat_bilgisi': {{
      title: '🌱 Hayat Bilgisi Paketi (1, 2, 3. Sınıf)',
      description: '1, 2, 3. Sınıf resmî Hayat Bilgisi çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'HAYAT',
    }},
    'bilisim_teknolojileri': {{
      title: '💻 Bilişim Teknolojileri ve Yazılım (5, 6. Sınıf)',
      description: '5 ve 6. Sınıf TYMM Bilişim Teknolojileri ve Yazılım planları.',
      filter: (o) => o.subjectCode === 'BILISIM',
    }},
    'beden_muzik_gorsel': {{
      title: '🎨 Görsel Sanatlar, Müzik, Beden Eğitimi & Spor',
      description: '1-8. Sınıf Görsel Sanatlar, Müzik, Beden Eğitimi ve Oyun/Spor planları.',
      filter: (o) => ['BEDEN', 'MUZIK', 'GORSEL'].includes(o.subjectCode),
    }}
  }};

  static applyPreset(presetKey, outcomesManager) {{
    const preset = this.PRESETS[presetKey];
    if (!preset) return 0;

    let toAdd = [];
    if (preset.isFull) {{
      toAdd = this.OFFICIAL_DATABASE;
    }} else if (preset.filter) {{
      toAdd = this.OFFICIAL_DATABASE.filter(preset.filter);
    }}

    if (toAdd.length === 0) return 0;

    const keysToReplace = new Set(toAdd.map(o => `${{o.gradeLevel}}_${{o.subjectCode}}`));
    outcomesManager.outcomes = outcomesManager.outcomes.filter(
      (o) => !keysToReplace.has(`${{o.gradeLevel}}_${{o.subjectCode}}`)
    );

    outcomesManager.outcomes.push(...toAdd);
    outcomesManager.save();

    return toAdd.length;
  }}
}}

window.CurriculumPresets = CurriculumPresets;
"""

    with open(PRESETS_JS, "w", encoding="utf-8") as js_file:
        js_file.write(js_content)
    print("✅ JSON ve Presets Güncellendi!")

if __name__ == "__main__":
    main()
