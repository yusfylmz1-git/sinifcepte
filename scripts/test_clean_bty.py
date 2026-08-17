import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

def extract_clean_plan(wb, sheetname, f_name):
    ws = wb[sheetname]
    
    # 1. Sütun indekslerini tespit et
    week_col = None
    unit_col = None
    topic_col = None
    outcome_col = None
    header_row = 1
    
    for r in range(1, min(6, ws.max_row + 1)):
        row_vals = [str(ws.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, ws.max_column + 1)]
        for c, val in enumerate(row_vals, 1):
            u = val.upper().strip()
            if u in ["HAFTA", "WEEK", "WOCHE"] or u.startswith("HAFTA (") or u.startswith("WEEK ("):
                week_col = c
                header_row = r
            elif u in ["ÜNİTE / TEMA", "ÜNİTE/TEMA", "ÜNİTE", "THEME", "TEMA", "ÖĞRENME ALANI"]:
                unit_col = c
            elif u in ["KONU (İÇERİK ÇERÇEVESİ)", "KONU", "CONTENT", "İÇERİK", "METİN", "SUB-THEME"]:
                topic_col = c
            elif "ÖĞRENME ÇIKTI" in u or "KAZANIM" in u or "OUTCOME" in u or "LERNZIELE" in u:
                outcome_col = c
                
        if week_col and outcome_col:
            break
            
    print(f"\nSheet '{sheetname}': HeaderRow={header_row}, WeekCol={week_col}, UnitCol={unit_col}, TopicCol={topic_col}, OutcomeCol={outcome_col}")
    
    # 2. Satırları oku
    rows = []
    last_unit = ""
    last_topic = ""
    last_w = 1
    
    for r in range(header_row + 1, ws.max_row + 1):
        row_vals = [str(ws.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, ws.max_column + 1)]
        if not any(row_vals): continue
        u_line = " ".join(row_vals).upper()
        if "ÖLÇME VE DEĞERLENDİRME" in u_line or "BEWERTUNG" in u_line or "ASSESSMENT" in u_line: continue
        
        # Hafta
        raw_w = row_vals[week_col-1] if week_col and week_col <= len(row_vals) else ""
        m_w = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})", raw_w, re.I) or re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", raw_w, re.I)
        w_list = [int(m_w.group(1))] if m_w else ([int(raw_w)] if raw_w.isdigit() and 1 <= int(raw_w) <= 36 else [])
        
        if w_list:
            last_w = w_list[0]
            
        # Ünite & Konu
        raw_u = row_vals[unit_col-1] if unit_col and unit_col <= len(row_vals) else ""
        raw_t = row_vals[topic_col-1] if topic_col and topic_col <= len(row_vals) else ""
        if raw_u and len(raw_u) > 1 and not any(k in raw_u.upper() for k in ["ÜNİTE", "THEME", "TEMA"]): 
            last_unit = raw_u
        if raw_t and len(raw_t) > 1 and not any(k in raw_t.upper() for k in ["KONU", "CONTENT", "İÇERİK"]): 
            last_topic = raw_t
        
        # Öncelik: Konu (İçerik Çerçevesi) varsa onu al, yoksa Ünite
        chosen_unit = last_topic if last_topic else last_unit
        
        # Kazanım
        raw_o = row_vals[outcome_col-1] if outcome_col and outcome_col <= len(row_vals) else ""
        
        if raw_o and len(raw_o) > 5 and not "ÖĞRENME ÇIKTI" in raw_o.upper() and not "KAZANIM" in raw_o.upper():
            rows.append({
                "week": last_w,
                "unit": chosen_unit,
                "outcome": raw_o
            })
            
    print(f"Parsed {len(rows)} data rows.")
    for idx, row in enumerate(rows[:10], 1):
        print(f"  {idx:02d}. Hafta {row['week']}: Ünite: '{row['unit']}'\n      Kazanım: '{row['outcome']}'")

# Test on 5. Sınıf and 6. Sınıf Bilişim
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if "BİLİŞİM" in f.upper() or "BTY" in f.upper():
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() != "sayfa1" and wb[s].max_row > 1:
                    extract_clean_plan(wb, s, f)
