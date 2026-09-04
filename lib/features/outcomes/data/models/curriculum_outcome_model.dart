import 'dart:convert';

/// Haftalık tekrarı elenmiş tekil kazanım (BEP tohumu vb.).
class UniqueOutcomeHit {
  final String code;
  final String description;
  final String unitTitle;
  final String subjectCode;
  final String subjectName;
  final List<String> steps;
  final String values;

  const UniqueOutcomeHit({
    required this.code,
    required this.description,
    required this.unitTitle,
    required this.subjectCode,
    required this.subjectName,
    this.steps = const [],
    this.values = '',
  });

  /// Kod açıklamada yoksa öne eklenir; varsa tekrar yazılmaz.
  String get label {
    if (code.isEmpty) return description;
    final d = description.trim();
    if (d.toUpperCase().startsWith(code.toUpperCase())) return d;
    return '$code  $d';
  }
}

/// Haftalık tekrarları eleyerek BEP tohum listesi üretir.
///
/// Aynı kazanım 3 hafta sürebilir; kod (veya metin) bir kez çıkar.
/// `outcome_description` çoğu satırda kodu tekrarlar — o önek silinir.
List<UniqueOutcomeHit> uniqueOutcomeHits(
  Iterable<Map<String, dynamic>> raw, {
  int limit = 40,
}) {
  final seen = <String>{};
  final out = <UniqueOutcomeHit>[];
  for (final m in raw) {
    if (_isNonInstructionalWeek(m)) continue;
    final unitTitle = m['unit_title'] as String? ?? '';
    final subjectCode = m['subject_code'] as String? ?? '';
    final subjectName = m['subject_name'] as String? ?? '';

    for (final seed in _outcomeSeeds(m)) {
      final textKey = 't:${_foldOutcome(seed.text)}';
      final codeKey = seed.code.isNotEmpty ? 'c:${seed.code}' : textKey;
      if (seen.contains(codeKey) || seen.contains(textKey)) continue;
      seen.add(codeKey);
      seen.add(textKey);
      out.add(UniqueOutcomeHit(
        code: seed.code,
        description: seed.text,
        unitTitle: unitTitle,
        subjectCode: subjectCode,
        subjectName: subjectName,
        steps: seed.steps,
        values: (m['maarif_values'] as String?)?.trim() ?? '',
      ));
      if (out.length >= limit) return out;
    }
  }
  return out;
}

Iterable<({String code, String text, List<String> steps})> _outcomeSeeds(
  Map<String, dynamic> m,
) sync* {
  final rawParts = m['outcome_parts'];
  final parts = rawParts is String
      ? OutcomePart.listFromDbText(rawParts)
      : OutcomePart.listFromJson(rawParts);
  if (parts.isNotEmpty) {
    for (final p in parts) {
      final code = normalizeOutcomeCode(p.code ?? '');
      final raw = p.text.trim().isNotEmpty
          ? p.text
          : (p.steps.isNotEmpty ? p.steps.first : '');
      final text = _cleanOutcomeText(raw, code);
      if (text.isNotEmpty) {
        yield (code: code, text: text, steps: p.steps);
      }
    }
    return;
  }
  final code = normalizeOutcomeCode((m['outcome_code'] as String?) ?? '');
  final text = _cleanOutcomeText((m['outcome_description'] as String?) ?? '', code);
  if (text.isNotEmpty) yield (code: code, text: text, steps: const []);
}

/// OTP, sosyal etkinlik ve tatil haftası BEP kazanımı değildir.
bool _isNonInstructionalWeek(Map<String, dynamic> m) {
  if ((m['is_holiday_week'] as int? ?? 0) == 1) return true;
  if ((m['is_otp_week'] as int? ?? 0) == 1) return true;
  if ((m['is_social_event_week'] as int? ?? 0) == 1) return true;
  final blob = [
    m['unit_title'],
    m['topic_title'],
    m['outcome_description'],
    m['holiday_note'],
  ].whereType<String>().join(' ').toLowerCase();
  const markers = [
    'okul temelli',
    'sosyal etkinlik',
    'yaz tatili',
    'ara tatil',
    'yarıyıl tatili',
    'yariyil tatili',
    'resmî tatil',
    'resmi tatil',
    'bayram tatili',
    'dinlenme dönemi',
    'dinlenme donemi',
  ];
  for (final k in markers) {
    if (blob.contains(k)) return true;
  }
  return false;
}

