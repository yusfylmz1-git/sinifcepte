import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

def normalize_tr(s):
    if not s: return ""
    s = str(s)
    for k, v in {'İ':'i','I':'ı','Ğ':'ğ','Ü':'ü','Ş':'ş','Ö':'ö','Ç':'ç'}.items():
        s = s.replace(k, v)
    return s.lower().strip()

def extract_week_num(s):
    if not s: return None
    s = str(s).strip()
    m_range = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})\s*[-–/]\s*(\d{1,2})", s, re.I) or \
              re.search(r"(\d{1,2})\s*[-–/]\s*(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m_range:
        w1, w2 = int(m_range.group(1)), int(m_range.group(2))
        return list(range(w1, w2 + 1))
    m = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})", s, re.I) or re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m: return [int(m.group(1))]
    if s.isdigit() and 1 <= int(s) <= 36: return [int(s)]
    return None

def find_sheet_columns(sheet):
    """
    Returns: week_col, unit_col, topic_col, outcome_col, header_row
    """
    for r in range(1, min(8, sheet.max_row + 1)):
        row_vals = [str(sheet.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, sheet.max_column + 1)]
        u_line = " ".join(row_vals).upper()
        if "HAFTA" in u_line or "WEEK" in u_line or "SÜRE" in u_line or "DURATION" in u_line or "ZEIT" in u_line:
            week_col = None
            unit_col = None
            topic_col = None
            outcome_col = None
            
            for c, val in enumerate(row_vals, 1):
                u = val.upper()
                if not week_col and ("HAFTA" in u or "WEEK" in u or "SÜRE" in u or "WOCHE" in u):
                    week_col = c
                elif not unit_col and ("ÜNİTE" in u or "THEME" in u or "TEMA" in u or "ÖĞRENME ALANI" in u or "ALAN" in u):
                    unit_col = c
                elif not topic_col and ("KONU" in u or "CONTENT" in u or "İÇERİK" in u or "METİN" in u or "ALT ÖĞRENME" in u or "SUB-THEME" in u):
                    topic_col = c
                elif not outcome_col and ("KAZANIM" in u or "OUTCOME" in u or "ÇIKTI" in u or "LERNZIELE" in u):
                    outcome_col = c
                    
            return week_col, unit_col, topic_col, outcome_col, r
    return None, None, None, None, 1

print("CHECKING EXACT COLUMN MAPPINGS ON ALL SHEETS:\n")

count = 0
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.xlsx') and not f.startswith('~$'):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                count += 1
                w_col, u_col, t_col, o_col, hr = find_sheet_columns(wb[s])
                
                # Check sample row 1
                ws = wb[s]
                sample_u = ""
                sample_o = ""
                for dr in range(hr + 1, min(hr + 6, ws.max_row + 1)):
                    row_v = [str(ws.cell(dr, c).value or '').replace('\n', ' ').strip() for c in range(1, ws.max_column + 1)]
                    if any(row_v) and not "ÖLÇME" in " ".join(row_v).upper() and not "DEĞERLENDİRME" in " ".join(row_v).upper():
                        if u_col: sample_u = row_v[u_col-1]
                        if not sample_u and t_col: sample_u = row_v[t_col-1]
                        if o_col: sample_o = row_v[o_col-1]
                        break
                print(f"{count:02d}. [{s[:20]:<20}] W:{w_col} U:{u_col} T:{t_col} O:{o_col} | Ünite: {sample_u[:25]:<25} | Kaz: {sample_o[:35]}")
