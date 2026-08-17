import openpyxl
import json
import re

wb = openpyxl.load_workbook(r"C:\Users\Okul\Desktop\TÜM_DERSLER_MERKEZ_STANDART.xlsx", data_only=True)
ws = wb['TÜM DERSLER BİRLEŞİK']

def detect_subject_publisher(branch_str, grade_val):
    b = branch_str.lower()
    publisher = 'MEB Yayınları'
    code = 'GENEL'
    name = 'Genel Ders'
    
    if 'bilişim' in b or 'bilisim' in b or 'bty' in b:
        code = 'BILISIM'
        name = 'Bilişim Teknolojileri ve Yazılım'
        publisher = 'TYMM (Maarif Modeli)'
    elif 'matematik' in b or 'mat' in b:
        code = 'MAT'
        name = 'Matematik'
        if grade_val in [1, 5]:
            publisher = 'TYMM (Maarif Modeli)'
    elif 'fen' in b:
        code = 'FEN'
        name = 'Fen Bilimleri'
        if grade_val in [5, 6]:
            publisher = 'TYMM (Maarif Modeli)'
    elif 'türkçe' in b or 'turkce' in b:
        code = 'TURKCE'
        name = 'Türkçe'
        if 'özgün' in b or 'ozgun' in b:
            publisher = 'Özgün Yayınları'
        elif 'hecce' in b:
            publisher = 'Hecce Yayıncılık'
        elif 'ilke' in b:
            publisher = 'İlke Yayınları'
        elif 'ada' in b:
            publisher = 'Ada Yayıncılık'
        elif grade_val in [1, 2]:
            publisher = 'TYMM (Maarif Modeli)'
    elif 'sosyal' in b:
        code = 'SOSYAL'
        name = 'Sosyal Bilgiler'
        if grade_val in [5, 6]:
            publisher = 'TYMM (Maarif Modeli)'
    elif 'inkılap' in b or 'inkilap' in b or 'inkılâp' in b:
        code = 'INKILAP'
        name = 'T.C. İnkılap Tarihi ve Atatürkçülük'
    elif 'hayat' in b:
        code = 'HAYAT'
        name = 'Hayat Bilgisi'
        if grade_val in [1, 2]:
            publisher = 'TYMM (Maarif Modeli)'
    elif 'ingilizce' in b or 'english' in b:
        code = 'INGILIZCE'
        name = 'İngilizce'
        if 'iydem' in b or 'iydem' in b or grade_val in [2, 5, 6, 7]:
            publisher = 'İYDEM (Maarif Modeli)'
    elif 'almanca' in b:
        code = 'ALMANCA'
        name = 'Almanca'
        publisher = 'TYMM (Maarif Modeli)'
    elif 'beden' in b or 'spor' in b:
        code = 'BEDEN'
        name = 'Beden Eğitimi ve Spor'
        if grade_val in [1, 2]:
            publisher = 'TYMM (Maarif Modeli)'
    elif 'görsel' in b or 'gorsel' in b:
        code = 'GORSEL'
        name = 'Görsel Sanatlar'
        if grade_val in [1, 5]:
            publisher = 'TYMM (Maarif Modeli)'
    elif 'müzik' in b or 'muzik' in b:
        code = 'MUZIK'
        name = 'Müzik'
        if grade_val in [5]:
            publisher = 'TYMM (Maarif Modeli)'
            
    return code, name, publisher

outcomes = []
seen_ids = set()

