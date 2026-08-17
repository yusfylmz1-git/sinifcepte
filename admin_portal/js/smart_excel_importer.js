/**
 * SınıfCepte Web Admin Paneli - Akıllı Excel & Yıllık Plan İçe Aktarıcısı (Client-Side Parser)
 * MEB Ham Excel planlarını, MERKEZ_BOT standart tablolarını ve TÜM DERSLER BİRLEŞİK master sayfalarını tarayıcıda otomatik çözümler.
 */
class SmartExcelImporter {
  static normalizeTr(s) {
    if (!s) return '';
    s = String(s);
    const map = { 'İ': 'i', 'I': 'ı', 'Ğ': 'ğ', 'Ü': 'ü', 'Ş': 'ş', 'Ö': 'ö', 'Ç': 'ç' };
    for (const [k, v] of Object.entries(map)) {
      s = s.replaceAll(k, v);
    }
    return s.toLowerCase().trim();
  }

  static cleanCell(val) {
    if (val === null || val === undefined) return '';
    const v = String(val).replace(/\r/g, ' ').replace(/\n/g, ' ').trim();
    return v.replace(/\s+/g, ' ');
  }

  static parseGrade(sheetname, filename) {
    const sn = this.normalizeTr(sheetname);
    const fn = this.normalizeTr(filename);
    const m = sn.match(/(\d+)\s*\.?\s*s[ıi]n[ıi]f/) || sn.match(/(?:turkce|türkçe|fen|tymm|cydem|çydem|bty|bilişim|bilisim|klasse|müzik|muzik|beden|görsel|gorsel)[^\d]*(\d+)/) || sn.match(/\b([1-9]|1[0-2])\b/);
    if (m) return parseInt(m[1]);
    const m2 = fn.match(/(\d+)\s*\.?\s*s[ıi]n[ıi]f/) || fn.match(/\b([1-9]|1[0-2])\b/);
    if (m2) return parseInt(m2[1]);
    return 5;
  }

