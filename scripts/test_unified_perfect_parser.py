import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

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

def clean_outcome_text(s):
    if not s: return ""
    s = str(s).replace('\r', ' ').strip()
    s = re.sub(r"\n+", " ", s)
    s = re.sub(r"\s+", " ", s)
    return s

def parse_sheet_perfect(sheet, filename, sheetname):
    # 1. Başlık ve Sütunları Bul
    week_col = None
    unit_col = None
    topic_col = None
    outcome_cols = []
    header_row = 1
    
    for r in range(1, min(6, sheet.max_row + 1)):
        row_vals = [str(sheet.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, sheet.max_column + 1)]
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
        row_vals = [str(sheet.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, sheet.max_column + 1)]
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
                val = clean_outcome_text(row_vals[oc-1])
                if val and len(val) > 4 and not any(k == val.upper() for k in ["KAZANIM", "KAZANIMLAR", "ÖĞRENME ÇIKTILARI", "LEARNING OUTCOMES", "DİNLEME/İZLEME", "KONUŞMA", "OKUMA", "YAZMA"]):
                    row_outcomes.append(val)
                    
        for w in current_weeks:
            if 1 <= w <= 36:
                week_map[w]["unit"] = chosen_unit
                for ro in row_outcomes:
                    if ro not in week_map[w]["outcomes"]:
                        week_map[w]["outcomes"].append(ro)

    # 36 Haftayı doldur (Boş kalan haftalara önceki ünite ve anlamlı kazanım ekle)
    last_known_unit = "1. Ünite"
    last_known_outcome = "MEB müfredat kazanımı ve etkinlikleri."
    
    clean_36_rows = []
    for w in range(1, 37):
        u = week_map[w]["unit"] or last_known_unit
        last_known_unit = u
        
        if week_map[w]["outcomes"]:
            # İlk 2 kazanımı al, gereksiz şişirmeyi engelle
            o = " ".join(week_map[w]["outcomes"][:2])
            last_known_outcome = o
        else:
            if "ORIENTATION" in u.upper() or "UYUM" in u.upper():
                o = "Orientation: Okul ve derse uyum, ders işleniş kuralları ve süreç planlama etkinlikleri."
            elif "REVISION" in u.upper() or "TEKRAR" in u.upper():
                o = f"{u}: Önceki yıl öğrenilen temel konular ve dil yapılarının tekrarı."
            else:
                o = last_known_outcome
                
        clean_36_rows.append({
            "week": w,
            "unit": u,
            "outcome": o
        })
        
    return clean_36_rows

print("VERIFYING PERFECT CLEAN ROWS ACROSS ALL 57 SHEETS:\n")

count = 0
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.xlsx') and not f.startswith('~$'):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                count += 1
                rows_36 = parse_sheet_perfect(wb[s], f, s)
                print(f"{count:02d}. [{s[:20]:<20}]")
                for r in rows_36[:3]:
                    print(f"     Hafta {r['week']:2d} | Ünite: {r['unit'][:28]:<28} | Kaz: {r['outcome'][:60]}")
                print()