for r in range(2, ws.max_row + 1):
    plan_order = ws.cell(r, 1).value
    ders_tipi = ws.cell(r, 2).value
    brans = ws.cell(r, 3).value
    sinif = ws.cell(r, 4).value
    unite = ws.cell(r, 5).value
    kazanim = ws.cell(r, 6).value
    hafta = ws.cell(r, 7).value
    
    if not brans and not unite:
        continue
        
    try:
        grade_val = int(sinif)
    except:
        grade_val = 5
        
    try:
        order_val = int(plan_order)
    except:
        order_val = r - 1
        
    code, name, publisher = detect_subject_publisher(str(brans), grade_val)
    
    is_holiday = (ders_tipi != 'Ders') or ('TATİL' in str(unite).upper()) or ('TATIL' in str(unite).upper())
    
    # Kazanım Kodu
    kazanim_str = str(kazanim or '').strip()
    if is_holiday:
        outcome_code = 'TATIL'
    else:
        m = re.search(r'([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+(?:\.\d+)?|\b[A-Z]\d\.\d\.\w+\b)', kazanim_str)
        outcome_code = m.group(1) if m else f"{code}.{grade_val}.{hafta or order_val}"
        
    full_title = f"{grade_val}. Sınıf - {name} - {publisher}"
    
    # ID
    pub_slug = publisher.lower().replace(' ', '_').replace('(', '').replace(')', '').replace('ı', 'i').replace('ö', 'o').replace('ü', 'u').replace('ç', 'c').replace('ş', 's').replace('ğ', 'g')
    item_id = f"plan_{grade_val}_{code}_{pub_slug}_w{order_val}"
    
    item = {
        'id': item_id,
        'gradeLevel': grade_val,
        'subjectCode': code,
        'subjectName': name,
        'publisher': publisher,
        'fullTitle': full_title,
        'weekNumber': order_val, # Exact chronological week (1..39)
        'teachingWeekNumber': int(hafta) if hafta and str(hafta).isdigit() else None,
        'unitTitle': str(unite or '').strip(),
        'topicTitle': str(unite or '').strip(),
        'outcomeCode': outcome_code,
        'outcomeDescription': kazanim_str,
        'isHolidayWeek': is_holiday,
        'holidayNote': str(unite).strip() if is_holiday else None,
        'academicYear': '2026-2027'
    }
    
    outcomes.append(item)

print(f"Total processed outcomes: {len(outcomes)}")

# Save JSON
with open('admin_portal/data/official_maarif_kazanimlar.json', 'w', encoding='utf-8') as f:
    json.dump(outcomes, f, ensure_ascii=False, indent=2)

print("official_maarif_kazanimlar.json written successfully!")

# Build compact curriculum_presets.js
rows = []
for d in outcomes:
    rows.append([
        d['id'],
        d['gradeLevel'],
        d['subjectCode'],
        d['subjectName'],
        d['publisher'],
        d['fullTitle'],
        d['weekNumber'],
        d['unitTitle'],
        d['topicTitle'],
        d['outcomeCode'],
        d['outcomeDescription'],
        1 if d['isHolidayWeek'] else 0,
        d.get('holidayNote') or '',
        d.get('academicYear') or '2026-2027'
    ])