  static detectSubjectAndPublisher(filename, sheetname) {
    const comb = this.normalizeTr(filename + ' ' + sheetname);
    let grade = this.parseGrade(sheetname, filename);
    let publisher = 'MEB Yayınları';
    let subCode = 'GENEL';
    let subName = 'Genel Ders';

    if (comb.includes('bilişim') || comb.includes('bilisim') || comb.includes('bty') || comb.includes('yazılım') || comb.includes('yazilim')) {
      subCode = 'BILISIM';
      subName = 'Bilişim Teknolojileri ve Yazılım';
      if (comb.includes('tymm') || comb.includes('maarif') || [5, 6].includes(grade)) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('matematik') || comb.includes('mat')) {
      subCode = 'MAT';
      subName = 'Matematik';
      if (comb.includes('tymm') || comb.includes('maarif') || [1, 5].includes(grade)) {
        publisher = 'TYMM (Maarif Modeli)';
      }
    } else if (comb.includes('fen')) {
      subCode = 'FEN';
      subName = 'Fen Bilimleri';
      if (comb.includes('tymm') || comb.includes('maarif') || ([5, 6].includes(grade) && comb.includes('tymm'))) {
        publisher = 'TYMM (Maarif Modeli)';
      }
    } else if (comb.includes('turkce') || comb.includes('türkçe')) {
      subCode = 'TURKCE';
      subName = 'Türkçe';
      if (comb.includes('özgün') || comb.includes('ozgun')) publisher = 'Özgün Yayınları';
      else if (comb.includes('hecce')) publisher = 'Hecce Yayıncılık';
      else if (comb.includes('ilke')) publisher = 'İlke Yayınları';
      else if (comb.includes('ada')) publisher = 'Ada Yayıncılık';
      else if (comb.includes('tymm') || comb.includes('maarif') || [1, 2].includes(grade)) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('inkılap') || comb.includes('inkilap') || comb.includes('inkılâp')) {
      grade = 8;
      subCode = 'INKILAP';
      subName = 'T.C. İnkılap Tarihi ve Atatürkçülük';
    } else if (comb.includes('sosyal')) {
      subCode = 'SOSYAL';
      subName = 'Sosyal Bilgiler';
      if (comb.includes('tymm') || comb.includes('maarif') || [5, 6].includes(grade)) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('hayat')) {
      subCode = 'HAYAT';
      subName = 'Hayat Bilgisi';
      if (comb.includes('tymm') || comb.includes('maarif') || [1, 2].includes(grade)) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('ingilizce') || comb.includes('english') || comb.includes('cydem') || comb.includes('çydem')) {
      subCode = 'INGILIZCE';
      subName = 'İngilizce';
      if (comb.includes('çydem') || comb.includes('cydem') || [2, 5, 6, 7].includes(grade)) publisher = 'ÇYDEM (Maarif Modeli)';
      else if (comb.includes('tymm')) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('beden') || comb.includes('spor') || comb.includes('bes') || comb.includes('beo')) {
      subCode = 'BEDEN';
      subName = 'Beden Eğitimi ve Spor';
      if (comb.includes('tymm') || comb.includes('maarif') || [1, 2].includes(grade)) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('müzik') || comb.includes('muzik')) {
      subCode = 'MUZIK';
      subName = 'Müzik';
      if (comb.includes('tymm') || comb.includes('maarif') || [5].includes(grade)) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('görsel') || comb.includes('gorsel') || comb.includes('resim')) {
      subCode = 'GORSEL';
      subName = 'Görsel Sanatlar';
      if (comb.includes('tymm') || comb.includes('maarif') || [1, 5].includes(grade)) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('almanca')) {
      subCode = 'ALMANCA';
      subName = 'Almanca';
      if (comb.includes('tymm') || comb.includes('maarif')) publisher = 'TYMM (Maarif Modeli)';
    } else if (comb.includes('din')) {
      subCode = 'DIN';
      subName = 'Din Kültürü ve Ahlak Bilgisi';
    } else if (comb.includes('teknoloji') || comb.includes('tasarım') || comb.includes('tasarim')) {
      subCode = 'TEKNOLOJI_TASARIM';
      subName = 'Teknoloji ve Tasarım';
    }

    const fullTitle = `${grade}. Sınıf - ${subName} - ${publisher}`;
    const shortPub = publisher.replace(' Yayınları', '').replace(' Yayıncılık', '').replace(' (Maarif Modeli)', '');
    let shortSub = subName.replace(' ve Yazılım', '').replace(' ve Spor', '').replace(' ve Atatürkçülük', '');
    if (shortSub === 'Bilişim Teknolojileri') shortSub = 'Bilişim';
    if (shortSub === 'Beden Eğitimi') shortSub = 'Beden';
    if (shortSub === 'Görsel Sanatlar') shortSub = 'Görsel';
    if (shortSub === 'T.C. İnkılap Tarihi') shortSub = 'İnkılap';
    if (shortSub === 'Fen Bilimleri') shortSub = 'Fen';
    if (shortSub === 'Sosyal Bilgiler') shortSub = 'Sosyal';

    const tabName = `${grade}-${shortSub}-${shortPub}`.substring(0, 30);

    return { grade, subCode, subName, publisher, fullTitle, tabName };
  }

