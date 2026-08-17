import os
import sys
import openpyxl

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

print("Target dir found:", target_dir)

for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith(".xlsx") and not f.startswith("~$"):
            path = os.path.join(root, f)
            try:
                wb = openpyxl.load_workbook(path, data_only=True)
                for s in wb.sheetnames:
                    if s.lower() == "sayfa1":
                        continue
                    sheet = wb[s]
                    print(f"\n=======================================================")
                    print(f"FILE: {f} | SHEET: {s} | (rows={sheet.max_row}, cols={sheet.max_column})")
                    
                    # Print first 12 non-empty rows with all columns
                    for r in range(1, min(14, sheet.max_row + 1)):
                        row_items = []
                        for c_idx, cell in enumerate(sheet[r], start=1):
                            if cell.value is not None and str(cell.value).strip():
                                clean_v = str(cell.value).replace('\n', ' ').strip()
                                row_items.append(f"Col{c_idx}: [{clean_v[:50]}]")
                        if row_items:
                            print(f"  R{r:02d}: " + " | ".join(row_items))
            except Exception as e:
                print(f"  Error on {f}: {e}")
