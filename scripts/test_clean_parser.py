import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

def extract_week_range(val):
    if not val: return []
    s = str(val).strip()
    m_range = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})\s*[-–/]\s*(\d{1,2})", s, re.I) or \
              re.search(r"(\d{1,2})\s*[-–/]\s*(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m_range:
        w1, w2 = int(m_range.group(1)), int(m_range.group(2))
        if 1 <= w1 <= 36 and 1 <= w2 <= 36 and w1 <= w2:
            return list(range(w1, w2 + 1))
    m1 = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})", s, re.I)
    if m1: return [int(m1.group(1))]
    m2 = re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m2: return [int(m2.group(1))]
    if s.isdigit() and 1 <= int(s) <= 36: return [int(s)]
    return []

def is_header_only_row(row_vals):
    u_line = " ".join(row_vals).upper()
    # Eğer satırda hafta numarası varsa kesinlikle başlık satırı değildir!
    for val in row_vals:
        if extract_week_range(val):
            return False
    if "ÖĞRENME ÇIKTILARI VE SÜREÇ" in u_line or "LEARNING OUTCOMES AND PROCESS" in u_line or "LERNZIELE UND PROZESS" in u_line:
        return True
    if "ÖLÇME VE DEĞERLENDİRME" in u_line or "ASSESSMENT AND EVALUATION" in u_line or "BEWERTUNG UND BEURTEILUNG" in u_line:
        return True
    return False

print("TESTING FIXED HEADER FILTER ON ALL 59 SHEETS:\n")

total_sheets = 0
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith(".xlsx") and not f.startswith("~$"):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                total_sheets += 1
                sheet = wb[s]
                
                week_outcomes = {w: [] for w in range(1, 37)}
                cur_weeks = [1]
                
                for r in range(1, sheet.max_row + 1):
                    row_vals = [str(sheet.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, sheet.max_column + 1)]
                    if not any(row_vals): continue
                    if is_header_only_row(row_vals): continue
                    
                    found_w = []
                    for val in row_vals[:5]:
                        w_list = extract_week_range(val)
                        if w_list:
                            found_w = w_list
                            break
                    if found_w:
                        cur_weeks = found_w
                        
                    for val in row_vals:
                        if len(val) > 15:
                            for w in cur_weeks:
                                if 1 <= w <= 36 and val not in week_outcomes[w]:
                                    week_outcomes[w].append(val)
                
                non_empty = sum(1 for w in range(1, 37) if len(week_outcomes[w]) > 0)
                print(f"{total_sheets:02d}. Sheet: {s:<30} -> {non_empty} / 36 Hafta Dolu (W1: {week_outcomes[1][0][:40] if week_outcomes[1] else 'BOS!'})")
