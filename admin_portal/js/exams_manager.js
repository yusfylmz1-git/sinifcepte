/**
 * SınıfCepte Web Admin Paneli - Resmî MEB & ÖSYM Sınav Takvimi Yöneticisi
 */
class ExamsManager {
  constructor() {
    this.exams = [];
    this.selectedInstitution = 'all'; // all, MEB, ÖSYM, MSÜ, DİĞER
    this.searchQuery = '';
    this.initDefaultExams();
  }

  getDefaultSeeds() {
    return [
      {
        doc_id: 'meb_ortak_yazili_1_2025',
        title: '1. Dönem 1. Ortak Yazılı Sınavları (MEB Geneli)',
        institution: 'MEB',
        examDate: '2025-10-27T09:00:00.000',
        applicationDeadline: '2025-10-20T23:59:59.000',
        applicationUrl: 'https://odsgm.meb.gov.tr',
        description: '6. ve 9. sınıflar Türkçe ve Matematik ortak yazılı sınavı',
        category: 'official',
      },
      {
        doc_id: 'meb_ortak_yazili_2_2025',
        title: '1. Dönem 2. Ortak Yazılı Sınavları',
        institution: 'MEB',
        examDate: '2025-12-22T09:00:00.000',
        applicationDeadline: '2025-12-15T23:59:59.000',
        applicationUrl: 'https://odsgm.meb.gov.tr',
        description: 'Ülke geneli ve il geneli 1. dönem 2. yazılı sınavları',
        category: 'official',
      },
      {
        doc_id: 'meb_bilsem_on_degerlendirme_2026',
        title: 'BİLSEM - Bireysel Değerlendirme ve Ön Tarama Sınavı',
        institution: 'BİLSEM',
        examDate: '2026-02-14T09:00:00.000',
        applicationDeadline: '2025-12-30T23:59:59.000',
        applicationUrl: 'https://meb.gov.tr',
        description: '1., 2. ve 3. sınıf öğrencileri yetenek tarama ve değerlendirmesi',
        category: 'official',
      },
      {
        doc_id: 'osym_eyds_2026',
        title: 'e-YDS - Elektronik Yabancı Dil Sınavı',
        institution: 'e-Sınav',
        examDate: '2026-03-07T13:45:00.000',
        applicationDeadline: '2026-02-26T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'ÖSYM e-Sınav Merkezlerinde elektronik Yabancı Dil Bilgisi Seviye Tespit Sınavı',
        category: 'official',
      },
      {
        doc_id: 'meb_ekys_2026',
        title: 'MEB EKYS - Eğitim Kurumlarına Yönetici Seçme Sınavı',
        institution: 'EKYS',
        examDate: '2026-03-15T10:15:00.000',
        applicationDeadline: '2026-02-12T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Milli Eğitim Bakanlığı Müdür ve Müdür Yardımcılığı seçme sınavı',
        category: 'official',
      },
      {
        doc_id: 'meb_mtsk_esinav_2026',
        title: 'MTSK e-Sınavı (Ehliyet Teori Oturumları)',
        institution: 'MTSK',
        examDate: '2026-03-15T10:00:00.000',
        applicationDeadline: '2026-03-01T23:59:59.000',
        applicationUrl: 'https://esinav.meb.gov.tr',
        description: 'MEB e-Sınav Merkezlerinde motorlu taşıt sürücü adayları randevulu teorik sınavı',
        category: 'official',
      },
      {
        doc_id: 'meb_mtsk_direksiyon_2026',
        title: 'MTSK Direksiyon Uygulama Sınavı',
        institution: 'MTSK',
        examDate: '2026-03-22T08:30:00.000',
        applicationDeadline: '2026-03-16T23:59:59.000',
        applicationUrl: 'https://mebbis.meb.gov.tr',
        description: 'İl/İlçe Milli Eğitim Müdürlükleri koordinasyonunda hafta sonu direksiyon sınavı',
        category: 'official',
      },
      {
        doc_id: 'osym_msu_2026',
        title: 'MSÜ - Milli Savunma Üniversitesi Askeri Öğrenci Belirleme Sınavı',
        institution: 'MSÜ',
        examDate: '2026-03-29T10:15:00.000',
        applicationDeadline: '2026-01-25T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Harp Okulları ve Astsubay Meslek Yüksekokulları Giriş Sınavı',
        category: 'official',
      },
      {
        doc_id: 'meb_acik_lise_esinav_2026',
        title: 'AÖK (Açık Lise & Ortaokul) 2. Dönem e-Sınavı',
        institution: 'e-Sınav',
        examDate: '2026-04-01T09:00:00.000',
        applicationDeadline: '2026-03-15T23:59:59.000',
        applicationUrl: 'https://aol.meb.gov.tr',
        description: 'MEB Açık Öğretim Kurumları 2. Dönem e-Sınav randevulu merkez oturumları',
        category: 'official',
      },
      {
        doc_id: 'osym_yds_1_2026',
        title: 'YDS/1 - Yabancı Dil Bilgisi Seviye Tespit Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-04-05T10:15:00.000',
        applicationDeadline: '2026-02-25T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Dil tazminatı ve lisansüstü eğitim için YDS İlkbahar oturumu',
        category: 'official',
      },
      {
        doc_id: 'aof_bahar_ara_2026',
        title: 'AÖF Bahar Dönemi Ara Sınavları (Gözetmenlik & Görev)',
        institution: 'AÖF',
        examDate: '2026-04-18T09:30:00.000',
        applicationDeadline: '2026-04-05T23:59:59.000',
        applicationUrl: 'https://augis.anadolu.edu.tr',
        description: 'Anadolu Üniversitesi Açıköğretim Fakültesi hafta sonu oturumları',
        category: 'official',
      },
      {
        doc_id: 'osym_ales_1_2026',
        title: 'ALES/1 - Akademik Personel ve Lisansüstü Eğitimi Giriş Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-04-19T10:15:00.000',
        applicationDeadline: '2026-03-12T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yüksek lisans ve doktora başvuruları için ALES İlkbahar dönemi',
        category: 'official',
      },
      {
        doc_id: 'meb_iokbs_bursluluk_2026',
        title: 'İOKBS - MEB İlköğretim ve Ortaöğretim Bursluluk Sınavı',
        institution: 'MEB',
        examDate: '2026-04-26T10:00:00.000',
        applicationDeadline: '2026-03-15T23:59:59.000',
        applicationUrl: 'https://odsgm.meb.gov.tr',
        description: '5, 6, 7, 8, 9, 10 ve 11. sınıflar için devlet bursluluk sınavı',
        category: 'official',
      },
      {
        doc_id: 'meb_mesem_kalfalik_2026',
        title: 'MESEM Kalfalık ve Ustalık Teorik e-Sınavı',
        institution: 'e-Sınav',
        examDate: '2026-05-02T10:00:00.000',
        applicationDeadline: '2026-04-20T23:59:59.000',
        applicationUrl: 'https://mesem.meb.gov.tr',
        description: 'Mesleki Eğitim Merkezi çıraklık, kalfalık ve ustalık e-Sınavları',
        category: 'official',
      },
      {
        doc_id: 'meb_lgs_2026',
        title: 'LGS - Liselere Geçiş Sistemi Sınavı',
        institution: 'MEB',
        examDate: '2026-06-14T09:30:00.000',
        applicationDeadline: '2026-04-15T23:59:59.000',
        applicationUrl: 'https://e-okul.meb.gov.tr',
        description: '8. Sınıf öğrencileri için Merkezi Sınav (Sözel & Sayısal oturumlar)',
        category: 'official',
      },
      {
        doc_id: 'osym_yks_tyt_2026',
        title: 'YKS 1. Oturum - TYT (Temel Yeterlilik Testi)',
        institution: 'ÖSYM',
        examDate: '2026-06-20T10:15:00.000',
        applicationDeadline: '2026-03-10T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yükseköğretim Kurumları Sınavı 1. Oturum TYT',
        category: 'official',
      },
      {
        doc_id: 'osym_yks_ayt_2026',
        title: 'YKS 2. Oturum - AYT (Alan Yeterlilik Testi)',
        institution: 'ÖSYM',
        examDate: '2026-06-21T10:15:00.000',
        applicationDeadline: '2026-03-10T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yükseköğretim Kurumları Sınavı 2. Oturum AYT',
        category: 'official',
      },
      {
        doc_id: 'meb_ags_oabt_2026',
        title: 'MEB-AGS - Milli Eğitim Akademisi Giriş Sınavı & ÖABT',
        institution: 'AGS',
        examDate: '2026-07-12T10:15:00.000',
        applicationDeadline: '2026-05-15T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Öğretmenlik Meslek Kanunu (ÖMK) kapsamında Milli Eğitim Akademisi hazırlık eğitimi giriş sınavı',
        category: 'official',
      },
      {
        doc_id: 'osym_kpss_lisans_2026',
        title: 'KPSS Lisans - Genel Yetenek & Genel Kültür / Eğitim Bilimleri',
        institution: 'ÖSYM',
        examDate: '2026-07-19T10:15:00.000',
        applicationDeadline: '2026-05-20T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Kamu Personel Seçme Sınavı oturumları',
        category: 'official',
      },
      {
        doc_id: 'osym_kpss_oabt_2026',
        title: 'KPSS ÖABT - Öğretmenlik Alan Bilgisi Testi',
        institution: 'ÖSYM',
        examDate: '2026-08-02T10:15:00.000',
        applicationDeadline: '2026-05-20T23:59:59.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Milli Eğitim Bakanlığı öğretmen alımı ÖABT oturumları',
        category: 'official',
      },
    ];
  }

