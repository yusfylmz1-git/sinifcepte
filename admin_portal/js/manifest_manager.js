/**
 * SınıfCepte Web Admin Paneli - Versiyon Manifesti ve Bakım Modu Yöneticisi
 */
class ManifestManager {
  constructor() {
    this.manifest = {
      calendarVersion: 1,
      outcomesVersion: 1,
      announcementsVersion: 1,
      minRequiredAppVersion: '1.0.0',
      latestAppVersion: '1.0.0',
      maintenanceMode: false,
      maintenanceMessage: 'Sistemde planlı bakım çalışması yapılmaktadır. Lütfen kısa süre sonra tekrar deneyiniz.',
      lastUpdated: new Date().toISOString(),
    };

    this.announcements = [
      {
        id: 'ann_1',
        title: '2025-2026 Eğitim Öğretim Yılı Hayırlı Olsun 🎉',
        body: 'Yeni eğitim döneminde tüm öğretmenlerimize başarılar dileriz. Güncel MEB çalışma takvimi uygulamaya entegre edilmiştir.',
        type: 'general',
        publishDate: '2025-09-08',
      },
      {
        id: 'ann_2',
        title: '1. Dönem Ortak Sınav Tarihleri Açıklandı 📝',
        body: 'MEB 1. Dönem 1. Ortak Sınavları Ekim ayı son haftasında gerçekleştirilecektir.',
        type: 'exam',
        publishDate: '2025-10-15',
      },
    ];

    this.initSaved();
  }

  initSaved() {
    const saved = localStorage.getItem('sinifcepte_admin_manifest');
    if (saved) {
      try {
        this.manifest = Object.assign(this.manifest, JSON.parse(saved));
      } catch (e) {
        console.error('Manifest parse error:', e);
      }
    }

    const savedAnn = localStorage.getItem('sinifcepte_admin_announcements');
    if (savedAnn) {
      try {
        this.announcements = JSON.parse(savedAnn);
      } catch (e) {
        console.error('Announcements parse error:', e);
      }
    }
  }

  save() {
    this.manifest.lastUpdated = new Date().toISOString();
    localStorage.setItem('sinifcepte_admin_manifest', JSON.stringify(this.manifest));
    localStorage.setItem('sinifcepte_admin_announcements', JSON.stringify(this.announcements));
  }

  incrementCalendarVersion() {
    this.manifest.calendarVersion++;
    this.save();
    return this.manifest.calendarVersion;
  }

  incrementOutcomesVersion() {
    this.manifest.outcomesVersion++;
    this.save();
    return this.manifest.outcomesVersion;
  }

  setMaintenanceMode(enabled, message = null) {
    this.manifest.maintenanceMode = enabled;
    if (message) this.manifest.maintenanceMessage = message;
    this.save();
  }

  addAnnouncement(ann) {
    if (!ann.id) ann.id = 'ann_' + Date.now();
    ann.publishDate = ann.publishDate || new Date().toISOString().split('T')[0];
    this.announcements.unshift(ann);
    this.manifest.announcementsVersion++;
    this.save();
  }

  deleteAnnouncement(id) {
    this.announcements = this.announcements.filter((a) => a.id !== id);
    this.manifest.announcementsVersion++;
    this.save();
  }

  renderAnnouncementsTable() {
    const tbody = document.getElementById('announcements-tbody');
    if (!tbody) return;

    if (this.announcements.length === 0) {
      tbody.innerHTML = `<tr><td colspan="5" style="text-align:center; color: var(--text-muted); padding: 20px;">Henüz yayınlanmış bir sistem duyurusu yok.</td></tr>`;
      return;
    }

    tbody.innerHTML = this.announcements
      .map((item) => {
        return `
        <tr>
          <td><strong>${item.title}</strong></td>
          <td style="max-width: 300px; font-size: 12.5px;">${item.body}</td>
          <td><span class="badge ${item.type === 'exam' ? 'badge-exam' : 'badge-special'}">${item.type === 'exam' ? '📝 Sınav' : '📢 Genel'}</span></td>
          <td>${item.publishDate}</td>
          <td style="text-align: right;">
            <button class="btn btn-danger" style="padding: 4px 8px; font-size: 11px;" onclick="window.adminApp.deleteAnnouncement('${item.id}')">Sil</button>
          </td>
        </tr>
      `;
      })
      .join('');
  }
}

window.ManifestManager = ManifestManager;
