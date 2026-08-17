import os
import sys
import re
import json
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

MASTER_EXCEL = r"C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART.xlsx"
MASTER_EXCEL_FALLBACK = r"C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART_GUNCEL.xlsx"
OUTPUT_JSON = r"c:\Users\Okul\Desktop\Projelerim\sinifcepte\admin_portal\data\official_maarif_kazanimlar.json"
PRESETS_JS = r"c:\Users\Okul\Desktop\Projelerim\sinifcepte\admin_portal\js\curriculum_presets.js"

def normalize_tr(s):
    if not s: return ""
    s = str(s)
    for k, v in {'İ':'i','I':'ı','Ğ':'ğ','Ü':'ü','Ş':'ş','Ö':'ö','Ç':'ç'}.items():
        s = s.replace(k, v)
    return s.lower().strip()

def clean_cell(val):
    if val is None: return ""
    v = str(val).replace('\r', ' ').replace('\n', ' ').strip()
    return re.sub(r"\s+", " ", v)

def parse_grade(sheetname, filename):
    sn = normalize_tr(sheetname)
    fn = normalize_tr(filename)
    m = re.search(r"(\d+)\s*\.?\s*s[ıi]n[ıi]f", sn) or re.search(r"(?:turkce|türkçe|fen|tymm|cydem|çydem|bty|klasse|müzik|muzik)[^\d]*(\d+)", sn) or re.search(r"\b([1-9]|1[0-2])\b", sn)
    if m: return int(m.group(1))
    m2 = re.search(r"(\d+)\s*\.?\s*s[ıi]n[ıi]f", fn) or re.search(r"\b([1-9]|1[0-2])\b", fn)
    if m2: return int(m2.group(1))
    return 5

def detect_subject_and_publisher(filename, sheetname):
    comb = normalize_tr(filename + " " + sheetname)
    grade = parse_grade(sheetname, filename)
    
    publisher = "MEB Yayınları"
    
    if "matematik" in comb:
        sub_code = "MAT"
        sub_name = "Matematik"
        if "tymm" in comb or "maarif" in comb or grade in (1, 5): 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "fen" in comb:
        sub_code = "FEN"
        sub_name = "Fen Bilimleri"
        if "tymm" in comb or "maarif" in comb or (grade in (5, 6) and "tymm" in comb): 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "turkce" in comb or "türkçe" in comb or "turkçe" in comb:
        sub_code = "TURKCE"
        sub_name = "Türkçe"
        if "özgün" in comb or "ozgun" in comb: 
            publisher = "Özgün Yayınları"
        elif "hecce" in comb: 
            publisher = "Hecce Yayıncılık"
        elif "ilke" in comb: 
            publisher = "İlke Yayınları"
        elif "ada" in comb: 
            publisher = "Ada Yayıncılık"
        elif "tymm" in comb or "maarif" in comb: 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "inkılap" in comb or "inkilap" in comb or "inkılâp" in comb:
        grade = 8
        sub_code = "INKILAP"
        sub_name = "T.C. İnkılap Tarihi ve Atatürkçülük"
        publisher = "MEB Yayınları"
    elif "sosyal" in comb:
        sub_code = "SOSYAL"
        sub_name = "Sosyal Bilgiler"
        if "tymm" in comb or "maarif" in comb: 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "hayat" in comb:
        sub_code = "HAYAT"
        sub_name = "Hayat Bilgisi"
        if "tymm" in comb or "maarif" in comb or grade in (1, 2): 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "ingilizce" in comb or "english" in comb or "cydem" in comb or "çydem" in comb:
        sub_code = "INGILIZCE"
        sub_name = "İngilizce"
        if "çydem" in comb or "cydem" in comb: 
            publisher = "ÇYDEM (Maarif Modeli)"
        elif "tymm" in comb: 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "bilişim" in comb or "bilisim" in comb or "bty" in comb:
        sub_code = "BILISIM"
        sub_name = "Bilişim Teknolojileri ve Yazılım"
        if "tymm" in comb or "maarif" in comb: 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "din" in comb:
        sub_code = "DIN"
        sub_name = "Din Kültürü ve Ahlak Bilgisi"
        publisher = "MEB Yayınları"
    elif "beden" in comb:
        sub_code = "BEDEN"
        sub_name = "Beden Eğitimi ve Spor"
        if "tymm" in comb or "maarif" in comb or grade in (1, 2): 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "müzik" in comb or "muzik" in comb:
        sub_code = "MUZIK"
        sub_name = "Müzik"
        if "tymm" in comb or "maarif" in comb: 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "görsel" in comb or "gorsel" in comb:
        sub_code = "GORSEL"
        sub_name = "Görsel Sanatlar"
        if "tymm" in comb or "maarif" in comb: 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    elif "almanca" in comb:
        sub_code = "ALMANCA"
        sub_name = "Almanca"
        if "tymm" in comb or "maarif" in comb: 
            publisher = "TYMM (Maarif Modeli)"
        else: 
            publisher = "MEB Yayınları"
    else:
        sub_code = "GENEL"
        sub_name = "Genel Ders"
        publisher = "MEB Yayınları"
        
    full_title = f"{grade}. Sınıf - {sub_name} - {publisher}"
    
    # Kısa Sekme Adı (Max 30 Karakter)
    short_pub = publisher.replace(" Yayınları", "").replace(" Yayıncılık", "").replace(" (Maarif Modeli)", "")
    
    short_sub = sub_name.replace(" ve Yazılım", "").replace(" ve Spor", "").replace(" ve Atatürkçülük", "")
    if short_sub == "Bilişim Teknolojileri": short_sub = "Bilişim"
    if short_sub == "Beden Eğitimi": short_sub = "Beden"
    if short_sub == "Görsel Sanatlar": short_sub = "Görsel"
    if short_sub == "T.C. İnkılap Tarihi": short_sub = "İnkılap"
    if short_sub == "Fen Bilimleri": short_sub = "Fen"
    if short_sub == "Sosyal Bilgiler": short_sub = "Sosyal"
    
    tab_name = f"{grade}-{short_sub}-{short_pub}"[:30]
    return grade, sub_code, sub_name, publisher, full_title, tab_name

