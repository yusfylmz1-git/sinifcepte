import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

def extract_week_num(val):
    if not val: return None
    s = str(val).strip()
    # 1. 'Week 1', 'Week 12', 'Hafta 1'
    m1 = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})", s, re.I)
    if m1: return int(m1.group(1))
    # 2. '1. Hafta', '1.Woche', '1.Week'
    m2 = re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m2: return int(m2.group(1))
    # 3. Direct number
    if s.isdigit() and 1 <= int(s) <= 36:
        return int(s)
    return None

print("TESTING ALL 59 SHEETS WEEK & CONTENT DETECTION:\n")

total_valid_weeks = 0
total_sheets_checked = 0

for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith(".xlsx") and not f.startswith("~$"):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                total_sheets_checked += 1
                sheet = wb[s]
                weeks_found = set()
                
                for r in range(1, sheet.max_row + 1):
                    for c in range(1, min(6, sheet.max_column + 1)):
                        w = extract_week_num(sheet.cell(r, c).value)
                        if w and 1 <= w <= 36:
                            weeks_found.add(w)
                
                print(f"{total_sheets_checked:02d}. Sheet: {s:<30} (Dosya: {f[:25]}) -> {len(weeks_found)} / 36 Hafta Tespit Edildi")
