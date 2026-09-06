/// Zümre ve ŞÖK tutanak taslağı.
///
/// MEB tek bir PDF maketi yayımlamaz. Bağlayıcı olan Eğitim Kurulları ve
/// Zümreleri Yönergesi'ndeki gündem, karar dili, tam imza ve e-Kurul
/// kaydıdır. Bu dosya o gündemi dönem ve kademeye göre üretir.
///
/// Çıktı **taslaktır**: e-Kurul yerine geçmez, resmî evrak iddiası taşımaz.
library;

import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/turkish_text.dart';

/// Kurul türü.
enum CouncilKind {
  /// Aynı dersi / alanı okutan öğretmenler.
  zumre,

  /// Aynı şubede dersi olan branş öğretmenleri + rehber öğretmen.
  sok,
}

/// Yönergedeki üç olağan toplantı.
enum CouncilPeriod {
  yearStart,
  secondTerm,
  yearEnd,
}

/// Gündem maddesi. Yönerge maddesi silinmez; ek madde eklenebilir.
class CouncilAgendaItem {
  final String id;
  final String text;
  final bool required;
  final String decision;

  const CouncilAgendaItem({
    required this.id,
    required this.text,
    this.required = true,
    this.decision = '',
  });

  CouncilAgendaItem copyWith({String? text, String? decision}) {
    return CouncilAgendaItem(
      id: id,
      text: text ?? this.text,
      required: required,
      decision: decision ?? this.decision,
    );
  }
}

/// İmza sirküsündeki üye.
class CouncilAttendee {
  final String name;
  final String branch;
  final bool present;
  final bool isChair;

  const CouncilAttendee({
    required this.name,
    required this.branch,
    this.present = true,
    this.isChair = false,
  });

  CouncilAttendee copyWith({
    String? name,
    String? branch,
    bool? present,
    bool? isChair,
  }) {
    return CouncilAttendee(
      name: name ?? this.name,
      branch: branch ?? this.branch,
      present: present ?? this.present,
      isChair: isChair ?? this.isChair,
    );
  }
}

/// Taslak üretimi için yardımcı kurallar.
class CouncilMinutes {
  CouncilMinutes._();

  /// Belgenin altına basılan işlem notu.
  ///
  /// Önce "SınıfCepte, Millî Eğitim Bakanlığı'nın resmî bir ürünü
  /// değildir" çekincesi de vardı; öğretmenin okul dosyasına koyacağı
  /// evrakta bu ibare belgeyi idarenin gözünde geçersiz gösteriyordu.
  /// Kalan cümle İŞLEVSEL: kararların nereye işleneceğini söylüyor.
  static const String disclaimer =
      'Arşiv kopyasıdır. Gündem ve kararlar e-Kurul ve Zümre Modülüne '
      'işlenir; müdür onayından sonra uygulanır.';

  static const String decisionHint =
      'Cümle "karar verildi / uygulanmasına karar verildi" ile bitsin. '
      '"Görüşüldü, temenni edildi" kullanılmaz.';

  static String kindLabel(CouncilKind kind) {
    switch (kind) {
      case CouncilKind.zumre:
        return 'Zümre Öğretmenler Kurulu';
      case CouncilKind.sok:
        return 'Şube Öğretmenler Kurulu (ŞÖK)';
    }
  }

  static String periodLabel(CouncilPeriod period) {
    switch (period) {
      case CouncilPeriod.yearStart:
        return 'Sene başı';
      case CouncilPeriod.secondTerm:
        return '2. dönem başı';
      case CouncilPeriod.yearEnd:
        return 'Ders yılı sonu';
    }
  }

  /// Ağustos–Ekim sene başı, Ocak–Mart 2. dönem, Mayıs–Temmuz yıl sonu.
  static CouncilPeriod suggestedPeriod([DateTime? now]) {
    final month = (now ?? DateTime.now()).month;
    if (month >= 5 && month <= 7) return CouncilPeriod.yearEnd;
    if (month == 1 || month == 2 || month == 3) return CouncilPeriod.secondTerm;
    return CouncilPeriod.yearStart;
  }

  /// Eğitim-öğretim yılı etiketi: Ağustos'tan itibaren yeni yıl.
  static String academicYearLabel([DateTime? now]) {
    final d = now ?? DateTime.now();
    final start = d.month >= 8 ? d.year : d.year - 1;
    return '$start-${start + 1}';
  }

  static int? gradeFromClassName(String className) {
    final raw = InputSanitizer.extractGradeLevel(className);
    if (raw == null) return null;
    return int.tryParse(raw);
  }

