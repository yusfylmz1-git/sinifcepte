/**
 * SınıfCepte Web Admin Paneli - MEB Maarif Modeli ve 39 Haftalık Kazanım Yöneticisi
 */
class OutcomesManager {
  /** Elle düzenlemelerin saklandığı anahtar (tüm veri değil, yalnızca fark). */
  static OVERRIDES_KEY = 'sinifcepte_admin_outcome_overrides';
  static YEAR_KEY = 'sinifcepte_admin_outcomes_year';

  /** Tabloya tek seferde basılacak en fazla satır. */
  static MAX_ROWS = 400;

  /** Yöneticinin panelden değiştirebildiği alanlar. */
  static EDITABLE_FIELDS = [
    'outcomeCode',
    'unitTitle',
    'topicTitle',
    'outcomeDescription',
    'maarifSummary',
    'maarifValues',
    'maarifSkills',
    'differentiation',
    'isPlaceholder',
  ];

  constructor() {
    this.outcomes = [];
    this.currentSchoolType = 'ALL';
    this.currentGrade = 10;
    this.currentSubject = 'ALL';
    this.currentPublisher = 'ALL';
    this.currentCategory = 'ALL';
    this.searchQuery = '';
    this.initDefaultOutcomes();
  }

  initDefaultOutcomes() {
    const presets = this.readOfficialPresets();

    if (presets.length === 0) {
      console.warn(
        'OutcomesManager: Resmî Maarif paketi yüklenemedi. ' +
          'curriculum_presets.js dosyası eksik veya bozuk olabilir; ' +
          'yeniden üretmek için: python scripts/maarif/yillik_guncelle.py'
      );
      this.outcomes = [];
      return;
    }

    // Veri kaynağı DAİMA curriculum_presets.js dosyasıdır. Tüm kayıtları
    // localStorage'a yansıtmak 9 MB'lık bir yazma demekti; tarayıcı kotası
    // ~5 MB olduğu için setItem QuotaExceededError fırlatıyor, bu hata
    // yapıcıdan dışarı sızıp AdminApp'in hiç kurulmamasına yol açıyordu
    // (window.adminApp undefined kalınca paneldeki düğmeler çalışmıyordu).
    // Artık yalnızca yöneticinin ELLE yaptığı düzenlemeler saklanır.
    this.outcomes = presets.map((item) => ({ ...item }));
    this.applySavedOverrides();
  }

  /** localStorage'daki elle düzenlemeleri paket verisinin üzerine uygular. */
  applySavedOverrides() {
    const presetYear = this.officialPresetYear();
    const savedYear = localStorage.getItem(OutcomesManager.YEAR_KEY);
    // Farklı bir eğitim yılına ait düzenlemeler bu pakete uygulanmaz.
    if (presetYear && savedYear && savedYear !== presetYear) return;

    let overrides;
    try {
      overrides = JSON.parse(localStorage.getItem(OutcomesManager.OVERRIDES_KEY) || '{}');
    } catch (e) {
      console.error('Kayıtlı düzenlemeler okunamadı:', e);
      return;
    }
    if (!overrides || typeof overrides !== 'object') return;

    const byId = new Map(this.outcomes.map((item) => [item.id, item]));
    let applied = 0;
    for (const [id, patch] of Object.entries(overrides)) {
      const target = byId.get(id);
      if (target) {
        Object.assign(target, patch);
        applied += 1;
      }
    }
    if (applied > 0) {
      console.info(`OutcomesManager: ${applied} elle düzenleme uygulandı.`);
    }
  }

  /** Üretilen veri paketini okur; paket yoksa boş dizi döner. */
  readOfficialPresets() {
    if (typeof CurriculumPresets === 'undefined') return [];
    const presets = CurriculumPresets.getAllOfficialPresets();
    return Array.isArray(presets) ? presets : [];
  }

