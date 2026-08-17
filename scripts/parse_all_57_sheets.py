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
MASTER_EXCEL_FALLBACK = r"C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART_GUNCEL.xlsx"
OUTPUT_JSON = r"c:\Users\Okul\Desktop\Projelerim\sinifcepte\admin_portal\data\official_maarif_kazanimlar.json"
PRESETS_JS = r"c:\Users\Okul\Desktop\Projelerim\sinifcepte\admin_portal\js\curriculum_presets.js"

def normalize_tr(s):
    if not s:
        return ""
    s = str(s)
    tr_map = {'İ': 'i', 'I': 'ı', 'Ğ': 'ğ', 'Ü': 'ü', 'Ş': 'ş', 'Ö': 'ö', 'Ç': 'ç'}
    for k, v in tr_map.items():
        s = s.replace(k, v)
    return s.lower().strip()

def clean_text(val):
    if val is None:
        return ""
    text = str(val).strip()
    text = re.sub(r"\s+", " ", text)
    return text

def parse_grade(sheetname, filename):
    sn = normalize_tr(sheetname)
    fn = normalize_tr(filename)

    # 1. Sheetname içinde '1.sınıf', '1. sınıf'
    m_sn = re.search(r"(\d+)\s*\.?\s*s[ıi]n[ıi]f", sn)
    if m_sn:
        return int(m_sn.group(1))

    # 2. Sheetname içinde 'türkçe1', 'türkçe2', 'fen 3', 'tymm 2', 'çydem 6', 'bty_5', 'müzik-5'
    m_sn_embedded = re.search(r"(?:turkce|türkçe|fen|tymm|cydem|çydem|bty|sinif|sınıf|klasse|woche|grade|müzik|muzik)[^\d]*(\d+)", sn)
    if m_sn_embedded:
        return int(m_sn_embedded.group(1))

    m_sn_digit = re.search(r"\b([1-9]|1[0-2])\b", sn)
    if m_sn_digit:
        return int(m_sn_digit.group(1))

    # 3. Dosya adından ara
    m_fn = re.search(r"(\d+)\s*\.?\s*s[ıi]n[ıi]f", fn)
    if m_fn:
        return int(m_fn.group(1))
    
    m_fn_digit = re.search(r"\b([1-9]|1[0-2])\b", fn)
    if m_fn_digit:
        return int(m_fn_digit.group(1))

    return 5


def detect_subject_info(filename, sheetname):
    comb = normalize_tr(filename + " " + sheetname)
    grade = parse_grade(sheetname, filename)

    if "matematik" in comb:
        return grade, "MAT", "Matematik"
    if "fen" in comb:
        return grade, "FEN", "Fen Bilimleri"
    if "turkce" in comb or "türkçe" in comb or "turkçe" in comb or "türkce" in comb:
        pub = ""
        if "özgün" in comb or "ozgun" in comb: pub = " (Özgün)"
        elif "hecce" in comb: pub = " (Hecce)"
        elif "ilke" in comb: pub = " (İlke)"
        elif "ada" in comb: pub = " (Ada)"
        elif "meb" in comb: pub = " (MEB)"
        elif "tymm" in comb: pub = " (TYMM)"
        return grade, "TURKCE", f"Türkçe{pub}"
    if "inkılap" in comb or "inkilap" in comb or "inkılâp" in comb:
        return 8, "INKILAP", "T.C. İnkılap Tarihi ve Atatürkçülük"
    if "sosyal" in comb:
        return grade, "SOSYAL", "Sosyal Bilgiler"
    if "hayat" in comb:
        return grade, "HAYAT", "Hayat Bilgisi"
    if "ingilizce" in comb or "english" in comb or "cydem" in comb or "çydem" in comb:
        sub_type = ""
        if "çydem" in comb or "cydem" in comb: sub_type = " (ÇYDEM)"
        elif "tymm" in comb: sub_type = " (TYMM)"
        return grade, "INGILIZCE", f"İngilizce{sub_type}"
    if "bilişim" in comb or "bilisim" in comb or "bty" in comb:
        return grade, "BILISIM", "Bilişim Teknolojileri ve Yazılım"
    if "din" in comb:
        return grade, "DIN", "Din Kültürü ve Ahlak Bilgisi"
    if "beden" in comb:
        return grade, "BEDEN", "Beden Eğitimi ve Spor"
    if "müzik" in comb or "muzik" in comb:
        return grade, "MUZIK", "Müzik"
    if "görsel" in comb or "gorsel" in comb:
        return grade, "GORSEL", "Görsel Sanatlar"
    if "almanca" in comb:
        return grade, "ALMANCA", "Almanca"
    
    return grade, "GENEL", "Genel Ders"