  static extractWeekNums(val) {
    if (!val) return [];
    const s = String(val).trim();
    
    // 1. Range: '1-2. Hafta', 'Week 1-2', '1./2. Woche'
    const mRange = s.match(/(?:Hafta|Woche|Week)\s*(\d{1,2})\s*[-–/]\s*(\d{1,2})/i) ||
                   s.match(/(\d{1,2})\s*[-–/]\s*(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)/i);
    if (mRange) {
      const w1 = parseInt(mRange[1]), w2 = parseInt(mRange[2]);
      if (w1 >= 1 && w1 <= 36 && w2 >= 1 && w2 <= 36 && w1 <= w2) {
        const arr = [];
        for (let i = w1; i <= w2; i++) arr.push(i);
        return arr;
      }
    }

    // 2. Single
    const m1 = s.match(/(?:Hafta|Woche|Week)\s*(\d{1,2})/i) || s.match(/(\d{1,2})\s*\.?\s*(?:Hafta|Woche|Week)/i);
    if (m1) {
      const w = parseInt(m1[1]);
      if (w >= 1 && w <= 36) return [w];
    }

    // 3. Just digits
    if (/^\d{1,2}$/.test(s)) {
      const w = parseInt(s);
      if (w >= 1 && w <= 36) return [w];
    }

    return [];
  }