def extract_week_nums(val):
    if not val: return []
    s = str(val).strip()
    m_range = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})\s*[-–/]\s*(\d{1,2})", s, re.I) or \
              re.search(r"(\d{1,2})\s*[-–/]\s*(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m_range:
        w1, w2 = int(m_range.group(1)), int(m_range.group(2))
        if 1 <= w1 <= 36 and 1 <= w2 <= 36 and w1 <= w2:
            return list(range(w1, w2 + 1))
    m = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})", s, re.I) or re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m:
        w = int(m.group(1))
        if 1 <= w <= 36: return [w]
    if s.isdigit() and 1 <= int(s) <= 36:
        return [int(s)]
    return []

def parse_sheet_exact(sheet, filename, sheetname):
    grade, sub_code, sub_name, publisher, full_title, tab_name = detect_subject_and_publisher(filename, sheetname)

    # 1. Başlık ve Sütunları Bul
    week_col = None
    unit_col = None
    topic_col = None
    outcome_cols = []
    header_row = 1
    
    for r in range(1, min(6, sheet.max_row + 1)):
        row_vals = [clean_cell(sheet.cell(r, c).value) for c in range(1, sheet.max_column + 1)]
        for c, val in enumerate(row_vals, 1):
            u = val.upper().strip()
            if u in ["HAFTA", "WEEK", "WOCHE"] or u.startswith("HAFTA (") or u.startswith("WEEK (") or u.startswith("HAFTA/"):
                if not week_col: week_col = c; header_row = r
            elif any(k in u for k in ["ÜNİTE / TEMA", "ÜNİTE/TEMA", "UNIT/THEME", "THEME", "TEMA", "ÖĞRENME ALANI"]):
                if not unit_col: unit_col = c
            elif any(k in u for k in ["KONU (İÇERİK ÇERÇEVESİ)", "KONU", "CONTENT FRAME", "İÇERİK", "METİN", "SUB-THEME", "FUNCTIONS"]):
                if not topic_col: topic_col = c
            elif any(k in u for k in ["ÖĞRENME ÇIKTILARI", "KAZANIM", "LEARNING OUTCOME", "LERNZIELE", "LEARNING SKILLS", "OKUMA", "YAZMA", "KONUŞMA", "DİNLEME"]):
                if c not in outcome_cols: outcome_cols.append(c)
                
        if week_col and outcome_cols:
            break
            
    if not week_col: week_col = 2
    if not unit_col: unit_col = 4 if sheet.max_column >= 4 else 1
    if not outcome_cols: outcome_cols = [6] if sheet.max_column >= 6 else [5]

    week_map = {w: {"unit": "", "topic": "", "outcomes": []} for w in range(1, 37)}
    current_weeks = [1]
    last_unit = "1. Ünite"
    last_topic = ""
    
    for r in range(header_row + 1, sheet.max_row + 1):
        row_vals = [clean_cell(sheet.cell(r, c).value) for c in range(1, sheet.max_column + 1)]
        if not any(row_vals): continue
        u_line = " ".join(row_vals).upper()
        if "ÖLÇME VE DEĞERLENDİRME" in u_line or "BEWERTUNG" in u_line or "ASSESSMENT" in u_line: continue
        if "EĞİTİM ÖĞRETİM YILI" in u_line and len(u_line) < 60: continue
        if "ACADEMIC YEAR" in u_line and len(u_line) < 60: continue
        if "SCHULJAHR" in u_line and len(u_line) < 60: continue
        
        # Hafta tespiti
        raw_w = row_vals[week_col-1] if week_col <= len(row_vals) else ""
        w_list = extract_week_nums(raw_w)
        if not w_list and week_col != 1:
            w_list = extract_week_nums(row_vals[0])
            
        if w_list:
            current_weeks = w_list
            
        # Ünite & Konu
        raw_u = row_vals[unit_col-1] if unit_col and unit_col <= len(row_vals) else ""
        raw_t = row_vals[topic_col-1] if topic_col and topic_col <= len(row_vals) else ""
        
        if raw_u and len(raw_u) > 1 and not any(k == raw_u.upper() for k in ["ÜNİTE", "THEME", "TEMA", "ÜNİTE/TEMA", "UNIT/THEME"]):
            last_unit = raw_u
        if raw_t and len(raw_t) > 1 and not any(k == raw_t.upper() for k in ["KONU", "CONTENT", "İÇERİK", "METİN"]):
            last_topic = raw_t
            
        chosen_unit = last_topic if last_topic else last_unit
        
        # Kazanımlar (Outcome Columns)
        row_outcomes = []
        for oc in outcome_cols:
            if oc <= len(row_vals):
                val = clean_cell(row_vals[oc-1])
                if val and len(val) > 4 and not any(k == val.upper() for k in ["KAZANIM", "KAZANIMLAR", "ÖĞRENME ÇIKTILARI", "LEARNING OUTCOMES", "DİNLEME/İZLEME", "KONUŞMA", "OKUMA", "YAZMA"]):
                    row_outcomes.append(val)
                    
        for w in current_weeks:
            if 1 <= w <= 36:
                week_map[w]["unit"] = chosen_unit
                for ro in row_outcomes:
                    if ro not in week_map[w]["outcomes"]:
                        week_map[w]["outcomes"].append(ro)

    # 36 Haftayı Standart MERKEZ_BOT Satırlarına Dönüştür
    merkez_rows = []
    last_known_unit = "1. Ünite"
    last_known_outcome = f"{grade}. Sınıf {sub_name} dersi MEB müfredat kazanımı."
    brans_label = f"{grade}.sinif {sub_name}"
    plan_order = 1

    for w in range(1, 37):
        # 1. DÖNEM ARA TATİLİ (9. Haftadan sonra)
        if w == 9:
            # 9. Haftanın kendi dersini ekle
            u = week_map[w]["unit"] or last_known_unit
            last_known_unit = u
            if week_map[w]["outcomes"]:
                o = " ".join(week_map[w]["outcomes"][:2])
                last_known_outcome = o
            else:
                o = last_known_outcome
                
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Ders",
                "brans": brans_label,
                "sinif": grade,
                "publisher": publisher,
                "unite": u,
                "kazanim": o,
                "hafta": str(w),
                "sub_code": sub_code,
                "week_num": w,
                "is_holiday": False
            })
            plan_order += 1

            # 1. Ara Tatil Satırı
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Ara Tatil",
                "brans": brans_label,
                "sinif": grade,
                "publisher": publisher,
                "unite": "1. DÖNEM ARA TATİLİ: 10 Kasım - 14 Kasım 2025",
                "kazanim": "1. DÖNEM ARA TATİLİ: 10 Kasım - 14 Kasım 2025",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": 9,
                "is_holiday": True
            })
            plan_order += 1
            continue

        # SÖMESTR TATİLİ (18. Haftadan sonra)
        elif w == 18:
            # 18. Haftanın kendi dersini ekle
            u = week_map[w]["unit"] or last_known_unit
            last_known_unit = u
            if week_map[w]["outcomes"]:
                o = " ".join(week_map[w]["outcomes"][:2])
                last_known_outcome = o
            else:
                o = last_known_outcome
                
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Ders",
                "brans": brans_label,
                "sinif": grade,
                "publisher": publisher,
                "unite": u,
                "kazanim": o,
                "hafta": str(w),
                "sub_code": sub_code,
                "week_num": w,
                "is_holiday": False
            })
            plan_order += 1

            # Yarıyıl Tatili Satırı
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Yarıyıl",
                "brans": brans_label,
                "sinif": grade,
                "publisher": publisher,
                "unite": "YARIYIL TATİLİ: 19 Ocak - 30 Ocak 2026",
                "kazanim": "YARIYIL TATİLİ: 19 Ocak - 30 Ocak 2026",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": 18,
                "is_holiday": True
            })
            plan_order += 1
            continue

        # 2. DÖNEM ARA TATİLİ (27. Haftadan sonra)
        elif w == 27:
            # 27. Haftanın kendi dersini ekle
            u = week_map[w]["unit"] or last_known_unit
            last_known_unit = u
            if week_map[w]["outcomes"]:
                o = " ".join(week_map[w]["outcomes"][:2])
                last_known_outcome = o
            else:
                o = last_known_outcome
                
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Ders",
                "brans": brans_label,
                "sinif": grade,
                "publisher": publisher,
                "unite": u,
                "kazanim": o,
                "hafta": str(w),
                "sub_code": sub_code,
                "week_num": w,
                "is_holiday": False
            })
            plan_order += 1

            # 2. Ara Tatil Satırı
            merkez_rows.append({
                "plan_order": plan_order,
                "ders_tipi": "Ara Tatil",
                "brans": brans_label,
                "sinif": grade,
                "publisher": publisher,
                "unite": "2. DÖNEM ARA TATİLİ: 16 Mart - 20 Mart 2026",
                "kazanim": "2. DÖNEM ARA TATİLİ: 16 Mart - 20 Mart 2026",
                "hafta": "",
                "sub_code": sub_code,
                "week_num": 27,
                "is_holiday": True
            })
            plan_order += 1
            continue

        # Normal Ders Satırı
        u = week_map[w]["unit"] or last_known_unit
        last_known_unit = u
        if week_map[w]["outcomes"]:
            o = " ".join(week_map[w]["outcomes"][:2])
            last_known_outcome = o
        else:
            if "ORIENTATION" in u.upper() or "UYUM" in u.upper():
                o = "Orientation: Okul ve derse uyum, ders işleniş kuralları ve süreç planlama etkinlikleri."
            elif "REVISION" in u.upper() or "TEKRAR" in u.upper():
                o = f"{u}: Önceki yıl öğrenilen temel konular ve dil yapılarının tekrarı."
            else:
                o = last_known_outcome

        merkez_rows.append({
            "plan_order": plan_order,
            "ders_tipi": "Ders",
            "brans": brans_label,
            "sinif": grade,
            "publisher": publisher,
            "unite": u,
            "kazanim": o,
            "hafta": str(w),
            "sub_code": sub_code,
            "week_num": w,
            "is_holiday": False
        })
        plan_order += 1

    return {
        "key": full_title,
        "grade": grade,
        "subject_code": sub_code,
        "subject_name": sub_name,
        "publisher": publisher,
        "full_title": full_title,
        "tab_name": tab_name,
        "filename": filename,
        "sheetname": sheetname,
        "rows": merkez_rows
    }