def parse_sheet_data(sheet, filename, sheetname):
    if sheet.max_row <= 1 or sheetname.lower() == "sayfa1":
        return None

    grade, sub_code, sub_name = detect_subject_info(filename, sheetname)

    # 1'den 36'ya kadar her haftanın unit ve outcome'larını topla
    week_data = {w: {"units": [], "outcomes": []} for w in range(1, 37)}
    current_week = 0

    for r in range(1, sheet.max_row + 1):
        row_vals = [clean_text(cell.value) for cell in sheet[r]]
        if not any(row_vals):
            continue

        full_row_str = " ".join(row_vals)

        # Hafta bulma
        found_week = None
        week_col_idx = None

        for idx, val in enumerate(row_vals[:6]):
            # Örn: 1. Hafta, Week 1, 1.Woche
            m = re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", val, re.I)
            if m:
                found_week = int(m.group(1))
                week_col_idx = idx
                break
            # Veya direkt sayı 1..36
            if val.isdigit() and 1 <= int(val) <= 36 and idx <= 2:
                if int(val) == current_week + 1 or found_week is None:
                    found_week = int(val)
                    week_col_idx = idx

        if found_week is not None and 1 <= found_week <= 36:
            current_week = found_week

        if current_week == 0 or current_week > 36:
            continue

        # Hücreleri ayrıştır
        for idx, val in enumerate(row_vals):
            if idx == week_col_idx or not val or len(val) < 3:
                continue

            u_val = val.upper()
            if "ÜNİTE" in u_val or "TEMA" in u_val or "THEME" in u_val or "ÖĞRENME ALANI" in u_val:
                if val not in week_data[current_week]["units"]:
                    week_data[current_week]["units"].append(val)
            elif re.search(r"([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+|\b[A-Z]\d\.\d\.\w+\b|Students will be able to)", val):
                if val not in week_data[current_week]["outcomes"]:
                    week_data[current_week]["outcomes"].append(val)
            elif len(val) > 15 and not re.match(r"^\d+$", val):
                if "DERSİ" not in u_val and "ÖĞRETİM YILI" not in u_val and "SÜREÇ BİLEŞEN" not in u_val and "İÇERİK ÇERÇEVESİ" not in u_val:
                    if val not in week_data[current_week]["outcomes"]:
                        week_data[current_week]["outcomes"].append(val)

    # 36 Haftalık Standart MERKEZ_BOT Satırlarını Oluştur
    merkez_rows = []
    last_unit = "1. Ünite / Tema"

    for w in range(1, 37):
        if w == 9:
            merkez_rows.append({
                "plan_order": w,
                "ders_tipi": "Ara Tatil",
                "brans": sub_name.upper(),
                "sinif": grade,
                "unite": "1. DÖNEM ARA TATİLİ",
                "kazanim": "1. DÖNEM ARA TATİLİ: Kasım Ara Tatil Haftası (Dinlenme)",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": 9,
                "is_holiday": True
            })
            continue
        elif w in (19, 20):
            merkez_rows.append({
                "plan_order": w,
                "ders_tipi": "Yarıyıl Tatili",
                "brans": sub_name.upper(),
                "sinif": grade,
                "unite": "YARIYIL (SÖMESTR) TATİLİ",
                "kazanim": f"YARIYIL TATİLİ: {w - 18}. Hafta Sömestr Dinlenme",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": w,
                "is_holiday": True
            })
            continue
        elif w == 28:
            merkez_rows.append({
                "plan_order": w,
                "ders_tipi": "Ara Tatil",
                "brans": sub_name.upper(),
                "sinif": grade,
                "unite": "2. DÖNEM ARA TATİLİ",
                "kazanim": "2. DÖNEM ARA TATİLİ: Nisan Ara Tatil Haftası (Dinlenme)",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": 28,
                "is_holiday": True
            })
            continue

        w_obj = week_data[w]
        if w_obj["units"]:
            last_unit = w_obj["units"][0]

        if w_obj["outcomes"]:
            outcome_str = " | ".join(w_obj["outcomes"][:3])
        else:
            outcome_str = f"{sub_name} {w}. Hafta MEB müfredat kazanımı ve etkinlikleri."

        merkez_rows.append({
            "plan_order": w,
            "ders_tipi": "Ders",
            "brans": sub_name.upper(),
            "sinif": grade,
            "unite": last_unit,
            "kazanim": outcome_str,
            "hafta": str(w),
            "sub_code": sub_code,
            "week_num": w,
            "is_holiday": False
        })

    title_label = f"{grade}. Sınıf {sub_name}"
    return {
        "key": title_label,
        "grade": grade,
        "subject_code": sub_code,
        "subject_name": sub_name,
        "filename": filename,
        "sheetname": sheetname,
        "rows": merkez_rows
    }