js_code = f"""/**
 * SınıfCepte Web Admin Paneli - Resmî MEB / Maarif Modeli Tüm 59 Çerçeve Yıllık Plan Kütüphanesi
 */
class CurriculumPresets {{
  static _RAW_ROWS = {json.dumps(rows, ensure_ascii=False)};
  
  static get OFFICIAL_DATABASE() {{
    if (!this._cachedDb) {{
      this._cachedDb = this._RAW_ROWS.map(r => ({{
        id: r[0],
        gradeLevel: r[1],
        subjectCode: r[2],
        subjectName: r[3],
        publisher: r[4],
        fullTitle: r[5],
        weekNumber: r[6],
        unitTitle: r[7],
        topicTitle: r[8],
        outcomeCode: r[9],
        outcomeDescription: r[10],
        isHolidayWeek: r[11] === 1,
        holidayNote: r[12] || null,
        academicYear: r[13] || '2026-2027'
      }}));
    }}
    return this._cachedDb;
  }}

  static PRESETS = {{
    'full_maarif_library': {{
      title: '🌟 Tüm Resmî MEB Müfredat Kütüphanesi (59 Plan, 2.301 Hafta)',
      description: '1-8. Sınıflar tüm dersler (Bilişim, Fen, Matematik, Türkçe, İngilizce, Sosyal, vb.).',
      isFull: true,
    }},
    'bilisim_full': {{
      title: '💻 Bilişim Teknolojileri ve Yazılım (5, 6. Sınıf)',
      description: '5 ve 6. Sınıf TYMM Bilişim Teknolojileri ve Yazılım çerçeve planları.',
      filter: (o) => o.subjectCode === 'BILISIM',
    }},
    'bilisim_teknolojileri': {{
      title: '💻 Bilişim Teknolojileri ve Yazılım (5, 6. Sınıf)',
      description: '5 ve 6. Sınıf TYMM Bilişim Teknolojileri ve Yazılım çerçeve planları.',
      filter: (o) => o.subjectCode === 'BILISIM',
    }},
    'ortaokul_matematik': {{
      title: '📐 Ortaokul Matematik Paketi (5, 6, 7, 8. Sınıf)',
      description: '5, 6, 7, 8. Sınıf resmî MEB Matematik çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'MAT' && o.gradeLevel >= 5,
    }},
    'ilkokul_matematik': {{
      title: '🔢 İlkokul Matematik Paketi (1, 2, 3, 4. Sınıf)',
      description: '1, 2, 3, 4. Sınıf resmî MEB Matematik çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'MAT' && o.gradeLevel <= 4,
    }},
    'ortaokul_fen': {{
      title: '🔬 Fen Bilimleri Paketi (3, 4, 5, 6, 7, 8. Sınıf)',
      description: '3, 4, 5, 6, 7, 8. Sınıf resmî MEB ve TYMM Fen Bilimleri yıllık planları.',
      filter: (o) => o.subjectCode === 'FEN',
    }},
    'turkce_full': {{
      title: '📚 Türkçe Paketi (1, 2, 3, 4, 5, 6, 7, 8. Sınıf)',
      description: '1-8. Sınıflar tüm resmî MEB ve yayınevi Türkçe yıllık planları.',
      filter: (o) => o.subjectCode === 'TURKCE',
    }},
    'sosyal_inkilap': {{
      title: '🌍 Sosyal Bilgiler & T.C. İnkılap Tarihi (4, 5, 6, 7, 8. Sınıf)',
      description: '4-7. Sınıf Sosyal Bilgiler ve 8. Sınıf İnkılap Tarihi resmî planları.',
      filter: (o) => ['SOSYAL', 'INKILAP'].includes(o.subjectCode),
    }},
    'ingilizce_full': {{
      title: '🇬🇧 İngilizce & Almanca (2-8. Sınıf MEB, TYMM ve İYDEM)',
      description: '2-8. Sınıf MEB, İYDEM, TYMM ve ÇYDEM Yabancı Dil çerçeve planları.',
      filter: (o) => ['INGILIZCE', 'ALMANCA'].includes(o.subjectCode),
    }},
    'hayat_bilgisi': {{
      title: '🌱 Hayat Bilgisi Paketi (1, 2, 3. Sınıf)',
      description: '1, 2, 3. Sınıf resmî Hayat Bilgisi çerçeve yıllık planları.',
      filter: (o) => o.subjectCode === 'HAYAT',
    }},
    'beden_muzik_gorsel': {{
      title: '🎨 Sanat & Beden Eğitimi (Beden, Müzik, Görsel)',
      description: '1, 2, 5, 6. Sınıf Beden Eğitimi, Müzik ve Görsel Sanatlar planları.',
      filter: (o) => ['BEDEN', 'MUZIK', 'GORSEL'].includes(o.subjectCode),
    }},
  }};

  static getPresetList() {{
    return Object.keys(this.PRESETS).map(key => ({{
      id: key,
      ...this.PRESETS[key]
    }}));
  }}

  static getPresetItems(presetId) {{
    const preset = this.PRESETS[presetId];
    if (!preset) return [];
    if (preset.isFull) return this.OFFICIAL_DATABASE;
    return this.OFFICIAL_DATABASE.filter(preset.filter);
  }}

  static applyPreset(presetKey, outcomesManager) {{
    const items = this.getPresetItems(presetKey);
    if (!items || items.length === 0) return 0;

    if (presetKey === 'full_maarif_library') {{
      outcomesManager.outcomes = [...items];
    }} else {{
      const keys = new Set(items.map(i => `${{i.gradeLevel}}_${{i.subjectCode}}_${{i.publisher}}`));
      outcomesManager.outcomes = outcomesManager.outcomes.filter(o => !keys.has(`${{o.gradeLevel}}_${{o.subjectCode}}_${{o.publisher}}`));
      outcomesManager.outcomes.push(...items);
    }}
    outcomesManager.save();
    return items.length;
  }}
}}

if (typeof window !== 'undefined') {{
  window.CurriculumPresets = CurriculumPresets;
}}
"""

with open('admin_portal/js/curriculum_presets.js', 'w', encoding='utf-8') as f:
    f.write(js_code)

print("curriculum_presets.js rebuilt successfully!")
