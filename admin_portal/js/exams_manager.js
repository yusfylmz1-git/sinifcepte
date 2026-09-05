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

  /**
   * Varsayilan sinav takvimi — 35 sinav.
   *
   * ## Bu liste ELLE DUZENLENMEZ
   * `assets/data/official_exams.json` dosyasindan uretiliyor; APK ile
   * ayni kaynak. Eskiden panel kendi kopyasini tutuyordu ve iki taraf
   * kaymisti (panelde 20, APK'da 35) — "Orijinal Takvimi Yukle" eski
   * listeye donuyordu.
   *
   * Veri degisince `tool/panel_tohum_uret.py` calistirilir.
   */
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
        doc_id: 'osym_eyds_20260124',
        title: 'e-YDS - Elektronik Yabancı Dil Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-01-24T09:00:00.000',
        applicationDeadline: '2026-01-15T23:59:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Bilgisayarlı yabancı dil sınavı.',
        category: 'ÖSYM',
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
        doc_id: 'osym_eyds_20260214',
        title: 'e-YDS - Elektronik Yabancı Dil Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-02-14T09:00:00.000',
        applicationDeadline: '2026-02-05T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Bilgisayarlı yabancı dil sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_msu_20260301',
        title: 'MSÜ - Askerî Öğrenci Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-03-01T10:15:00.000',
        applicationDeadline: '2026-01-29T23:59:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Askerî öğrenci aday belirleme sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_yokdil_20260308',
        title: 'YÖKDİL - Yabancı Dil Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-03-08T09:00:00.000',
        applicationDeadline: '2026-01-29T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yükseköğretim yabancı dil sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_mebekys_20260315',
        title: 'EKYS - Yönetici Seçme Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-03-15T09:00:00.000',
        applicationDeadline: '2026-02-05T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Okul yöneticiliği seçme sınavı.',
        category: 'ÖSYM',
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
        doc_id: 'osym_yds_20260405',
        title: 'YDS - Yabancı Dil Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-04-05T09:00:00.000',
        applicationDeadline: '2026-02-26T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yabancı dil seviye tespit sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_tryos_20260412',
        title: 'TR-YÖS - Yurt Dışı Öğrenci Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-04-12T09:00:00.000',
        applicationDeadline: '2026-02-03T23:59:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yurt dışından öğrenci kabul sınavı.',
        category: 'ÖSYM',
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
        doc_id: 'osym_ekpss_20260419',
        title: 'EKPSS - Engelli Kamu Personeli Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-04-19T09:00:00.000',
        applicationDeadline: '2026-02-24T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Engelli kamu personeli sınavı; öğretmenler görev alır.',
        category: 'ÖSYM',
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
        doc_id: 'osym_ales_20260510',
        title: 'ALES - Akademik Personel Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-05-10T09:00:00.000',
        applicationDeadline: '2026-04-02T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Lisansüstü eğitim ve akademik kadro giriş sınavı.',
        category: 'ÖSYM',
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
        doc_id: 'osym_yks_20260620',
        title: 'YKS - Yükseköğretim Kurumları Sınavı — 1. Oturum (TYT)',
        institution: 'ÖSYM',
        examDate: '2026-06-20T09:00:00.000',
        applicationDeadline: '2026-03-02T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Üniversiteye giriş sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_yks_20260621',
        title: 'YKS - Yükseköğretim Kurumları Sınavı — 2. Oturum (AYT)',
        institution: 'ÖSYM',
        examDate: '2026-06-21T09:00:00.000',
        applicationDeadline: '2026-03-02T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Üniversiteye giriş sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_yks_20260621',
        title: 'YKS - Yükseköğretim Kurumları Sınavı — 3. Oturum (YDT)',
        institution: 'ÖSYM',
        examDate: '2026-06-21T09:00:00.000',
        applicationDeadline: '2026-03-02T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Üniversiteye giriş sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_dgs_20260719',
        title: 'DGS - Dikey Geçiş Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-07-19T09:00:00.000',
        applicationDeadline: '2026-06-02T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Ön lisanstan lisansa geçiş sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_mebags_20260726',
        title: 'AGS - Akademi Giriş Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-07-26T09:00:00.000',
        applicationDeadline: '2026-05-20T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Öğretmenlik akademi giriş sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_ales_20260802',
        title: 'ALES - Akademik Personel Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-08-02T09:00:00.000',
        applicationDeadline: '2026-06-18T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Lisansüstü eğitim ve akademik kadro giriş sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_yokdil_20260809',
        title: 'YÖKDİL - Yabancı Dil Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-08-09T09:00:00.000',
        applicationDeadline: '2026-06-24T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yükseköğretim yabancı dil sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_kpss_20260906',
        title: 'KPSS - Kamu Personel Seçme Sınavı — Lisans (Genel Yetenek-Genel Kültür)',
        institution: 'ÖSYM',
        examDate: '2026-09-06T09:00:00.000',
        applicationDeadline: '2026-07-13T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Kamu personeli seçme sınavı; öğretmenler görev alır.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_kpss_20260912',
        title: 'KPSS - Kamu Personel Seçme Sınavı — Lisans (Alan Bilgisi) 1. gün',
        institution: 'ÖSYM',
        examDate: '2026-09-12T09:00:00.000',
        applicationDeadline: '2026-07-13T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Kamu personeli seçme sınavı; öğretmenler görev alır.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_kpss_20260913',
        title: 'KPSS - Kamu Personel Seçme Sınavı — Lisans (Alan Bilgisi) 2. gün',
        institution: 'ÖSYM',
        examDate: '2026-09-13T09:00:00.000',
        applicationDeadline: '2026-07-13T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Kamu personeli seçme sınavı; öğretmenler görev alır.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_kpss_20261004',
        title: 'KPSS - Kamu Personel Seçme Sınavı — Ön Lisans',
        institution: 'ÖSYM',
        examDate: '2026-10-04T10:15:00.000',
        applicationDeadline: '2026-08-10T23:59:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Kamu personeli seçme sınavı; öğretmenler görev alır.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_tryos_20261011',
        title: 'TR-YÖS - Yurt Dışı Öğrenci Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-10-11T09:00:00.000',
        applicationDeadline: '2026-08-03T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yurt dışından öğrenci kabul sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_kpss_20261025',
        title: 'KPSS - Kamu Personel Seçme Sınavı — Ortaöğretim',
        institution: 'ÖSYM',
        examDate: '2026-10-25T09:00:00.000',
        applicationDeadline: '2026-09-08T23:59:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Kamu personeli seçme sınavı; öğretmenler görev alır.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_kpss_20261101',
        title: 'KPSS - Kamu Personel Seçme Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-11-01T09:00:00.000',
        applicationDeadline: '2026-09-30T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Kamu personeli seçme sınavı; öğretmenler görev alır.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_yds_20261122',
        title: 'YDS - Yabancı Dil Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-11-22T09:00:00.000',
        applicationDeadline: '2026-10-08T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Yabancı dil seviye tespit sınavı.',
        category: 'ÖSYM',
      },
      {
        doc_id: 'osym_ales_20261129',
        title: 'ALES - Akademik Personel Sınavı',
        institution: 'ÖSYM',
        examDate: '2026-11-29T09:00:00.000',
        applicationDeadline: '2026-10-15T09:00:00.000',
        applicationUrl: 'https://ais.osym.gov.tr',
        description: 'Lisansüstü eğitim ve akademik kadro giriş sınavı.',
        category: 'ÖSYM',
      },
    ];
  }

  initDefaultExams() {
    const defaultSeeds = this.getDefaultSeeds();
    const saved = localStorage.getItem('sinifcepte_admin_exams_v5');
    if (saved) {
      try {
        this.exams = JSON.parse(saved);
        return;
      } catch (e) {
        console.error('Saved exams parse error:', e);
      }
    }

    // ESKİ SÜRÜMLERDEN BİRLEŞTİRME YAPILMIYOR.
    //
    // v3/v2 anahtarlarında ÖSYM'den süzülmemiş 87 sınav duruyor
    // (tıp/hukuk uzmanlık sınavları dahil). Birleştirme onları geri
    // getiriyor ve temiz liste kirleniyordu.
    //
    // Birleştirme eskiden gerekliydi: panele yeni sınav türü
    // eklendiğinde yöneticinin düzenlemeleri kaybolmasın diye. Artık
    // tohum listesi APK verisinden üretiliyor (tool/panel_tohum_uret.py),
    // yani her iki taraf da aynı kaynağı kullanıyor.
    this.exams = defaultSeeds;
    this.save();
  }

  resetToDefaultExams() {
    this.exams = this.getDefaultSeeds();
    this.save();
    return this.exams.length;
  }

  save() {
    // Tek anahtar: eski sürümlere de yazmak, kirli kopyaların
    // yaşamasına yol açıyordu.
    localStorage.setItem('sinifcepte_admin_exams_v5', JSON.stringify(this.exams));
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