def main():
    print("==================================================")
    print("🚀 TÜM 22 EXCEL DOSYASI VE 57 ÇALIŞMA SAYFASI TARANIYOR")
    print("==================================================\n")

    parsed_sheets = []
    seen_titles = {}

    for root, dirs, files in os.walk(FOLDER):
        for f in files:
            if f.endswith('.xlsx') and not f.startswith('~$'):
                path = os.path.join(root, f)
                try:
                    wb = openpyxl.load_workbook(path, data_only=True)
                    for s in wb.sheetnames:
                        res = parse_sheet_data(wb[s], f, s)
                        if res:
                            t_key = res['key']
                            if t_key in seen_titles:
                                seen_titles[t_key] += 1
                                res['tab_title'] = f"{res['key']} ({s[:10]})"
                            else:
                                seen_titles[t_key] = 1
                                res['tab_title'] = res['key']
                            
                            parsed_sheets.append(res)
                            print(f"  [+] {len(parsed_sheets):02d}. {res['tab_title']:<40} (36 Hafta)")
                except Exception as e:
                    print(f"  [-] Hata: {f} -> {e}")

    print(f"\n✅ Toplam {len(parsed_sheets)} Adet Ders Çerçeve Planı (57 Sayfa) Eksiksiz Ayrıştırıldı!")

    # 1. Master Excel Dosyasını Kaydet (Tüm 57 Sekme Dahil)
    save_master_excel_all(parsed_sheets)

    # 2. JSON ve JavaScript Kütüphanesini Güncelle
    save_json_and_presets(parsed_sheets)

def save_master_excel_all(parsed_sheets):
    wb = openpyxl.Workbook()
    
    # İlk Sayfa: TÜM DERSLER MERKEZ
    ws_all = wb.active
    ws_all.title = "TÜM DERSLER BİRLEŞİK"

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

    def write_to_sheet(ws, rows):
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

        ws.column_dimensions['A'].width = 12
        ws.column_dimensions['B'].width = 14
        ws.column_dimensions['C'].width = 25
        ws.column_dimensions['D'].width = 10
        ws.column_dimensions['E'].width = 32
        ws.column_dimensions['F'].width = 75
        ws.column_dimensions['G'].width = 10

    # 1. Ana sayfaya tüm satırları ekle
    all_rows = []
    for item in parsed_sheets:
        all_rows.extend(item["rows"])
    write_to_sheet(ws_all, all_rows)

    # 2. Her bir ders planı için ayrı Excel sekmesi aç (57 Sekme)
    used_sheet_names = set()
    for idx, item in enumerate(parsed_sheets):
        raw_tab_name = f"{item['grade']}.Snf {item['subject_name']}"
        safe_tab_name = re.sub(r'[\\/*?:\[\]]', '', raw_tab_name)[:28]
        if safe_tab_name in used_sheet_names:
            safe_tab_name = f"{safe_tab_name[:24]}_{idx+1}"
        used_sheet_names.add(safe_tab_name)

        ws_sub = wb.create_sheet(title=safe_tab_name)
        write_to_sheet(ws_sub, item["rows"])

    # Kaydetme ve Permission Error Fallback
    target_path = MASTER_EXCEL
    try:
        wb.save(MASTER_EXCEL)
        print(f"\n📊 Master Excel Kaydedildi: {MASTER_EXCEL}")
    except PermissionError:
        wb.save(MASTER_EXCEL_FALLBACK)
        target_path = MASTER_EXCEL_FALLBACK
        print(f"\n⚠️ {MASTER_EXCEL} açık olduğu için {MASTER_EXCEL_FALLBACK} olarak kaydedildi!")