def main():
    print("==================================================")
    print("🚀 MERKEZ_BOT FORMATINA %100 BİREBİR UYUMLU DÖNÜŞTÜRÜCÜ")
    print("==================================================\n")

    parsed_sheets = []
    seen_tabs = {}

    for root, dirs, files in os.walk(target_dir):
        for f in files:
            if f.endswith('.xlsx') and not f.startswith('~$'):
                path = os.path.join(root, f)
                try:
                    wb = openpyxl.load_workbook(path, data_only=True)
                    for s in wb.sheetnames:
                        if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                        res = parse_sheet_exact(wb[s], f, s)
                        if res:
                            t_tab = res['tab_name']
                            if t_tab in seen_tabs:
                                seen_tabs[t_tab] += 1
                                res['tab_name'] = f"{res['tab_name']}_{seen_tabs[t_tab]}"[:30]
                            else:
                                seen_tabs[t_tab] = 1
                            
                            parsed_sheets.append(res)
                            
                            sample_u = res['rows'][0]['unite'][:25]
                            sample_k = res['rows'][0]['kazanim'][:45]
                            print(f"  [+] {len(parsed_sheets):02d}. [{res['tab_name']:<18}] Ünite: '{sample_u:<25}' | Kaz: '{sample_k}'")
                except Exception as e:
                    print(f"  [-] Hata: {f} -> {e}")

    print(f"\n✅ Toplam {len(parsed_sheets)} Çerçeve Plan MERKEZ_BOT Formatına Birebir Ayrıştırıldı!")

    # 1. Master Excel Dosyasını Kaydet
    save_master_excel(parsed_sheets)

    # 2. JSON ve JavaScript Presets Güncelle
    save_json_and_presets(parsed_sheets)

