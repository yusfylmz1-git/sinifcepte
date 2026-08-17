import os, sys, openpyxl

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith(".xlsx") and not f.startswith("~$"):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            if 'ÇYDEM 6' in wb.sheetnames:
                sheet = wb['ÇYDEM 6']
                print(f"=== FULL INSPECTION OF ÇYDEM 6 ({sheet.max_row} rows, {sheet.max_column} cols) ===")
                for r in range(1, sheet.max_row + 1):
                    non_empty = []
                    for c in range(1, sheet.max_column + 1):
                        val = sheet.cell(r, c).value
                        if val is not None and str(val).strip():
                            clean_v = str(val).replace('\n', ' ').strip()
                            non_empty.append(f"C{c}: [{clean_v[:40]}]")
                    if non_empty:
                        print(f"Row {r:02d}: " + " | ".join(non_empty))
                break