String normalizeOutcomeCode(String raw) {
  return raw.trim().toUpperCase().replaceAll(RegExp(r'\.+$'), '');
}

String _foldOutcome(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// "MAT.5.1.1. Sayıları okur | a) ..." → "Sayıları okur"
String _cleanOutcomeText(String raw, String code) {
  var t = raw.trim();
  if (t.isEmpty) return '';
  if (code.isNotEmpty) {
    final escaped = RegExp.escape(code);
    t = t.replaceFirst(RegExp('^$escaped\\.\\s*', caseSensitive: false), '');
    t = t.replaceFirst(RegExp('^$escaped\\s+', caseSensitive: false), '');
  }
  t = t.replaceFirst(RegExp(r'^[A-ZÇĞİÖŞÜ]{2,10}\.[\dA-Z.]+\.?\s*'), '');
  final pipe = t.indexOf(' |');
  if (pipe > 8) t = t.substring(0, pipe);
  t = t.replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'\|+\s*$'), '').trim();
  return t;
}

/// SınıfCepte - Müfredat Haftalık Konu ve Kazanım Veri Modeli
class CurriculumOutcomeModel {
  final int? id;
  final String docId;
  final int gradeLevel; // 1 to 12
  final String subjectCode; // Örn: "BILISIM", "MAT", "FEN", "TURKCE"
  final String subjectName; // Örn: "Bilişim Teknolojileri ve Yazılım", "Matematik"
  final String publisher; // Örn: "TYMM (Maarif Modeli)", "MEB Yayınları"
  final String fullTitle; // Örn: "5. Sınıf - Bilişim Teknolojileri ve Yazılım - TYMM (Maarif Modeli)"
  final String category; // 'core', 'elective', 'course', 'iho', 'harezmi'
  final int weekNumber; // 1 to 39 (Takvim Sırası)
  final int? teachingWeekNumber; // 1 to 36 (Ders Sırası)
  final String unitTitle; // Örn: "Bilişim Teknolojilerinin Sınıflandırılması"
  final String topicTitle; // Örn: "Bilişim Teknolojilerinin Sınıflandırılması"
  final String? outcomeCode; // Örn: "BTY.5.1.1"
  final String outcomeDescription; // Kazanım açıklaması

  /// Haftanın kazanımları, koda göre ayrıştırılmış hâlde.
  ///
  /// MEB planlarında bir haftaya birden fazla kazanım düşebiliyor
  /// (ör. MAT.5.1.2 ve MAT.5.1.3 aynı hafta). Düz metin olarak
  /// gösterilince hangi "a) b) c)" maddesinin hangi kazanıma ait olduğu
  /// anlaşılmıyordu; bu liste her kazanımı ayrı blok yapar.
  final List<OutcomePart> outcomeParts;

  /// OTP / sosyal etkinlik haftaları için branşa uygun örnek etkinlikler.
  ///
  /// MEB bu haftalarda içerik belirlemez; ne yapılacağına zümre karar
  /// verir. Bunlar resmî kazanım DEĞİL, öğretmene fikir vermek için
  /// hazırlanmış önerilerdir ve kartta öyle etiketlenir.
  final List<String> suggestedActivities;

  /// Aynı kazanım birden çok hafta sürüyorsa: kaçıncı hafta / toplam.
  ///
  /// MEB planlarında bir kazanım 2-5 hafta sürebiliyor ve o haftaların
  /// metni birebir aynı oluyor. Bu bir veri hatası değil, planın gereği;
  /// kart "3 haftalık kazanımın 2. haftası" diyerek bunu görünür kılar.
  final int? spanIndex;
  final int? spanTotal;