  initDefaultExams() {
    const defaultSeeds = this.getDefaultSeeds();
    const saved = localStorage.getItem('sinifcepte_admin_exams_v4');
    if (saved) {
      try {
        this.exams = JSON.parse(saved);
        return;
      } catch (e) {
        console.error('Saved exams parse error:', e);
      }
    }

    // Eski versiyonlardaki hafızayı yeni tohumlarla (AGS, MTSK, e-Sınav, İOKBS, EKYS, ALES, AÖF) otomatik birleştir
    const oldSaved = localStorage.getItem('sinifcepte_admin_exams_v3') || localStorage.getItem('sinifcepte_admin_exams_v2') || localStorage.getItem('sinifcepte_admin_exams');
    if (oldSaved) {
      try {
        const oldExams = JSON.parse(oldSaved);
        const existingIds = new Set(oldExams.map((e) => e.doc_id));
        const merged = [...oldExams];
        for (const seed of defaultSeeds) {
          if (!existingIds.has(seed.doc_id)) {
            merged.push(seed);
          }
        }
        this.exams = merged;
        this.save();
        return;
      } catch (e) {
        console.error('Old exams merge error:', e);
      }
    }

    this.exams = defaultSeeds;
    this.save();
  }

  resetToDefaultExams() {
    this.exams = this.getDefaultSeeds();
    this.save();
    return this.exams.length;
  }