def save_master_excel(parsed_sheets):
    wb = openpyxl.Workbook()
    ws_all = wb.active
    ws_all.title = "TÜM DERSLER BİRLEŞİK"

    headers = ["Plan Sırası", "Ders Tipi", "Branş", "Sınıf", "Ünite", "Kazanım", "Hafta"]
    header_fill = PatternFill(start_color="4F46E5", end_color="4F46E5", fill_type="solid")
    header_font = Font(name="Calibri", size=11, bold=True, color="FFFFFF")
    holiday_fill = PatternFill(start_color="FEF3C7", end_color="FEF3C7", fill_type="solid")
    border_thin = Border(
        left=Side(style='thin', color='E5E7EB'), right=Side(style='thin', color='E5E7EB'),
        top=Side(style='thin', color='E5E7EB'), bottom=Side(style='thin', color='E5E7EB')
    )

    def write_sheet(ws, rows):
        ws.append(headers)
        ws.row_dimensions[1].height = 24
        for col_num in range(1, 8):
            cell = ws.cell(row=1, column=col_num)
            cell.fill = header_fill
            cell.font = header_font
            cell.alignment = Alignment(horizontal="center", vertical="center")

        for r_idx, r in enumerate(rows, start=2):
            ws.append([
                r["plan_order"], 
                r["ders_tipi"], 
                r["brans"], 
                r["sinif"], 
                r["unite"], 
                r["kazanim"], 
                r["hafta"]
            ])
            for c_idx in range(1, 8):
                cell = ws.cell(row=r_idx, column=c_idx)
                cell.border = border_thin
                if r["is_holiday"]:
                    cell.fill = holiday_fill
                if c_idx in (1, 2, 4, 7):
                    cell.alignment = Alignment(horizontal="center", vertical="center")

        ws.column_dimensions['A'].width = 12
        ws.column_dimensions['B'].width = 14
        ws.column_dimensions['C'].width = 32
        ws.column_dimensions['D'].width = 10
        ws.column_dimensions['E'].width = 38
        ws.column_dimensions['F'].width = 85
        ws.column_dimensions['G'].width = 10

    # Master Birleşik Sekme
    all_rows = []
    for item in parsed_sheets:
        all_rows.extend(item["rows"])
    write_sheet(ws_all, all_rows)

    # 59 Bireysel Ders Sekmesi
    for item in parsed_sheets:
        ws_sub = wb.create_sheet(title=item["tab_name"])
        write_sheet(ws_sub, item["rows"])

    try:
        wb.save(MASTER_EXCEL)
        print(f"\n📊 Master Excel Kaydedildi: {MASTER_EXCEL}")
    except PermissionError:
        wb.save(MASTER_EXCEL_FALLBACK)
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
                "id": f"merkez_{r['sinif']}_{r['sub_code']}_w{r['week_num']}_{item['tab_name'].lower().replace('-', '_')}",
                "gradeLevel": r["sinif"],
                "subjectCode": r["sub_code"],
                "subjectName": r["brans"].replace(f"{r['sinif']}.sinif ", "").title(),
                "publisher": r["publisher"],
                "fullTitle": item["full_title"],
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
 * SınıfCepte Web Admin Paneli - Resmî MEB / Maarif Modeli Tüm 59 Çerçeve Yıllık Plan Kütüphanesi
 */
