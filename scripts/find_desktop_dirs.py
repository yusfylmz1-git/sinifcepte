import os

desktop = r"C:\Users\Okul\Desktop"
for item in os.listdir(desktop):
    full = os.path.join(desktop, item)
    if os.path.isdir(full):
        print("DIR on Desktop:", repr(item), "-> files:", len(os.listdir(full)))