  save() {
    localStorage.setItem('sinifcepte_admin_exams_v4', JSON.stringify(this.exams));
    localStorage.setItem('sinifcepte_admin_exams_v3', JSON.stringify(this.exams));
    localStorage.setItem('sinifcepte_admin_exams_v2', JSON.stringify(this.exams));
    localStorage.setItem('sinifcepte_admin_exams', JSON.stringify(this.exams));
  }

  getAllExams() {
    return this.exams.sort((a, b) => new Date(a.examDate) - new Date(b.examDate));
  }

  getFilteredExams() {
    return this.getAllExams().filter((item) => {
      // Kurum filtresi
      if (this.selectedInstitution !== 'all' && item.institution !== this.selectedInstitution) {
        return false;
      }
      // Arama filtresi
      if (this.searchQuery) {
        const q = this.searchQuery.toLowerCase();
        const t = (item.title || '').toLowerCase();
        const d = (item.description || '').toLowerCase();
        const inst = (item.institution || '').toLowerCase();
        return t.includes(q) || d.includes(q) || inst.includes(q);
      }
      return true;
    });
  }

  addExam(exam) {
    if (!exam.doc_id) {
      exam.doc_id = 'exam_' + Date.now() + '_' + Math.random().toString(36).substr(2, 4);
    }
    this.exams.push(exam);
    this.save();
  }

  updateExam(updated) {
    const idx = this.exams.findIndex((e) => e.doc_id === updated.doc_id);
    if (idx !== -1) {
      this.exams[idx] = updated;
      this.save();
    }
  }

