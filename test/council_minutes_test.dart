import 'package:flutter_test/flutter_test.dart';
import 'package:sinifcepte/features/documents/data/council_minutes.dart';

void main() {
  group('ŞÖK kademe sınırı', () {
    test('ilkokul 1-4. sınıfta ŞÖK kurulmaz', () {
      for (final g in [1, 2, 3, 4]) {
        expect(CouncilMinutes.sokPermitted(grade: g), isFalse);
      }
    });

    test('okul türü ilkokul ise şube adı 5-A olsa da ŞÖK kapalı', () {
      expect(
        CouncilMinutes.sokPermitted(grade: 5, schoolType: 'İlkokul'),
        isFalse,
      );
    });

    test('ortaokul ve lise ŞÖK açılır', () {
      expect(CouncilMinutes.sokPermitted(grade: 5), isTrue);
      expect(CouncilMinutes.sokPermitted(grade: 8), isTrue);
      expect(CouncilMinutes.sokPermitted(grade: 11), isTrue);
    });
  });

  group('Gündem yönerge maddeleri', () {
    test('zümre sene başı ölçme maddesini silmeden taşır', () {
      final items = CouncilMinutes.buildAgenda(
        kind: CouncilKind.zumre,
        period: CouncilPeriod.yearStart,
      );
      expect(items.length, greaterThanOrEqualTo(8));
      expect(items.every((i) => i.required), isTrue);
      expect(
        items.any((i) => i.text.toLowerCase().contains('ölçme')),
        isTrue,
      );
      expect(
        items.every((i) => i.decision.toLowerCase().contains('karar')),
        isTrue,
      );
    });

    test('zümre yıl sonu işlenmemiş karar bırakılmaz der', () {
      final items = CouncilMinutes.buildAgenda(
        kind: CouncilKind.zumre,
        period: CouncilPeriod.yearEnd,
      );
      expect(
        items.any((i) => i.text.contains('işlenmemiş karar')),
        isTrue,
      );
    });

    test('ŞÖK yıl sonu 5. sınıfta sınıf geçme maddesi vardır', () {
      final items = CouncilMinutes.buildAgenda(
        kind: CouncilKind.sok,
        period: CouncilPeriod.yearEnd,
        grade: 6,
      );
      expect(
        items.any((i) => i.text.toLowerCase().contains('sınıf geçme')),
        isTrue,
      );
    });

    test('yönerge maddesi silinmez, ek madde silinir', () {
      var items = CouncilMinutes.buildAgenda(
        kind: CouncilKind.zumre,
        period: CouncilPeriod.yearStart,
      );
      final before = items.length;
      items = CouncilMinutes.removeAt(items, 0);
      expect(items.length, before);

      items = CouncilMinutes.addExtra(items);
      expect(items.last.required, isFalse);
      items = CouncilMinutes.removeAt(items, items.length - 1);
      expect(items.length, before);
    });
  });

  group('Etiketler ve taslak iddiası', () {
    test('akademik yıl Ağustos’tan itibaren yeni yılı açar', () {
      expect(
        CouncilMinutes.academicYearLabel(DateTime(2026, 8, 15)),
        '2026-2027',
      );
      expect(
        CouncilMinutes.academicYearLabel(DateTime(2026, 3, 1)),
        '2025-2026',
      );
    });

    test('önerilen dönem takvime uyar', () {
      expect(
        CouncilMinutes.suggestedPeriod(DateTime(2026, 9, 8)),
        CouncilPeriod.yearStart,
      );
      expect(
        CouncilMinutes.suggestedPeriod(DateTime(2026, 2, 3)),
        CouncilPeriod.secondTerm,
      );
      expect(
        CouncilMinutes.suggestedPeriod(DateTime(2026, 6, 20)),
        CouncilPeriod.yearEnd,
      );
    });

    test('PDF başlığı resmî ürün iddiası taşımaz; işlem notu vardır', () {
      // Önce burada "resmî bir ürünü değildir" ibaresi ZORUNLU
      // tutuluyordu. Öğretmen o çekincenin kalkmasını istedi:
      // okul dosyasına konan evrakta belgeyi idarenin gözünde
      // geçersiz gösteriyordu (BEP raporunda da aynısı kaldırıldı).
      //
      // Testin ardındaki kaygı meşru — belge MEB'in resmî ürünü gibi
      // görünmemeli — ama bu, çekince cümlesiyle değil UYGULAMA
      // ADININ belgede hiç geçmemesiyle sağlanır. Başlıkta okulun
      // kendi adı basılıyor.
      expect(CouncilMinutes.disclaimer.contains('SınıfCepte'), isFalse,
          reason: 'uygulama adı resmî evrakta geçmemeli');
      // İşlem notu KALIR: kararların nereye işleneceğini söylüyor.
      expect(CouncilMinutes.disclaimer.contains('e-Kurul'), isTrue);
      final title = CouncilMinutes.documentTitle(
        kind: CouncilKind.sok,
        period: CouncilPeriod.yearStart,
        branch: 'Matematik',
        className: '6-A',
      );
      expect(title.contains('6-A'), isTrue);
      expect(title.contains('ŞUBE ÖĞRETMENLER KURULU'), isTrue);
    });

    test('sınıf adından kademe okunur', () {
      expect(CouncilMinutes.gradeFromClassName('6-A'), 6);
      expect(CouncilMinutes.gradeFromClassName('11-D'), 11);
    });
  });

  group('Branş yerleşimi', () {
    test('sınıf açıklaması branş olarak kullanılmaz', () {
      expect(CouncilMinutes.titleBranch(profileBranch: 'Matematik'), 'Matematik');
      expect(CouncilMinutes.titleBranch(profileBranch: ''), '');
    });

    test('görev parantezi branştan ayrılır', () {
      expect(
        CouncilMinutes.stripRoleSuffix('Matematik (Sınıf Rehber Öğretmeni)'),
        'Matematik',
      );
    });

    test('sınıf öğretmeni zümresi şube adına göre 3. sınıflar olur', () {
      final title = CouncilMinutes.documentTitle(
        kind: CouncilKind.zumre,
        period: CouncilPeriod.yearStart,
        branch: 'Sınıf Öğretmeni',
        className: '3-B',
      );
      expect(title.contains('3. SINIFLAR'), isTrue);
      expect(title.contains('SABAH'), isFalse);
    });

    test('zümre yalnızca aynı branşı alır', () {
      final staff = [
        const CouncilAttendee(name: 'Ayşe', branch: 'Matematik', isChair: true),
        const CouncilAttendee(name: 'Can', branch: 'Fen Bilimleri'),
        const CouncilAttendee(name: 'Deniz', branch: 'Matematik (Sınıf Rehber Öğretmeni)'),
      ];
      final got = CouncilMinutes.resolveAttendees(
        kind: CouncilKind.zumre,
        teacherName: 'Ayşe',
        teacherBranch: 'Matematik',
        staff: staff,
      );
      expect(got.map((a) => a.name), ['Ayşe', 'Deniz']);
      expect(got.every((a) => CouncilMinutes.sameBranch(a.branch, 'Matematik')), isTrue);
    });

    test('ŞÖK şubedeki tüm branşları alır', () {
      final staff = [
        const CouncilAttendee(name: 'Ayşe', branch: 'Türkçe', isChair: true),
        const CouncilAttendee(name: 'Can', branch: 'Matematik'),
        const CouncilAttendee(name: 'Deniz', branch: 'Fen Bilimleri'),
      ];
      final got = CouncilMinutes.resolveAttendees(
        kind: CouncilKind.sok,
        teacherName: 'Ayşe',
        teacherBranch: 'Türkçe',
        staff: staff,
      );
      expect(got.map((a) => a.branch).toSet(), {'Türkçe', 'Matematik', 'Fen Bilimleri'});
      expect(got.where((a) => a.isChair).single.name, 'Ayşe');
    });

    test('kadro boşsa yalnızca profil branşı yazılır', () {
      final got = CouncilMinutes.resolveAttendees(
        kind: CouncilKind.zumre,
        teacherName: 'Ayşe Kaya',
        teacherBranch: 'İngilizce',
      );
      expect(got, hasLength(1));
      expect(got.single.branch, 'İngilizce');
      expect(got.single.isChair, isTrue);
    });
  });
}
