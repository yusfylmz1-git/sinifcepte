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

/// Kademe: yönerge kademeye özgü maddeleri yalnız o kademede ister
/// ("maddelerden ilgili görülenler gündeme alınır").
enum CouncilLevel { ilkokul, ortaokul, ortaogretim, bilinmiyor }

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

  /// Kademe: önce sınıf seviyesi, sonra okul türü, sonra branş.
  static CouncilLevel levelFrom({int? grade, String? schoolType, String? branch}) {
    if (grade != null) {
      if (grade <= 4) return CouncilLevel.ilkokul;
      if (grade <= 8) return CouncilLevel.ortaokul;
      return CouncilLevel.ortaogretim;
    }
    final t = trFold(schoolType ?? '');
    if (t.contains('ilkokul') || t.contains('okul oncesi') || t.contains('anaokul')) {
      return CouncilLevel.ilkokul;
    }
    if (t.contains('ortaokul')) return CouncilLevel.ortaokul;
    if (t.contains('lise') || t.contains('mesleki') || t.contains('meslek')) {
      return CouncilLevel.ortaogretim;
    }
    if (branch != null && isClassroomTeacher(branch)) return CouncilLevel.ilkokul;
    return CouncilLevel.bilinmiyor;
  }

  static List<CouncilAgendaItem> buildAgenda({
    required CouncilKind kind,
    required CouncilPeriod period,
    int? grade,
    CouncilLevel? level,
  }) {
    final kademe = level ?? levelFrom(grade: grade);
    final items = kind == CouncilKind.zumre
        ? _zumreAgenda(period, kademe)
        : _sokAgenda(period, kademe);
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

  // ---------------------------------------------------------------------------
  // GÜNDEMLER — Türkiye Yüzyılı Maarif Modeli (10 Ekim 2026)
  //
  // Kaynaklar (metin bunlardan, uydurma yok):
  // * Eğitim Kurulları ve Zümreleri Yönergesi, 21/01/2025 değişikliğiyle:
  //   zümre m.12/8 (a)–(v), şube öğretmenler kurulu m.10/8 (a)–(l).
  //   2025 eki: okul temelli faaliyetler (ç), farklılaştırılmış uygulamalar
  //   (zenginleştirme ve destekleme) (d), bütüncül gelişim (t).
  // * TYMM Öğretim Programları Ortak Metni 2025: öğrenme çıktıları ve süreç
  //   bileşenleri, kavramsal beceriler, alan becerileri, eğilimler,
  //   programlar arası bileşenler (sosyal-duygusal öğrenme becerileri,
  //   Erdem-Değer-Eylem Çerçevesi, okuryazarlık becerileri), öğrenme
  //   kanıtları, farklılaştırma, okul temelli planlama (zümre kararlaştırır,
  //   yıllık plana yazılır, etkisi değerlendirilir), öğretmen yansıtmaları
  //   (zümre ve ŞÖK raporları veri kaynağıdır).
  //
  // Yönerge "maddelerden ilgili görülenler gündeme alınır" diyor: kademeye
  // özgü maddeler ([CouncilLevel]) yalnız o kademede gelir. Bent harfleri
  // yorumlarda; teftişte hangi maddeye dayandığı izlenebilsin.
  // ---------------------------------------------------------------------------

  static const _acilis = (
    'Açılış, yoklama ve gündemin okunması.',
    'Toplantı açıldı; yoklama yapıldı. Gündemin görüşülmesine karar verildi.',
  );

  static const _kapanis = (
    'Dilek, temenniler ve kapanış.',
    'Gündem maddeleri görüşüldü; tutanağın yazılarak imzaya açılmasına karar verildi.',
  );

  static List<(String, String)> _zumreAgenda(CouncilPeriod period, CouncilLevel level) {
    final ilkokul = level == CouncilLevel.ilkokul;
    final sinavli = level == CouncilLevel.ortaokul || level == CouncilLevel.ortaogretim;
    switch (period) {
      case CouncilPeriod.yearStart:
        return [
          _acilis,
          // (a)
          (
            'Bir önceki toplantıda alınan kararların ve sonuçlarının değerlendirilmesi.',
            'Önceki kararların sonuçları değerlendirildi; uygulanmayan kararların bu yıl izlenmesine karar verildi.',
          ),
          // (b) (c)
          (
            'Planlamaların eğitim-öğretim mevzuatına, okulun kuruluş amacına ve Türkiye Yüzyılı Maarif Modeli öğretim programına uygun yapılması; yıllık planların öğrenme çıktıları, süreç bileşenleri ve ünite/tema süreleri esas alınarak hazırlanması.',
            'Yıllık planların öğretim programındaki öğrenme çıktıları, süreç bileşenleri ve ünite/tema süreleri esas alınarak, çevre özellikleri de dikkate alınarak hazırlanmasına karar verildi.',
          ),
          // (c)
          (
            'Atatürkçülükle ilgili konuların ilgili öğrenme çıktılarıyla ilişkilendirilerek planlanması.',
            'Atatürkçülükle ilgili konuların ilgili öğrenme çıktılarıyla ve belirli gün ve haftalarla ilişkilendirilerek işlenmesine karar verildi.',
          ),
          // (ç) + Ortak Metin 1.4.10
          (
            'Okul temelli planlama: ders kapsamında yapılacak araştırma-gözlem, proje, yerel çalışma, okuma ve sosyal etkinliklerin belirlenmesi.',
            'Okul temelli planlamaya ayrılan sürede yürütülecek çalışmaların zümrece belirlenerek yıllık plana işlenmesine karar verildi.',
          ),
          // (ç) (p) (r) (t) + Ortak Metin 1.4.1–1.4.4
          (
            'Öğrenme-öğretme yaşantılarında kullanılacak yöntem ve tekniklerin; kavramsal beceriler, alan becerileri, eğilimler ve programlar arası bileşenler (sosyal-duygusal öğrenme becerileri, Erdem-Değer-Eylem Çerçevesi, okuryazarlık becerileri) dikkate alınarak belirlenmesi.',
            'Derslerin beceri temelli yürütülmesine; eğilimler, sosyal-duygusal öğrenme becerileri, değerler ve okuryazarlık becerilerinin öğrenme çıktılarıyla ilişkilendirilerek öğrenme-öğretme uygulamalarına yansıtılmasına karar verildi.',
          ),
          // (d) + Ortak Metin 1.4.9
          (
            'Farklılaştırılmış uygulamalar: hazırbulunuşluğa göre zenginleştirme ve destekleme çalışmaları; özel eğitim ihtiyacı olan öğrenciler için BEP ve ders planlarının görüşülmesi.',
            'Ön değerlendirme sonuçlarına göre zenginleştirme ve destekleme etkinliklerinin planlanmasına; BEP\'i bulunan öğrencilerin planlarının zümrece izlenmesine karar verildi.',
          ),
          // (ı) (i) (k) (l) (n) (ö) + Ortak Metin 1.4.7
          (
            'Ölçme ve değerlendirme: süreç odaklı değerlendirme ve öğrenme kanıtları; ${sinavli ? 'ortak yazılı ve uygulamalı sınavların konu-soru dağılım tablosu ve dereceli puanlama anahtarıyla hazırlanması; ' : ''}proje ve performans çalışmalarının belirlenmesi (sınıf-ders düzeyine uymayan hususta karar alınmaz, madde silinmez).',
            'Ölçme ve değerlendirmenin mevzuata uygun, süreç odaklı ve birden fazla öğrenme kanıtına dayalı yürütülmesine${sinavli ? '; ortak sınavların konu-soru dağılım tablosu ve dereceli puanlama anahtarıyla hazırlanmasına' : ''} karar verildi.',
          ),
          // (v) — yalnız okul öncesi ve ilkokul
          if (ilkokul)
            (
              'Öğrencilerin akademik ve sosyal gelişiminin gözlem formları, oyun temelli değerlendirmeler ve görev temelli ölçme araçlarıyla izlenmesinin planlanması.',
              'Öğrenci gelişiminin gözlem formları ve oyun temelli değerlendirmelerle ders yılı boyunca izlenmesine karar verildi.',
            ),
          // (e) (ş)
          (
            'Disiplinler arası ortak çalışmalar ve diğer zümrelerle iş birliği; zümre üyeleri arasında ders ziyareti ve geri bildirim.',
            'Disiplinler arası ortak çalışmaların takvime bağlanmasına; zümre üyelerinin oy birliğiyle yıl içinde en az bir ders ziyareti yapılmasına ve geri bildirimlerin zümrede değerlendirilmesine karar verildi.',
          ),
          // (ğ) (h) (ü)
          (
            'Ders kitabı, araç-gereç ve öğretim materyalleri; laboratuvar, kütüphane, atölye gibi ortamların ve okul dışı öğrenme ortamlarının (gezi, gözlem) kullanımının planlanması.',
            'İhtiyaç duyulan materyallerin idareye bildirilmesine; okul içi ve okul dışı öğrenme ortamlarının yıllık plana göre kullanılmasına karar verildi.',
          ),
          // (g) (u)
          (
            'Sosyal sorumluluk, girişimcilik ve araştırma-tasarım çalışmalarının ders kapsamında planlanması.',
            'Ders kapsamında yürütülecek sosyal sorumluluk ve girişimcilik çalışmalarının zümrece belirlenmesine karar verildi.',
          ),
          // (f) (j)
          (
            'Alandaki akademik ve teknolojik gelişmelerin, ulusal ve uluslararası sınav ve yarışma raporlarının izlenmesi.',
            'Alan yayınlarının ve sınav-yarışma raporlarının izlenerek sonuçlarının derslere yansıtılmasına karar verildi.',
          ),
          // (s) — Ortaöğretim Kurumları Yönetmeliği 59/A
          if (level == CouncilLevel.ortaogretim)
            (
              'Sınıf tekrarı riski olan öğrencilere yönelik önleme, müdahale ve yönlendirme komisyonunda yürütülecek çalışmaların planlanması.',
              'Riskli öğrenciler için önleme, müdahale ve yönlendirme çalışmalarının komisyonla iş birliği içinde planlanmasına karar verildi.',
            ),
          // (m)
          (
            'İş sağlığı ve güvenliği tedbirlerinin değerlendirilmesi.',
            'Ders ve uygulama ortamlarında iş sağlığı ve güvenliği tedbirlerine uyulmasına karar verildi.',
          ),
          _kapanis,
        ];
      case CouncilPeriod.secondTerm:
        return [
          _acilis,
          (
            'Birinci dönem kararlarının sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Birinci dönem kararlarının sonuçları tek tek değerlendirildi; tamamlanmayan işlerin ikinci dönemde bitirilmesine karar verildi.',
          ),
          (
            'Birinci dönem öğretim programının uygulanması: öğrenme çıktılarına ulaşma durumu ve kalan konuların planlanması.',
            'Ulaşılamayan öğrenme çıktılarının gerekçeleriyle belirlenerek ikinci dönem planına alınmasına karar verildi.',
          ),
          // (ı)
          (
            'Birinci dönem ölçme-değerlendirme ${sinavli ? 've ortak sınav analizleri' : 'sonuçları'}; eksik öğrenme çıktıları için eylem planı.',
            'Analizlerde eksikliği görülen öğrenme çıktıları için destekleme eylem planının hazırlanıp uygulanmasına ve izlenmesine karar verildi.',
          ),
          // Ortak Metin 1.4.10
          (
            'Okul temelli planlama çalışmalarının birinci dönem değerlendirmesi ve ikinci dönem planı.',
            'Okul temelli planlama çalışmalarının etkisi değerlendirildi; ikinci dönem çalışmalarının yıllık plana göre sürdürülmesine karar verildi.',
          ),
          // (d)
          (
            'Zenginleştirme, destekleme ve BEP uygulamalarının gözden geçirilmesi.',
            'Zenginleştirme ve destekleme uygulamalarının sürdürülmesine; BEP hedeflerinin gerektiğinde güncellenmesine karar verildi.',
          ),
          // (e) + Ortak Metin 1.4.13
          (
            'Ders ziyaretleri ve öğretmen yansıtmaları: öğretim programının uygulanmasında güçlü ve iyileştirilmesi gereken yönler.',
            'Ders ziyareti geri bildirimleri ve öğretmen yansıtmaları değerlendirildi; iyileştirme önerilerinin ikinci dönemde uygulanmasına karar verildi.',
          ),
          (
            'İkinci dönem ${sinavli ? 'ortak sınav, ' : ''}proje ve performans çalışmalarının planlanması.',
            'İkinci dönem ölçme-değerlendirme takviminin zümrece ortak uygulanmasına karar verildi.',
          ),
          // (ş) (u)
          (
            'Disiplinler arası ortak çalışmalar ve sosyal sorumluluk etkinliklerinin ikinci dönem takvimi.',
            'Ortak çalışma ve etkinlik takviminin uygulanmasına karar verildi.',
          ),
          _kapanis,
        ];
      case CouncilPeriod.yearEnd:
        return [
          _acilis,
          // m.12/4: ders yılı sonunda yıl boyunca alınan kararlar değerlendirilir
          (
            'Eğitim-öğretim yılı boyunca alınan tüm kararların ve sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Yıl içi kararların sonuçları değerlendirildi; tamamlanan ve tamamlanamayan hususların tutanağa işlenmesine karar verildi.',
          ),
          (
            'Öğretim programının yıllık uygulanması: öğrenme çıktılarına ulaşma durumu ve ulaşılamayanların gerekçeleri.',
            'Ulaşılamayan öğrenme çıktılarının gerekçeleriyle kayda geçirilmesine ve gelecek yılın planlamasında dikkate alınmasına karar verildi.',
          ),
          (
            'Yıl sonu başarı, ölçme-değerlendirme ve sınav analizi sonuçlarının değerlendirilmesi.',
            'Sonuçların bir sonraki yılın planlamasında ve destekleme çalışmalarında esas alınmasına karar verildi.',
          ),
          // Ortak Metin 1.4.10: etkisine yönelik değerlendirme beklenir
          (
            'Okul temelli planlama çalışmalarının yıllık değerlendirmesi (ihtiyaç, uygulama ve etki).',
            'Okul temelli planlama çalışmalarının etkisi değerlendirildi; gelecek yıl için önerilerin sene başı toplantısında görüşülmesine karar verildi.',
          ),
          // Ortak Metin 1.4.13
          (
            'Öğretmen yansıtmaları: öğretim programının ve öğretim sürecinin güçlü ve iyileştirilmesi gereken yönleri.',
            'Öğretmen yansıtmaları kayda geçirildi; iyileştirme önerilerinin gelecek yıl planlamasında dikkate alınmasına karar verildi.',
          ),
          (
            'Ders kitabı, materyal ve öğrenme ortamlarının yıl sonu durumu ile gelecek yıl ihtiyaçları.',
            'Eksik ve yıpranan materyallerin idareye bildirilmesine karar verildi.',
          ),
          // m.12/1: haziran toplantısında 2 yıllığına başkan ve yedek başkan
          (
            'Zümre başkanı ve yedek başkanın seçimi (görev süresi biten zümrelerde; eylülden itibaren iki yıl için).',
            'Zümre başkanı ve yedek başkanın seçilerek eğitim kurumu yönetimine bildirilmesine karar verildi.',
          ),
          (
            'Bir sonraki eğitim-öğretim yılına ilişkin ön planlama.',
            'Gelecek yıl zümre planının sene başı toplantısında bu değerlendirmeye göre hazırlanmasına karar verildi.',
          ),
          _kapanis,
        ];
    }
  }

  static List<(String, String)> _sokAgenda(CouncilPeriod period, CouncilLevel level) {
    switch (period) {
      case CouncilPeriod.yearStart:
        return [
          _acilis,
          // (a)
          (
            'Bir önceki toplantıda alınan kararların değerlendirilmesi.',
            'Önceki kararların sonuçları değerlendirildi; izlemeye devam edilmesine karar verildi.',
          ),
          // (b) + Ortak Metin 1.4.8.2 ön değerlendirme
          (
            'Öğrencilerin başarı durumlarının ve ön değerlendirme sonuçlarının incelenmesi; başarıyı artırıcı önlemlerin alınması.',
            'Desteklemeye ihtiyaç duyan öğrenciler için destekleme, ileri düzeydeki öğrenciler için zenginleştirme çalışmalarının branş öğretmenlerince yürütülmesine karar verildi.',
          ),
          // (c)
          (
            'Derslerin Türkiye Yüzyılı Maarif Modeli öğretim programlarıyla uyumlu olarak yürütülmesi.',
            'Derslerin öğretim programı ve yıllık plana uygun, beceri temelli işlenmesine karar verildi.',
          ),
          // (d)
          (
            'Kaynaştırma/bütünleştirme yoluyla eğitimine devam eden öğrencilerin başarısının artırılması için alınacak tedbirler.',
            'İlgili öğrenciler için BEP ve destek eğitim odası süreçlerinin izlenmesine karar verildi.',
          ),
          // (i) (j)
          (
            'Öğrencilerin kişilik ve sosyal gelişimlerinin desteklenmesi, sağlıklarının korunması ve dengeli beslenmeleri (ayrıntı ekteki değerlendirme ızgarasına yazılır).',
            'Değerlendirme ızgarasının doldurularak rehberlik servisi ve idare ile paylaşılmasına karar verildi.',
          ),
          // (k) + Erdem-Değer-Eylem Çerçevesi
          (
            'Değerler eğitimi çalışmaları (Erdem-Değer-Eylem Çerçevesi).',
            'Değerler eğitiminin derslerde örtük olarak ve şube etkinlikleriyle yürütülmesine karar verildi.',
          ),
          // (ğ) (ı)
          (
            'Bilimsel, sosyal, kültürel, sanatsal ve sportif etkinlikler, geziler, öğrenci kulüpleri, sosyal sorumluluk ve girişimcilik çalışmaları.',
            'Şubenin yıl içi etkinlik ve sosyal sorumluluk çalışmalarının planlanmasına karar verildi.',
          ),
          // (f)
          (
            'Okul-çevre ve okul-aile iş birliği; veli iletişimi.',
            'Riskli durumlarda veli görüşmesinin şube rehber öğretmenince planlanmasına karar verildi.',
          ),
          // (e) (l)
          (
            'Eğitim kaynakları, atölye, laboratuvar ve diğer birimlerden güvenli yararlanma; iş sağlığı ve güvenliği.',
            'Öğrenme ortamlarının güvenli kullanımına ve iş sağlığı ve güvenliği tedbirlerine uyulmasına karar verildi.',
          ),
          _kapanis,
        ];
      case CouncilPeriod.secondTerm:
        return [
          _acilis,
          (
            'Birinci dönem kararlarının sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Birinci dönem kararlarının sonuçları değerlendirildi; süren işlerin tamamlanmasına karar verildi.',
          ),
          (
            'Birinci dönem başarı, devam ve davranış durumlarının incelenmesi; başarıyı artırıcı önlemler.',
            'Başarısı ve devamı riskli öğrenciler için ikinci dönem destekleme planının uygulanmasına karar verildi.',
          ),
          (
            'Derslerin öğretim programlarıyla uyumlu yürütülmesi; destekleme ve zenginleştirme uygulamalarının sonuçları.',
            'Destekleme ve zenginleştirme uygulamalarının ikinci dönemde sürdürülmesine karar verildi.',
          ),
          (
            'Kaynaştırma/bütünleştirme öğrencilerinin ikinci dönem izlemi.',
            'BEP hedeflerinin ikinci dönemde gözden geçirilmesine karar verildi.',
          ),
          (
            'Kişilik ve sosyal gelişim, sağlık ve beslenme değerlendirmesinin güncellenmesi (ızgara ekte).',
            'Izgaranın güncellenerek rehberlik servisine iletilmesine karar verildi.',
          ),
          (
            'Değerler eğitimi ve sosyal etkinliklerin ikinci dönem planı.',
            'İkinci dönem değerler eğitimi ve etkinlik planının uygulanmasına karar verildi.',
          ),
          (
            'Veli görüşmeleri ve okul-aile iş birliği.',
            'Gerekli velilerle ikinci dönem görüşme takvimi oluşturulmasına karar verildi.',
          ),
          _kapanis,
        ];
      case CouncilPeriod.yearEnd:
        return [
          _acilis,
          (
            'Yıl boyunca alınan kararların ve sonuçlarının değerlendirilmesi (işlenmemiş karar bırakılmaz).',
            'Yıl içi kararların sonuçları değerlendirildi; tutanağa işlenmesine karar verildi.',
          ),
          (
            'Öğrencilerin yıl sonu başarı, devam ve davranış durumlarının incelenmesi.',
            'Şube yıl sonu durumunun branş görüşleriyle birlikte kayda geçirilmesine karar verildi.',
          ),
          // (ç) — yalnız ortaokul ve imam hatip ortaokulu
          if (level == CouncilLevel.ortaokul)
            (
              'Ortaokul ve imam hatip ortaokullarında öğrencilerin sınıf geçme ve sınıf tekrarı durumları (EK-5 ve e-Okul süreci ayrıca yürütülür).',
              'Mevzuata giren öğrencilerin durumunun şube kurulunca değerlendirilerek e-Okul işlemlerinin idarece tamamlanmasına karar verildi.',
            ),
          (
            'Kaynaştırma/bütünleştirme öğrencilerinin yıl sonu değerlendirmesi.',
            'BEP yıl sonu değerlendirmesinin rehberlik servisiyle paylaşılmasına karar verildi.',
          ),
          (
            'Kişilik ve sosyal gelişim, sağlık ve beslenme yıl sonu ızgarası (ekte).',
            'Izgaranın doldurularak kurul dosyasında saklanmasına karar verildi.',
          ),
          _kapanis,
        ];
    }
  }
}
