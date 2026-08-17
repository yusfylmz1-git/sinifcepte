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

def parse_english_sheet(sheet):
    week_col = 2
    unit_col = 4
    func_col = 5
    outcome_col = 6
    
    last_unit = "1 Friendship"
    last_outcome = ""
    last_func = ""
    
    week_map = {}
    
    for r in range(3, sheet.max_row + 1):
        row_vals = [str(sheet.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, sheet.max_column + 1)]
        if not any(row_vals): continue
        
        w_list = extract_week_nums(row_vals[1] if len(row_vals) > 1 else "")
        if not w_list: continue
        
        raw_u = row_vals[3] if len(row_vals) > 3 else ""
        raw_f = row_vals[4] if len(row_vals) > 4 else ""
        raw_o = row_vals[5] if len(row_vals) > 5 else ""
        
        if raw_u and len(raw_u) > 1: last_unit = raw_u
        if raw_f and len(raw_f) > 3: last_func = raw_f
        if raw_o and len(raw_o) > 5: last_outcome = raw_o
        
        # Outcome metni: Eğer outcome varsa onu al, yoksa functions al
        eff_outcome = last_outcome if last_outcome else last_func
        
        for w in w_list:
            if 1 <= w <= 36 and w not in week_map:
                week_map[w] = {
                    "unit": last_unit,
                    "outcome": eff_outcome
                }
                
    for w in range(1, 37):
        item = week_map.get(w, {"unit": last_unit, "outcome": last_outcome})
        print(f"Hafta {w:2d} | Ünite: {item['unit'][:25]:<25} | Kaz: {item['outcome'][:60]}")

for root, dirs, files in os.walk(target_dir):
    for f in files:
        if '8' in f and 'İNGİLİZCE' in f.upper():
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if '8' in s:
                    print(f"=== {f} | {s} ===")
                    parse_english_sheet(wb[s])