  /// ŞÖK ilkokul ve okul öncesinde kurulmaz (yönerge).
  static bool sokPermitted({int? grade, String? schoolType}) {
    final type = (schoolType ?? '').toLowerCase();
    if (type.contains('ilkokul') || type.contains('okul öncesi')) {
      return false;
    }
    if (grade != null && grade <= 4) return false;
    return true;
  }

  static String sokBlockedReason({int? grade, String? schoolType}) {
    return 'ŞÖK, okul öncesi ve ilkokullarda kurulmaz (Eğitim Kurulları ve '
        'Zümreleri Yönergesi). ${grade != null ? '$grade. sınıf için ' : ''}'
        'zümre tutanağı kullanın.';
  }

  static String documentTitle({
    required CouncilKind kind,
    required CouncilPeriod period,
    required String branch,
    String? className,
  }) {
    final periodText = periodLabel(period).toUpperCase();
    if (kind == CouncilKind.sok) {
      final cls = (className ?? '').trim();
      final head = cls.isEmpty ? 'ŞUBE' : cls.toUpperCase();
      return '$head ŞUBE ÖĞRETMENLER KURULU ($periodText) TOPLANTI TUTANAĞI';
    }
    final cleaned = stripRoleSuffix(branch);
    final grade = className == null ? null : gradeFromClassName(className);
    if (isClassroomTeacher(cleaned) && grade != null) {
      return '$grade. SINIFLAR ZÜMRE ÖĞRETMENLER KURULU ($periodText) TOPLANTI TUTANAĞI';
    }
    final subject = cleaned.trim().isEmpty ? 'ALAN' : cleaned.trim().toUpperCase();
    return '$subject ZÜMRE ÖĞRETMENLER KURULU ($periodText) TOPLANTI TUTANAĞI';
  }

  /// Sınıfın "açıklama / ders" alanı branş değildir.
  static String titleBranch({required String profileBranch}) =>
      stripRoleSuffix(profileBranch);

