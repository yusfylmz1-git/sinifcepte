import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/classes/data/services/recent_student_documents.dart';

/// WhatsApp belgeleri Android "Son dosyalar"da görünmez.
/// Uygulama içi listede WhatsApp kaynaklı PDF en üstte durmalı.
void main() {
  RecentStudentDocument doc({
    required String name,
    required String source,
    required DateTime modified,
  }) {
    return RecentStudentDocument(
      name: name,
      path: '/tmp/$name',
      modified: modified,
      source: source,
      size: 10,
    );
  }

  test('KRİTİK: WhatsApp belgeleri Son dosyalardan önce sıralanır', () {
    final newerDownload = doc(
      name: 'indirilen.xlsx',
      source: 'download',
      modified: DateTime(2026, 9, 11, 12),
    );
    final olderWhatsApp = doc(
      name: '5A_liste.pdf',
      source: 'whatsapp',
      modified: DateTime(2026, 9, 10, 8),
    );
    final newerWhatsApp = doc(
      name: '5B_liste.pdf',
      source: 'whatsapp',
      modified: DateTime(2026, 9, 11, 9),
    );

    final sorted = RecentStudentDocument.sortForTeacher([
      newerDownload,
      olderWhatsApp,
      newerWhatsApp,
    ]);

    expect(sorted.map((e) => e.name).toList(), [
      '5B_liste.pdf',
      '5A_liste.pdf',
      'indirilen.xlsx',
    ]);
  });

  test('Kaynak etiketleri öğretmene anlaşılır', () {
    expect(
      doc(
        name: 'a.pdf',
        source: 'whatsapp',
        modified: DateTime(2026, 1, 1),
      ).sourceLabel,
      'WhatsApp',
    );
    expect(
      doc(
        name: 'a.pdf',
        source: 'shared',
        modified: DateTime(2026, 1, 1),
      ).sourceLabel,
      'Paylaşılan',
    );
  });

  test('Haritadan belge üretilir', () {
    final parsed = RecentStudentDocument.fromMap({
      'name': 'liste.pdf',
      'path': '/cache/incoming_share_liste.pdf',
      'modified': 0,
      'source': 'whatsapp',
      'size': 1200,
    });
    expect(parsed.isWhatsApp, isTrue);
    expect(parsed.path, contains('incoming_share'));
  });
}
