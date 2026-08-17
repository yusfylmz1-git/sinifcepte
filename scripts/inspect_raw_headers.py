import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

print("INSPECTING RAW FILES COLUMN HEADERS:\n")

for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.xlsx') and not f.startswith('~$'):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                ws = wb[s]
                # Find header row
                for r in range(1, min(6, ws.max_row + 1)):
                    row_vals = [str(ws.cell(r, c).value or '').replace('\n', ' ').strip() for c in range(1, ws.max_column + 1)]
                    u_line = " ".join(row_vals).upper()
                    if "HAFTA" in u_line or "WEEK" in u_line or "SÜRE" in u_line:
                        # Print header row columns
                        cols = [f"Col{c}: {v}" for c, v in enumerate(row_vals, 1) if v]
                        print(f"[{f[:25]} | {s[:15]}] (Row {r}):")
                        print("   " + " | ".join(cols[:6]))
                        # Print first data row
                        for dr in range(r + 1, min(r + 4, ws.max_row + 1)):
                            d_vals = [str(ws.cell(dr, c).value or '').replace('\n', ' ').strip() for c in range(1, ws.max_column + 1)]
                            if any(d_vals) and not "ÖLÇME" in " ".join(d_vals).upper():
                                print(f"   Data (Row {dr}): " + " || ".join([f"C{c}: {v[:30]}" for c, v in enumerate(d_vals, 1) if v][:5]))
                                break
                        print()
                        break
