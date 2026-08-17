/**
 * SınıfCepte Web Admin Paneli - JSON İndirici & Bulut Dışa Aktarma Motoru
 */
class CloudExporter {
  static downloadFile(filename, content, type = 'application/json') {
    const blob = new Blob([content], { type: type });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    setTimeout(() => {
      document.body.removeChild(a);
      window.URL.revokeObjectURL(url);
    }, 100);
  }

  static exportManifest(manifestManager) {
    const data = JSON.stringify(manifestManager.manifest, null, 2);
    this.downloadFile('sync_manifest.json', data);
  }

  static exportCalendar(calendarManager) {
    const data = JSON.stringify(calendarManager.getEvents(), null, 2);
    this.downloadFile('academic_calendar_2025_2026.json', data);
  }

  static exportOutcomes(outcomesManager, gradeLevel = null, subjectCode = null) {
    let list = outcomesManager.outcomes;
    if (gradeLevel && subjectCode) {
      list = outcomesManager.getFilteredOutcomes(gradeLevel, subjectCode);
      this.downloadFile(`outcomes_${gradeLevel}_${subjectCode}.json`, JSON.stringify(list, null, 2));
    } else {
      this.downloadFile('curriculum_outcomes_all.json', JSON.stringify(list, null, 2));
    }
  }

  static exportExams(examsManager) {
    const data = JSON.stringify(examsManager.getAllExams(), null, 2);
    this.downloadFile('official_exams.json', data);
  }

  static exportFullBackup(calendarManager, outcomesManager, manifestManager, examsManager = null) {
    const bundle = {
      sync_manifest: manifestManager.manifest,
      system_announcements: manifestManager.announcements,
      academic_calendar_events: calendarManager.getEvents(),
      curriculum_outcomes: outcomesManager.outcomes,
      official_exams: examsManager ? examsManager.getAllExams() : [],
      exported_at: new Date().toISOString(),
      app: 'SınıfCepte Admin Portal',
      version: '1.1.0',
    };
    this.downloadFile('sinifcepte_cloud_bundle.json', JSON.stringify(bundle, null, 2));
  }
}

window.CloudExporter = CloudExporter;