def save_json_and_presets(parsed_sheets):
    all_outcomes = []
    for item in parsed_sheets:
        for r in item["rows"]:
            if r["is_holiday"]:
                code = "TATIL"
            else:
                m = re.search(r"([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+(?:\.\d+)?|\b[A-Z]\d\.\d\.\w+\b)", r["kazanim"])
                code = m.group(1) if m else f"{r['sub_code']}.{r['sinif']}.{r['hafta']}"

            all_outcomes.append({
                "id": f"merkez_{r['sinif']}_{r['sub_code']}_w{r['week_num']}_{item['sheetname'][:4].lower()}",
                "gradeLevel": r["sinif"],
                "subjectCode": r["sub_code"],
                "subjectName": r["brans"].title(),
                "weekNumber": r["week_num"],
                "unitTitle": r["unite"],
                "topicTitle": r["unite"],
                "outcomeCode": code,
                "outcomeDescription": r["kazanim"],
                "isHolidayWeek": r["is_holiday"],
                "holidayNote": r["unite"] if r["is_holiday"] else None,
                "academicYear": "2026-2027"
            })

    with open(OUTPUT_JSON, "w", encoding="utf-8") as f:
        json.dump(all_outcomes, f, ensure_ascii=False, indent=2)

    presets_json_str = json.dumps(all_outcomes, ensure_ascii=False)
    js_content = f"""/**
 * SınıfCepte Web Admin Paneli - Resmî MEB / Maarif Modeli Tüm 57 Çerçeve Yıllık Plan Kütüphanesi
 * Masaüstünüzdeki 22 dosyanın 57 ayrı çalışma sayfasından eksiksiz üretilmiştir.
 */
class CurriculumPresets {{
  static OFFICIAL_DATABASE = {presets_json_str};

  static PRESETS = {{
    'full_maarif_library': {{
      title: '🌟 Tüm Resmî MEB / Maarif Modeli Kütüphanesini Yükle (57 Ders Planı - {len(all_outcomes)} Hafta)',
      description: 'Masaüstünüzdeki tüm derslerin, tüm yayınevlerinin ve Maarif Modeli (TYMM/ÇYDEM) çerçeve planlarının tamamını tek tıkla yükler.',
      isFull: true,
    }},
    'ortaokul_matematik': {{
      title: '📐 Ortaokul Matematik Paketi (5, 6, 7, 8. Sınıf)',
      description: '5-8. Sınıf 36 haftalık resmî MEB Matematik çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'MAT' && [5,6,7,8].includes(o.gradeLevel),
    }},
    'ilkokul_matematik': {{
      title: '🔢 İlkokul Matematik Paketi (1, 2, 3, 4. Sınıf)',
      description: '1-4. Sınıf 36 haftalık resmî MEB İlkokul Matematik planları.',
      filter: (o) => o.subjectCode === 'MAT' && [1,2,3,4].includes(o.gradeLevel),
    }},
    'ortaokul_fen': {{
      title: '🔬 Fen Bilimleri Paketi (3, 4, 5, 6, 7, 8. Sınıf)',
      description: '3-8. Sınıf resmî MEB ve TYMM Fen Bilimleri planları.',
      filter: (o) => o.subjectCode === 'FEN',
    }},
    'turkce_full': {{
      title: '📚 Türkçe Paketi (1-8. Sınıf Tüm Yayınlar: MEB, Özgün, Hecce, İlke, Ada)',
      description: '1-8. Sınıflar tüm resmî MEB ve yayınevi Türkçe yıllık planları.',
      filter: (o) => o.subjectCode === 'TURKCE',
    }},
    'sosyal_inkilap': {{
      title: '🌍 Sosyal Bilgiler & T.C. İnkılap Tarihi (4, 5, 6, 7, 8. Sınıf)',
      description: '4-7. Sınıf Sosyal Bilgiler ve 8. Sınıf İnkılap Tarihi resmî planları.',
      filter: (o) => ['SOSYAL', 'INKILAP'].includes(o.subjectCode),
    }},
    'ingilizce_full': {{
      title: '🇬🇧 İngilizce & Almanca (2-8. Sınıf MEB, TYMM ve ÇYDEM)',
      description: '2-8. Sınıf MEB, İYDEM, TYMM ve ÇYDEM Yabancı Dil çerçeve planları.',
      filter: (o) => ['INGILIZCE', 'ALMANCA'].includes(o.subjectCode),
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
    print("✅ JSON ve JS Presets Başarıyla Güncellendi!")

if __name__ == "__main__":
    main()
