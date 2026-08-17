import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

def clean_cell(val):
    if val is None: return ""
    v = str(val).replace('\n', ' ').strip()
    return re.sub(r"\s+", " ", v)

for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith(".xlsx") and not f.startswith("~$"):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            if 'ÇYDEM 6' in wb.sheetnames:
                sheet = wb['ÇYDEM 6']
                
                # Check header detection
                header_row_idx = -1
                col_roles = {}
                for r in range(1, min(10, sheet.max_row + 1)):
                    row_vals = [clean_cell(sheet.cell(r, c).value) for c in range(1, sheet.max_column + 1)]
                    u_line = " ".join(row_vals).upper()
                    if "HAFTA" in u_line or "WEEK" in u_line or "SÜRE" in u_line or "DURATION" in u_line or "ZEIT" in u_line:
                        header_row_idx = r
                        for c_idx, val in enumerate(row_vals, start=1):
                            u_val = val.upper()
                            if "HAFTA" in u_val or "WEEK" in u_val or "SÜRE" in u_val or "DURATION" in u_val or "ZEIT" in u_val:
                                if "week" not in col_roles.values():
                                    col_roles[c_idx] = "week"
                            elif "ÜNİTE" in u_val or "TEMA" in u_val or "THEME" in u_val or "ÖĞRENME ALANI" in u_val or "ALAN" in u_val:
                                if "unit" not in col_roles.values():
                                    col_roles[c_idx] = "unit"
                            elif "KONU" in u_val or "CONTENT" in u_val or "İÇERİK" in u_val or "METİN" in u_val or "ALT ÖĞRENME" in u_val:
                                col_roles[c_idx] = "topic"
                            elif "KAZANIM" in u_val or "OUTCOME" in u_val or "ÇIKTI" in u_val or "LERNZIELE" in u_val or "OKUMA" in u_val or "YAZMA" in u_val or "KONUŞMA" in u_val or "DİNLEME" in u_val:
                                col_roles[c_idx] = "outcome"
                        break
                
                print(f"Header Row: {header_row_idx}, Roles: {col_roles}")
                
                current_week = 0
                for r in range(header_row_idx + 1, 20):
                    row_vals = [clean_cell(sheet.cell(r, c).value) for c in range(1, sheet.max_column + 1)]
                    found_week = None
                    for c_idx, val in enumerate(row_vals, start=1):
                        if not val: continue
                        m = re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", val, re.I)
                        if m:
                            found_week = int(m.group(1))
                            break
                        if col_roles.get(c_idx) == "week":
                            m_dig = re.search(r"\b([1-9]|[123]\d)\b", val)
                            if m_dig:
                                found_week = int(m_dig.group(1))
                                break
                    
                    if found_week is not None:
                        current_week = found_week
                    
                    print(f"Row {r:02d}: found_week={found_week}, current_week={current_week}, C2={row_vals[1] if len(row_vals)>1 else ''}, C4={row_vals[3] if len(row_vals)>3 else ''}, C6={row_vals[5] if len(row_vals)>5 else ''}")
                break