  /// MEB'in öğretim programı PDF'inde bu kazanım için yazdığı ders
  /// anlatımı ("Öğrenme-Öğretme Uygulamaları").
  ///
  /// Bizim ürettiğimiz [maarifSummary] alanından farklı olarak RESMÎ
  /// metindir; kartta kaynağı belirtilerek gösterilir.
  final String? officialActivity;

  /// Haftalık dağılım MEB tarafından yayımlanmadı mı?
  ///
  /// Seçmeli derslerde MEB taslak yıllık plan yayımlamıyor; kazanımlar
  /// öğretim programından alınıp haftalara EŞİT dağıtılıyor. Kazanımın
  /// kendisi resmîdir, yalnızca hangi hafta işleneceği tahmindir.
  final bool isEstimatedSchedule;
  final String academicYear; // "2026-2027"
  final bool isHolidayWeek;
  final String? holidayNote;
  final String? dateRangeStr;
  final bool isFavorite;

  /// Boru hattının ürettiği ham OTP bayrağı (bkz. [isOtpWeek]).
  final bool isOtpWeekFlag;

  /// Boru hattının ürettiği ham sosyal etkinlik bayrağı (bkz. [isSocialEventWeek]).
  final bool isSocialEventWeekFlag;
  final String? maarifSummary; // Maarif Modeli Ders Özeti & Pedagojik İpucu
  final String? maarifValues; // Erdem-Değer-Eylem
  final String? maarifSkills; // Alan ve Kavramsal Beceriler (KB/AB/SDB)
  final String? differentiation; // Zenginleştirme / Destekleme İpuçları

  const CurriculumOutcomeModel({
    this.id,
    required this.docId,
    required this.gradeLevel,
    required this.subjectCode,
    required this.subjectName,
    this.publisher = 'MEB Yayınları',
    this.fullTitle = '',
    this.category = 'core',
    required this.weekNumber,
    this.teachingWeekNumber,
    required this.unitTitle,
    required this.topicTitle,
    this.outcomeCode,
    required this.outcomeDescription,
    this.outcomeParts = const [],
    this.suggestedActivities = const [],
    this.spanIndex,
    this.spanTotal,
    this.officialActivity,
    this.isEstimatedSchedule = false,
    this.academicYear = '2026-2027',
    this.isHolidayWeek = false,
    this.holidayNote,
    this.dateRangeStr,
    this.isFavorite = false,
    this.isOtpWeekFlag = false,
    this.isSocialEventWeekFlag = false,
    this.maarifSummary,
    this.maarifValues,
    this.maarifSkills,
    this.differentiation,
  });

