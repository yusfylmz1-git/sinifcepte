import os, sys, openpyxl, re
sys.path.append(r"C:\Users\Okul\Desktop\Projelerim\sinifcepte")
from scripts.smart_column_aware_parser import parse_sheet_smart


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
                res = parse_sheet_smart(wb['ÇYDEM 6'], f, 'ÇYDEM 6')
                print("PARSED RESULT FOR ÇYDEM 6:")
                for r in res['rows'][:20]:
                    print(r)
                break