  deleteExam(docId) {
    this.exams = this.exams.filter((e) => e.doc_id !== docId);
    this.save();
  }

  importExamsJSON(jsonArray) {
    if (!Array.isArray(jsonArray)) throw new Error('Geçersiz sınav JSON formatı!');
    let count = 0;
    jsonArray.forEach((item) => {
      if (item.title && item.examDate) {
        const existingIdx = this.exams.findIndex((e) => e.doc_id === item.doc_id);
        if (existingIdx !== -1) {
          this.exams[existingIdx] = item;
        } else {
          this.exams.push(item);
        }
        count++;
      }
    });
    this.save();
    return count;
  }

  exportJSON() {
    const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(this.exams, null, 2));
    const dlAnchorElem = document.createElement('a');
    dlAnchorElem.setAttribute('href', dataStr);
    dlAnchorElem.setAttribute('download', 'official_exams.json');
    dlAnchorElem.click();
  }

  getInstitutionBadge(inst) {
    switch (inst) {
      case 'MEB':
        return '<span class="badge" style="background: rgba(37, 99, 235, 0.12); color: #2563EB; font-weight: 700;">🏛️ MEB</span>';
      case 'ÖSYM':
        return '<span class="badge" style="background: rgba(147, 51, 234, 0.12); color: #9333EA; font-weight: 700;">🎓 ÖSYM</span>';
      case 'MTSK':
        return '<span class="badge" style="background: rgba(5, 150, 105, 0.12); color: #059669; font-weight: 700;">🚗 MTSK</span>';
      case 'e-Sınav':
        return '<span class="badge" style="background: rgba(2, 132, 199, 0.12); color: #0284C7; font-weight: 700;">💻 e-Sınav</span>';
      case 'MSÜ':
        return '<span class="badge" style="background: rgba(217, 119, 6, 0.12); color: #D97706; font-weight: 700;">🎖️ MSÜ</span>';
      case 'BİLSEM':
        return '<span class="badge" style="background: rgba(13, 148, 136, 0.12); color: #0D9488; font-weight: 700;">💡 BİLSEM</span>';
      case 'AÖF':
        return '<span class="badge" style="background: rgba(79, 70, 229, 0.12); color: #4F46E5; font-weight: 700;">📚 AÖF</span>';
      case 'EKYS':
        return '<span class="badge" style="background: rgba(180, 83, 9, 0.12); color: #B45309; font-weight: 700;">💼 EKYS</span>';
      case 'AGS':
        return '<span class="badge" style="background: rgba(225, 29, 72, 0.12); color: #E11D48; font-weight: 700;">🏫 MEB-AGS</span>';
      default:
        return `<span class="badge" style="background: rgba(100, 116, 139, 0.12); color: #64748B; font-weight: 700;">📌 ${inst}</span>`;
    }
  }


  getCountdownBadge(examDateStr) {
    const examDate = new Date(examDateStr);
    const now = new Date();
    const diffMs = examDate - now;
    const diffDays = Math.ceil(diffMs / (1000 * 60 * 60 * 24));

    if (diffDays < 0) {
      return '<span class="badge" style="background: rgba(100, 116, 139, 0.12); color: #94A3B8;">Tamamlandı</span>';
    }
    if (diffDays === 0) {
      return '<span class="badge" style="background: rgba(220, 38, 38, 0.15); color: #DC2626; font-weight: 800; animation: pulse 1.5s infinite;">🚨 Bugün Sınav Günü!</span>';
    }
    if (diffDays <= 7) {
      return `<span class="badge" style="background: rgba(234, 88, 12, 0.15); color: #EA580C; font-weight: 800;">⚡ Son ${diffDays} Gün!</span>`;
    }
    if (diffDays <= 30) {
      return `<span class="badge" style="background: rgba(202, 138, 4, 0.15); color: #CA8A04; font-weight: 700;">⏳ ${diffDays} Gün Kaldı</span>`;
    }
    return `<span class="badge" style="background: rgba(22, 163, 74, 0.12); color: #16A34A; font-weight: 700;">⏳ ${diffDays} Gün</span>`;
  }
}

window.ExamsManager = ExamsManager;