  /**
   * Bir XLSX dosyasını ArrayBuffer olarak alır ve tüm sekmelerini ayrıştırır.
   */
  static parseWorkbook(arrayBuffer, filename = 'plan.xlsx') {
    if (typeof XLSX === 'undefined') {
      throw new Error('SheetJS (XLSX) kütüphanesi yüklenemedi. Lütfen internet bağlantınızı kontrol ediniz.');
    }

    const workbook = XLSX.read(arrayBuffer, { type: 'array' });
    const parsedPlans = [];
    const seenTabs = {};

    // 1. Önce TÜM DERSLER BİRLEŞİK veya Çoklu Ders içeren Master Sheet Kontrolü
    const masterSheetName = workbook.SheetNames.find(sn => 
      sn.toUpperCase().includes('BİRLEŞİK') || 
      sn.toUpperCase().includes('BIRLESIK') || 
      sn.toUpperCase().includes('MASTER')
    );

    if (masterSheetName) {
      const sheet = workbook.Sheets[masterSheetName];
      if (sheet) {
        const rawMatrix = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });
        if (rawMatrix && rawMatrix.length > 1) {
          const multiPlans = this.parseMergedMatrix(rawMatrix, filename, masterSheetName);
          if (multiPlans.length > 0) {
            for (const p of multiPlans) {
              let tTab = p.tabName;
              if (seenTabs[tTab]) {
                seenTabs[tTab]++;
                p.tabName = `${p.tabName}_${seenTabs[tTab]}`.substring(0, 30);
              } else {
                seenTabs[tTab] = 1;
              }
              parsedPlans.push(p);
            }
            return parsedPlans; // Master sayfa bulundu ve ayrıştırıldı, tekil sekmeleri tekrar ekleyip mükerrer yapma!
          }
        }
      }
    }

    // 2. Normal Tekil Sekme Ayrıştırma
    for (const sheetName of workbook.SheetNames) {
      if (sheetName.toLowerCase() === 'sayfa1') continue;

      const sheet = workbook.Sheets[sheetName];
      if (!sheet) continue;

      const rawMatrix = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });
      if (!rawMatrix || rawMatrix.length <= 1) continue;

      const planResult = this.parseSheetMatrix(rawMatrix, filename, sheetName);
      if (planResult && planResult.rows && planResult.rows.length > 0) {
        let tTab = planResult.tabName;
        if (seenTabs[tTab]) {
          seenTabs[tTab]++;
          planResult.tabName = `${planResult.tabName}_${seenTabs[tTab]}`.substring(0, 30);
        } else {
          seenTabs[tTab] = 1;
        }
        parsedPlans.push(planResult);
      }
    }

    return parsedPlans;
  }

  /**
   * Birden fazla dersi alt alta barındıran TÜM DERSLER BİRLEŞİK master tablosunu ayrıştırır.
   */
  static parseMergedMatrix(matrix, filename, sheetname) {
    const plans = [];
    let headerRow = 0;

    // Header tespiti
    for (let r = 0; r < Math.min(5, matrix.length); r++) {
      const line = matrix[r].map(v => this.cleanCell(v)).join(' ').toUpperCase();
      if (line.includes('PLAN SIRASI') || line.includes('DERS TIPI') || line.includes('DERS TİPİ') || line.includes('BRANŞ') || line.includes('BRANS')) {
        headerRow = r;
        break;
      }
    }

    // Satırları ders gruplarına ayır (Sınıf + Branş + Yayın bazında)
    const groups = {};

    for (let r = headerRow + 1; r < matrix.length; r++) {
      const rowVals = matrix[r].map(v => this.cleanCell(v));
      if (!rowVals.some(v => v.length > 0)) continue;

      let planOrder = parseInt(rowVals[0]) || (r - headerRow);
      let dersTipi = rowVals[1] || 'Ders';
      let brans = rowVals[2] || '';
      let sinif = parseInt(rowVals[3]) || 5;
      let unite = '';
      let kazanim = '';
      let hafta = '';
      let publisher = 'MEB Yayınları';

      if (rowVals.length >= 8) {
        publisher = rowVals[4] || 'MEB Yayınları';
        unite = rowVals[5] || '';
        kazanim = rowVals[6] || '';
        hafta = rowVals[7] || '';
      } else {
        unite = rowVals[4] || '';
        kazanim = rowVals[5] || '';
        hafta = rowVals[6] || '';
      }

      if (!brans && !unite && !kazanim) continue;

      const groupKey = `${sinif}_${brans}_${publisher}`;
      if (!groups[groupKey]) {
        groups[groupKey] = {
          sinif,
          brans,
          publisher,
          rows: []
        };
      }

      const isHoliday = dersTipi !== 'Ders' || unite.toUpperCase().includes('TATİL') || unite.toUpperCase().includes('TATIL');

      groups[groupKey].rows.push({
        planOrder,
        dersTipi,
        brans: brans || `${sinif}. Sınıf ${dersTipi}`,
        sinif,
        publisher,
        unite,
        kazanim,
        hafta,
        isHoliday,
        weekNum: planOrder // Tatiller dahil tüm satırlar 1..39 kronolojik takvim sırasına oturur!
      });
    }

    for (const [key, grp] of Object.entries(groups)) {
      if (grp.rows.length === 0) continue;

      const meta = this.detectSubjectAndPublisher(filename, `${grp.sinif}-${grp.brans}`);
      if (grp.publisher && grp.publisher !== 'MEB Yayınları') {
        meta.publisher = grp.publisher;
        meta.fullTitle = `${grp.sinif}. Sınıf - ${meta.subName} - ${grp.publisher}`;
      }

      plans.push({
        key: meta.fullTitle,
        grade: grp.sinif,
        subjectCode: meta.subCode,
        subjectName: meta.subName,
        publisher: meta.publisher,
        fullTitle: meta.fullTitle,
        tabName: meta.tabName,
        sheetName: sheetname,
        rows: grp.rows.map(r => ({
          ...r,
          subCode: meta.subCode
        }))
      });
    }

    return plans;
  }

  /**
   * 2D Dizi halindeki tekil çalışma sayfasını ayrıştırır.
   */
  static parseSheetMatrix(matrix, filename, sheetname) {
    const meta = this.detectSubjectAndPublisher(filename, sheetname);

    // 1. Zaten MERKEZ_BOT formatında mı kontrol et (Plan Sırası, Ders Tipi, vb.)
    for (let r = 0; r < Math.min(5, matrix.length); r++) {
      const line = matrix[r].map(v => this.cleanCell(v)).join(' ').toUpperCase();
      if ((line.includes('PLAN SIRASI') || line.includes('PLAN SIRASI')) && (line.includes('DERS TIPI') || line.includes('DERS TİPİ') || line.includes('BRANŞ') || line.includes('BRANS'))) {
        // Doğrudan MERKEZ_BOT satır satır ayrıştırma
        const directRows = [];
        for (let i = r + 1; i < matrix.length; i++) {
          const rowVals = matrix[i].map(v => this.cleanCell(v));
          if (!rowVals.some(v => v.length > 0)) continue;

          let planOrder = parseInt(rowVals[0]) || (i - r);
          let dersTipi = rowVals[1] || 'Ders';
          let brans = rowVals[2] || `${meta.grade}.sinif ${meta.subName}`;
          let sinif = parseInt(rowVals[3]) || meta.grade;
          let unite = '';
          let kazanim = '';
          let hafta = '';
          let pub = meta.publisher;

          if (rowVals.length >= 8) {
            pub = rowVals[4] || meta.publisher;
            unite = rowVals[5] || '';
            kazanim = rowVals[6] || '';
            hafta = rowVals[7] || '';
          } else {
            unite = rowVals[4] || '';
            kazanim = rowVals[5] || '';
            hafta = rowVals[6] || '';
          }

          const isHoliday = dersTipi !== 'Ders' || unite.toUpperCase().includes('TATİL') || unite.toUpperCase().includes('TATIL');

          directRows.push({
            planOrder,
            dersTipi,
            brans,
            sinif,
            publisher: pub,
            unite,
            kazanim,
            hafta,
            subCode: meta.subCode,
            weekNum: planOrder,
            isHoliday
          });
        }

        if (directRows.length > 0) {
          return {
            key: meta.fullTitle,
            grade: meta.grade,
            subjectCode: meta.subCode,
            subjectName: meta.subName,
            publisher: meta.publisher,
            fullTitle: meta.fullTitle,
            tabName: meta.tabName,
            sheetName: sheetname,
            rows: directRows
          };
        }
      }
    }

    // 2. Ham MEB Planı Sütun Tespiti
    let weekCol = null;
    let unitCol = null;
    let topicCol = null;
    let outcomeCols = [];
    let headerRow = 0;

    for (let r = 0; r < Math.min(6, matrix.length); r++) {
      const rowVals = matrix[r].map(v => this.cleanCell(v));
      for (let c = 0; c < rowVals.length; c++) {
        const u = rowVals[c].toUpperCase().trim();
        if (u === 'HAFTA' || u === 'WEEK' || u === 'WOCHE' || u.startsWith('HAFTA (') || u.startsWith('WEEK (') || u.startsWith('HAFTA/')) {
          if (weekCol === null) { weekCol = c; headerRow = r; }
        } else if (['ÜNİTE / TEMA', 'ÜNİTE/TEMA', 'UNIT/THEME', 'THEME', 'TEMA', 'ÖĞRENME ALANI'].some(k => u.includes(k))) {
          if (unitCol === null) unitCol = c;
        } else if (['KONU (İÇERİK ÇERÇEVESİ)', 'KONU', 'CONTENT FRAME', 'İÇERİK', 'METİN', 'SUB-THEME', 'FUNCTIONS'].some(k => u.includes(k))) {
          if (topicCol === null) topicCol = c;
        } else if (['ÖĞRENME ÇIKTILARI', 'KAZANIM', 'LEARNING OUTCOME', 'LERNZIELE', 'LEARNING SKILLS', 'OKUMA', 'YAZMA', 'KONUŞMA', 'DİNLEME'].some(k => u.includes(k))) {
          if (!outcomeCols.includes(c)) outcomeCols.push(c);
        }
      }
      if (weekCol !== null && outcomeCols.length > 0) break;
    }

    if (weekCol === null) weekCol = 1;
    if (unitCol === null) unitCol = 3;
    if (outcomeCols.length === 0) outcomeCols = [5];

    const weekMap = {};
    for (let w = 1; w <= 36; w++) {
      weekMap[w] = { unit: '', topic: '', outcomes: [] };
    }

    let currentWeeks = [1];
    let lastUnit = '1. Ünite';
    let lastTopic = '';

    for (let r = headerRow + 1; r < matrix.length; r++) {
      const rowVals = matrix[r].map(v => this.cleanCell(v));
      if (!rowVals.some(v => v.length > 0)) continue;

      const uLine = rowVals.join(' ').toUpperCase();
      if (uLine.includes('ÖLÇME VE DEĞERLENDİRME') || uLine.includes('BEWERTUNG') || uLine.includes('ASSESSMENT')) continue;
      if (uLine.includes('EĞİTİM ÖĞRETİM YILI') && uLine.length < 60) continue;
      if (uLine.includes('ACADEMIC YEAR') && uLine.length < 60) continue;
      if (uLine.includes('SCHULJAHR') && uLine.length < 60) continue;

      // Hafta tespiti
      const rawW = rowVals[weekCol] || '';
      let wList = this.extractWeekNums(rawW);
      if (wList.length === 0 && weekCol !== 0) {
        wList = this.extractWeekNums(rowVals[0]);
      }
      if (wList.length > 0) {
        currentWeeks = wList;
      }

      // Ünite & Konu
      const rawU = rowVals[unitCol] || '';
      const rawT = (topicCol !== null && topicCol < rowVals.length) ? rowVals[topicCol] : '';

      if (rawU && rawU.length > 1 && !['ÜNİTE', 'THEME', 'TEMA', 'ÜNİTE/TEMA', 'UNIT/THEME'].includes(rawU.toUpperCase())) {
        lastUnit = rawU;
      }
      if (rawT && rawT.length > 1 && !['KONU', 'CONTENT', 'İÇERİK', 'METİN'].includes(rawT.toUpperCase())) {
        lastTopic = rawT;
      }

      const chosenUnit = lastTopic ? lastTopic : lastUnit;

      // Kazanımlar
      const rowOutcomes = [];
      for (const oc of outcomeCols) {
        if (oc < rowVals.length) {
          const val = this.cleanCell(rowVals[oc]);
          if (val && val.length > 4 && !['KAZANIM', 'KAZANIMLAR', 'ÖĞRENME ÇIKTILARI', 'LEARNING OUTCOMES', 'DİNLEME/İZLEME', 'KONUŞMA', 'OKUMA', 'YAZMA'].includes(val.toUpperCase())) {
            rowOutcomes.push(val);
          }
        }
      }

      for (const w of currentWeeks) {
        if (w >= 1 && w <= 36) {
          weekMap[w].unit = chosenUnit;
          for (const ro of rowOutcomes) {
            if (!weekMap[w].outcomes.includes(ro)) {
              weekMap[w].outcomes.push(ro);
            }
          }
        }
      }
    }

    // 36 Haftayı Standart Satırlara Dönüştür
    const rows = [];
    let lastKnownUnit = '1. Ünite';
    let lastKnownOutcome = `${meta.grade}. Sınıf ${meta.subName} dersi MEB müfredat kazanımı.`;
    const bransLabel = `${meta.grade}.sinif ${meta.subName}`;
    let planOrder = 1;

    for (let w = 1; w <= 36; w++) {
      if (w === 9) {
        const u = weekMap[w].unit || lastKnownUnit;
        lastKnownUnit = u;
        if (weekMap[w].outcomes.length > 0) {
          lastKnownOutcome = weekMap[w].outcomes.slice(0, 2).join(' ');
        }
        rows.push({
          planOrder: planOrder++,
          dersTipi: 'Ders',
          brans: bransLabel,
          sinif: meta.grade,
          publisher: meta.publisher,
          unite: u,
          kazanim: lastKnownOutcome,
          hafta: String(w),
          subCode: meta.subCode,
          weekNum: w,
          isHoliday: false
        });

        // 1. Ara Tatil
        rows.push({
          planOrder: planOrder++,
          dersTipi: 'Ara Tatil',
          brans: bransLabel,
          sinif: meta.grade,
          publisher: meta.publisher,
          unite: '1. DÖNEM ARA TATİLİ: 10 Kasım - 14 Kasım 2025',
          kazanim: '1. DÖNEM ARA TATİLİ: 10 Kasım - 14 Kasım 2025',
          hafta: '',
          subCode: meta.subCode,
          weekNum: 9,
          isHoliday: true
        });
        continue;
      } else if (w === 18) {
        const u = weekMap[w].unit || lastKnownUnit;
        lastKnownUnit = u;
        if (weekMap[w].outcomes.length > 0) {
          lastKnownOutcome = weekMap[w].outcomes.slice(0, 2).join(' ');
        }
        rows.push({
          planOrder: planOrder++,
          dersTipi: 'Ders',
          brans: bransLabel,
          sinif: meta.grade,
          publisher: meta.publisher,
          unite: u,
          kazanim: lastKnownOutcome,
          hafta: String(w),
          subCode: meta.subCode,
          weekNum: w,
          isHoliday: false
        });

        // Yarıyıl Tatili
        rows.push({
          planOrder: planOrder++,
          dersTipi: 'Yarıyıl',
          brans: bransLabel,
          sinif: meta.grade,
          publisher: meta.publisher,
          unite: 'YARIYIL TATİLİ: 19 Ocak - 30 Ocak 2026',
          kazanim: 'YARIYIL TATİLİ: 19 Ocak - 30 Ocak 2026',
          hafta: '',
          subCode: meta.subCode,
          weekNum: 18,
          isHoliday: true
        });
        continue;
      } else if (w === 27) {
        const u = weekMap[w].unit || lastKnownUnit;
        lastKnownUnit = u;
        if (weekMap[w].outcomes.length > 0) {
          lastKnownOutcome = weekMap[w].outcomes.slice(0, 2).join(' ');
        }
        rows.push({
          planOrder: planOrder++,
          dersTipi: 'Ders',
          brans: bransLabel,
          sinif: meta.grade,
          publisher: meta.publisher,
          unite: u,
          kazanim: lastKnownOutcome,
          hafta: String(w),
          subCode: meta.subCode,
          weekNum: w,
          isHoliday: false
        });

        // 2. Ara Tatil
        rows.push({
          planOrder: planOrder++,
          dersTipi: 'Ara Tatil',
          brans: bransLabel,
          sinif: meta.grade,
          publisher: meta.publisher,
          unite: '2. DÖNEM ARA TATİLİ: 16 Mart - 20 Mart 2026',
          kazanim: '2. DÖNEM ARA TATİLİ: 16 Mart - 20 Mart 2026',
          hafta: '',
          subCode: meta.subCode,
          weekNum: 27,
          isHoliday: true
        });
        continue;
      }

      // Normal Hafta
      const u = weekMap[w].unit || lastKnownUnit;
      lastKnownUnit = u;
      if (weekMap[w].outcomes.length > 0) {
        lastKnownOutcome = weekMap[w].outcomes.slice(0, 2).join(' ');
      } else {
        if (u.toUpperCase().includes('ORIENTATION') || u.toUpperCase().includes('UYUM')) {
          lastKnownOutcome = 'Orientation: Okul ve derse uyum, ders işleniş kuralları ve süreç planlama etkinlikleri.';
        } else if (u.toUpperCase().includes('REVISION') || u.toUpperCase().includes('TEKRAR')) {
          lastKnownOutcome = `${u}: Önceki yıl öğrenilen temel konular ve dil yapılarının tekrarı.`;
        }
      }

      rows.push({
        planOrder: planOrder++,
        dersTipi: 'Ders',
        brans: bransLabel,
        sinif: meta.grade,
        publisher: meta.publisher,
        unite: u,
        kazanim: lastKnownOutcome,
        hafta: String(w),
        subCode: meta.subCode,
        weekNum: w,
        isHoliday: false
      });
    }

    return {
      key: meta.fullTitle,
      grade: meta.grade,
      subjectCode: meta.subCode,
      subjectName: meta.subName,
      publisher: meta.publisher,
      fullTitle: meta.fullTitle,
      tabName: meta.tabName,
      sheetName: sheetname,
      rows: rows
    };
  }
}

if (typeof window !== 'undefined') {
  window.SmartExcelImporter = SmartExcelImporter;
}