  /** Veri paketinin ait olduğu eğitim öğretim yılı. */
  officialPresetYear() {
    if (typeof CurriculumPresets === 'undefined') return null;
    if (CurriculumPresets.ACADEMIC_YEAR) return CurriculumPresets.ACADEMIC_YEAR;
    const first = this.readOfficialPresets()[0];
    return first ? first.academicYear || null : null;
  }

  /**
   * Yalnızca paket verisinden FARKLI olan alanları saklar.
   *
   * Tüm kayıtları yazmak ~9 MB ediyordu ve tarayıcı kotasını (~5 MB)
   * aştığı için hata fırlatıyordu. Fark genelde birkaç kilobayttır.
   */
  save() {
    const presetById = new Map(this.readOfficialPresets().map((p) => [p.id, p]));
    const overrides = {};

    for (const item of this.outcomes) {
      const preset = presetById.get(item.id);
      if (!preset) {
        // Pakette olmayan kayıt (elle eklenmiş): tamamı saklanır.
        overrides[item.id] = item;
        continue;
      }
      const patch = {};
      for (const key of OutcomesManager.EDITABLE_FIELDS) {
        if (item[key] !== preset[key]) patch[key] = item[key];
      }
      if (Object.keys(patch).length > 0) overrides[item.id] = patch;
    }

    try {
      localStorage.setItem(OutcomesManager.OVERRIDES_KEY, JSON.stringify(overrides));
      const year = this.officialPresetYear();
      if (year) localStorage.setItem(OutcomesManager.YEAR_KEY, year);
      // Eski sürümün bıraktığı dev kayıt varsa yer açmak için silinir.
      localStorage.removeItem('sinifcepte_admin_outcomes');
      return true;
    } catch (e) {
      // Kota dolsa bile panel çalışmaya devam etmeli; düzenleme bellekte durur.
      console.error('Düzenlemeler kaydedilemedi:', e);
      return false;
    }
  }

  syncWithOfficialPresets() {
    const presets = this.readOfficialPresets();
    if (presets.length === 0) {
      throw new Error(
        'Resmî Maarif veri paketi bulunamadı. curriculum_presets.js yüklenmemiş olabilir. ' +
          'Yeniden üretmek için: python scripts/maarif/yillik_guncelle.py --year <yıl>'
      );
    }
    // Senkronizasyon paketi yeniden yükler; elle düzenlemeler temizlenir.
    this.outcomes = presets.map((item) => ({ ...item }));
    try {
      localStorage.removeItem(OutcomesManager.OVERRIDES_KEY);
      localStorage.removeItem('sinifcepte_admin_outcomes');
    } catch (_) {}
    this.save();
    return this.outcomes.length;
  }

