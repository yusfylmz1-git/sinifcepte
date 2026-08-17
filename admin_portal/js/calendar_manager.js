/**
 * SınıfCepte Web Admin Paneli - MEB Akademik Takvim Yöneticisi
 */
class CalendarManager {
  constructor() {
    this.events = [];
    this.selectedYear = '2026-2027';
    this.initDefaultEvents();
  }

  initDefaultEvents() {
    const saved = localStorage.getItem('sinifcepte_admin_calendar');
    if (saved) {
      try {
        this.events = JSON.parse(saved);
        // En güncel yılı seç
        const years = this.getDistinctYears();
        if (years.length > 0) this.selectedYear = years[0];
        return;
      } catch (e) {
        console.error('Saved calendar parse error:', e);
      }
    }

    // Başlangıç için 2026-2027 ve 2025-2026 tohumları
    this.events = [
      ...CalendarWizard.generateFullCalendar('2026-09-14', '2026-2027'),
    ];
    this.selectedYear = '2026-2027';
    this.save();
  }

  save() {
    localStorage.setItem('sinifcepte_admin_calendar', JSON.stringify(this.events));
  }

  getDistinctYears() {
    const set = new Set(this.events.map((e) => e.academicYear).filter(Boolean));
    set.add('2026-2027');
    set.add('2025-2026');
    return Array.from(set).sort((a, b) => b.localeCompare(a));
  }

  getEvents(academicYear = null) {
    const targetYear = academicYear || this.selectedYear;
    return this.events
      .filter((e) => !targetYear || e.academicYear === targetYear)
      .sort((a, b) => new Date(a.startDate) - new Date(b.startDate));
  }

  addEvent(event) {
    if (!event.id) {
      event.id = 'event_' + Date.now() + '_' + Math.random().toString(36).substr(2, 4);
    }
    if (!event.academicYear) {
      event.academicYear = this.selectedYear;
    }
    this.events.push(event);
    this.save();
  }

  updateEvent(updated) {
    const idx = this.events.findIndex((e) => e.id === updated.id);
    if (idx !== -1) {
      this.events[idx] = updated;
      this.save();
    }
  }

  deleteEvent(id) {
    this.events = this.events.filter((e) => e.id !== id);
    this.save();
  }

  /**
   * Belirtilen akademik yılın eski tüm olaylarını temizleyip yerine yenilerini kaydeder (Sıfır Çakışma)
   */
  replaceYearEvents(academicYear, newEvents) {
    this.events = this.events.filter((e) => e.academicYear !== academicYear);
    newEvents.forEach((ev) => {
      ev.academicYear = academicYear;
      this.events.push(ev);
    });
    this.selectedYear = academicYear;
    this.save();
  }

  clearYearEvents(academicYear) {
    this.events = this.events.filter((e) => e.academicYear !== academicYear);
    this.save();
  }

  getCategoryBadge(cat) {
    switch (cat) {
      case 'period':
        return '<span class="badge badge-period">🚩 Dönem</span>';
      case 'breakHoliday':
        return '<span class="badge badge-break">🏖️ Ara Tatil / Sömestr</span>';
      case 'officialHoliday':
        return '<span class="badge badge-official">🇹🇷 Resmî Tatil</span>';
      case 'examPeriod':
        return '<span class="badge badge-exam">📝 Ortak Sınav</span>';
      default:
        return '<span class="badge badge-special">🎉 Özel Gün</span>';
    }
  }

  renderTable(academicYear = null, filterCategory = null) {
    const tbody = document.getElementById('calendar-tbody');
    if (!tbody) return;

    const targetYear = academicYear || this.selectedYear;
    this.selectedYear = targetYear;

    let list = this.getEvents(targetYear);
    if (filterCategory) {
      list = list.filter((e) => e.category === filterCategory);
    }

    // Yıl Seçici Dropdown'ı Senkronize Et
    const yearSelect = document.getElementById('calendar-year-filter');
    if (yearSelect) {
      const distinctYears = this.getDistinctYears();
      yearSelect.innerHTML = distinctYears
        .map((y) => `<option value="${y}" ${y === targetYear ? 'selected' : ''}>📅 ${y} Eğitim Öğretim Yılı ${y === '2026-2027' ? '(Aktif)' : ''}</option>`)
        .join('') + `<option value="__new__">➕ Yeni Eğitim Yılı Ekle...</option>`;
    }

    if (list.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="6" style="text-align:center; color: var(--text-muted); padding: 40px;">
            <div style="font-size: 32px; margin-bottom: 8px;">📅</div>
            <strong>${targetYear} yılına ait kayıtlı takvim olayı bulunamadı.</strong><br>
            <span style="font-size: 12px;">Yukarıdaki "🪄 Takvim Sihirbazı" veya "📋 Akıllı Genelge Yapıştır" butonunu kullanarak bu yılı anında oluşturabilirsiniz.</span>
          </td>
        </tr>`;
      return;
    }

    tbody.innerHTML = list
      .map((item) => {
        const start = new Date(item.startDate);
        const end = new Date(item.endDate);
        const diffDays = Math.max(1, Math.ceil((end - start) / (1000 * 60 * 60 * 24)) + 1);

        return `
        <tr>
          <td><strong>${item.title}</strong><br><small style="color: var(--text-muted)">${item.description || ''}</small></td>
          <td>${this.getCategoryBadge(item.category)}</td>
          <td>${item.startDate}</td>
          <td>${item.endDate}</td>
          <td><span class="badge" style="background: rgba(79,70,229,0.1); color: var(--primary)">${diffDays} Gün</span></td>
          <td style="text-align: right;">
            <button class="btn btn-secondary" style="padding: 5px 10px; font-size: 11px;" onclick="window.adminApp.editCalendarEvent('${item.id}')">Düzenle</button>
            <button class="btn btn-danger" style="padding: 5px 10px; font-size: 11px;" onclick="window.adminApp.deleteCalendarEvent('${item.id}')">Sil</button>
          </td>
        </tr>
      `;
      })
      .join('');
  }
}

window.CalendarManager = CalendarManager;
