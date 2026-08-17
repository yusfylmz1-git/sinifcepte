import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

print("Files in target_dir:", os.listdir(target_dir))
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith(".xlsx") and not f.startswith("~$"):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            if 'ÇYDEM 7' in wb.sheetnames:
                sheet = wb['ÇYDEM 7']
                print(f"\nDEBUG {f} -> ÇYDEM 7:")
                for r in range(1, 15):
                    vals = [str(sheet.cell(r, c).value or '').replace('\n', ' ') for c in range(1, sheet.max_column + 1)]
                    print(f"Row {r:02d}:", vals[:8])