  getFilteredOutcomes(schoolType = 'ALL', gradeLevel = 'ALL', subjectCode = 'ALL', publisher = 'ALL', category = 'ALL', searchQuery = '') {
    const q = searchQuery ? searchQuery.trim().toLowerCase() : '';

    return this.outcomes.filter((o) => {
      const g = parseInt(o.gradeLevel) || 0;

      // 1. Okul Türü / Kademe Kontrolü
      if (schoolType !== 'ALL') {
        if (schoolType === 'PRIMARY' && (g < 1 || g > 4)) return false;
        if (schoolType === 'MIDDLE' && (g < 5 || g > 8)) return false;
        if (schoolType === 'HIGH' && (g < 9 || g > 12)) return false;
        if (schoolType === 'IHO') {
          const itemCat = (o.category || '').toLowerCase();
          const sName = (o.subjectName || '').toLowerCase();
          const isIho = itemCat === 'iho' || sName.includes('arapça') || sName.includes('kuran') || sName.includes('siyer') || sName.includes('fıkıh') || sName.includes('tefsir') || sName.includes('hadis');
          if (!isIho && (g < 5 || g > 12)) return false;
        }
      }

      // 2. Sınıf Kontrolü
      if (gradeLevel !== 'ALL' && g !== parseInt(gradeLevel)) return false;
      
      // 3. Branş Kontrolü
      if (subjectCode !== 'ALL' && o.subjectCode !== subjectCode) return false;
      
      // 4. Yayınevi Kontrolü
      if (publisher !== 'ALL' && o.publisher !== publisher) return false;

      // 5. Kategori Kontrolü (Ders, Seçmeli, Kurs, İHO, Harezmi)
      if (category !== 'ALL') {
        const itemCat = (o.category || 'core').toLowerCase();
        const sName = (o.subjectName || '').toLowerCase();
        if (category === 'elective' && itemCat !== 'elective' && !sName.includes('seçmeli')) return false;
        if (category === 'course' && itemCat !== 'course' && !sName.includes('kurs') && !sName.includes('dyk')) return false;
        if (category === 'iho' && itemCat !== 'iho' && !sName.includes('arapça') && !sName.includes('kuran') && !sName.includes('siyer') && !sName.includes('fıkıh')) return false;
        if (category === 'harezmi' && itemCat !== 'harezmi' && !sName.includes('harezmi')) return false;
        if (category === 'core' && itemCat !== 'core' && (itemCat === 'elective' || itemCat === 'iho' || itemCat === 'harezmi')) return false;
      }

      // 6. Arama Sorgusu
      if (q.length > 0) {
        const fullText = `${o.subjectName || ''} ${o.unitTitle || ''} ${o.topicTitle || ''} ${o.outcomeCode || ''} ${o.outcomeDescription || ''} ${o.publisher || ''}`.toLowerCase();
        if (!fullText.includes(q)) return false;
      }

      return true;
    }).sort((a, b) => {
      if (a.gradeLevel !== b.gradeLevel) return a.gradeLevel - b.gradeLevel;
      if (a.subjectCode !== b.subjectCode) return (a.subjectCode || '').localeCompare(b.subjectCode || '');
      return (a.weekNumber || 1) - (b.weekNumber || 1);
    });
  }

  getAvailableSubjectsForGrade(gradeLevel, schoolType = 'ALL') {
    const subjectsMap = new Map();
    this.outcomes.forEach((o) => {
      const g = parseInt(o.gradeLevel) || 0;
      
      let matchSchool = true;
      if (schoolType === 'PRIMARY') matchSchool = (g >= 1 && g <= 4);
      else if (schoolType === 'MIDDLE') matchSchool = (g >= 5 && g <= 8);
      else if (schoolType === 'HIGH') matchSchool = (g >= 9 && g <= 12);

      const matchGrade = (gradeLevel === 'ALL' || g === parseInt(gradeLevel));

      if (matchSchool && matchGrade) {
        if (!subjectsMap.has(o.subjectCode)) {
          subjectsMap.set(o.subjectCode, {
            code: o.subjectCode,
            name: o.subjectName,
            category: o.category || 'core',
            count: 0,
            publishers: new Set()
          });
        }
        const item = subjectsMap.get(o.subjectCode);
        item.count++;
        if (o.publisher) item.publishers.add(o.publisher);
      }
    });

    // SIRALAMA: temel dersler ustte, secmeli/CYDEM altta.
    //
    // Once Map ekleme sirasinda donuyordu — yani veri dosyasindaki
    // siraya bagliydi ve ongorulemezdi. Ogretmen kendi dersini
    // ararken pilot okul dersleri (Coklu Yabanci Dil) ve secmeliler
    // arasinda kaybolmamali.
    const oncelik = (kategori) => {
      const k = (kategori || 'core').toLowerCase();
      if (k === 'core') return 0;
      if (k === 'iho') return 1;
      return 2;
    };
    return Array.from(subjectsMap.values()).sort((a, b) => {
      const fark = oncelik(a.category) - oncelik(b.category);
      if (fark !== 0) return fark;
      return (a.name || '').localeCompare(b.name || '', 'tr');
    });
  }