  /// Kadro etiketinden görev parantezini ayıklar.
  ///
  /// `"Matematik (Sınıf Rehber Öğretmeni)"` → `"Matematik"`
  static String stripRoleSuffix(String raw) {
    return raw
        .replaceAll(
          RegExp(
            r'\s*\((sınıf rehber öğretmeni|şube rehber öğretmeni|zümre başkanı)\)\s*$',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
  }

  static bool isClassroomTeacher(String branch) {
    final folded = trFold(stripRoleSuffix(branch));
    return folded == 'sinif ogretmeni' || folded == 'okul oncesi';
  }

  static bool sameBranch(String left, String right) {
    final a = trFold(stripRoleSuffix(left));
    final b = trFold(stripRoleSuffix(right));
    return a.isNotEmpty && a == b;
  }

  /// Zümre: aynı branş. ŞÖK: şubenin tüm ders öğretmenleri.
  static List<CouncilAttendee> resolveAttendees({
    required CouncilKind kind,
    required String teacherName,
    required String teacherBranch,
    List<CouncilAttendee> staff = const [],
  }) {
    final name = teacherName.trim();
    final branch = stripRoleSuffix(teacherBranch);

    if (kind == CouncilKind.zumre) {
      final peers = staff
          .where((a) =>
              branch.isEmpty ||
              sameBranch(a.branch, branch) ||
              isClassroomTeacher(branch) && isClassroomTeacher(a.branch))
          .map((a) => a.copyWith(branch: stripRoleSuffix(a.branch)))
          .toList();
      if (peers.isEmpty) {
        return [
          CouncilAttendee(
            name: name,
            branch: branch.isEmpty ? 'Zümre üyesi' : branch,
            present: true,
            isChair: true,
          ),
        ];
      }
      return _ensureSelfAndChair(peers, name: name, branch: branch);
    }

    if (staff.isEmpty) {
      return [
        CouncilAttendee(
          name: name,
          branch: branch.isEmpty ? 'Şube rehber öğretmeni' : branch,
          present: true,
          isChair: true,
        ),
      ];
    }

    final members = [
      for (final a in staff)
        a.copyWith(branch: stripRoleSuffix(a.branch)),
    ];
    return _ensureSelfAndChair(members, name: name, branch: branch);
  }

  static List<CouncilAttendee> _ensureSelfAndChair(
    List<CouncilAttendee> raw, {
    required String name,
    required String branch,
  }) {
    var list = [...raw];
    final selfIdx = list.indexWhere((a) => trFold(a.name) == trFold(name));
    if (selfIdx < 0 && name.isNotEmpty) {
      list = [
        CouncilAttendee(
          name: name,
          branch: branch,
          present: true,
          isChair: true,
        ),
        ...list,
      ];
    }

    if (list.any((a) => a.isChair)) {
      return [
        for (var i = 0; i < list.length; i++)
          list[i].copyWith(
            isChair: list[i].isChair &&
                list.indexWhere((a) => a.isChair) == i,
          ),
      ];
    }

    final chairIdx = list.indexWhere((a) => trFold(a.name) == trFold(name));
    return [
      for (var i = 0; i < list.length; i++)
        list[i].copyWith(isChair: i == (chairIdx < 0 ? 0 : chairIdx)),
    ];
  }

  static String defaultLocation(CouncilKind kind, String? className) {
    if (kind == CouncilKind.sok && className != null && className.trim().isNotEmpty) {
      return '${className.trim()} dersliği';
    }
    return 'Öğretmenler odası';
  }

  static List<CouncilAgendaItem> buildAgenda({
    required CouncilKind kind,
    required CouncilPeriod period,
    int? grade,
  }) {
    final items = kind == CouncilKind.zumre
        ? _zumreAgenda(period)
        : _sokAgenda(period, grade);
    return [
      for (var i = 0; i < items.length; i++)
        CouncilAgendaItem(
          id: 'req_$i',
          text: '${i + 1}. ${items[i].$1}',
          required: true,
          decision: items[i].$2,
        ),
    ];
  }

  static List<CouncilAgendaItem> addExtra(List<CouncilAgendaItem> current) {
    final n = current.length + 1;
    return [
      ...current,
      CouncilAgendaItem(
        id: 'extra_${DateTime.now().microsecondsSinceEpoch}',
        text: '$n. ',
        required: false,
        decision: 'Bu maddede alınan kararın uygulanmasına karar verildi.',
      ),
    ];
  }

  static List<CouncilAgendaItem> removeAt(List<CouncilAgendaItem> current, int index) {
    if (index < 0 || index >= current.length) return current;
    if (current[index].required) return current;
    final next = [...current]..removeAt(index);
    return [
      for (var i = 0; i < next.length; i++)
        next[i].copyWith(text: _renumber(next[i].text, i + 1)),
    ];
  }

  static String _renumber(String text, int n) {
    final stripped = text.replaceFirst(RegExp(r'^\s*\d+\.\s*'), '');
    return '$n. $stripped';
  }

  static List<(String, String)> _zumreAgenda(CouncilPeriod period) {
    switch (period) {
      case CouncilPeriod.yearStart:
        return const [
          (
            'Açılış, yoklama ve gündemin okunması.',
            'Toplantı açıldı; yoklama yapıldı. Gündemin görüşülmesine karar verildi.',
          ),
          (
            'Bir önceki toplantıda alınan kararların ve sonuçlarının değerlendirilmesi.',
            'Önceki kararların sonuçları değerlendirildi; izlemeye devam edilmesine karar verildi.',
          ),
          (
            'Planlamaların mevzuat, okulun kuruluş amacı ve öğretim programına uygun yapılması.',
            'Yıllık ve ders planlarının yürürlükteki programa göre hazırlanmasına karar verildi.',
          ),
          (
            'Atatürkçülük konularının planlanması; öğretim programlarının incelenmesi; yıllık ve ders planlarında konu ve kazanım ağırlıklarının dikkate alınması.',
            'Atatürkçülük konularının ilgili kazanımlarla birlikte işlenmesine karar verildi.',
          ),
          (
            'Derslerin işlenişinde uygulanacak öğretim yöntem ve tekniklerinin belirlenmesi.',
            'Derslerde öğrenci merkezli yöntem ve tekniklerin kullanılmasına karar verildi.',
          ),
          (
            'Özel eğitim ihtiyacı olan öğrenciler için BEP ve ders planlarının görüşülmesi.',
            'BEP\'i bulunan öğrenciler için planların zümrece izlenmesine karar verildi.',
          ),
          (
            'Diğer zümre ve alan öğretmenleriyle iş birliği esaslarının belirlenmesi.',
            'Ortak sınav, proje ve etkinliklerde zümreler arası iş birliği yapılmasına karar verildi.',
          ),
          (
            'Ders kitabı, materyal ve eğitim ortamlarının değerlendirilmesi.',
            'Ders kitabı ve materyallerin programa uygun kullanılmasına karar verildi.',
          ),
          (
            'Ölçme ve değerlendirme esasları ile sınav sayısı, zamanı, türü ve yazılı-uygulamalı olma şeklinin tespiti (sınıf-ders düzeyine uymayan hususta karar alınmaz, madde silinmez).',
            'Ölçme-değerlendirmenin mevzuattaki sınırlara göre uygulanmasına karar verildi.',
          ),
          (
            'Öğrenci başarı, devam-devamsızlık durumları ve alınacak önlemler.',
            'Başarısı ve devamı riskli öğrenciler için veli ve rehberlik iş birliği yapılmasına karar verildi.',
          ),
          (
            'Dilek, temenniler ve kapanış.',
            'Gündem maddeleri görüşüldü; tutanağın yazılarak imzaya açılmasına karar verildi.',
          ),
        ];
      case CouncilPeriod.secondTerm:
        return const [
          (
            'Açılış, yoklama ve gündemin okunması.',
            'Toplantı açıldı; yoklama yapıldı. Gündemin görüşülmesine karar verildi.',
          ),
          (
            'Bir önceki toplantıda alınan kararların sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Birinci dönem kararlarının sonuçları tek tek değerlendirildi; tamamlanmayan işlerin ikinci dönemde bitirilmesine karar verildi.',
          ),
          (
            'Birinci dönem öğretim programı uygulanmasının ve kalan kazanımların planlanması.',
            'Kalan kazanımların ikinci dönem takvimine göre tamamlanmasına karar verildi.',
          ),
          (
            'Birinci dönem ölçme-değerlendirme sonuçları ve ikinci dönem sınav planı.',
            'İkinci dönem yazılı/uygulama takviminin zümrece ortak uygulanmasına karar verildi.',
          ),
          (
            'Özel eğitim ihtiyacı olan öğrenciler için BEP uygulamalarının gözden geçirilmesi.',
            'BEP uygulamalarının ikinci dönemde izlenmesine ve gerektiğinde güncellenmesine karar verildi.',
          ),
          (
            'Başarısı düşük öğrenciler için alınacak destekleyici önlemler.',
            'Eksik kazanımlar için ek çalışma ve veli bilgilendirmesi yapılmasına karar verildi.',
          ),
          (
            'Zümreler arası iş birliği ve ortak etkinliklerin ikinci dönem planı.',
            'Ortak etkinlik takviminin uygulanmasına karar verildi.',
          ),
          (
            'Dilek, temenniler ve kapanış.',
            'Gündem maddeleri görüşüldü; tutanağın yazılarak imzaya açılmasına karar verildi.',
          ),
        ];
      case CouncilPeriod.yearEnd:
        return const [
          (
            'Açılış, yoklama ve gündemin okunması.',
            'Toplantı açıldı; yoklama yapıldı. Gündemin görüşülmesine karar verildi.',
          ),
          (
            'Eğitim-öğretim yılı boyunca alınan tüm kararların ve sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Yıl içi kararların sonuçları değerlendirildi; tamamlanan ve tamamlanamayan hususlar tutanağa işlenmesine karar verildi.',
          ),
          (
            'Öğretim programının yıllık gerçekleşme durumu ve kazanım tamamlama.',
            'İşlenemeyen kazanımların gerekçeleriyle birlikte kayda geçirilmesine karar verildi.',
          ),
          (
            'Yıl sonu başarı, devam-devamsızlık ve ölçme-değerlendirme sonuçlarının değerlendirilmesi.',
            'Sonuçların bir sonraki yılın planlamasında esas alınmasına karar verildi.',
          ),
          (
            'Ders kitabı, materyal ve ortamların yıl sonu envanteri.',
            'Eksik ve yıpranan materyallerin idareye bildirilmesine karar verildi.',
          ),
          (
            'Bir sonraki eğitim-öğretim yılına ilişkin ön planlama.',
            'Gelecek yıl zümre planının sene başı toplantısında bu değerlendirmeye göre hazırlanmasına karar verildi.',
          ),
          (
            'Dilek, temenniler ve kapanış.',
            'Gündem maddeleri görüşüldü; tutanağın yazılarak imzaya açılmasına karar verildi.',
          ),
        ];
    }
  }

  static List<(String, String)> _sokAgenda(CouncilPeriod period, int? grade) {
    final includePromotion = grade == null || grade >= 5;
    switch (period) {
      case CouncilPeriod.yearStart:
        return [
          (
            'Açılış, yoklama ve gündemin okunması.',
            'Toplantı açıldı; yoklama yapıldı. Gündemin görüşülmesine karar verildi.',
          ),
          (
            'Bir önceki toplantıda alınan kararların değerlendirilmesi.',
            'Önceki kararların sonuçları değerlendirildi; izlemeye devam edilmesine karar verildi.',
          ),
          (
            'Öğrencilerin başarı durumlarının incelenmesi ve başarıyı artırıcı önlemlerin alınması.',
            'Şube başarı durumunun branş öğretmenlerince izlenmesine ve gereken öğrenciler için önlem alınmasına karar verildi.',
          ),
          (
            'Derslerin öğretim programlarıyla uyumlu olarak yürütülmesi.',
            'Derslerin program ve yıllık plana uygun işlenmesine karar verildi.',
          ),
          (
            'Kaynaştırma/bütünleştirme yoluyla eğitimine devam eden öğrenciler için alınacak tedbirler.',
            'İlgili öğrenciler için BEP ve destek eğitim odası süreçlerinin izlenmesine karar verildi.',
          ),
          (
            'Öğrencilerin kişilik, beslenme, sağlık, sosyal ilişkiler ve ailenin ekonomik durumu ile alınacak önlemler (ayrıntı ekteki değerlendirme ızgarasına yazılır).',
            'Değerlendirme ızgarasının doldurularak rehberlik servisi ve idare ile paylaşılmasına karar verildi.',
          ),
          (
            'Veli iletişimi ve okul-aile iş birliği.',
            'Riskli durumlarda veli görüşmesinin şube rehber öğretmenince planlanmasına karar verildi.',
          ),
          (
            'Dilek, temenniler ve kapanış.',
            'Gündem maddeleri görüşüldü; tutanağın yazılarak imzaya açılmasına karar verildi.',
          ),
        ];
      case CouncilPeriod.secondTerm:
        return [
          (
            'Açılış, yoklama ve gündemin okunması.',
            'Toplantı açıldı; yoklama yapıldı. Gündemin görüşülmesine karar verildi.',
          ),
          (
            'Birinci dönem kararlarının sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Birinci dönem kararlarının sonuçları değerlendirildi; süren işlerin tamamlanmasına karar verildi.',
          ),
          (
            'Birinci dönem başarı, devam ve davranış durumlarının incelenmesi.',
            'Başarısı ve devamı riskli öğrenciler için ikinci dönem destek planı uygulanmasına karar verildi.',
          ),
          (
            'Kaynaştırma/bütünleştirme öğrencilerinin ikinci dönem izlemi.',
            'BEP hedeflerinin ikinci dönemde gözden geçirilmesine karar verildi.',
          ),
          (
            'Kişilik, beslenme, sağlık, sosyal ilişki ve ekonomik durum değerlendirmesinin güncellenmesi (ızgara ekte).',
            'İzgaranın güncellenerek rehberlik servisine iletilmesine karar verildi.',
          ),
          (
            'Veli görüşmeleri ve alınacak ortak önlemler.',
            'Gerekli velilerle ikinci dönem görüşme takvimi oluşturulmasına karar verildi.',
          ),
          (
            'Dilek, temenniler ve kapanış.',
            'Gündem maddeleri görüşüldü; tutanağın yazılarak imzaya açılmasına karar verildi.',
          ),
        ];
      case CouncilPeriod.yearEnd:
        return [
          (
            'Açılış, yoklama ve gündemin okunması.',
            'Toplantı açıldı; yoklama yapıldı. Gündemin görüşülmesine karar verildi.',
          ),
          (
            'Yıl boyunca alınan kararların ve sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Yıl içi kararların sonuçları değerlendirildi; tutanağa işlenmesine karar verildi.',
          ),
          (
            'Öğrencilerin yıl sonu başarı, devam ve davranış durumlarının incelenmesi.',
            'Şube yıl sonu durumunun branş görüşleriyle birlikte kayda geçirilmesine karar verildi.',
          ),
          if (includePromotion)
            (
              'Ortaokul ve imam hatip ortaokullarında sınıf geçme ve sınıf tekrarı durumları (ilgili kademede; EK-5 ve e-Okul süreci ayrıca yürütülür).',
              'Mevzuata giren öğrencilerin durumunun şube kurulunca değerlendirilerek e-Okul işlemlerinin idarece tamamlanmasına karar verildi.',
            ),
          (
            'Kaynaştırma/bütünleştirme öğrencilerinin yıl sonu değerlendirmesi.',
            'BEP yıl sonu değerlendirmenin rehberlik servisiyle paylaşılmasına karar verildi.',
          ),
          (
            'Kişilik, beslenme, sağlık, sosyal ilişki ve ekonomik durum yıl sonu ızgarası (ekte).',
            'İzgaranın doldurularak kurul dosyasında saklanmasına karar verildi.',
          ),
          (
            'Dilek, temenniler ve kapanış.',
            'Gündem maddeleri görüşüldü; tutanağın yazılarak imzaya açılmasına karar verildi.',
          ),
        ];
    }
  }
}