  CurriculumOutcomeModel copyWith({
    int? id,
    String? docId,
    int? gradeLevel,
    String? subjectCode,
    String? subjectName,
    String? publisher,
    String? fullTitle,
    String? category,
    int? weekNumber,
    int? teachingWeekNumber,
    String? unitTitle,
    String? topicTitle,
    String? outcomeCode,
    String? outcomeDescription,
    List<OutcomePart>? outcomeParts,
    List<String>? suggestedActivities,
    int? spanIndex,
    int? spanTotal,
    String? officialActivity,
    bool? isEstimatedSchedule,
    String? academicYear,
    bool? isHolidayWeek,
    String? holidayNote,
    String? dateRangeStr,
    bool? isFavorite,
    bool? isOtpWeekFlag,
    bool? isSocialEventWeekFlag,
    String? maarifSummary,
    String? maarifValues,
    String? maarifSkills,
    String? differentiation,
  }) {
    return CurriculumOutcomeModel(
      id: id ?? this.id,
      docId: docId ?? this.docId,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      subjectCode: subjectCode ?? this.subjectCode,
      subjectName: subjectName ?? this.subjectName,
      publisher: publisher ?? this.publisher,
      fullTitle: fullTitle ?? this.fullTitle,
      category: category ?? this.category,
      weekNumber: weekNumber ?? this.weekNumber,
      teachingWeekNumber: teachingWeekNumber ?? this.teachingWeekNumber,
      unitTitle: unitTitle ?? this.unitTitle,
      topicTitle: topicTitle ?? this.topicTitle,
      outcomeCode: outcomeCode ?? this.outcomeCode,
      outcomeDescription: outcomeDescription ?? this.outcomeDescription,
      outcomeParts: outcomeParts ?? this.outcomeParts,
      suggestedActivities: suggestedActivities ?? this.suggestedActivities,
      spanIndex: spanIndex ?? this.spanIndex,
      spanTotal: spanTotal ?? this.spanTotal,
      officialActivity: officialActivity ?? this.officialActivity,
      isEstimatedSchedule: isEstimatedSchedule ?? this.isEstimatedSchedule,
      academicYear: academicYear ?? this.academicYear,
      isHolidayWeek: isHolidayWeek ?? this.isHolidayWeek,
      holidayNote: holidayNote ?? this.holidayNote,
      dateRangeStr: dateRangeStr ?? this.dateRangeStr,
      isFavorite: isFavorite ?? this.isFavorite,
      isOtpWeekFlag: isOtpWeekFlag ?? this.isOtpWeekFlag,
      isSocialEventWeekFlag: isSocialEventWeekFlag ?? this.isSocialEventWeekFlag,
      maarifSummary: maarifSummary ?? this.maarifSummary,
      maarifValues: maarifValues ?? this.maarifValues,
      maarifSkills: maarifSkills ?? this.maarifSkills,
      differentiation: differentiation ?? this.differentiation,
    );
  }