class CurriculumPresets {{
  static OFFICIAL_DATABASE = {presets_json_str};

  static PRESETS = {{
    'full_maarif_library': {{
      title: '🌟 Tüm Resmî MEB / Maarif Modeli Kütüphanesini Yükle (59 Ders Planı - {len(all_outcomes)} Hafta)',
      description: 'Masaüstünüzdeki tüm derslerin, tüm yayınevlerinin ve Maarif Modeli (TYMM/ÇYDEM) çerçeve planlarının tamamını tek tıkla yükler.',
      isFull: true,
    }},
    'ortaokul_matematik': {{
      title: '📐 Ortaokul Matematik Paketi (5, 6, 7, 8. Sınıf)',
      description: '5-8. Sınıf 36 haftalık resmî MEB ve TYMM Matematik çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'MAT' && [5,6,7,8].includes(o.gradeLevel),
    }},
    'ilkokul_matematik': {{
      title: '🔢 İlkokul Matematik Paketi (1, 2, 3, 4. Sınıf)',
      description: '1-4. Sınıf 36 haftalık resmî MEB ve TYMM İlkokul Matematik planları.',
      filter: (o) => o.subjectCode === 'MAT' && [1,2,3,4].includes(o.gradeLevel),
    }},
    'ortaokul_fen': {{
      title: '🔬 Fen Bilimleri Paketi (3, 4, 5, 6, 7, 8. Sınıf)',
      description: '3-8. Sınıf resmî MEB ve TYMM Fen Bilimleri planları.',
      filter: (o) => o.subjectCode === 'FEN',
    }},
    'turkce_full': {{
      title: '📚 Türkçe Paketi (1-8. Sınıf Tüm Yayınlar: MEB, Özgün, Hecce, İlke, Ada, TYMM)',
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
  }};

  static getPresetList() {{
    return Object.keys(this.PRESETS).map(key => ({{
      id: key,
      ...this.PRESETS[key]
    }}));
  }}

  static getPresetItems(presetId) {{
    const preset = this.PRESETS[presetId];
    if (!preset) return [];
    if (preset.isFull) return this.OFFICIAL_DATABASE;
    return this.OFFICIAL_DATABASE.filter(preset.filter);
  }}
}}

if (typeof window !== 'undefined') {{
  window.CurriculumPresets = CurriculumPresets;
}}
"""
    with open(PRESETS_JS, "w", encoding="utf-8") as f:
        f.write(js_content)
    print("✅ JSON ve Presets Başarıyla Güncellendi!")

if __name__ == "__main__":
    main()
