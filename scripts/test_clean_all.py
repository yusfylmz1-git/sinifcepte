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

def clean_sheet_parser(sheet, filename, sheetname):
    # Sütunları bul
    week_col = None
    unit_col = None
    topic_col = None
    outcome_col = None
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
            elif any(k in u for k in ["ÖĞRENME ÇIKTILARI", "KAZANIM", "LEARNING OUTCOME", "LERNZIELE", "LEARNING SKILLS"]):
                if not outcome_col: outcome_col = c
                
        if week_col and outcome_col:
            break
            
    # Fallback: Eğer week_col bulunamadıysa Col 2, outcome_col bulunamadıysa Col 5/6
    if not week_col: week_col = 2
    if not outcome_col: outcome_col = 6 if sheet.max_column >= 6 else (5 if sheet.max_column >= 5 else 4)
    if not unit_col: unit_col = 4 if sheet.max_column >= 4 else 1

    week_map = {w: {"units": [], "topics": [], "outcomes": []} for w in range(1, 37)}
    current_weeks = [1]
    last_unit = ""
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
            
        chosen_unit = last_topic if last_topic else (last_unit if last_unit else "1. Ünite")
        
        # Kazanım
        raw_o = row_vals[outcome_col-1] if outcome_col <= len(row_vals) else ""
        
        if raw_o and len(raw_o) > 3 and not any(k == raw_o.upper() for k in ["KAZANIM", "KAZANIMLAR", "ÖĞRENME ÇIKTILARI", "LEARNING OUTCOMES"]):
            for w in current_weeks:
                if 1 <= w <= 36:
                    if chosen_unit not in week_map[w]["units"]:
                        week_map[w]["units"].append(chosen_unit)
                    if raw_o not in week_map[w]["outcomes"]:
                        week_map[w]["outcomes"].append(raw_o)

    return week_map

print("TESTING CLEAN PARSER ON ALL 57 SHEETS:\n")

count = 0
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.xlsx') and not f.startswith('~$'):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                count += 1
                w_map = clean_sheet_parser(wb[s], f, s)
                filled = sum(1 for w in range(1, 37) if len(w_map[w]["outcomes"]) > 0)
                sample_u = w_map[1]["units"][0] if w_map[1]["units"] else "---"
                sample_o = w_map[1]["outcomes"][0] if w_map[1]["outcomes"] else "---"
                print(f"{count:02d}. [{s[:18]:<18}] ({filled}/36 Hafta Dolu) | Ünite: {sample_u[:24]:<24} | Kaz: {sample_o[:45]}")
