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
    
    # 1. Range: '1-2. Hafta', '1 - 2. HAFTA', 'Week 1-2', '1./2. Woche'
    m_range = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})\s*[-–/]\s*(\d{1,2})", s, re.I) or \
              re.search(r"(\d{1,2})\s*[-–/]\s*(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m_range:
        w1, w2 = int(m_range.group(1)), int(m_range.group(2))
        if 1 <= w1 <= 36 and 1 <= w2 <= 36 and w1 <= w2:
            return list(range(w1, w2 + 1))
            
    # 2. 'Week 1', 'Week 12', 'Hafta 1'
    m1 = re.search(r"(?:Hafta|Woche|Week)\s*(\d{1,2})", s, re.I)
    if m1: return [int(m1.group(1))]
    
    # 3. '1. Hafta', '1.Woche', '1.Week'
    m2 = re.search(r"(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)", s, re.I)
    if m2: return [int(m2.group(1))]
    
    # 4. Direct number in week column
    if s.isdigit() and 1 <= int(s) <= 36:
        return [int(s)]
        
    return []

print("TESTING RANGE-AWARE DETECTION ON ALL 59 SHEETS:\n")

total_sheets = 0
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith(".xlsx") and not f.startswith("~$"):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                total_sheets += 1
                sheet = wb[s]
                weeks_found = set()
                
                for r in range(1, sheet.max_row + 1):
                    for c in range(1, min(6, sheet.max_column + 1)):
                        w_list = extract_week_range(sheet.cell(r, c).value)
                        for w in w_list:
                            if 1 <= w <= 36:
                                weeks_found.add(w)
                
                print(f"{total_sheets:02d}. Sheet: {s:<32} -> {len(weeks_found)} / 36 Hafta")
