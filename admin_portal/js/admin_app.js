/**
 * SınıfCepte Web Admin Paneli - Ana Uygulama Mantığı & State Yöneticisi
 */
class AdminApp {
  constructor() {
    this.calendarManager = new CalendarManager();
    this.outcomesManager = new OutcomesManager();
    this.manifestManager = new ManifestManager();
    this.examsManager = new ExamsManager();
    this.wizardEventsTemp = [];
    this.parsedEventsTemp = [];
    this.parsedExcelPlans = [];
    this.currentSelectedExcelPlanIndex = 0;

    this.initTheme();
    this.initEventListeners();
    this.updateDashboardStats();
    this.renderAll();
  }

  initTheme() {
    const savedTheme = localStorage.getItem('sinifcepte_admin_theme') || 'light';
    document.documentElement.setAttribute('data-theme', savedTheme);
  }

  toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || 'light';
    const next = current === 'light' ? 'dark' : 'light';
    document.documentElement.setAttribute('data-theme', next);
    localStorage.setItem('sinifcepte_admin_theme', next);
    this.showToast(`Tema değiştirildi: ${next === 'dark' ? 'Koyu Mod 🌙' : 'Aydınlık Mod ☀️'}`, 'info');
  }

  switchTab(tabId) {
    document.querySelectorAll('.tab-content').forEach((el) => el.classList.remove('active'));
    document.querySelectorAll('.menu-item').forEach((el) => el.classList.remove('active'));

    const targetTab = document.getElementById(`tab-${tabId}`);
    const targetMenu = document.querySelector(`.menu-item[data-tab="${tabId}"]`);

    if (targetTab) targetTab.classList.add('active');
    if (targetMenu) targetMenu.classList.add('active');

    const titles = {
      dashboard: { title: 'Genel Bakış & İstatistikler', sub: 'SınıfCepte Bulut Yönetim Merkezi' },
      calendar: { title: 'MEB Akademik Takvim Yöneticisi', sub: `${this.calendarManager.selectedYear} Resmî Tatil & Dönem Tarihleri` },
      outcomes: { title: 'Müfredat ve 36 Haftalık Kazanım Kütüphanesi', sub: '1-12. Sınıflar Tüm Branşlar' },
      exams: { title: 'MEB & ÖSYM Resmî Sınav Takvimi', sub: 'LGS, YKS, MEB Ortak Sınavlar ve Kurumsal Sınav Takvimi' },
      manifest: { title: 'Versiyon Manifesti & Sistem Duyuruları', sub: 'Mobil Uygulama Senkronizasyonu & Bakım Modu' },
    };

    if (titles[tabId]) {
      const pTitle = document.getElementById('page-title');
      const pSub = document.getElementById('page-subtitle');
      if (pTitle) pTitle.innerText = titles[tabId].title;
      if (pSub) pSub.innerText = titles[tabId].sub;
    }

    this.updateDashboardStats();
    if (tabId === 'calendar') this.calendarManager.renderTable();
    if (tabId === 'outcomes') this.refreshOutcomesTable();
    if (tabId === 'exams') this.renderExamsTable();
    if (tabId === 'manifest') {
      this.manifestManager.renderAnnouncementsTable();
      this.renderManifestUI();
    }
  }

  updateDashboardStats() {
    const totalOutcomes = this.outcomesManager.outcomes.length;
    const currentYearEvents = this.calendarManager.getEvents(this.calendarManager.selectedYear).length;
    const totalExams = this.examsManager.getAllExams().length;
    const calVer = this.manifestManager.manifest.calendarVersion;
    const outVer = this.manifestManager.manifest.outcomesVersion;

    const elOut = document.getElementById('stat-total-outcomes');
    const elEv = document.getElementById('stat-total-events');
    const elEx = document.getElementById('stat-total-exams');
    const elVer = document.getElementById('stat-manifest-version');
    const elYear = document.getElementById('stat-active-year');

    if (elOut) elOut.innerText = totalOutcomes;
    if (elEv) elEv.innerText = currentYearEvents;
    if (elEx) elEx.innerText = totalExams;
    if (elVer) elVer.innerText = `v${calVer}.${outVer}`;
    if (elYear) elYear.innerText = this.calendarManager.selectedYear;
  }

  renderAll() {
    this.calendarManager.renderTable();
    const initSchoolType = document.getElementById('outcomes-school-type-select')?.value || 'HIGH';
    this.populateGradeOptions(initSchoolType);
    this.populateSubjectOptions();
    this.refreshOutcomesTable();
    this.renderExamsTable();
    this.manifestManager.renderAnnouncementsTable();
    this.renderManifestUI();
  }

  // --- TAKVİM YIL SEÇİCİ & YÖNETİMİ ---

  handleCalendarYearChange(year) {
    if (year === '__new__') {
      const newYear = prompt('Lütfen yeni eğitim öğretim yılını giriniz (Örn: 2027-2028):', '2027-2028');
      if (newYear && newYear.trim()) {
        const cleaned = newYear.trim();
        this.calendarManager.selectedYear = cleaned;
        this.openCalendarWizardModal(cleaned);
      } else {
        this.calendarManager.renderTable();
      }
      return;
    }

    this.calendarManager.selectedYear = year;
    this.calendarManager.renderTable(year);
    this.updateDashboardStats();
    this.showToast(`${year} Eğitim Öğretim Yılı seçildi 📅`, 'info');
  }

  // --- TAKVİM MANUEL İŞLEMLERİ ---

  openAddCalendarModal() {
    const form = document.getElementById('calendar-form');
    if (form) form.reset();
    const idEl = document.getElementById('cal-event-id');
    if (idEl) idEl.value = '';
    const titleEl = document.getElementById('modal-cal-title');
    if (titleEl) titleEl.innerText = `${this.calendarManager.selectedYear} İçin Yeni Takvim Olayı Ekle`;
    this.openModal('modal-calendar');
  }

  editCalendarEvent(id) {
    const event = this.calendarManager.events.find((e) => e.id === id);
    if (!event) return;

    const idEl = document.getElementById('cal-event-id');
    const titleEl = document.getElementById('cal-title');
    const descEl = document.getElementById('cal-description');
    const catEl = document.getElementById('cal-category');
    const startEl = document.getElementById('cal-start-date');
    const endEl = document.getElementById('cal-end-date');
    const holEl = document.getElementById('cal-is-holiday');
    const mTitleEl = document.getElementById('modal-cal-title');

    if (idEl) idEl.value = event.id;
    if (titleEl) titleEl.value = event.title;
    if (descEl) descEl.value = event.description || '';
    if (catEl) catEl.value = event.category;
    if (startEl) startEl.value = event.startDate;
    if (endEl) endEl.value = event.endDate;
    if (holEl) holEl.checked = !!event.isOfficialHoliday;
    if (mTitleEl) mTitleEl.innerText = 'Takvim Olayını Düzenle';

    this.openModal('modal-calendar');
  }

  saveCalendarEvent(e) {
    e.preventDefault();
    const id = document.getElementById('cal-event-id')?.value;
    const title = document.getElementById('cal-title')?.value;
    const desc = document.getElementById('cal-description')?.value;
    const category = document.getElementById('cal-category')?.value;
    const startDate = document.getElementById('cal-start-date')?.value;
    const endDate = document.getElementById('cal-end-date')?.value;
    const isHoliday = document.getElementById('cal-is-holiday')?.checked;

    const payload = {
      id: id || 'meb_' + Date.now(),
      title,
      description: desc,
      category,
      startDate,
      endDate,
      academicYear: this.calendarManager.selectedYear,
      isOfficialHoliday: isHoliday,
    };

    if (id) {
      this.calendarManager.updateEvent(payload);
      this.showToast('Takvim olayı güncellendi ✨', 'success');
    } else {
      this.calendarManager.addEvent(payload);
      this.showToast('Yeni takvim olayı eklendi 🚩', 'success');
    }

    this.manifestManager.incrementCalendarVersion();
    this.closeModal('modal-calendar');
    this.calendarManager.renderTable();
    this.updateDashboardStats();
  }

  deleteCalendarEvent(id) {
    if (confirm('Bu takvim olayını silmek istediğinize emin misiniz?')) {
      this.calendarManager.deleteEvent(id);
      this.manifestManager.incrementCalendarVersion();
      this.calendarManager.renderTable();
      this.updateDashboardStats();
      this.showToast('Takvim olayı silindi 🗑️', 'info');
    }
  }

  // --- 1. DÜĞME: MEB TAKVİM SİHİRBAZI (STANDART ŞABLON & CANLI DÜZENLEME) ---

  openCalendarWizardModal(prefilledYear = null) {
    const year = prefilledYear || this.calendarManager.selectedYear || '2026-2027';
    const yearInput = document.getElementById('wizard-year');
    const dateInput = document.getElementById('wizard-start-date');

    if (yearInput) yearInput.value = year;
    if (dateInput) {
      const baseYear = parseInt(year.split('-')[0]) || 2026;
      dateInput.value = `${baseYear}-09-14`; // 14 Eylül varsayılan
    }

    this.previewWizardCalendar();
    this.openModal('modal-wizard');
  }

  previewWizardCalendar() {
    const year = document.getElementById('wizard-year')?.value || '2026-2027';
    const startDate = document.getElementById('wizard-start-date')?.value || '2026-09-14';

    const events = CalendarWizard.generateFullCalendar(startDate, year);
    this.wizardEventsTemp = events;

    const container = document.getElementById('wizard-events-list');
    if (!container) return;

    container.innerHTML = events
      .map((ev, index) => {
        const isSingleDay = ev.startDate === ev.endDate;
        return `
        <div style="background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 10px; padding: 10px 14px; margin-bottom: 8px; display: grid; grid-template-columns: 1fr auto auto; gap: 12px; align-items: center;">
          <div>
            <strong style="font-size: 13px; color: var(--text-main);">${ev.title}</strong>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">${ev.description || ''}</div>
          </div>
          <div>
            ${this.calendarManager.getCategoryBadge(ev.category)}
          </div>
          <div style="display: flex; align-items: center; gap: 6px;">
            <input type="date" id="wiz-start-${index}" class="form-control" style="width: 130px; font-size: 12px; padding: 4px 6px;" value="${ev.startDate}">
            ${
              !isSingleDay
                ? `<span style="font-size: 12px; color: var(--text-muted);">-</span>
                   <input type="date" id="wiz-end-${index}" class="form-control" style="width: 130px; font-size: 12px; padding: 4px 6px;" value="${ev.endDate}">`
                : `<input type="hidden" id="wiz-end-${index}" value="${ev.endDate}">`
            }
          </div>
        </div>
      `;
      })
      .join('');
  }

  handleCalendarWizardSubmit(e) {
    e.preventDefault();
    const year = document.getElementById('wizard-year')?.value || '2026-2027';

    // Canlı tablodaki düzenlenmiş tarihleri topla
    const updatedEvents = this.wizardEventsTemp.map((ev, index) => {
      const startEl = document.getElementById(`wiz-start-${index}`);
      const endEl = document.getElementById(`wiz-end-${index}`);
      return {
        ...ev,
        academicYear: year,
        startDate: startEl ? startEl.value : ev.startDate,
        endDate: endEl ? endEl.value : (startEl ? startEl.value : ev.endDate),
      };
    });

    // O yılın eski takvimini tamamen temizle ve bu standart listeyi kaydet
    this.calendarManager.replaceYearEvents(year, updatedEvents);
    this.calendarManager.selectedYear = year;

    this.manifestManager.incrementCalendarVersion();
    this.closeModal('modal-wizard');
    this.calendarManager.renderTable(year);
    this.updateDashboardStats();
    this.showToast(`📅 ${year} yılı resmî standart MEB takvimi oluşturuldu ve kaydedildi! 🚀`, 'success');
  }

  /**
   * MEB takvim sayfasındaki tatil tarihleriyle kazanım kartlarındaki tatil
   * haftalarını karşılaştırır ve farkı gösterir.
   *
   * Panelde bu iki sistem birbirinden bağımsızdı: takvimde ara tatili
   * değiştirmek kartlardaki hafta yapısını etkilemiyordu ve tutarsızlık
   * hiçbir yerde görünmüyordu.
   */
  checkCalendarAgainstOutcomes() {
    const year = this.calendarManager.selectedYear;
    const events = this.calendarManager.getEvents(year);
    const { weeks, warnings } = CalendarToWeeks.buildWeeks(events);

    if (!weeks.length) {
      this.showToast(`❌ ${warnings[0] || 'Takvimden hafta yapısı üretilemedi.'}`, 'error');
      return;
    }

    const calendarHolidays = weeks.filter((w) => w.isHolidayWeek).map((w) => w.weekNumber);

    // Kazanım kartlarındaki tatil haftaları
    const outcomeHolidays = [
      ...new Set(
        this.outcomesManager.outcomes
          .filter((o) => o.isHolidayWeek)
          .map((o) => o.weekNumber)
      ),
    ].sort((a, b) => a - b);

    const onlyInCalendar = calendarHolidays.filter((w) => !outcomeHolidays.includes(w));
    const onlyInOutcomes = outcomeHolidays.filter((w) => !calendarHolidays.includes(w));
    const matches = onlyInCalendar.length === 0 && onlyInOutcomes.length === 0;

    const lines = [
      `Takvim tatil haftaları : ${calendarHolidays.join(', ') || '(yok)'}`,
      `Kartlardaki tatiller   : ${outcomeHolidays.join(', ') || '(yok)'}`,
      `Ders haftası sayısı    : ${Math.max(...weeks.map((w) => w.teachingWeekNumber || 0))}`,
    ];
    if (onlyInCalendar.length) lines.push(`Yalnızca takvimde: ${onlyInCalendar.join(', ')}. hafta`);
    if (onlyInOutcomes.length) lines.push(`Yalnızca kartlarda: ${onlyInOutcomes.join(', ')}. hafta`);
    warnings.forEach((w) => lines.push(`Uyarı: ${w}`));

    console.info(`[${year}] Takvim / kazanım karşılaştırması\n` + lines.join('\n'));

    if (matches && !warnings.length) {
      this.showToast(
        `✅ Takvim ve kazanım kartları uyumlu (tatil haftaları: ${calendarHolidays.join(', ')}).`,
        'success'
      );
      return;
    }

    this.showToast(
      `⚠️ Takvim ile kartlar uyuşmuyor. Takvim: ${calendarHolidays.join(', ')} | ` +
        `Kartlar: ${outcomeHolidays.join(', ')}. Ayrıntı için tarayıcı konsoluna bakın.`,
      'error'
    );
    this.downloadOutcomesOverride(year, events);
  }

  /**
   * Takvimden üretilen hafta yapısını Python boru hattının okuduğu
   * overrides JSON'u olarak indirir.
   */
  downloadOutcomesOverride(year, events) {
    const source = events || this.calendarManager.getEvents(year);
    const otpWeeks = [
      ...new Set(this.outcomesManager.outcomes.filter((o) => o.isOtpWeek).map((o) => o.weekNumber)),
    ].sort((a, b) => a - b);
    const socialEventWeeks = [
      ...new Set(
        this.outcomesManager.outcomes.filter((o) => o.isSocialEventWeek).map((o) => o.weekNumber)
      ),
    ].sort((a, b) => a - b);

    const { override } = CalendarToWeeks.toOverrideJson(source, year, { otpWeeks, socialEventWeeks });
    if (!override) return;

    CloudExporter.downloadFile(`${year}.json`, JSON.stringify(override, null, 2));
    console.info(
      `İndirilen ${year}.json dosyasını scripts/maarif/overrides/ altına koyup calıştırın:\n` +
        `  python scripts/maarif/build_curriculum.py --year ${year}`
    );
  }

  // --- 2. DÜĞME: AKILLI GENELGE AYRIŞTIRICI & EKSİK KONTROLÜ ---

  openSmartParserModal() {
    const form = document.getElementById('smart-parser-form');
    if (form) form.reset();
    const yearInput = document.getElementById('circular-year');
    if (yearInput) yearInput.value = this.calendarManager.selectedYear || '2026-2027';
    const preview = document.getElementById('parser-preview-area');
    if (preview) preview.style.display = 'none';
    this.parsedEventsTemp = [];
    this.openModal('modal-smart-parser');
  }

  handleSmartParserSubmit(e) {
    e.preventDefault();
    const rawText = document.getElementById('circular-raw-text')?.value || '';
    const defaultYear = document.getElementById('circular-year')?.value || '2026-2027';

    if (!rawText.trim()) {
      this.showToast('Lütfen genelge metnini yapıştırınız!', 'error');
      return;
    }

    const { academicYear, events, missingMilestones } = SmartCircularParser.parseCircularText(rawText, defaultYear);

    const yearInput = document.getElementById('circular-year');
    if (yearInput) yearInput.value = academicYear;

    if (events.length === 0) {
      this.showToast('Metinden takvim olayı çıkarılamadı. Lütfen tarih içeren cümleleri kontrol ediniz.', 'error');
      return;
    }

    this.parsedEventsTemp = events;

    // Eksik Uyarı Kutusu Render
    const warnBox = document.getElementById('parser-warnings-box');
    if (warnBox) {
      if (missingMilestones.length > 0) {
        warnBox.innerHTML = `
          <div style="background: rgba(245, 158, 11, 0.12); border: 1px solid var(--warning); border-radius: 10px; padding: 12px 16px; margin-bottom: 14px; color: #b45309; font-size: 12.5px;">
            <strong>⚠️ Eksik MEB Dönüm Noktası Uyarısı:</strong><br>
            Aşağıdaki standart olay(lar) yapıştırılan genelge metninde bulunamadı:
            <ul style="margin: 6px 0 0 18px; font-weight: 700;">
              ${missingMilestones.map((m) => `<li>${m}</li>`).join('')}
            </ul>
            <span style="font-size: 11.5px; opacity: 0.9;">Tarihleri aşağıdaki kutulardan tamamlayabilir veya sonrasında Takvim Sihirbazı ile eksiksiz şablonu oluşturabilirsiniz.</span>
          </div>
        `;
      } else {
        warnBox.innerHTML = `
          <div style="background: rgba(16, 185, 129, 0.12); border: 1px solid #10B981; border-radius: 10px; padding: 10px 14px; margin-bottom: 14px; color: #047857; font-size: 12.5px; font-weight: 700;">
            ✅ Harika! Tüm 6 temel MEB dönüm noktası metinden başarıyla ayrıştırıldı.
          </div>
        `;
      }
    }

    // Tespit Edilen Olaylar (Canlı Düzenlenebilir)
    const listHtml = events
      .map((ev, index) => {
        const isSingleDay = ev.startDate === ev.endDate;
        return `
        <div style="background: var(--bg-card); border: 1px solid var(--border-color); border-radius: 10px; padding: 10px 14px; margin-bottom: 8px; display: grid; grid-template-columns: 1fr auto auto; gap: 12px; align-items: center;">
          <div>
            <strong style="font-size: 13px; color: var(--text-main);">${ev.title}</strong>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">${ev.description || ''}</div>
          </div>
          <div>
            ${this.calendarManager.getCategoryBadge(ev.category)}
          </div>
          <div style="display: flex; align-items: center; gap: 6px;">
            <input type="date" id="parse-start-${index}" class="form-control" style="width: 130px; font-size: 12px; padding: 4px 6px;" value="${ev.startDate}">
            ${
              !isSingleDay
                ? `<span style="font-size: 12px; color: var(--text-muted);">-</span>
                   <input type="date" id="parse-end-${index}" class="form-control" style="width: 130px; font-size: 12px; padding: 4px 6px;" value="${ev.endDate}">`
                : `<input type="hidden" id="parse-end-${index}" value="${ev.endDate}">`
            }
          </div>
        </div>
      `;
      })
      .join('');

    const resultsList = document.getElementById('parser-results-list');
    const previewArea = document.getElementById('parser-preview-area');
    if (resultsList) resultsList.innerHTML = listHtml;
    if (previewArea) previewArea.style.display = 'block';
    this.showToast(`${events.length} adet olay ayrıştırıldı! 🎉`, 'success');
  }

  applyParsedCircularEvents() {
    if (!this.parsedEventsTemp || this.parsedEventsTemp.length === 0) {
      this.showToast('Önce genelge metnini ayrıştırınız!', 'error');
      return;
    }

    const year = document.getElementById('circular-year')?.value || '2026-2027';

    // Düzenlenen tarihleri topla
    const updatedEvents = this.parsedEventsTemp.map((ev, index) => {
      const startEl = document.getElementById(`parse-start-${index}`);
      const endEl = document.getElementById(`parse-end-${index}`);
      return {
        ...ev,
        academicYear: year,
        startDate: startEl ? startEl.value : ev.startDate,
        endDate: endEl ? endEl.value : (startEl ? startEl.value : ev.endDate),
      };
    });

    // O yılın takvimine aktar
    this.calendarManager.replaceYearEvents(year, updatedEvents);
    this.calendarManager.selectedYear = year;

    this.manifestManager.incrementCalendarVersion();
    this.closeModal('modal-smart-parser');
    this.calendarManager.renderTable(year);
    this.updateDashboardStats();
    this.showToast(`${updatedEvents.length} adet takvim olayı ${year} yılına başarıyla aktarıldı! 🚀`, 'success');
  }

  // --- HAZIR TTKB KAZANIM PAKETLERİ METODLARI ---

  openCurriculumPresetsModal() {
    this.openModal('modal-presets');
  }

  handleApplyPreset(presetKey) {
    const count = CurriculumPresets.applyPreset(presetKey, this.outcomesManager);
    this.manifestManager.incrementOutcomesVersion();
    this.closeModal('modal-presets');
    this.refreshOutcomesTable();
    this.updateDashboardStats();
    this.showToast(`Hazır TTKB Paketi yüklendi (${count} haftalık kazanım) 🚀`, 'success');
  }

  // --- KAZANIM İŞLEMLERİ ---

  handleSchoolTypeChange(schoolType) {
    this.populateGradeOptions(schoolType);
    this.populateSubjectOptions();
    this.refreshOutcomesTable();
  }

  handleGradeChange() {
    this.populateSubjectOptions();
    this.refreshOutcomesTable();
  }

  populateGradeOptions(schoolType) {
    const gradeSelect = document.getElementById('outcomes-grade-select');
    if (!gradeSelect) return;

    let grades = [];
    if (schoolType === 'PRIMARY') grades = [1, 2, 3, 4];
    else if (schoolType === 'MIDDLE') grades = [5, 6, 7, 8];
    else if (schoolType === 'HIGH') grades = [9, 10, 11, 12];
    else if (schoolType === 'IHO') grades = [5, 6, 7, 8, 9, 10, 11, 12];
    else grades = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

    const currentVal = gradeSelect.value;
    let html = '<option value="ALL">Tüm Sınıflar</option>';
    grades.forEach((g) => {
      html += `<option value="${g}">${g}. Sınıf</option>`;
    });
    gradeSelect.innerHTML = html;

    // Kullanıcının seçimi korunur; kademeye uymuyorsa 'Tüm Sınıflar'a
    // dönülür. Eskiden zorla 10. sınıfa atlıyordu ve 1-8 çalışan bir
    // yönetici her kademe değişiminde yeniden seçim yapmak zorunda kalıyordu.
    gradeSelect.value = grades.includes(parseInt(currentVal)) ? currentVal : 'ALL';
  }

  populateSubjectOptions() {
    const schoolTypeSelect = document.getElementById('outcomes-school-type-select');
    const gradeSelect = document.getElementById('outcomes-grade-select');
    const subjectSelect = document.getElementById('outcomes-subject-select');
    if (!subjectSelect) return;

    const schoolType = schoolTypeSelect ? schoolTypeSelect.value : 'ALL';
    const grade = gradeSelect ? gradeSelect.value : 'ALL';

    const subjects = this.outcomesManager.getAvailableSubjectsForGrade(grade, schoolType);
    const currentVal = subjectSelect.value;

    let html = '<option value="ALL">🌟 Tüm Branşlar</option>';
    
    const iconMap = {
      TURKCE: '📚', EDEBIYAT: '📖', MAT: '📐', FEN: '🔬', FIZIK: '⚡', KIMYA: '🧪', BIYOLOJI: '🧬',
      SOSYAL: '🌍', INKILAP: '🏛️', TARIH: '🏛️', COGRAFYA: '🌍', FELSEFE: '🤔', HAYAT: '🌱',
      INGILIZCE: '🇬🇧', ALMANCA: '🇩🇪', BILISIM: '💻', DIN: '🕌', BEDEN: '🏃', GORSEL: '🎨',
      MUZIK: '🎵', TEKNO_TASARIM: '⚙️', REHBERLIK: '🧭', KURAN: '📖', PEYGAMBER: '🕊️',
      SAGLIK: '🩺', HAREZMI: '🤖', ARAPCA: '🇸🇦', YAZARLIK: '✍️',
      // İHÖ ve seçmeli dersler ayrı kodlar aldı; ikonsuz kalmasınlar.
      SIYER: '🕊️', FIKIH: '⚖️', HADIS: '📜', TEFSIR: '📜', KELAM: '💭',
      AKAID: '🤲', HITABET: '🗣️', ISLAM_KULTUR: '🕌', TEMEL_DINI: '🕌',
      KURAN_ANLAM: '📖', AIHL_MESLEK: '🕌', PSIKOLOJI: '🧠', SOSYOLOJI: '👥',
      MANTIK: '🧩', SOSYAL_BILIM: '🔍', MAT_BILIM_UYG: '🔭', BILIM_UYG: '🔭',
      BEDEN_TEMEL: '🏃', ATLETIK_PERF: '🏅'
    };

    // Kategoriye göre grupla: zorunlu dersler önce, sonra seçmeli/İHÖ.
    const groups = { core: [], elective: [], iho: [], course: [], harezmi: [] };
    subjects.forEach((item) => {
      (groups[item.category] || groups.core).push(item);
    });

    const groupLabels = {
      core: '📗 Zorunlu Dersler',
      elective: '📙 Seçmeli Dersler',
      iho: '🕌 İmam Hatip Dersleri',
      course: '📕 Kurslar',
      harezmi: '🤖 Harezmî',
    };

    for (const [key, items] of Object.entries(groups)) {
      if (items.length === 0) continue;
      items.sort((a, b) => (a.name || '').localeCompare(b.name || '', 'tr'));
      html += `<optgroup label="${groupLabels[key]}">`;
      items.forEach((item) => {
        const icon = iconMap[item.code] || '📘';
        html += `<option value="${item.code}">${icon} ${item.name} (${item.count})</option>`;
      });
      html += '</optgroup>';
    }

    subjectSelect.innerHTML = html;
    
    if (subjects.some((s) => s.code === currentVal)) {
      subjectSelect.value = currentVal;
    } else {
      subjectSelect.value = 'ALL';
    }
  }

  setCategoryFilter(category, btnEl) {
    this.outcomesManager.currentCategory = category || 'ALL';
    const container = document.getElementById('outcomes-category-pills');
    if (container) {
      container.querySelectorAll('.btn-pill').forEach((b) => b.classList.remove('active'));
    }
    if (btnEl) btnEl.classList.add('active');
    this.refreshOutcomesTable();
  }

  handleOutcomesSearch(query) {
    this.outcomesManager.searchQuery = query || '';
    this.refreshOutcomesTable();
  }

  syncFromOfficialMaarif() {
    let count;
    try {
      count = this.outcomesManager.syncWithOfficialPresets();
    } catch (error) {
      // Eskiden 0 kayıt yüklense bile başarı mesajı gösteriliyordu.
      console.error('Maarif senkronizasyonu başarısız:', error);
      this.showToast(`❌ Senkronizasyon başarısız: ${error.message}`, 'error');
      return;
    }

    this.manifestManager.incrementOutcomesVersion();
    this.renderManifestUI();
    const initSchoolType = document.getElementById('outcomes-school-type-select')?.value || 'HIGH';
    this.populateGradeOptions(initSchoolType);
    this.populateSubjectOptions();
    this.refreshOutcomesTable();
    this.updateDashboardStats();

    const year = this.outcomesManager.officialPresetYear() || '';
    this.showToast(
      `🌐 ${count} adet resmî MEB Maarif kazanımı${year ? ` (${year})` : ''} başarıyla yüklendi! 🚀`,
      'success'
    );
  }

  refreshOutcomesTable() {
    const schoolTypeSelect = document.getElementById('outcomes-school-type-select');
    const gradeSelect = document.getElementById('outcomes-grade-select');
    const subjectSelect = document.getElementById('outcomes-subject-select');
    const publisherSelect = document.getElementById('outcomes-publisher-select');
    const searchInput = document.getElementById('outcomes-search-input');

    const schoolType = schoolTypeSelect ? schoolTypeSelect.value : 'ALL';
    const grade = gradeSelect ? gradeSelect.value : 'ALL';
    const subject = subjectSelect ? subjectSelect.value : 'ALL';
    const publisher = publisherSelect ? publisherSelect.value : 'ALL';
    const category = this.outcomesManager.currentCategory || 'ALL';
    const searchQuery = searchInput ? searchInput.value : (this.outcomesManager.searchQuery || '');

    // Dinamik Yayınevi Seçiciyi Güncelle
    if (publisherSelect) {
      const currentVal = publisherSelect.value;
      const availablePubs = this.outcomesManager.getAvailablePublishersFor(grade, subject, schoolType);
      let optionsHtml = '<option value="ALL">Tüm Yayınlar</option>';
      availablePubs.forEach((p) => {
        optionsHtml += `<option value="${p}" ${p === currentVal ? 'selected' : ''}>${p}</option>`;
      });
      publisherSelect.innerHTML = optionsHtml;
    }

    this.outcomesManager.renderTable(schoolType, grade, subject, publisher, category, searchQuery);
  }

  /**
   * Kazanımı düzenleme modalında açar.
   *
   * Eskiden üç ardışık prompt() kutusu vardı ve Maarif alanlarına
   * (özet, değerler, beceriler, farklılaştırma) hiç dokunulamıyordu.
   */
  editOutcome(id) {
    const item = this.outcomesManager.outcomes.find((o) => o.id === id);
    if (!item) {
      this.showToast('Kazanım bulunamadı.', 'error');
      return;
    }

    const set = (elementId, value) => {
      const el = document.getElementById(elementId);
      if (el) el.value = value || '';
    };

    set('edit-outcome-id', item.id);
    set('edit-outcome-code', item.outcomeCode);
    set('edit-outcome-unit', item.unitTitle);
    set('edit-outcome-topic', item.topicTitle);
    set('edit-outcome-desc', item.outcomeDescription);
    set('edit-outcome-summary', item.maarifSummary);
    set('edit-outcome-values', item.maarifValues);
    set('edit-outcome-skills', item.maarifSkills);
    set('edit-outcome-diff', item.differentiation);

    const context = document.getElementById('edit-outcome-context');
    if (context) {
      context.textContent =
        `${item.gradeLevel}. Sınıf · ${item.subjectName} · ${item.publisher} · ` +
        `${item.weekNumber}. Hafta${item.dateRangeStr ? ` (${item.dateRangeStr})` : ''}`;
    }

    this.openModal('modal-edit-outcome');
  }

  handleEditOutcomeSubmit(e) {
    e.preventDefault();
    const id = document.getElementById('edit-outcome-id')?.value;
    const item = this.outcomesManager.outcomes.find((o) => o.id === id);
    if (!item) {
      this.showToast('Kazanım bulunamadı.', 'error');
      return;
    }

    const get = (elementId) => (document.getElementById(elementId)?.value || '').trim();

    const description = get('edit-outcome-desc');
    if (!description) {
      this.showToast('Kazanım açıklaması boş bırakılamaz.', 'error');
      return;
    }

    item.outcomeCode = get('edit-outcome-code') || null;
    item.unitTitle = get('edit-outcome-unit') || item.unitTitle;
    item.topicTitle = get('edit-outcome-topic') || item.topicTitle;
    item.outcomeDescription = description;
    item.maarifSummary = get('edit-outcome-summary') || null;
    item.maarifValues = get('edit-outcome-values') || null;
    item.maarifSkills = get('edit-outcome-skills') || null;
    item.differentiation = get('edit-outcome-diff') || null;
    // Elle düzenlenen hafta artık "planlanmamış" sayılmaz.
    if (item.isPlaceholder) item.isPlaceholder = false;

    this.outcomesManager.save();
    this.manifestManager.incrementOutcomesVersion();
    this.renderManifestUI();
    this.closeModal('modal-edit-outcome');
    this.refreshOutcomesTable();
    this.showToast('Kazanım güncellendi ✏️', 'success');
  }

  openBulkImportModal() {
    const form = document.getElementById('bulk-import-form');
    if (form) form.reset();
    this.openModal('modal-bulk-import');
  }

  handleBulkImport(e) {
    e.preventDefault();
    const grade = document.getElementById('outcomes-grade-select')?.value || 5;
    const subjectSelect = document.getElementById('outcomes-subject-select');
    const subjectCode = subjectSelect ? subjectSelect.value : 'MAT';
    const subjectName = subjectSelect && subjectSelect.selectedOptions.length > 0 ? subjectSelect.selectedOptions[0].text : 'Matematik';
    const rawText = document.getElementById('bulk-import-text')?.value || '';

    if (!rawText.trim()) {
      this.showToast('Lütfen içe aktarılacak metni yapıştırınız!', 'error');
      return;
    }

    const count = this.outcomesManager.bulkImportFromText(grade, subjectCode, subjectName, rawText);
    this.manifestManager.incrementOutcomesVersion();
    this.closeModal('modal-bulk-import');
    this.refreshOutcomesTable();
    this.updateDashboardStats();
    this.showToast(`${count} adet haftalık kazanım başarıyla yüklendi 🚀`, 'success');
  }

  fillSampleOutcomes() {
    const gradeSelect = document.getElementById('outcomes-grade-select');
    const subjectSelect = document.getElementById('outcomes-subject-select');
    const grade = gradeSelect ? gradeSelect.value : 5;
    const subjectCode = subjectSelect ? subjectSelect.value : 'MAT';
    const subjectName = subjectSelect && subjectSelect.selectedOptions.length > 0 ? subjectSelect.selectedOptions[0].text : 'Matematik';

    const sample = this.outcomesManager.generateSampleOutcomes(parseInt(grade), subjectCode, subjectName);
    this.outcomesManager.outcomes = this.outcomesManager.outcomes.filter(
      (o) => !(o.gradeLevel === parseInt(grade) && o.subjectCode === subjectCode)
    );
    this.outcomesManager.outcomes.push(...sample);
    this.outcomesManager.save();
    this.manifestManager.incrementOutcomesVersion();

    this.refreshOutcomesTable();
    this.updateDashboardStats();
    this.showToast(`${grade}. Sınıf ${subjectName} 36 haftalık taslak oluşturuldu ✨`, 'success');
  }

  // --- MANİFEST & DUYURULAR ---

  renderManifestUI() {
    const m = this.manifestManager.manifest;
    const elCal = document.getElementById('manifest-cal-ver');
    const elOut = document.getElementById('manifest-out-ver');
    const elAnn = document.getElementById('manifest-ann-ver');
    const elMinApp = document.getElementById('manifest-min-app');
    const elMaintSwitch = document.getElementById('manifest-maint-switch');
    const elMaintMsg = document.getElementById('manifest-maint-msg');

    if (elCal) elCal.innerText = `v${m.calendarVersion}`;
    if (elOut) elOut.innerText = `v${m.outcomesVersion}`;
    if (elAnn) elAnn.innerText = `v${m.announcementsVersion}`;
    if (elMinApp) elMinApp.value = m.minRequiredAppVersion;
    if (elMaintSwitch) elMaintSwitch.checked = m.maintenanceMode;
    if (elMaintMsg) elMaintMsg.value = m.maintenanceMessage;
  }

  saveManifestSettings() {
    const minApp = document.getElementById('manifest-min-app')?.value;
    const isMaint = document.getElementById('manifest-maint-switch')?.checked;
    const maintMsg = document.getElementById('manifest-maint-msg')?.value;

    this.manifestManager.manifest.minRequiredAppVersion = minApp;
    this.manifestManager.manifest.maintenanceMode = isMaint;
    this.manifestManager.manifest.maintenanceMessage = maintMsg;
    this.manifestManager.save();

    this.showToast('Manifest ayarları kaydedildi ⚙️', 'success');
    this.renderManifestUI();
  }

  incrementCalendarVersionManual() {
    const v = this.manifestManager.incrementCalendarVersion();
    this.showToast(`Takvim sürümü artırıldı: v${v} 🚩`, 'success');
    this.renderManifestUI();
    this.updateDashboardStats();
  }

  incrementOutcomesVersionManual() {
    const v = this.manifestManager.incrementOutcomesVersion();
    this.showToast(`Kazanım sürümü artırıldı: v${v} 📚`, 'success');
    this.renderManifestUI();
    this.updateDashboardStats();
  }

  openAddAnnouncementModal() {
    const form = document.getElementById('announcement-form');
    if (form) form.reset();
    this.openModal('modal-announcement');
  }

  saveAnnouncement(e) {
    e.preventDefault();
    const title = document.getElementById('ann-title')?.value;
    const body = document.getElementById('ann-body')?.value;
    const type = document.getElementById('ann-type')?.value;

    this.manifestManager.addAnnouncement({
      title,
      body,
      type,
      publishDate: new Date().toISOString().split('T')[0],
    });

    this.closeModal('modal-announcement');
    this.manifestManager.renderAnnouncementsTable();
    this.renderManifestUI();
    this.showToast('Sistem duyurusu yayınlandı 📢', 'success');
  }

  deleteAnnouncement(id) {
    if (confirm('Bu duyuruyu silmek istediğinize emin misiniz?')) {
      this.manifestManager.deleteAnnouncement(id);
      this.manifestManager.renderAnnouncementsTable();
      this.renderManifestUI();
      this.showToast('Duyuru kaldırıldı 🗑️', 'info');
    }
  }

  // --- AKILLI EXCEL (.XLSX) İÇE AKTARICI ---

  openExcelImportModal() {
    this.openModal('modal-excel-import');
  }

  async handleExcelFileInput(e) {
    const files = e.target?.files || e.dataTransfer?.files;
    if (!files || files.length === 0) return;
    const file = files[0];
    await this.processExcelFile(file);
  }

  async processExcelFile(file) {
    try {
      this.showToast(`Dosya okunuyor: ${file.name} ⏳`, 'info');
      const buffer = await file.arrayBuffer();
      const plans = SmartExcelImporter.parseWorkbook(buffer, file.name);

      if (!plans || plans.length === 0) {
        this.showToast('Uyarı: Bu Excel dosyasından geçerli bir haftalık plan çıkarılamadı.', 'error');
        return;
      }

      this.parsedExcelPlans = plans;
      this.currentSelectedExcelPlanIndex = 0;
      this.renderExcelAnalysisPreview(file.name);
      this.showToast(`Başarılı: ${plans.length} adet ders planı analiz edildi! 🎉`, 'success');
    } catch (err) {
      console.error('Excel parse error:', err);
      this.showToast(`Excel okuma hatası: ${err.message}`, 'error');
    }
  }

  renderExcelAnalysisPreview(fileName = '') {
    const analysisArea = document.getElementById('excel-analysis-area');
    const fnBadge = document.getElementById('excel-file-name-badge');
    const countBadge = document.getElementById('excel-plans-count-badge');
    const sheetSel = document.getElementById('excel-sheet-selector');
    const btnSingle = document.getElementById('btn-apply-single-sheet');
    const btnAll = document.getElementById('btn-apply-all-sheets');
    const btnJson = document.getElementById('btn-export-excel-json');

    if (analysisArea) analysisArea.style.display = 'block';
    if (fnBadge && fileName) fnBadge.innerText = `📄 ${fileName}`;
    if (countBadge) countBadge.innerText = `✨ ${this.parsedExcelPlans.length} Ders Planı`;
    if (btnSingle) btnSingle.style.display = 'inline-flex';
    if (btnAll) btnAll.style.display = 'inline-flex';
    if (btnJson) btnJson.style.display = 'inline-flex';

    if (sheetSel) {
      sheetSel.innerHTML = this.parsedExcelPlans.map((p, idx) => {
        return `<option value="${idx}">${p.fullTitle} (${p.tabName})</option>`;
      }).join('');
      sheetSel.value = this.currentSelectedExcelPlanIndex;
    }

    this.renderExcelPreviewTable();
  }

  handleExcelSheetChange(indexStr) {
    this.currentSelectedExcelPlanIndex = parseInt(indexStr) || 0;
    this.renderExcelPreviewTable();
  }

  renderExcelPreviewTable() {
    const tbody = document.getElementById('excel-preview-tbody');
    if (!tbody) return;

    const plan = this.parsedExcelPlans[this.currentSelectedExcelPlanIndex];
    if (!plan || !plan.rows) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center;">Önizleme verisi bulunamadı.</td></tr>';
      return;
    }

    tbody.innerHTML = plan.rows.map((r, rIdx) => {
      const isHol = r.isHoliday;
      const bg = isHol ? 'background: rgba(245, 158, 11, 0.08); font-weight: 600;' : '';
      const badge = isHol ? `<span class="badge badge-break">${r.dersTipi}</span>` : `<span class="badge" style="background: rgba(16,185,129,0.1); color: var(--accent);">Ders</span>`;

      return `
        <tr style="${bg}">
          <td style="text-align:center; font-weight:700;">${r.planOrder}</td>
          <td>${badge}</td>
          <td style="text-align:center;"><strong>${r.hafta || '-'}</strong></td>
          <td><span style="font-weight:600; color:var(--primary);">${r.sinif}. Sınıf ${r.subCode}</span></td>
          <td contenteditable="true" onblur="window.adminApp.updateExcelCell(${this.currentSelectedExcelPlanIndex}, ${rIdx}, 'unite', this.innerText)">${r.unite}</td>
          <td contenteditable="true" onblur="window.adminApp.updateExcelCell(${this.currentSelectedExcelPlanIndex}, ${rIdx}, 'kazanim', this.innerText)">${r.kazanim}</td>
        </tr>
      `;
    }).join('');
  }

  updateExcelCell(planIndex, rowIndex, field, value) {
    if (this.parsedExcelPlans[planIndex] && this.parsedExcelPlans[planIndex].rows[rowIndex]) {
      this.parsedExcelPlans[planIndex].rows[rowIndex][field] = value.trim();
    }
  }

  applySelectedExcelSheet() {
    const plan = this.parsedExcelPlans[this.currentSelectedExcelPlanIndex];
    if (!plan) return;

    const formattedOutcomes = plan.rows.map((r) => {
      const codeMatch = r.kazanim.match(/([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+(?:\.\d+)?|\b[A-Z]\d\.\d\.\w+\b)/);
      const code = r.isHoliday ? 'TATIL' : (codeMatch ? codeMatch[1] : `${plan.subjectCode}.${plan.grade}.${r.weekNum || r.planOrder}`);

      return {
        id: `out_${plan.grade}_${plan.subjectCode}_w${r.weekNum || r.planOrder}_${Date.now()}`,
        gradeLevel: plan.grade,
        subjectCode: plan.subjectCode,
        subjectName: plan.subjectName,
        publisher: plan.publisher,
        fullTitle: plan.fullTitle,
        weekNumber: r.weekNum || r.planOrder || 1,
        teachingWeekNumber: r.isHoliday ? null : (parseInt(r.hafta) || null),
        unitTitle: r.unite,
        topicTitle: r.unite,
        outcomeCode: code,
        outcomeDescription: r.kazanim,
        isHolidayWeek: r.isHoliday,
        holidayNote: r.isHoliday ? r.unite : null,
        academicYear: '2026-2027',
      };
    });

    // OutcomesManager'a yaz
    this.outcomesManager.outcomes = this.outcomesManager.outcomes.filter(
      (o) => !(o.gradeLevel === plan.grade && o.subjectCode === plan.subjectCode && o.publisher === plan.publisher)
    );
    this.outcomesManager.outcomes.push(...formattedOutcomes);
    this.outcomesManager.save();

    // UI'daki sınıf ve branş seçimini bu plana getir
    const gradeSel = document.getElementById('outcomes-grade-select');
    const subSel = document.getElementById('outcomes-subject-select');
    if (gradeSel) gradeSel.value = plan.grade;
    if (subSel) {
      if (Array.from(subSel.options).some((opt) => opt.value === plan.subjectCode)) {
        subSel.value = plan.subjectCode;
      }
    }

    this.refreshOutcomesTable();
    this.updateDashboardStats();
    this.manifestManager.incrementOutcomesVersion();
    this.renderManifestUI();

    this.closeModal('modal-excel-import');
    this.showToast(`✅ ${plan.fullTitle} başarıyla sisteme aktarıldı ve canlıya alındı!`, 'success');
  }

  applyAllParsedExcelPlans() {
    if (!this.parsedExcelPlans || this.parsedExcelPlans.length === 0) return;

    if (!confirm(`Tespit edilen ${this.parsedExcelPlans.length} ders planının tamamı sisteme aktarılacaktır. Devam etmek istiyor musunuz?`)) {
      return;
    }

    let totalImported = 0;
    const allOutcomes = [];

    for (const plan of this.parsedExcelPlans) {
      for (const r of plan.rows) {
        const codeMatch = r.kazanim.match(/([A-ZÇĞİÖŞÜa-zçğıöşü]{1,4}\.\d+\.\d+(?:\.\d+)?|\b[A-Z]\d\.\d\.\w+\b)/);
        const code = r.isHoliday ? 'TATIL' : (codeMatch ? codeMatch[1] : `${plan.subjectCode}.${plan.grade}.${r.weekNum || r.planOrder}`);

        allOutcomes.push({
          id: `out_${plan.grade}_${plan.subjectCode}_w${r.weekNum || r.planOrder}_${Date.now()}_${totalImported}`,
          gradeLevel: plan.grade,
          subjectCode: plan.subjectCode,
          subjectName: plan.subjectName,
          publisher: plan.publisher,
          fullTitle: plan.fullTitle,
          weekNumber: r.weekNum || r.planOrder || 1,
          teachingWeekNumber: r.isHoliday ? null : (parseInt(r.hafta) || null),
          unitTitle: r.unite,
          topicTitle: r.unite,
          outcomeCode: code,
          outcomeDescription: r.kazanim,
          isHolidayWeek: r.isHoliday,
          holidayNote: r.isHoliday ? r.unite : null,
          academicYear: '2026-2027',
        });
        totalImported++;
      }
    }

    this.outcomesManager.outcomes = allOutcomes;
    this.outcomesManager.save();

    this.refreshOutcomesTable();
    this.updateDashboardStats();
    this.manifestManager.incrementOutcomesVersion();
    this.renderManifestUI();

    this.closeModal('modal-excel-import');
    this.showToast(`🚀 Harika! Toplam ${this.parsedExcelPlans.length} dersin ${totalImported} satırlık planı başarıyla canlıya alındı!`, 'success');
  }

  exportParsedExcelJson() {
    if (!this.parsedExcelPlans || this.parsedExcelPlans.length === 0) return;
    const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(this.parsedExcelPlans, null, 2));
    const a = document.createElement('a');
    a.setAttribute('href', dataStr);
    a.setAttribute('download', `sinifcepte_excel_parsed_${Date.now()}.json`);
    document.body.appendChild(a);
    a.click();
    a.remove();
    this.showToast('Ayrıştırılan planlar JSON olarak indirildi 📥', 'info');
  }

  // ==========================================
  // --- MEB & ÖSYM RESMÎ SINAV YÖNETİMİ ---
  // ==========================================

  filterExamsByInstitution(inst, btnEl) {
    this.examsManager.selectedInstitution = inst || 'all';
    const selectEl = document.getElementById('exam-institution-select');
    if (selectEl && selectEl.value !== this.examsManager.selectedInstitution) {
      selectEl.value = this.examsManager.selectedInstitution;
    }
    const container = document.getElementById('exams-institution-filters');
    if (container) {
      container.querySelectorAll('.filter-inst-btn').forEach((b) => {
        b.classList.remove('btn-primary', 'active');
        b.classList.add('btn-secondary');
      });
    }
    if (btnEl) {
      btnEl.classList.remove('btn-secondary');
      btnEl.classList.add('btn-primary', 'active');
    }
    this.renderExamsTable();
  }

  handleExamsSearch(query) {
    this.examsManager.searchQuery = query || '';
    this.renderExamsTable();
  }

  renderExamsTable() {
    const tbody = document.getElementById('exams-table-body') || document.getElementById('exams-tbody');
    if (!tbody) return;

    const filtered = this.examsManager.getFilteredExams();
    const countBadge = document.getElementById('exams-count-badge') || document.getElementById('exams-count');
    if (countBadge) countBadge.innerText = `${filtered.length} Sınav`;

    if (filtered.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="6" style="text-align: center; padding: 36px 16px; color: var(--text-muted);">
            <div style="font-size: 28px; margin-bottom: 8px;">🏛️</div>
            <p style="font-weight: 600;">Eşleşen resmî sınav bulunamadı.</p>
            <p style="font-size: 12px; margin-top: 4px;">Yeni sınav ekleyebilir veya filtreleri temizleyebilirsiniz.</p>
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = filtered
      .map((exam, idx) => {
        const instBadge = this.examsManager.getInstitutionBadge(exam.institution);
        const countdownBadge = this.examsManager.getCountdownBadge(exam.examDate);
        
        const examDateFormatted = new Date(exam.examDate).toLocaleDateString('tr-TR', {
          day: '2-digit',
          month: 'short',
          year: 'numeric',
          hour: '2-digit',
          minute: '2-digit',
        });

        const deadlineFormatted = exam.applicationDeadline
          ? new Date(exam.applicationDeadline).toLocaleDateString('tr-TR', {
              day: '2-digit',
              month: 'short',
              year: 'numeric',
            })
          : '—';

        return `
          <tr>
            <td style="font-weight: 700; color: var(--text-muted); width: 40px;">${idx + 1}</td>
            <td>
              ${instBadge}
              ${this.kaynakBaglantisi(exam.institution)}
            </td>
            <td>
              <div style="font-weight: 700; color: var(--text-main); font-size: 13.5px;">${exam.title}</div>
              ${exam.description ? `<div style="font-size: 11.5px; color: var(--text-muted); margin-top: 2px;">${exam.description}</div>` : ''}
              ${exam.applicationUrl ? `<a href="${exam.applicationUrl}" target="_blank" style="font-size: 11px; color: var(--primary); text-decoration: none; display: inline-flex; align-items: center; gap: 3px; margin-top: 3px;">🔗 Başvuru Sayfası ↗</a>` : ''}
            </td>
            <td>
              <div style="font-weight: 700; font-size: 13px; color: var(--text-main);">📅 ${examDateFormatted}</div>
              <div style="margin-top: 4px;">${countdownBadge}</div>
            </td>
            <td style="font-size: 12px; color: var(--text-muted);">
              ⏳ Son: ${deadlineFormatted}
            </td>
            <td style="text-align: right; white-space: nowrap;">
              <button class="btn btn-sm btn-secondary" onclick="window.adminApp.editExam('${exam.doc_id}')" title="Düzenle">
                ✏️
              </button>
              <button class="btn btn-sm btn-danger" onclick="window.adminApp.deleteExam('${exam.doc_id}')" title="Sil">
                🗑️
              </button>
            </td>
          </tr>
        `;
      })
      .join('');
  }

  openAddExamModal() {
    const form = document.getElementById('exam-form');
    if (form) form.reset();
    const docIdEl = document.getElementById('exam-doc-id');
    if (docIdEl) docIdEl.value = '';
    const modalTitle = document.getElementById('modal-exam-title');
    if (modalTitle) modalTitle.innerText = '➕ Yeni Resmî Sınav Ekle';
    this.openModal('modal-exam');
  }

  editExam(docId) {
    const exam = this.examsManager.exams.find((e) => e.doc_id === docId);
    if (!exam) return;

    const docIdEl = document.getElementById('exam-doc-id');
    const titleEl = document.getElementById('exam-title');
    const instEl = document.getElementById('exam-institution');
    const dateEl = document.getElementById('exam-date');
    const deadlineEl = document.getElementById('exam-deadline');
    const urlEl = document.getElementById('exam-url');
    const descEl = document.getElementById('exam-desc');
    const modalTitle = document.getElementById('modal-exam-title');

    if (docIdEl) docIdEl.value = exam.doc_id;
    if (titleEl) titleEl.value = exam.title || '';
    if (instEl) instEl.value = exam.institution || 'MEB';
    
    // ISO string formatını datetime-local için ayarla (YYYY-MM-DDTHH:MM)
    if (dateEl && exam.examDate) {
      dateEl.value = exam.examDate.substring(0, 16);
    }
    if (deadlineEl && exam.applicationDeadline) {
      deadlineEl.value = exam.applicationDeadline.substring(0, 16);
    } else if (deadlineEl) {
      deadlineEl.value = '';
    }

    if (urlEl) urlEl.value = exam.applicationUrl || '';
    if (descEl) descEl.value = exam.description || '';
    if (modalTitle) modalTitle.innerText = '✏️ Resmî Sınavı Düzenle';

    this.openModal('modal-exam');
  }

  saveExam(e) {
    e.preventDefault();
    const docId = document.getElementById('exam-doc-id')?.value;
    const title = document.getElementById('exam-title')?.value?.trim();
    const institution = document.getElementById('exam-institution')?.value;
    const examDateVal = document.getElementById('exam-date')?.value;
    const deadlineVal = document.getElementById('exam-deadline')?.value;
    const url = document.getElementById('exam-url')?.value?.trim();
    const description = document.getElementById('exam-desc')?.value?.trim();

    if (!title || !examDateVal) {
      this.showToast('Lütfen sınav adı ve tarihini eksiksiz giriniz.', 'warning');
      return;
    }

    const examData = {
      doc_id: docId || `exam_${institution.toLowerCase()}_${Date.now()}`,
      title: title,
      institution: institution || 'MEB',
      examDate: new Date(examDateVal).toISOString(),
      applicationDeadline: deadlineVal ? new Date(deadlineVal).toISOString() : null,
      applicationUrl: url || '',
      description: description || '',
      category: 'official',
    };

    if (docId) {
      this.examsManager.updateExam(examData);
      this.showToast(`"${title}" sınavı güncellendi! ✅`, 'success');
    } else {
      this.examsManager.addExam(examData);
      this.showToast(`"${title}" sınavı eklendi! 🎉`, 'success');
    }

    this.renderExamsTable();
    this.updateDashboardStats();
    this.closeModal('modal-exam');
  }

  deleteExam(docId) {
    const exam = this.examsManager.exams.find((e) => e.doc_id === docId);
    const title = exam ? exam.title : 'Bu sınav';
    if (confirm(`"${title}" kaydını silmek istediğinize emin misiniz?`)) {
      this.examsManager.deleteExam(docId);
      this.renderExamsTable();
      this.updateDashboardStats();
      this.showToast(`"${title}" silindi. 🗑️`, 'info');
    }
  }

  exportExamsJSON() {
    CloudExporter.exportExams(this.examsManager);
    this.showToast('Resmî Sınav Takvimi JSON olarak indirildi 📥', 'success');
  }

  /**
   * Sinav takvimini mobil uygulamalara yayinlar.
   *
   * DIGER MODULLERDEN FARKLI: takvim ve kazanim yalnizca "guncelleme
   * var" uyarisi uretir, veri APK ile gelir. Sinav tarihleri ise yil
   * icinde degisiyor (ertelenen LGS, acilanan basvuru tarihi) ve
   * ogretmen uygulama guncellemesi bekleyemez.
   *
   * Uretilen dosya Remote Config'e su komutla yayinlanir:
   *   node scripts/admin/publish_remote_config.mjs remote_config_params.json
   */
  async publishExamsToMobile() {
    const sinavSayisi = this.examsManager.getAllExams().length;
    if (sinavSayisi === 0) {
      this.showToast('Yayınlanacak sınav yok.', 'error');
      return;
    }

    const onay = confirm(
      `${sinavSayisi} sınav mobil uygulamalara yayınlanacak.\n\n` +
        'Öğretmenler uygulamayı güncellemeden yeni tarihleri görecek.\n' +
        'Cihazlar en geç 6 saat içinde alır; öğretmen "yenile" derse ' +
        'anında.\n\nDevam edilsin mi?'
    );
    if (!onay) return;

    const dugme = document.querySelector('[data-publish-exams]');
    if (dugme) {
      dugme.disabled = true;
      dugme.textContent = '⏳ Yayınlanıyor…';
    }

    // Sürüm ÖNCE artırılıyor ama yayın başarısız olursa geri alınıyor:
    // aksi hâlde sayaç ilerler, bir dahaki denemede "zaten güncel"
    // sanılır ve veri hiç gitmez.
    const oncekiSurum = this.manifestManager.manifest.examsVersion || 1;
    const yeniSurum = this.manifestManager.incrementExamsVersion();

    try {
      const sonuc = await window.SinifCepteAdminAuth.publishRemoteConfig(
        this.manifestManager.toRemoteConfigParams(this.examsManager)
      );

      this.updateDashboardStats();
      this.showToast(
        `${sinavSayisi} sınav yayınlandı (v${yeniSurum}). ` +
          'Öğretmenler en geç 6 saat içinde alacak 🚀',
        'success'
      );
      console.info('Remote Config sürümü:', sonuc?.version);
    } catch (e) {
      // Sayaç geri alınır ki yeniden denenebilsin.
      this.manifestManager.manifest.examsVersion = oncekiSurum;
      this.manifestManager.save();

      this.showToast(this.yayinHatasi(e), 'error');
      console.error('Yayın hatası:', e);
    } finally {
      if (dugme) {
        dugme.disabled = false;
        dugme.textContent = '🚀 Mobil Uygulamaya Yayınla';
      }
    }
  }

  /**
   * MEB duyuru metninden sınav tarihi ayıklama penceresini açar.
   *
   * ## Neden yapıştırma
   * MEB sınav tarihlerini yapılandırılmış veri olarak yayımlamıyor —
   * duyuru metni ve PDF içinde geçiyor, biçim her yıl değişiyor.
   * ÖSYM'de yaptığımız gibi sayfayı otomatik okumak burada güvenilmez:
   * yanlış ayrıştırma 30.000 öğretmene yanlış LGS tarihi göndermek
   * demek.
   *
   * Bu yol ortayı buluyor: yönetici metni yapıştırıyor, tarihler
   * ayıklanıyor, o onaylıyor. Sıfırdan elle girmek yok.
   */
  mebMetinAc() {
    const giris = document.getElementById('meb-paste-input');
    const sonuc = document.getElementById('meb-paste-result');
    const uygula = document.getElementById('meb-paste-apply');
    if (giris) giris.value = '';
    if (sonuc) sonuc.innerHTML = '';
    if (uygula) uygula.style.display = 'none';
    this._mebSonuc = null;
    this.openModal('meb-paste-modal');
  }

  mebMetinKapat() {
    this.closeModal('meb-paste-modal');
    this._mebSonuc = null;
  }

  /** Yapıştırılan metni ayrıştırır ve sonucu gösterir. */
  mebMetinAyristir() {
    const giris = document.getElementById('meb-paste-input');
    const kutu = document.getElementById('meb-paste-result');
    const uygula = document.getElementById('meb-paste-apply');
    if (!giris || !kutu) return;

    const metin = giris.value.trim();
    if (!metin) {
      kutu.innerHTML = this.mebUyari('Önce duyuru metnini yapıştırın.');
      return;
    }

    const r = window.ExamTextParser.ayristir(metin);
    this._mebSonuc = r;

    if (r.sinavlar.length === 0) {
      kutu.innerHTML = this.mebUyari(
        'Metinde tanınan sınav bulunamadı. Tarihlerin "12 Kasım 2026" ' +
          'ya da "12.11.2026" biçiminde olduğundan emin olun.'
      );
      if (uygula) uygula.style.display = 'none';
      return;
    }

    // Mevcut kayıtlarla karşılaştır: hangisi yeni, hangisi değişiyor?
    const mevcut = this.examsManager.getAllExams();
    const eskiler = new Map(mevcut.map((x) => [x.doc_id, x]));

    const tarihYaz = (iso) =>
      new Date(iso).toLocaleDateString('tr-TR', {
        day: '2-digit', month: 'long', year: 'numeric',
      });

    let html = `<h4 style="margin: 0 0 10px; font-size: 14px;">
                  ${r.sinavlar.length} sınav bulundu</h4>`;

    for (const s of r.sinavlar) {
      const eski = eskiler.get(s.doc_id);
      const durum = eski ? 'güncellenecek' : 'yeni eklenecek';
      const renk = eski ? '245,158,11' : '99,102,241';

      html += `
        <div style="padding: 10px 12px; margin-bottom: 7px; border-radius: 10px;
                    background: rgba(${renk},0.08);
                    border: 1px solid rgba(${renk},0.28);">
          <div style="font-weight: 700; font-size: 13px;">
            ${this.kacisliMetin(s.title)}
          </div>
          <div style="font-size: 12.5px; margin-top: 2px;">
            📅 ${tarihYaz(s.examDate)}
            <span style="color: var(--text-muted); font-size: 11.5px;">
              · ${durum}
            </span>
          </div>
          <div style="font-size: 11px; color: var(--text-muted); margin-top: 3px;
                      font-style: italic;">
            "${this.kacisliMetin(s.kaynakSatir)}"
          </div>
        </div>`;
    }

    if (r.taninmayan.length > 0) {
      html += `
        <h4 style="margin: 16px 0 8px; font-size: 13.5px;">
          ⚠️ Tarihi var ama tanınmadı (${r.taninmayan.length})
        </h4>
        <p style="margin: 0 0 8px; font-size: 11.5px; color: var(--text-muted);">
          Bu satırlar atlanacak; gerekiyorsa elle ekleyin.
        </p>`;
      for (const t of r.taninmayan) {
        html += `
          <div style="padding: 8px 11px; margin-bottom: 5px; border-radius: 8px;
                      background: rgba(100,116,139,0.07); font-size: 11.5px;
                      color: var(--text-muted);">
            ${t.tarih} — "${this.kacisliMetin(t.satir)}"
          </div>`;
      }
    }

    html += `
      <p style="margin: 14px 0 0; font-size: 11.5px; color: var(--text-muted);
                line-height: 1.5;">
        Uygulamak yalnızca paneli günceller. Öğretmenlere ulaşması için
        ardından <strong>"Mobil Uygulamaya Yayınla"</strong> demeniz gerekir.
      </p>`;

    kutu.innerHTML = html;
    if (uygula) {
      uygula.style.display = '';
      uygula.textContent = `${r.sinavlar.length} Sınavı Uygula`;
    }
  }

  /** Ayıklanan sınavları panele işler. */
  mebMetinUygula() {
    const r = this._mebSonuc;
    if (!r || r.sinavlar.length === 0) return;

    let sayac = 0;
    for (const s of r.sinavlar) {
      // Ayrıştırıcıya özel alanlar veriye girmesin.
      const { kaynakSatir, yil, ...temiz } = s;
      const mevcut = this.examsManager
        .getAllExams()
        .find((x) => x.doc_id === temiz.doc_id);

      if (mevcut) {
        this.examsManager.updateExam({ ...mevcut, ...temiz });
      } else {
        this.examsManager.addExam(temiz);
      }
      sayac++;
    }

    this.renderExamsTable();
    this.updateDashboardStats();
    this.mebMetinKapat();

    this.showToast(
      `${sayac} sınav güncellendi. Öğretmenlere ulaşması için ` +
        '"Mobil Uygulamaya Yayınla" deyin.',
      'success'
    );
  }

  mebUyari(mesaj) {
    return `
      <div style="padding: 12px 14px; border-radius: 10px;
                  background: rgba(245,158,11,0.1);
                  border: 1px solid rgba(245,158,11,0.3);
                  font-size: 12.5px; line-height: 1.5;">
        ${this.kacisliMetin(mesaj)}
      </div>`;
  }

  /**
   * ÖSYM takvimini çeker ve farkları gösterir.
   *
   * YAYINLAMAZ. Sunucu sayfayı okuyup mevcut veriyle karşılaştırıyor;
   * yönetici ne değiştiğini görüp onaylıyor.
   *
   * Sebep: sayfa yapısı ÖSYM'nin kontrolünde. Bir gün değişirse
   * ayrıştırma bozulur ve yanlış tarih 30.000 öğretmene gider.
   */
  async osymdenCek() {
    const dugme = document.querySelector('[data-fetch-osym]');
    if (dugme) {
      dugme.disabled = true;
      dugme.textContent = '⏳ ÖSYM okunuyor…';
    }

    try {
      const mevcut = this.examsManager.getAllExams();
      const sonuc = await window.SinifCepteAdminAuth.fetchOsymTakvim(mevcut);
      this._osymSonuc = sonuc;
      this.osymFarkGoster(sonuc);
    } catch (e) {
      this.showToast(this.yayinHatasi(e), 'error');
      console.error('ÖSYM çekme hatası:', e);
    } finally {
      if (dugme) {
        dugme.disabled = false;
        dugme.textContent = "🔄 ÖSYM'den Güncelle";
      }
    }
  }

  /** Fark ekranını doldurur ve açar. */
  osymFarkGoster(sonuc) {
    const govde = document.getElementById('osym-diff-body');
    const uygulaBtn = document.getElementById('osym-apply-btn');
    if (!govde) return;

    const yeni = sonuc.yeni || [];
    const degisen = sonuc.degisen || [];
    const tarihYaz = (iso) => {
      if (!iso) return '—';
      const d = new Date(iso);
      return d.toLocaleDateString('tr-TR', {
        day: '2-digit',
        month: 'long',
        year: 'numeric',
      });
    };

    let html = `
      <p style="margin: 0 0 16px; font-size: 13.5px; line-height: 1.6;">
        ÖSYM takviminde <strong>${sonuc.toplam}</strong> sınav bulundu.
        ${sonuc.atlanan > 0 ? `<span style="color: var(--text-secondary);">(${sonuc.atlanan} satır tarihsiz olduğu için atlandı)</span>` : ''}
      </p>`;

    if (degisen.length === 0 && yeni.length === 0) {
      html += `
        <div style="padding: 20px; text-align: center; background: rgba(16,185,129,0.08);
                    border-radius: 12px; border: 1px solid rgba(16,185,129,0.3);">
          <div style="font-size: 30px;">✅</div>
          <p style="margin: 8px 0 0; font-weight: 700;">Takviminiz güncel</p>
          <p style="margin: 4px 0 0; font-size: 12.5px; color: var(--text-secondary);">
            ${sonuc.ayniSayisi} sınav zaten aynı tarihte kayıtlı.
          </p>
        </div>`;
      if (uygulaBtn) uygulaBtn.style.display = 'none';
    } else {
      if (uygulaBtn) {
        uygulaBtn.style.display = '';
        uygulaBtn.textContent =
          `${degisen.length + yeni.length} Değişikliği Uygula`;
      }

      if (degisen.length > 0) {
        html += `<h4 style="margin: 18px 0 8px; font-size: 14px;">
                   📅 Tarihi değişen (${degisen.length})</h4>`;
        for (const d of degisen) {
          html += `
            <div style="padding: 11px 13px; margin-bottom: 7px; border-radius: 10px;
                        background: rgba(245,158,11,0.09);
                        border: 1px solid rgba(245,158,11,0.3);">
              <div style="font-weight: 600; font-size: 13px; margin-bottom: 3px;">
                ${this.kacisliMetin(d.yeni.title)}
              </div>
              <div style="font-size: 12.5px;">
                <span style="text-decoration: line-through; color: var(--text-secondary);">
                  ${tarihYaz(d.eski.examDate)}
                </span>
                <span style="margin: 0 6px;">→</span>
                <strong>${tarihYaz(d.yeni.examDate)}</strong>
              </div>
            </div>`;
        }
      }

      if (yeni.length > 0) {
        html += `<h4 style="margin: 18px 0 8px; font-size: 14px;">
                   ➕ Yeni sınav (${yeni.length})</h4>
                 <div style="max-height: 220px; overflow-y: auto;">`;
        for (const y of yeni) {
          html += `
            <div style="padding: 9px 13px; margin-bottom: 6px; border-radius: 10px;
                        background: rgba(99,102,241,0.07);
                        border: 1px solid rgba(99,102,241,0.25);">
              <div style="font-size: 12.5px; font-weight: 600;">
                ${this.kacisliMetin(y.title)}
              </div>
              <div style="font-size: 12px; color: var(--text-secondary);">
                ${tarihYaz(y.examDate)}
              </div>
            </div>`;
        }
        html += '</div>';
      }

      html += `
        <p style="margin: 16px 0 0; font-size: 12px; color: var(--text-secondary);
                  line-height: 1.5;">
          Uygulamak yalnızca paneli günceller. Öğretmenlere ulaşması için
          ardından <strong>"Mobil Uygulamaya Yayınla"</strong> demeniz gerekir.
        </p>`;
    }

    html += `
      <p style="margin: 14px 0 0; font-size: 11.5px; color: var(--text-secondary);">
        Kaynak: <a href="${sonuc.kaynak}" target="_blank" rel="noopener">${sonuc.kaynak}</a>
      </p>`;

    govde.innerHTML = html;
    this.openModal('osym-diff-modal');
  }

  /** Çekilen değişiklikleri panele işler. */
  osymFarkUygula() {
    const sonuc = this._osymSonuc;
    if (!sonuc) return;

    let sayac = 0;

    // Tarihi değişenler güncellenir.
    for (const d of sonuc.degisen || []) {
      const mevcut = this.examsManager
        .getAllExams()
        .find((x) => x.doc_id === d.yeni.doc_id);
      if (mevcut) {
        this.examsManager.updateExam({ ...mevcut, ...d.yeni });
        sayac++;
      }
    }

    // Yeniler eklenir.
    for (const y of sonuc.yeni || []) {
      this.examsManager.addExam(y);
      sayac++;
    }

    this.renderExamsTable();
    this.updateDashboardStats();
    this.osymFarkKapat();
    this._osymSonuc = null;

    this.showToast(
      `${sayac} sınav güncellendi. Öğretmenlere ulaşması için ` +
        '"Mobil Uygulamaya Yayınla" deyin.',
      'success'
    );
  }

  osymFarkKapat() {
    this.closeModal('osym-diff-modal');
  }

  /**
   * Kurumun takvim kaynağına bağlantı.
   *
   * ## Neden var
   * Sınav tarihleri elle giriliyor ve yönetici her seferinde "bu sınav
   * nerede yayımlanıyordu?" diye aramak zorunda kalıyordu. Kaynak
   * adresi satırın yanında duruyor.
   *
   * ÖSYM sınavları otomatik çekiliyor ama bağlantı yine gösteriliyor:
   * çekilen veriyi doğrulamak isteyebilir.
   */
  kaynakBaglantisi(kurum) {
    const k = window.SinavKaynaklari?.bul(kurum);
    if (!k) return '';

    const isaret = k.otomatik ? '🔄' : '🔗';
    const ipucu = `${k.ad}\n${k.aciklama}\nGüncelleme dönemi: ${k.nezaman}`;

    return `
      <a href="${k.url}" target="_blank" rel="noopener"
         title="${this.kacisliMetin(ipucu)}"
         style="display: block; margin-top: 4px; font-size: 10.5px;
                color: var(--text-muted); text-decoration: none;">
        ${isaret} kaynak ↗
      </a>`;
  }

  /**
   * HTML kaçışı.
   *
   * Sınav adı dış bir siteden geliyor; doğrudan innerHTML'e basmak
   * script enjeksiyonuna açık olurdu.
   */
  kacisliMetin(x) {
    const d = document.createElement('div');
    d.textContent = x ?? '';
    return d.innerHTML;
  }

  /** Fonksiyon hatasını öğretmenin anlayacağı dile çevirir. */
  yayinHatasi(e) {
    switch (e?.code) {
      case 'functions/unauthenticated':
        return 'Oturumunuz düşmüş. Çıkıp yeniden giriş yapın.';
      case 'functions/permission-denied':
        return 'Bu işlem için süper yönetici yetkisi gerekiyor.';
      case 'functions/invalid-argument':
        return `Veri reddedildi: ${e.message}`;
      case 'functions/deadline-exceeded':
        // Sunucunun kendi mesajı daha bilgilendirici: sorunun ÖSYM'de
        // olduğunu söylüyor. Genel "internet bağlantınızı kontrol
        // edin" metni kullanıcıyı yanlış yere baktırıyordu.
        return e.message || 'İşlem zaman aşımına uğradı.';
      case 'functions/unavailable':
        return 'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edin.';
      case 'functions/not-found':
        return 'İşlev bulunamadı. Önce `firebase deploy --only functions` çalıştırın.';
      case 'functions/failed-precondition':
        // Ayrıştırma bozuldu: kaynak sitenin yapısı değişmiş olabilir.
        return e.message;
      default:
        return `Yayın başarısız: ${e?.message || e}`;
    }
  }

  resetExamsToDefault() {
    if (confirm('Tüm sınav takvimini orijinal MEB & ÖSYM resmî varsayılanlarına sıfırlamak istiyor musunuz?')) {
      const count = this.examsManager.resetToDefaultExams();
      this.renderExamsTable();
      this.updateDashboardStats();
      this.showToast(`Sınavlar orijinal resmî takvime sıfırlandı (${count} Sınav) 🔄`, 'success');
    }
  }

  importExamsJSON(event) {
    const file = event.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = JSON.parse(e.target.result);
        const list = Array.isArray(data) ? data : (data.exams || []);
        if (list.length === 0) {
          this.showToast('Geçerli bir sınav listesi bulunamadı.', 'warning');
          return;
        }
        this.examsManager.exams = list;
        this.examsManager.save();
        this.renderExamsTable();
        this.updateDashboardStats();
        this.showToast(`${list.length} adet sınav başarıyla içe aktarıldı! 🎉`, 'success');
      } catch (err) {
        console.error('Import exams error:', err);
        this.showToast('JSON dosyası okunamadı veya format geçersiz.', 'error');
      }
    };
    reader.readAsText(file);
    event.target.value = '';
  }


  // --- MODAL & TOAST YARDIMCILARI ---


  openModal(id) {
    const el = document.getElementById(id);
    if (el) {
      el.classList.add('show');
      el.style.display = 'flex';
      el.style.opacity = '1';
      el.style.visibility = 'visible';
      el.style.zIndex = '99999';
    } else {
      console.error('Modal bulunamadı:', id);
    }
  }

  closeModal(id) {
    const el = document.getElementById(id);
    if (el) {
      el.classList.remove('show');
      el.style.display = 'none';
      el.style.opacity = '0';
      el.style.visibility = 'hidden';
    }
  }

  showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerText = message;
    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      setTimeout(() => toast.remove(), 250);
    }, 3000);
  }

  initEventListeners() {
    // Menü Tıklamaları
    document.querySelectorAll('.menu-item').forEach((item) => {
      item.addEventListener('click', (e) => {
        e.preventDefault();
        const tab = item.getAttribute('data-tab');
        if (tab) this.switchTab(tab);
      });
    });

    // Tema Değiştir
    const themeBtn = document.getElementById('theme-toggle');
    if (themeBtn) themeBtn.addEventListener('click', () => this.toggleTheme());

    // Excel Yükleme Dinleyicileri
    const fileInput = document.getElementById('excel-file-input');
    const modalDropzone = document.getElementById('excel-modal-dropzone');
    const quickDropzone = document.getElementById('outcomes-quick-dropzone');

    if (modalDropzone && fileInput) {
      modalDropzone.addEventListener('click', () => fileInput.click());
      fileInput.addEventListener('change', (e) => this.handleExcelFileInput(e));

      modalDropzone.addEventListener('dragover', (e) => {
        e.preventDefault();
        modalDropzone.style.background = 'rgba(79, 70, 229, 0.1)';
      });
      modalDropzone.addEventListener('dragleave', (e) => {
        e.preventDefault();
        modalDropzone.style.background = 'rgba(79, 70, 229, 0.03)';
      });
      modalDropzone.addEventListener('drop', (e) => {
        e.preventDefault();
        modalDropzone.style.background = 'rgba(79, 70, 229, 0.03)';
        this.handleExcelFileInput(e);
      });
    }

    if (quickDropzone) {
      quickDropzone.addEventListener('dragover', (e) => {
        e.preventDefault();
        quickDropzone.style.background = 'rgba(79, 70, 229, 0.12)';
      });
      quickDropzone.addEventListener('dragleave', (e) => {
        e.preventDefault();
        quickDropzone.style.background = 'rgba(79, 70, 229, 0.04)';
      });
      quickDropzone.addEventListener('drop', (e) => {
        e.preventDefault();
        quickDropzone.style.background = 'rgba(79, 70, 229, 0.04)';
        this.openExcelImportModal();
        this.handleExcelFileInput(e);
      });
    }

    // Form Dinleyicileri
    const calForm = document.getElementById('calendar-form');
    if (calForm) calForm.addEventListener('submit', (e) => this.saveCalendarEvent(e));

    const smartForm = document.getElementById('smart-parser-form');
    if (smartForm) smartForm.addEventListener('submit', (e) => this.handleSmartParserSubmit(e));

    const wizForm = document.getElementById('wizard-form');
    if (wizForm) wizForm.addEventListener('submit', (e) => this.handleCalendarWizardSubmit(e));

    const bulkForm = document.getElementById('bulk-import-form');
    if (bulkForm) bulkForm.addEventListener('submit', (e) => this.handleBulkImport(e));

    const editOutcomeForm = document.getElementById('edit-outcome-form');
    if (editOutcomeForm) {
      editOutcomeForm.addEventListener('submit', (e) => this.handleEditOutcomeSubmit(e));
    }

    const annForm = document.getElementById('announcement-form');
    if (annForm) annForm.addEventListener('submit', (e) => this.saveAnnouncement(e));

    // Kazanım Filtreleri (MEB TYMM Resmî Hiyerarşisi)
    const schoolTypeSel = document.getElementById('outcomes-school-type-select');
    if (schoolTypeSel) schoolTypeSel.addEventListener('change', (e) => this.handleSchoolTypeChange(e.target.value));

    const gradeSel = document.getElementById('outcomes-grade-select');
    if (gradeSel) gradeSel.addEventListener('change', () => this.handleGradeChange());

    const subSel = document.getElementById('outcomes-subject-select');
    if (subSel) subSel.addEventListener('change', () => this.refreshOutcomesTable());

    const pubSel = document.getElementById('outcomes-publisher-select');
    if (pubSel) pubSel.addEventListener('change', () => this.refreshOutcomesTable());

    // Sınav Formu & Filtreleri
    const examForm = document.getElementById('exam-form');
    if (examForm) examForm.addEventListener('submit', (e) => this.saveExam(e));

    const examInstSel = document.getElementById('exam-institution-select');
    if (examInstSel) {
      examInstSel.addEventListener('change', (e) => {
        this.examsManager.selectedInstitution = e.target.value;
        this.renderExamsTable();
      });
    }

    const examSearchInput = document.getElementById('exam-search-input');
    if (examSearchInput) {
      examSearchInput.addEventListener('input', (e) => {
        this.examsManager.searchQuery = e.target.value;
        this.renderExamsTable();
      });
    }

    // Modal Dışına Tıklayınca Kapatma
    document.querySelectorAll('.modal-backdrop').forEach((backdrop) => {
      backdrop.addEventListener('click', (e) => {
        if (e.target === backdrop) {
          this.closeModal(backdrop.id);
        }
      });
    });
  }
}

window.AdminApp = AdminApp;

// Uygulamayı Başlat ve Global Scope'a Bağla
function initAdminApp() {
  if (window.adminApp) return;
  try {
    window.adminApp = new AdminApp();
  } catch (error) {
    // Yapıcıdaki tek bir hata window.adminApp'i undefined bırakıyordu;
    // paneldeki her düğme onclick="window.adminApp..." çağırdığı için
    // arayüz tamamen tepkisiz kalıyor ve sebebi görünmüyordu.
    console.error('Admin paneli başlatılamadı:', error);
    const banner = document.createElement('div');
    banner.style.cssText =
      'position:fixed;inset:0 0 auto 0;z-index:9999;padding:14px 18px;' +
      'background:#b91c1c;color:#fff;font:14px/1.5 system-ui,sans-serif;';
    banner.textContent =
      'Panel başlatılamadı: ' + (error && error.message ? error.message : error) +
      ' — Ayrıntı için tarayıcı konsolunu açın (F12).';
    document.body.appendChild(banner);
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initAdminApp);
} else {
  initAdminApp();
}