  getAvailablePublishersFor(gradeLevel, subjectCode, schoolType = 'ALL') {
    const pubSet = new Set();
    this.outcomes.forEach((o) => {
      const g = parseInt(o.gradeLevel) || 0;
      let matchSchool = true;
      if (schoolType === 'PRIMARY') matchSchool = (g >= 1 && g <= 4);
      else if (schoolType === 'MIDDLE') matchSchool = (g >= 5 && g <= 8);
      else if (schoolType === 'HIGH') matchSchool = (g >= 9 && g <= 12);

      const matchGrade = (gradeLevel === 'ALL' || g === parseInt(gradeLevel));
      const matchSubject = (subjectCode === 'ALL' || o.subjectCode === subjectCode);

      if (matchSchool && matchGrade && matchSubject) {
        if (o.publisher) pubSet.add(o.publisher);
      }
    });
    return Array.from(pubSet);
  }

  updateOutcome(updated) {
    const idx = this.outcomes.findIndex((o) => o.id === updated.id);
    if (idx !== -1) {
      this.outcomes[idx] = { ...this.outcomes[idx], ...updated };
    } else {
      this.outcomes.push(updated);
    }
    this.save();
  }

  /**
   * Filtre yeterince daraltılmış mı?
   *
   * 9000+ kaydın tamamını DOM'a basmak 27 MB HTML üretiyor ve paneli
   * kilitliyordu. En az bir sınıf, ders veya arama seçilmiş olmalı.
   */
  static isNarrowEnough(gradeLevel, subjectCode, searchQuery) {
    if (subjectCode && subjectCode !== 'ALL') return true;
    if (gradeLevel && gradeLevel !== 'ALL') return true;
    return Boolean(searchQuery && searchQuery.trim().length >= 3);
  }

