import os, sys, openpyxl, re

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

desktop = r"C:\Users\Okul\Desktop"
target_dir = None
for d in os.listdir(desktop):
    if "Kazan" in d or "kazan" in d.lower():
        target_dir = os.path.join(desktop, d)
        break

def normalize_tr(s):
    if not s: return ""
    s = str(s)
    for k, v in {'İ':'i','I':'ı','Ğ':'ğ','Ü':'ü','Ş':'ş','Ö':'ö','Ç':'ç'}.items():
        s = s.replace(k, v)
    return s.lower().strip()

def parse_grade(sheetname, filename):
    sn = normalize_tr(sheetname)
    fn = normalize_tr(filename)
    m = re.search(r"(\d+)\s*\.?\s*s[ıi]n[ıi]f", sn) or re.search(r"(?:turkce|türkçe|fen|tymm|cydem|çydem|bty|klasse|müzik|muzik)[^\d]*(\d+)", sn) or re.search(r"\b([1-9]|1[0-2])\b", sn)
    if m: return int(m.group(1))
    m2 = re.search(r"(\d+)\s*\.?\s*s[ıi]n[ıi]f", fn) or re.search(r"\b([1-9]|1[0-2])\b", fn)
    if m2: return int(m2.group(1))
    return 5

def detect_subject_and_publisher(filename, sheetname):
    comb = normalize_tr(filename + " " + sheetname)
    grade = parse_grade(sheetname, filename)
    
    publisher = "MEB Yayınları"
    
    if "matematik" in comb:
        sub_code = "MAT"
        sub_name = "Matematik"
        if "tymm" in comb or "maarif" in comb or grade in (1, 5): publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "fen" in comb:
        sub_code = "FEN"
        sub_name = "Fen Bilimleri"
        if "tymm" in comb or "maarif" in comb or (grade in (5, 6) and "tymm" in comb): publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "turkce" in comb or "türkçe" in comb or "turkçe" in comb:
        sub_code = "TURKCE"
        sub_name = "Türkçe"
        if "özgün" in comb or "ozgun" in comb: publisher = "Özgün Yayınları"
        elif "hecce" in comb: publisher = "Hecce Yayıncılık"
        elif "ilke" in comb: publisher = "İlke Yayınları"
        elif "ada" in comb: publisher = "Ada Yayıncılık"
        elif "tymm" in comb or "maarif" in comb: publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "inkılap" in comb or "inkilap" in comb or "inkılâp" in comb:
        grade = 8
        sub_code = "INKILAP"
        sub_name = "T.C. İnkılap Tarihi ve Atatürkçülük"
        publisher = "MEB Yayınları"
    elif "sosyal" in comb:
        sub_code = "SOSYAL"
        sub_name = "Sosyal Bilgiler"
        if "tymm" in comb or "maarif" in comb: publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "hayat" in comb:
        sub_code = "HAYAT"
        sub_name = "Hayat Bilgisi"
        if "tymm" in comb or "maarif" in comb or grade in (1, 2): publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "ingilizce" in comb or "english" in comb or "cydem" in comb or "çydem" in comb:
        sub_code = "INGILIZCE"
        sub_name = "İngilizce"
        if "çydem" in comb or "cydem" in comb: publisher = "ÇYDEM (Maarif)"
        elif "tymm" in comb: publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "bilişim" in comb or "bilisim" in comb or "bty" in comb:
        sub_code = "BILISIM"
        sub_name = "Bilişim Teknolojileri ve Yazılım"
        if "tymm" in comb or "maarif" in comb: publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "din" in comb:
        sub_code = "DIN"
        sub_name = "Din Kültürü ve Ahlak Bilgisi"
        publisher = "MEB Yayınları"
    elif "beden" in comb:
        sub_code = "BEDEN"
        sub_name = "Beden Eğitimi ve Spor"
        if "tymm" in comb or "maarif" in comb or grade in (1, 2): publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "müzik" in comb or "muzik" in comb:
        sub_code = "MUZIK"
        sub_name = "Müzik"
        if "tymm" in comb or "maarif" in comb: publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "görsel" in comb or "gorsel" in comb:
        sub_code = "GORSEL"
        sub_name = "Görsel Sanatlar"
        if "tymm" in comb or "maarif" in comb: publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    elif "almanca" in comb:
        sub_code = "ALMANCA"
        sub_name = "Almanca"
        if "tymm" in comb or "maarif" in comb: publisher = "TYMM (Maarif)"
        else: publisher = "MEB Yayınları"
    else:
        sub_code = "GENEL"
        sub_name = "Genel Ders"
        publisher = "MEB Yayınları"
        
    full_title = f"{grade}. Sınıf - {sub_name} - {publisher}"
    
    # Kısa Sekme Adı (Max 30 Karakter)
    short_pub = publisher.replace(" Yayınları", "").replace(" Yayıncılık", "").replace(" (Maarif)", "-TYMM")
    if short_pub == "ÇYDEM-TYMM": short_pub = "ÇYDEM"
    
    short_sub = sub_name.replace(" ve Yazılım", "").replace(" ve Spor", "").replace(" ve Atatürkçülük", "")
    if short_sub == "Bilişim Teknolojileri": short_sub = "Bilişim"
    if short_sub == "Beden Eğitimi": short_sub = "Beden"
    if short_sub == "Görsel Sanatlar": short_sub = "Görsel"
    if short_sub == "T.C. İnkılap Tarihi": short_sub = "İnkılap"
    if short_sub == "Fen Bilimleri": short_sub = "Fen"
    if short_sub == "Sosyal Bilgiler": short_sub = "Sosyal"
    
    tab_name = f"{grade}-{short_sub}-{short_pub}"[:30]
    return grade, sub_code, sub_name, publisher, full_title, tab_name

print("TESTING DETECTED TITLES & TAB NAMES ACROSS ALL SHEETS:\n")

count = 0
for root, dirs, files in os.walk(target_dir):
    for f in files:
        if f.endswith('.xlsx') and not f.startswith('~$'):
            wb = openpyxl.load_workbook(os.path.join(root, f), data_only=True)
            for s in wb.sheetnames:
                if s.lower() == "sayfa1" or wb[s].max_row <= 1: continue
                count += 1
                g, sc, sn, pub, full_title, tab_name = detect_subject_and_publisher(f, s)
                print(f"{count:02d}. Tab: {tab_name:<24} | Başlık: {full_title}")