  factory CurriculumOutcomeModel.fromMap(Map<String, dynamic> map) {
    return CurriculumOutcomeModel(
      id: map['id'] as int?,
      docId: map['doc_id'] as String? ?? '',
      gradeLevel: map['grade_level'] as int? ?? 5,
      subjectCode: map['subject_code'] as String? ?? 'GENEL',
      subjectName: map['subject_name'] as String? ?? 'Genel Ders',
      publisher: map['publisher'] as String? ?? 'MEB Yayınları',
      fullTitle: map['full_title'] as String? ?? '',
      category: map['category'] as String? ?? 'core',
      weekNumber: map['week_number'] as int? ?? 1,
      teachingWeekNumber: map['teaching_week_number'] as int?,
      unitTitle: map['unit_title'] as String? ?? '',
      topicTitle: map['topic_title'] as String? ?? '',
      outcomeCode: map['outcome_code'] as String?,
      outcomeDescription: map['outcome_description'] as String? ?? '',
      outcomeParts: OutcomePart.listFromDbText(map['outcome_parts'] as String?),
      suggestedActivities:
          _stringListFromDbText(map['suggested_activities'] as String?),
      spanIndex: map['span_index'] as int?,
      spanTotal: map['span_total'] as int?,
      officialActivity: map['official_activity'] as String?,
      isEstimatedSchedule: (map['is_estimated_schedule'] as int? ?? 0) == 1,
      academicYear: map['academic_year'] as String? ?? '2026-2027',
      isHolidayWeek: (map['is_holiday_week'] as int? ?? 0) == 1,
      holidayNote: map['holiday_note'] as String?,
      dateRangeStr: map['date_range_str'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      isOtpWeekFlag: (map['is_otp_week'] as int? ?? 0) == 1,
      isSocialEventWeekFlag: (map['is_social_event_week'] as int? ?? 0) == 1,
      maarifSummary: map['maarif_summary'] as String?,
      maarifValues: map['maarif_values'] as String?,
      maarifSkills: map['maarif_skills'] as String?,
      differentiation: map['differentiation'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doc_id': docId,
      'grade_level': gradeLevel,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'publisher': publisher,
      'full_title': fullTitle,
      'category': category,
      'week_number': weekNumber,
      'teaching_week_number': teachingWeekNumber,
      'unit_title': unitTitle,
      'topic_title': topicTitle,
      'outcome_code': outcomeCode,
      'outcome_description': outcomeDescription,
      'outcome_parts': OutcomePart.listToDbText(outcomeParts),
      'suggested_activities': suggestedActivities.isEmpty
          ? null
          : jsonEncode(suggestedActivities),
      'span_index': spanIndex,
      'span_total': spanTotal,
      'official_activity': officialActivity,
      'is_estimated_schedule': isEstimatedSchedule ? 1 : 0,
      'academic_year': academicYear,
      'is_holiday_week': isHolidayWeek ? 1 : 0,
      'is_otp_week': isOtpWeekFlag ? 1 : 0,
      'is_social_event_week': isSocialEventWeekFlag ? 1 : 0,
      'holiday_note': holidayNote,
      'date_range_str': dateRangeStr,
      'maarif_summary': maarifSummary,
      'maarif_values': maarifValues,
      'maarif_skills': maarifSkills,
      'differentiation': differentiation,
    };
  }

  factory CurriculumOutcomeModel.fromJson(Map<String, dynamic> json) {
    String? formattedRange;
    if (json['dateRange'] is Map) {
      formattedRange = (json['dateRange'] as Map)['formatted'] as String?;
    }

    return CurriculumOutcomeModel(
      docId: json['id'] as String? ?? '',
      gradeLevel: json['gradeLevel'] as int? ?? 5,
      subjectCode: json['subjectCode'] as String? ?? 'GENEL',
      subjectName: json['subjectName'] as String? ?? 'Genel Ders',
      publisher: json['publisher'] as String? ?? 'MEB Yayınları',
      fullTitle: json['fullTitle'] as String? ?? '',
      category: json['category'] as String? ?? 'core',
      weekNumber: json['weekNumber'] as int? ?? 1,
      teachingWeekNumber: json['teachingWeekNumber'] as int?,
      unitTitle: json['unitTitle'] as String? ?? '',
      topicTitle: json['topicTitle'] as String? ?? '',
      outcomeCode: json['outcomeCode'] as String?,
      outcomeDescription: json['outcomeDescription'] as String? ?? '',
      outcomeParts: OutcomePart.listFromJson(json['outcomeParts']),
      suggestedActivities: _stringListFromJson(json['suggestedActivities']),
      spanIndex: json['spanIndex'] as int?,
      spanTotal: json['spanTotal'] as int?,
      officialActivity: json['officialActivity'] as String?,
      isEstimatedSchedule: json['isEstimatedSchedule'] as bool? ?? false,
      academicYear: json['academicYear'] as String? ?? '2026-2027',
      isHolidayWeek: json['isHolidayWeek'] as bool? ?? false,
      isOtpWeekFlag: json['isOtpWeek'] as bool? ?? false,
      isSocialEventWeekFlag: json['isSocialEventWeek'] as bool? ?? false,
      holidayNote: json['holidayNote'] as String?,
      dateRangeStr: formattedRange ?? (json['dateRangeStr'] as String?),
      maarifSummary: json['maarifSummary'] as String?,
      maarifValues: json['maarifValues'] as String?,
      maarifSkills: json['maarifSkills'] as String?,
      differentiation: json['differentiation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': docId,
      'gradeLevel': gradeLevel,
      'subjectCode': subjectCode,
      'subjectName': subjectName,
      'publisher': publisher,
      'fullTitle': fullTitle,
      'category': category,
      'weekNumber': weekNumber,
      'teachingWeekNumber': teachingWeekNumber,
      'unitTitle': unitTitle,
      'topicTitle': topicTitle,
      'outcomeCode': outcomeCode,
      'outcomeDescription': outcomeDescription,
      'outcomeParts': outcomeParts.map((p) => p.toJson()).toList(),
      'suggestedActivities': suggestedActivities,
      'spanIndex': spanIndex,
      'spanTotal': spanTotal,
      'officialActivity': officialActivity,
      'isEstimatedSchedule': isEstimatedSchedule,
      'academicYear': academicYear,
      'isHolidayWeek': isHolidayWeek,
      'isOtpWeek': isOtpWeek,
      'isSocialEventWeek': isSocialEventWeek,
      'holidayNote': holidayNote,
      'dateRangeStr': dateRangeStr,
      'maarifSummary': maarifSummary,
      'maarifValues': maarifValues,
      'maarifSkills': maarifSkills,
      'differentiation': differentiation,
    };
  }

  /// Türkiye Yüzyılı Maarif Modeli (TYMM) uyumlu mu?
  bool get isMaarif =>
      publisher.toLowerCase().contains('maarif') ||
      publisher.toLowerCase().contains('tymm') ||
      unitTitle.toLowerCase().contains('maarif') ||
      fullTitle.toLowerCase().contains('maarif') ||
      (maarifSummary != null && maarifSummary!.isNotEmpty);

  /// Okul Temelli Planlama (OTP) Haftası mı?
  ///
  /// Hafta numarası MEB'in her yıl tebliğle belirlediği takvime göre değişir;
  /// bu yüzden karar verinin kendi bayrağıyla verilir. 8/17/29 gibi sabit
  /// hafta numaraları takvim kaydığında yanlış etiket üretiyordu.
  bool get isOtpWeek =>
      isOtpWeekFlag ||
      topicTitle.toLowerCase().contains('okul temelli') ||
      unitTitle.toLowerCase().contains('okul temelli') ||
      outcomeDescription.toLowerCase().contains('okul temelli');

  /// Dönem Sonu MEB Sosyal Etkinlikler Haftası mı?
  bool get isSocialEventWeek =>
      isSocialEventWeekFlag ||
      topicTitle.toLowerCase().contains('sosyal etkinlik') ||
      unitTitle.toLowerCase().contains('sosyal etkinlik') ||
      outcomeDescription.toLowerCase().contains('sosyal etkinlik');
}


/// Tek bir kazanım: kodu, açıklaması ve süreç bileşenleri.
class OutcomePart {
  const OutcomePart({
    this.code,
    this.text = '',
    this.steps = const [],
    this.lead,
  });

  /// Kazanım kodu (ör. "MAT.5.1.2"). Kaynakta kod yoksa null olabilir.
  final String? code;

  /// Kazanımın kendi açıklaması.
  final String text;

  /// "a) ... b) ..." biçimindeki süreç bileşenleri.
  final List<String> steps;

  /// İlk kazanımdan önce gelen ünite/konu başlığı (yalnızca ilk blokta).
  final String? lead;

  bool get isEmpty => (code == null || code!.isEmpty) &&
      text.trim().isEmpty && steps.isEmpty;

  factory OutcomePart.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    return OutcomePart(
      code: json['code'] as String?,
      text: json['text'] as String? ?? '',
      steps: rawSteps is List
          ? rawSteps.map((e) => e.toString()).toList()
          : const [],
      lead: json['lead'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'text': text,
        'steps': steps,
        if (lead != null) 'lead': lead,
      };

  static List<OutcomePart> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => OutcomePart.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => !p.isEmpty)
        .toList();
  }

  /// SQLite'ta tek sütunda JSON metni olarak saklanır.
  static List<OutcomePart> listFromDbText(String? text) {
    if (text == null || text.trim().isEmpty) return const [];
    try {
      return listFromJson(jsonDecode(text));
    } catch (_) {
      return const [];
    }
  }

  static String? listToDbText(List<OutcomePart> parts) {
    if (parts.isEmpty) return null;
    return jsonEncode(parts.map((p) => p.toJson()).toList());
  }
}


/// JSON'dan metin listesi okur; biçim beklenmedikse boş liste döner.
List<String> _stringListFromJson(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
}

/// SQLite'ta JSON metni olarak saklanan listeyi çözer.
List<String> _stringListFromDbText(String? text) {
  if (text == null || text.trim().isEmpty) return const [];
  try {
    return _stringListFromJson(jsonDecode(text));
  } catch (_) {
    return const [];
  }
}