  renderTable(schoolType = 'ALL', gradeLevel = 'ALL', subjectCode = 'ALL', publisher = 'ALL', category = 'ALL', searchQuery = '') {
    /**
     * Kaydin geldigi MEB sitesini okunabilir yazar.
     *
     * publisher YALNIZCA okul turudur (Anadolu / Fen / Sosyal
     * Bilimler Lisesi) ve cogu derste bos. Bos rozette "MEB
     * Yayinlari" yazmak yaniltiyordu: o bir okul turu degil,
     * "bilinmiyor" demekti.
     */
    const sourceLabel = (item) => {
      if (item.sourcePortal === 'tymm') return 'MEB TYMM';
      if (item.sourcePortal === 'dogm') return 'MEB DÖGM';
      return '';
    };
    const tbody = document.getElementById('outcomes-tbody');
    if (!tbody) return;

    // Seçim yapılmadan tüm veriyi basma: tarayıcı donuyordu.
    if (!OutcomesManager.isNarrowEnough(gradeLevel, subjectCode, searchQuery)) {
      const total = this.outcomes.length.toLocaleString('tr-TR');
      tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; padding: 44px 20px;">
        <div style="font-size: 34px; margin-bottom: 10px;">🎯</div>
        <strong style="font-size: 15px; color: var(--text-color);">Görüntülemek için bir sınıf veya ders seçin</strong>
        <div style="font-size: 12.5px; color: var(--text-muted); margin-top: 8px; line-height: 1.6;">
          Kütüphanede <strong>${total}</strong> kayıt var. Hepsini birden listelemek
          tarayıcıyı yavaşlattığı için önce yukarıdan<br>
          <strong>Sınıf Seviyesi</strong> veya <strong>Ders / Branş</strong> seçin
          ya da arama kutusuna en az 3 harf yazın.
        </div>
      </td></tr>`;
      this.renderRowInfo(0, 0);
      return;
    }

    const list = this.getFilteredOutcomes(schoolType, gradeLevel, subjectCode, publisher, category, searchQuery);

    if (list.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; color: var(--text-muted); padding: 35px 20px;">
        <div style="font-size: 32px; margin-bottom: 8px;">🔍</div>
        <strong style="font-size: 14px; color: var(--text-color);">Seçilen filtre için henüz kayıt bulunamadı.</strong><br>
        <span style="font-size: 12px; color: var(--text-muted);">
          (${schoolType === 'ALL' ? 'Tüm Kademeler' : schoolType} / ${gradeLevel === 'ALL' ? 'Tüm Sınıflar' : gradeLevel + '. Sınıf'} / ${subjectCode} / Kategori: ${category})
        </span><br><br>
        <button class="btn btn-primary" style="background: linear-gradient(135deg, #10b981, #059669); border:none; padding: 8px 16px; font-size: 12px;" onclick="window.adminApp.syncFromOfficialMaarif()">
          🌐 Resmî Maarif Müfredatını Yükle / Senkronize Et
        </button>
      </td></tr>`;
      this.renderRowInfo(0, 0);
      return;
    }

    // Çok geniş sonuçlarda ilk N satır basılır; gerisi filtre ile daraltılır.
    const shown = list.slice(0, OutcomesManager.MAX_ROWS);
    this.renderRowInfo(shown.length, list.length);

    tbody.innerHTML = shown
      .map((item) => {
        // Rozet ve hafta bayraklari VERIDEN gelir, tahminle degil.
        //
        // Once isMaarif metin aramasina geri dusuyordu (publisher'da
        // "Maarif" geciyor mu) ve olcumde 89 ders rozet almasi
        // gerekirken almiyordu. Veri artik gercek kaynagi tasiyor:
        // program turu Excel sutun basligindan olculuyor.
        //
        // OTP ve sosyal etkinlik haftalari da hafta numarasindan
        // tahmin ediliyordu (8, 17, 29 / 18, 37). Bu haftalar MEB'in
        // her yil tebligle belirledigi takvime gore DEGISIYOR; sabit
        // numara varsaymak yanlis haftayi isaretler.
        const isMaarif = item.isMaarif === true;
        const isOtp = item.isOtpWeek === true;
        const isSocial = item.isSocialEventWeek === true;
        const isHoliday = item.isHolidayWeek;

        let dateStr = '';
        if (item.dateRange && typeof item.dateRange === 'object' && item.dateRange.formatted) {
          dateStr = item.dateRange.formatted;
        } else if (item.dateRangeStr) {
          dateStr = item.dateRangeStr;
        }

        const pubBadge = `<span class="badge" style="font-size: 10px; background: ${isMaarif ? 'rgba(16, 185, 129, 0.15)' : 'rgba(100, 116, 139, 0.12)'}; color: ${isMaarif ? '#059669' : 'var(--text-muted)'}; border: 1px solid ${isMaarif ? 'rgba(16, 185, 129, 0.3)' : 'transparent'};">
          ${item.publisher || sourceLabel(item) || 'Resmî plan yok'} ${isMaarif ? '• Maarif' : ''}
        </span>`;

        let statusBadge = '<span class="badge" style="background: rgba(16,185,129,0.1); color: #059669;">Ders</span>';
        if (isHoliday) {
          statusBadge = '<span class="badge badge-break" style="background: rgba(245, 158, 11, 0.15); color: #d97706;">🏖️ Tatil</span>';
        } else if (isOtp) {
          statusBadge = '<span class="badge" style="background: rgba(245, 158, 11, 0.2); color: #b45309; font-weight: 700;">🎯 OTP</span>';
        } else if (isSocial) {
          statusBadge = '<span class="badge" style="background: rgba(236, 72, 153, 0.18); color: #be185d; font-weight: 700;">🎭 Sosyal Etk.</span>';
        } else if (item.isPlaceholder) {
          // Resmî planda karşılığı olmayan hafta; yöneticinin görmesi gerekir.
          statusBadge = '<span class="badge" style="background: rgba(239, 68, 68, 0.14); color: #b91c1c; font-weight: 700;">⚠️ Planlanmamış</span>';
        }

        // Resmî MEB planından gelen kayıtlar kodlu değer listesi taşır.
        const officialBadge = item.hasOfficialMeta
          ? '<span class="badge" style="font-size: 9.5px; background: rgba(79,70,229,0.12); color: var(--primary); margin-left: 4px;">Resmî Plan</span>'
          : '';

        const e = OutcomesManager.escapeHtml;
        const metaRow = (label, value, color) =>
          value
            ? `<div style="font-size: 10.5px; color: ${color}; margin-top: 3px;"><strong>${label}:</strong> ${e(value)}</div>`
            : '';

        return `
        <tr style="${isHoliday ? 'background: rgba(245, 158, 11, 0.04);' : (item.isPlaceholder ? 'background: rgba(239, 68, 68, 0.03);' : (isOtp ? 'background: rgba(245, 158, 11, 0.02);' : ''))}">
          <td style="white-space: nowrap;">
            <strong style="color: var(--primary); font-size: 13px;">${item.weekNumber}. Hafta</strong>
            ${item.teachingWeekNumber ? `<span style="font-size: 10px; color: var(--text-muted);"> (${item.teachingWeekNumber}. ders)</span>` : ''}
            <div style="font-size: 10.5px; color: var(--text-muted); margin-top: 2px;">${item.gradeLevel}. Sınıf - ${e(item.subjectName)}</div>
            ${dateStr ? `<div style="font-size: 10px; color: var(--text-muted); margin-top: 1px;">📅 ${e(dateStr)}</div>` : ''}
          </td>
          <td>
            <div style="font-weight: 600; color: var(--text-color); margin-bottom: 3px;">${e(item.unitTitle)}</div>
            ${pubBadge}${officialBadge}
          </td>
          <td style="font-size: 12px; color: var(--text-color);">${e(item.topicTitle)}</td>
          <td><code style="font-weight: 700; font-size: 11px; color: var(--primary); background: rgba(79, 70, 229, 0.08); padding: 2px 6px; border-radius: 4px;">${e(item.outcomeCode) || '-'}</code></td>
          <td style="max-width: 380px; font-size: 12px; line-height: 1.45; color: var(--text-color);">
            <div>${e(item.outcomeDescription)}</div>
            ${item.maarifSummary ? `<div style="font-size: 11px; color: #059669; margin-top: 5px; background: rgba(16, 185, 129, 0.08); padding: 5px 7px; border-radius: 6px; border-left: 2px solid #10b981;">💡 <strong>Maarif Özeti:</strong> ${e(item.maarifSummary)}</div>` : ''}
            ${metaRow('🏅 Değerler', item.maarifValues, '#b45309')}
            ${metaRow('🧠 Beceriler', item.maarifSkills, '#4f46e5')}
            ${metaRow('🎯 Farklılaştırma', item.differentiation, 'var(--text-muted)')}
          </td>
          <td>${statusBadge}</td>
          <td style="text-align: right; white-space: nowrap;">
            <button class="btn btn-secondary" style="padding: 4px 10px; font-size: 11px;" onclick="window.adminApp.editOutcome('${e(item.id)}')">
              ✏️ Düzenle
            </button>
          </td>
        </tr>
      `;
      })
      .join('');
  }

  /** Tablo üstünde "N / M kayıt gösteriliyor" bilgisini yazar. */
  renderRowInfo(shown, total) {
    const el = document.getElementById('outcomes-row-info');
    if (!el) return;
    if (total === 0) {
      el.textContent = '';
      return;
    }
    el.textContent = shown < total
      ? `${shown} / ${total.toLocaleString('tr-TR')} kayıt gösteriliyor — daraltmak için ders seçin`
      : `${total.toLocaleString('tr-TR')} kayıt`;
  }

  /** MEB metinleri tırnak ve < > içerebiliyor; HTML'e ham gömmek tabloyu bozar. */
  static escapeHtml(value) {
    if (value === null || value === undefined) return '';
    return String(value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }
}

window.OutcomesManager = OutcomesManager;
