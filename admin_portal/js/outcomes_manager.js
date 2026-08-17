/**
 * SınıfCepte Web Admin Paneli - Müfredat ve 36 Haftalık Kazanım Yöneticisi
 */
class OutcomesManager {
  constructor() {
    this.outcomes = [];
    this.currentGrade = 5;
    this.currentSubject = 'BILISIM';
    this.currentPublisher = 'ALL';
    this.initDefaultOutcomes();
  }

  initDefaultOutcomes() {
    const saved = localStorage.getItem('sinifcepte_admin_outcomes');
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        const hasZeroWeeks = Array.isArray(parsed) && parsed.some(p => p.weekNumber === 0 || p.weekNumber === '0');
        if (Array.isArray(parsed) && parsed.length >= 1000 && !hasZeroWeeks) {
          this.outcomes = parsed;
          return;
        }
      } catch (e) {
        console.error('Saved outcomes parse error:', e);
      }
    }

    // Varsayılan olarak tüm resmî MEB / Maarif Modeli kütüphanesini yükle (59 Ders, 2.301 Hafta):
    if (typeof CurriculumPresets !== 'undefined' && CurriculumPresets.OFFICIAL_DATABASE && CurriculumPresets.OFFICIAL_DATABASE.length > 0) {
      this.outcomes = [...CurriculumPresets.OFFICIAL_DATABASE];
    } else {
      this.outcomes = this.generateSampleOutcomes(5, 'MAT', 'Matematik');
    }
    this.save();
  }

  generateSampleOutcomes(gradeLevel, subjectCode, subjectName) {
    const list = [];
    for (let w = 1; w <= 36; w++) {
      if (w === 9) {
        list.push({
          id: `out_${gradeLevel}_${subjectCode}_w${w}`,
          gradeLevel: gradeLevel,
          subjectCode: subjectCode,
          subjectName: subjectName,
          publisher: 'MEB Yayınları',
          fullTitle: `${gradeLevel}. Sınıf - ${subjectName} - MEB Yayınları`,
          weekNumber: w,
          unitTitle: '1. Dönem Ara Tatili',
          topicTitle: 'Kasım Ara Tatili Haftası',
          outcomeCode: 'TATIL',
          outcomeDescription: '1. Dönem Ara Tatil Haftası (Dinlenme ve Etkinlik)',
          isHolidayWeek: true,
          holidayNote: '1. Dönem Ara Tatili 🎉',
          academicYear: '2026-2027',
        });
      } else if (w === 19 || w === 20) {
        list.push({
          id: `out_${gradeLevel}_${subjectCode}_w${w}`,
          gradeLevel: gradeLevel,
          subjectCode: subjectCode,
          subjectName: subjectName,
          publisher: 'MEB Yayınları',
          fullTitle: `${gradeLevel}. Sınıf - ${subjectName} - MEB Yayınları`,
          weekNumber: w,
          unitTitle: 'Yarıyıl Tatili',
          topicTitle: 'Sömestr Tatili',
          outcomeCode: 'TATIL',
          outcomeDescription: '1. Dönem Sonu Yarıyıl Sömestr Tatili',
          isHolidayWeek: true,
          holidayNote: 'Yarıyıl Tatili ⛄',
          academicYear: '2026-2027',
        });
      } else if (w === 29) {
        list.push({
          id: `out_${gradeLevel}_${subjectCode}_w${w}`,
          gradeLevel: gradeLevel,
          subjectCode: subjectCode,
          subjectName: subjectName,
          publisher: 'MEB Yayınları',
          fullTitle: `${gradeLevel}. Sınıf - ${subjectName} - MEB Yayınları`,
          weekNumber: w,
          unitTitle: '2. Dönem Ara Tatili',
          topicTitle: 'Nisan Ara Tatili',
          outcomeCode: 'TATIL',
          outcomeDescription: '2. Dönem Ara Tatil Haftası',
          isHolidayWeek: true,
          holidayNote: '2. Dönem Ara Tatili 🏖️',
          academicYear: '2026-2027',
        });
      } else {
        list.push({
          id: `out_${gradeLevel}_${subjectCode}_w${w}`,
          gradeLevel: gradeLevel,
          subjectCode: subjectCode,
          subjectName: subjectName,
          publisher: 'MEB Yayınları',
          fullTitle: `${gradeLevel}. Sınıf - ${subjectName} - MEB Yayınları`,
          weekNumber: w,
          unitTitle: `${Math.ceil(w / 6)}. Ünite: Temel Konular ve Uygulamalar`,
          topicTitle: `${w}. Hafta Konusu`,
          outcomeCode: `${subjectCode}.${gradeLevel}.${Math.ceil(w / 6)}.1.${w % 5 + 1}`,
          outcomeDescription: `${gradeLevel}. Sınıf ${subjectName} dersi ${w}. hafta müfredat kazanımı ve etkinlikleri.`,
          isHolidayWeek: false,
          holidayNote: null,
          academicYear: '2026-2027',
        });
      }
    }
    return list;
  }

  save() {
    localStorage.setItem('sinifcepte_admin_outcomes', JSON.stringify(this.outcomes));
  }

  getFilteredOutcomes(gradeLevel, subjectCode = 'ALL', publisher = 'ALL') {
    return this.outcomes.filter((o) => {
      if (gradeLevel !== 'ALL' && parseInt(o.gradeLevel) !== parseInt(gradeLevel)) return false;
      if (subjectCode !== 'ALL' && o.subjectCode !== subjectCode) return false;
      if (publisher !== 'ALL' && o.publisher !== publisher) return false;
      return true;
    }).sort((a, b) => {
      if (a.gradeLevel !== b.gradeLevel) return a.gradeLevel - b.gradeLevel;
      if (a.subjectCode !== b.subjectCode) return a.subjectCode.localeCompare(b.subjectCode);
      return a.weekNumber - b.weekNumber;
    });
  }

  getAvailableSubjectsForGrade(gradeLevel) {
    const subjectsMap = new Map();
    this.outcomes.forEach((o) => {
      if (gradeLevel === 'ALL' || parseInt(o.gradeLevel) === parseInt(gradeLevel)) {
        if (!subjectsMap.has(o.subjectCode)) {
          subjectsMap.set(o.subjectCode, {
            code: o.subjectCode,
            name: o.subjectName,
            count: 0,
            publishers: new Set()
          });
        }
        const item = subjectsMap.get(o.subjectCode);
        item.count++;
        if (o.publisher) item.publishers.add(o.publisher);
      }
    });
    return Array.from(subjectsMap.values());
  }

  getAvailablePublishersFor(gradeLevel, subjectCode) {
    const pubSet = new Set();
    this.outcomes.forEach((o) => {
      if (gradeLevel === 'ALL' || parseInt(o.gradeLevel) === parseInt(gradeLevel)) {
        if (subjectCode === 'ALL' || o.subjectCode === subjectCode) {
          if (o.publisher) pubSet.add(o.publisher);
        }
      }
    });
    return Array.from(pubSet);
  }

  updateOutcome(updated) {
    const idx = this.outcomes.findIndex((o) => o.id === updated.id);
    if (idx !== -1) {
      this.outcomes[idx] = updated;
    } else {
      this.outcomes.push(updated);
    }
    this.save();
  }

  bulkImportFromText(gradeLevel, subjectCode, subjectName, rawText) {
    const lines = rawText.split('\n').map((l) => l.trim()).filter((l) => l.length > 0);
    const newItems = [];

    lines.forEach((line, index) => {
      if (index === 0 && (line.includes('Plan Sırası') || line.includes('Ders Tipi') || line.includes('Ünite'))) {
        return;
      }

      let parts = line.split('\t');
      if (parts.length < 3) parts = line.split(';');
      if (parts.length < 3) parts = line.split('|');

      let weekNum = index + 1;
      let unit = '';
      let topic = '';
      let code = '';
      let desc = '';
      let isHoliday = false;
      let publisher = 'MEB Yayınları';

      if (parts.length >= 7 && (parts[1].trim() === 'Ders' || parts[1].toLowerCase().includes('tatil'))) {
        const dersTipi = parts[1].trim();
        const parsedGrade = parseInt(parts[3]) || parseInt(gradeLevel);
        
        if (parts.length >= 8) {
          publisher = parts[4] || 'MEB Yayınları';
          unit = parts[5] || '1. Ünite';
          desc = parts[6] || '';
          weekNum = parseInt(parts[7]) || parseInt(parts[0]) || (index + 1);
        } else {
          unit = parts[4] || '1. Ünite';
          desc = parts[5] || '';
          weekNum = parseInt(parts[6]) || parseInt(parts[0]) || (index + 1);
        }
        
        topic = unit;
        isHoliday = dersTipi !== 'Ders';
        
        const codeMatch = desc.match(/([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+(?:\.\d+)?|\b[A-Z]\d\.\d\.\w+\b)/);
        code = isHoliday ? 'TATIL' : (codeMatch ? codeMatch[1] : `${subjectCode}.${parsedGrade}.${weekNum}`);
      } else {
        weekNum = parseInt(parts[0]) || (index + 1);
        unit = parts[1] || `${Math.ceil(weekNum / 6)}. Ünite`;
        topic = parts[2] || `${weekNum}. Hafta Konusu`;
        code = parts[3] || `${subjectCode}.${gradeLevel}.${weekNum}`;
        desc = parts[4] || parts[2] || `${weekNum}. Hafta Kazanım Açıklaması`;
        isHoliday = desc.toLowerCase().includes('tatil') || topic.toLowerCase().includes('tatil');
      }

      newItems.push({
        id: `out_${gradeLevel}_${subjectCode}_w${weekNum}_${Date.now()}`,
        gradeLevel: parseInt(gradeLevel),
        subjectCode: subjectCode,
        subjectName: subjectName,
        publisher: publisher,
        fullTitle: `${gradeLevel}. Sınıf - ${subjectName} - ${publisher}`,
        weekNumber: weekNum,
        unitTitle: unit,
        topicTitle: topic,
        outcomeCode: code,
        outcomeDescription: desc,
        isHolidayWeek: isHoliday,
        holidayNote: isHoliday ? unit : null,
        academicYear: '2026-2027',
      });
    });

    if (newItems.length > 0) {
      this.outcomes = this.outcomes.filter(
        (o) => !(o.gradeLevel === parseInt(gradeLevel) && o.subjectCode === subjectCode)
      );
      this.outcomes.push(...newItems);
      this.save();
    }

    return newItems.length;
  }

  renderTable(gradeLevel, subjectCode = 'ALL', publisher = 'ALL') {
    const tbody = document.getElementById('outcomes-tbody');
    if (!tbody) return;

    const list = this.getFilteredOutcomes(gradeLevel, subjectCode, publisher);

    if (list.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; color: var(--text-muted); padding: 30px;">
        Seçilen filtre için (${gradeLevel === 'ALL' ? 'Tüm Sınıflar' : gradeLevel + '. Sınıf'} / ${subjectCode}) henüz kazanım bulunmuyor.<br>
        Yukarıdaki <strong>"📂 Excel Dosyası Yükle (.xlsx)"</strong> veya <strong>"📦 Hazır TTKB Paketleri"</strong> butonundan tek tıkla yükleyebilirsiniz.
      </td></tr>`;
      return;
    }

    tbody.innerHTML = list
      .map((item) => {
        const isMaarif = item.publisher && (item.publisher.includes('Maarif') || item.publisher.includes('TYMM') || item.publisher.includes('İYDEM'));
        const pubBadge = `<span class="badge" style="font-size: 10px; background: ${isMaarif ? 'rgba(79, 70, 229, 0.12)' : 'rgba(100, 116, 139, 0.12)'}; color: ${isMaarif ? 'var(--primary)' : 'var(--text-muted)'}; border: 1px solid ${isMaarif ? 'rgba(79, 70, 229, 0.25)' : 'transparent'};">
          ${item.publisher || 'MEB'}
        </span>`;

        return `
        <tr style="${item.isHolidayWeek ? 'background: rgba(245, 158, 11, 0.05);' : ''}">
          <td style="white-space: nowrap;">
            <strong>${item.weekNumber}. Hafta</strong>
            <div style="font-size: 10.5px; color: var(--text-muted);">${item.gradeLevel}. Sınıf - ${item.subjectName}</div>
          </td>
          <td>
            <div style="font-weight: 600; color: var(--primary); margin-bottom: 2px;">${item.unitTitle}</div>
            ${pubBadge}
          </td>
          <td style="font-size: 12px; color: var(--text-color);">${item.topicTitle}</td>
          <td><code style="font-weight: 700; font-size: 11px; color: var(--primary);">${item.outcomeCode || '-'}</code></td>
          <td style="max-width: 320px; font-size: 12.5px; line-height: 1.4;">${item.outcomeDescription}</td>
          <td>${item.isHolidayWeek ? '<span class="badge badge-break">🏖️ Tatil</span>' : '<span class="badge" style="background: rgba(16,185,129,0.1); color: var(--accent);">Ders</span>'}</td>
          <td style="text-align: right; white-space: nowrap;">
            <button class="btn btn-secondary" style="padding: 4px 8px; font-size: 11px;" onclick="window.adminApp.editOutcome('${item.id}')">Düzenle</button>
          </td>
        </tr>
      `;
      })
      .join('');
  }
}

window.OutcomesManager = OutcomesManager;
