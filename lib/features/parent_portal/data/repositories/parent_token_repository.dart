import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../../core/storage/prefs_service.dart';
import '../../../../core/storage/prefs_keys.dart';
import '../../../../core/utils/perf_trace.dart';
import '../../../../core/storage/prefs_migrator.dart';
import '../../../../data/models/class_model.dart';
import '../../../../data/models/student_model.dart';
import '../../../auth_profile/data/models/teacher_profile_model.dart';
import '../models/parent_link_model.dart';
import '../models/parent_token_model.dart';
import '../../../../core/cloud/cloud_ids.dart';

/// Doğrulama Sonucu Modeli
class TokenVerificationResult {
  final bool isSuccess;
  final ParentTokenModel? token;
  final String? errorMessage;

  const TokenVerificationResult._({
    required this.isSuccess,
    this.token,
    this.errorMessage,
  });

  factory TokenVerificationResult.success(ParentTokenModel token) {
    return TokenVerificationResult._(isSuccess: true, token: token);
  }

  factory TokenVerificationResult.failure(String errorMessage) {
    return TokenVerificationResult._(isSuccess: false, errorMessage: errorMessage);
  }
}

/// SınıfCepte - Veli Referans Kodu & Güvenlik Deposu
class ParentTokenRepository {
  static const String _tokensPrefKey = PrefsKeys.parentTokens;
  static const String _linksPrefKey = PrefsKeys.parentLinks;
  static const String _auditLogsPrefKey = PrefsKeys.auditLogs;

  /// Cihazda tutulacak azami token sayısı.
  ///
  /// Her öğrenci için tek aktif kod yeterlidir; bu sınır yalnızca
  /// beklenmedik birikmelere karşı güvenlik ağıdır.
  static const int _maxStoredTokens = 2000;

  /// Denetim günlüğünde tutulacak azami kayıt sayısı.
  static const int _maxAuditLogs = 1000;

  List<ParentTokenModel>? _cachedTokens;
  List<ParentLinkModel>? _cachedLinks;

  /// Rastgele 4 Haneli Kod Üretici (Örn: 9402)
  String _generateRandomCodeDigits() {
    final random = Random();
    final digits = 1000 + random.nextInt(9000);
    return digits.toString();
  }

  /// Sınıf Etiketini Temizleme (Örn: "8-A" -> "8A", "10/B" -> "10B")
  String _sanitizeClassName(String rawClassName) {
    final clean = rawClassName
        .replaceAll('-', '')
        .replaceAll('/', '')
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .toUpperCase()
        .trim();
    return clean.isNotEmpty ? clean : 'OKUL';
  }

  /// Tüm Tokenları Yükleme
  Future<List<ParentTokenModel>> _loadTokens() async {
    if (_cachedTokens != null) return _cachedTokens!;
    return PerfTrace.run('token listesi yükleme', _loadTokensUncached);
  }

  Future<List<ParentTokenModel>> _loadTokensUncached() async {
    await PrefsMigrator.migrateParentStores();
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return const [];
      final rawList = prefs.getStringList(_tokensPrefKey) ?? [];
      final list = <ParentTokenModel>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(ParentTokenModel.fromMap(decoded));
          }
        } catch (_) {}
      }
      _cachedTokens = list;
      return list;
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository _loadTokens hatası: $e\n$stackTrace');
      return [];
    }
  }

  /// Tokenları Kaydetme
  Future<void> _saveTokens(List<ParentTokenModel> list) async {
    _cachedTokens = list;
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      final rawList = list.map((t) => jsonEncode(t.toMap())).toList();
      await prefs.setStringList(_tokensPrefKey, rawList);
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository _saveTokens hatası: $e\n$stackTrace');
    }
  }

  /// Tüm Veli Bağlantılarını (parent_links) Yükleme
  Future<List<ParentLinkModel>> _loadLinks() async {
    if (_cachedLinks != null) return _cachedLinks!;
    await PrefsMigrator.migrateParentStores();
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return const [];
      final rawList = prefs.getStringList(_linksPrefKey) ?? [];
      final list = <ParentLinkModel>[];
      for (final raw in rawList) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            list.add(ParentLinkModel.fromMap(decoded));
          }
        } catch (_) {}
      }
      _cachedLinks = list;
      return list;
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository _loadLinks hatası: $e\n$stackTrace');
      return [];
    }
  }

  /// Veli Bağlantılarını Kaydetme
  Future<void> _saveLinks(List<ParentLinkModel> list) async {
    _cachedLinks = list;
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      final rawList = list.map((l) => jsonEncode(l.toMap())).toList();
      await prefs.setStringList(_linksPrefKey, rawList);
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository _saveLinks hatası: $e\n$stackTrace');
    }
  }

  /// Audit Log Kaydı Ekleme (KVKK & Hesap Verebilirlik)
  Future<void> _logAudit({
    required String actorId,
    required String actorRole,
    required String action,
    required String targetId,
    String? details,
  }) async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return;
      final rawLogs = prefs.getStringList(_auditLogsPrefKey) ?? [];
      final logEntry = {
        'id': 'log_${DateTime.now().millisecondsSinceEpoch}',
        'actor_id': actorId,
        'actor_role': actorRole,
        'action': action,
        'target_id': targetId,
        'details': details,
        'timestamp': DateTime.now().toIso8601String(),
      };
      rawLogs.add(jsonEncode(logEntry));

      // Günlük sınırsız büyürse her okuma yavaşlar ve depo şişer.
      // En eski kayıtlar düşürülür (yeni kayıtlar listenin sonundadır).
      if (rawLogs.length > _maxAuditLogs) {
        rawLogs.removeRange(0, rawLogs.length - _maxAuditLogs);
      }

      await prefs.setStringList(_auditLogsPrefKey, rawLogs);
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository _logAudit hatası: $e\n$stackTrace');
    }
  }

  /// Öğrenci İçin Yeni Veli Referans Kodu ve QR Üretme
  /// Etiketi kimlikte kullanilabilir hale getirir (Turkce harfler dahil).
  static String _slug(String raw) {
    const map = {
      'ç': 'c', 'ğ': 'g', 'ı': 'i', 'ö': 'o', 'ş': 's', 'ü': 'u',
      'Ç': 'c', 'Ğ': 'g', 'İ': 'i', 'Ö': 'o', 'Ş': 's', 'Ü': 'u',
    };
    final buffer = StringBuffer();
    for (final ch in raw.split('')) {
      final mapped = map[ch] ?? ch.toLowerCase();
      if (RegExp(r'[a-z0-9]').hasMatch(mapped)) buffer.write(mapped);
    }
    final out = buffer.toString();
    return out.isEmpty ? 'veli' : out;
  }

  /// Öğrenciye referans kodu üretir.
  ///
  /// [parentLabel] boşsa bu öğrencinin ortak kodudur (anne de baba da
  /// aynı kodu kullanabilir) ve öğrencinin varsa eski ortak kodunun
  /// yerine geçer. Doluysa ('Anne'/'Baba'/'Vasi') ayrı yaşayan aileler
  /// için ikinci bir koddur; diğer kodları etkilemez.
  Future<ParentTokenModel> generateTokenForStudent({
    required StudentModel student,
    required ClassModel classModel,
    required TeacherProfileModel teacher,
    String parentLabel = '',
  }) async {
    final tokens = await _loadTokens();

    // 1. Bu öğrencinin ESKİ kayıtlarını tamamen kaldır.
    //
    // Önceden yalnızca 'revoked' işaretleniyor ama listede bırakılıyordu.
    // Her kod üretiminde liste büyüyor, her okumada tamamı JSON olarak
    // ayrıştırılıp yeniden yazılıyordu. Birkaç denemeden sonra ekran
    // açılmaz hale geliyordu — kullanıcı "ilk açılışta çalıştı, sonra
    // bozuldu" diye bildirdi.
    //
    // İptal edilmiş kodun saklanması için bir gerekçe yok: veli o kodla
    // bağlanamaz, denetim izi ayrıca audit log'da tutulur.
    //
    // Yalnızca AYNI etiketli kod değiştirilir: ayrı yaşayan ailelerde
    // öğrencinin birden fazla kodu olabilir ("Anne", "Baba"). Etiketten
    // bağımsız silmek, anneye kod üretirken babanınkini yok ederdi.
    tokens.removeWhere(
      (t) => t.studentId == student.id && t.parentLabel == parentLabel,
    );

    // 2. Güvenlik ağı: toplam kayıt sayısını sınırla.
    //
    // Sınıf sayısı arttıkça liste yine büyüyebilir. Süresi dolmuş
    // kayıtlar zaten işe yaramaz, temizlenir.
    // Süresiz kodlar (yeni varsayılan) bu temizlikten etkilenmez;
    // yalnızca eski sürümden kalan tarihli kodlar düşer.
    final now0 = DateTime.now();
    tokens.removeWhere((t) => !t.isOpenEnded && t.expiresAt.isBefore(now0));
    if (tokens.length > _maxStoredTokens) {
      tokens.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      tokens.removeRange(_maxStoredTokens, tokens.length);
    }

    final classTag = _sanitizeClassName(classModel.name);
    final existingCodes = tokens.map((t) => t.code).toSet();
    String formattedCode;
    do {
      final randomDigits = _generateRandomCodeDigits();
      formattedCode = 'SC-$classTag-$randomDigits'; // Örn: SC-8A-9402
    } while (existingCodes.contains(formattedCode));

    final codeHash = ParentTokenModel.generateSha256(formattedCode);
    final secondFactorHash = ParentTokenModel.generateSha256(student.schoolNumber.toString());

    final now = DateTime.now();
    // Kodun gün bazlı süresi yoktur: öğrenci okulda olduğu sürece
    // geçerlidir ve olayla kapanır (mezuniyet, başka okula nakil,
    // öğrenci silme, öğretmenin elle iptali). Veli her dönem yeniden
    // kod istemek zorunda kalmaz.
    final expiresAt = ParentTokenModel.noExpiry;

    // Kimlik yalnizca zaman damgasi olsaydi, ayni ogrenciye ayni
    // milisaniyede uretilen iki kod (anne/baba) ayni kimligi alir ve
    // birini iptal etmek digerini kapatirdi. Etiket kimlige girer.
    final labelTag = parentLabel.isEmpty ? 'ortak' : _slug(parentLabel);
    final tokenId =
        'tok_${student.id}_${labelTag}_${now.millisecondsSinceEpoch}';

    // QR Kod Payload (JSON formatında güvenli derin bağlantı)
    final qrMap = {
      'action': 'sinifcepte_parent_link',
      'version': '2.0',
      'token_id': tokenId,
      'code': formattedCode,
      'school_id': teacher.schoolId ?? '',
      'school_name': teacher.schoolName,
      'class_id': classModel.id ?? 0,
      'class_name': classModel.name,
      'student_id': student.id ?? 0,
      'student_name': student.fullName,
      'expires_at': expiresAt.toIso8601String(),
    };
    final qrPayload = jsonEncode(qrMap);

    final newToken = ParentTokenModel(
      id: tokenId,
      schoolId: teacher.schoolId ?? '',
      schoolName: teacher.schoolName,
      classId: classModel.id ?? 0,
      className: classModel.name,
      studentId: student.id ?? 0,
      studentName: student.fullName,
      studentNumber: student.schoolNumber,
      code: formattedCode,
      codeHash: codeHash,
      secondFactorHash: secondFactorHash,
      createdAt: now,
      expiresAt: expiresAt,
      status: 'active',
      linkedParentCount: 0,
      maxLinkedParents: 2,
      qrPayload: qrPayload,
      parentLabel: parentLabel,
      teacherUid: teacher.id,
    );

    tokens.insert(0, newToken);
    await _saveTokens(tokens);

    await _logAudit(
      actorId: teacher.fullName,
      actorRole: 'teacher',
      action: 'token_generated',
      targetId: 'student_${student.id}',
      details: 'Kod: $formattedCode üretildi '
          '(Öğrenci okuldan ayrılana kadar geçerli)',
    );

    return newToken;
  }

  /// Birden Fazla Öğrenci İçin Tek Seferde Toplu ve Hızlı Referans Kodu Üretme (Sıfır Donma / ANR)
  Future<List<ParentTokenModel>> generateTokensForStudentsBatch({
    required List<StudentModel> students,
    required ClassModel classModel,
    required TeacherProfileModel teacher,
  }) async {
    if (students.isEmpty) return const [];
    final tokens = await _loadTokens();

    final now0 = DateTime.now();
    tokens.removeWhere((t) => t.expiresAt.isBefore(now0));

    final studentIds = students.map((s) => s.id).whereType<int>().toSet();
    tokens.removeWhere((t) => studentIds.contains(t.studentId));

    final classTag = _sanitizeClassName(classModel.name);
    final now = DateTime.now();
    // Süre sınırı yoktur; kod olayla kapanır (bkz. generateTokenForStudent).
    final expiresAt = ParentTokenModel.noExpiry;
    final generatedTokens = <ParentTokenModel>[];

    final existingCodes = tokens.map((t) => t.code).toSet();

    for (int i = 0; i < students.length; i++) {
      final student = students[i];
      if (student.id == null) continue;

      String formattedCode;
      do {
        final randomDigits = _generateRandomCodeDigits();
        formattedCode = 'SC-$classTag-$randomDigits';
      } while (existingCodes.contains(formattedCode));
      existingCodes.add(formattedCode);

      final codeHash = ParentTokenModel.generateSha256(formattedCode);
      final secondFactorHash = ParentTokenModel.generateSha256(student.schoolNumber.toString());
      final tokenId = 'tok_${student.id}_${now.millisecondsSinceEpoch}_$i';

      final qrMap = {
        'action': 'sinifcepte_parent_link',
        'version': '2.0',
        'token_id': tokenId,
        'code': formattedCode,
        'school_id': teacher.schoolId ?? '',
        'school_name': teacher.schoolName,
        'class_id': classModel.id ?? 0,
        'class_name': classModel.name,
        'student_id': student.id ?? 0,
        'student_name': student.fullName,
        'expires_at': expiresAt.toIso8601String(),
      };
      final qrPayload = jsonEncode(qrMap);

      final newToken = ParentTokenModel(
        id: tokenId,
        schoolId: teacher.schoolId ?? '',
        schoolName: teacher.schoolName,
        classId: classModel.id ?? 0,
        className: classModel.name,
        studentId: student.id ?? 0,
        studentName: student.fullName,
        studentNumber: student.schoolNumber,
        code: formattedCode,
        codeHash: codeHash,
        secondFactorHash: secondFactorHash,
        createdAt: now,
        expiresAt: expiresAt,
        status: 'active',
        linkedParentCount: 0,
        maxLinkedParents: 2,
        qrPayload: qrPayload,
      );

      generatedTokens.add(newToken);
      tokens.insert(0, newToken);
    }

    if (tokens.length > _maxStoredTokens) {
      tokens.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      tokens.removeRange(_maxStoredTokens, tokens.length);
    }

    await _saveTokens(tokens);

    await _logAudit(
      actorId: teacher.fullName,
      actorRole: 'teacher',
      action: 'tokens_batch_generated',
      targetId: 'class_${classModel.id}',
      details: '${generatedTokens.length} adet kod toplu üretildi',
    );

    return generatedTokens;
  }

  /// Öğrencinin TÜM aktif kodlarını getirir.
  ///
  /// [getActiveTokenForStudent] yalnızca ilkini döndürür; ayrı yaşayan
  /// ailelerde öğrenciye ikinci bir veli kodu üretilebildiği için
  /// yaşam döngüsü işlemlerinde hepsine dokunmak gerekir.
  Future<List<ParentTokenModel>> getTokensForStudent(int studentId) async {
    final tokens = await _loadTokens();
    return tokens
        .where((t) => t.studentId == studentId && t.status == 'active')
        .toList();
  }

  /// Öğrencinin aktif kodlarını verilen durumla kapatır.
  ///
  /// [newStatus]: 'revoked' | 'graduated' | 'transferred'.
  /// Kapatılan kod sayısını döndürür.
  Future<int> closeTokensForStudent({
    required int studentId,
    required String newStatus,
  }) async {
    final tokens = await _loadTokens();
    var count = 0;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.studentId == studentId && t.status == 'active') {
        tokens[i] = t.copyWith(status: newStatus);
        count++;
      }
    }
    if (count > 0) await _saveTokens(tokens);
    return count;
  }

  /// Öğrencinin aktif veli bağlarını verilen durumla kapatır.
  Future<int> closeLinksForStudent({
    required int studentId,
    required String newStatus,
  }) async {
    final links = await _loadLinks();
    var count = 0;
    for (var i = 0; i < links.length; i++) {
      final l = links[i];
      if (l.studentId == studentId && l.status == 'active') {
        links[i] = l.copyWith(status: newStatus);
        count++;
      }
    }
    if (count > 0) await _saveLinks(links);
    return count;
  }

  /// Şube değişikliğinde kod ve bağ kayıtlarını yeni sınıfa taşır.
  ///
  /// Bağ koparılmaz: çocuk aynı çocuktur, veli aynı velidir. Yalnızca
  /// sınıf bilgisi güncellenir; böylece veli yeniden kod almak zorunda
  /// kalmaz ve panelinde doğru şube adını görür.
  Future<void> moveStudentTokensAndLinks({
    required int studentId,
    required int newClassId,
    required String newClassName,
  }) async {
    final tokens = await _loadTokens();
    var tokenChanged = false;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.studentId == studentId && t.status == 'active') {
        tokens[i] = t.copyWith(classId: newClassId, className: newClassName);
        tokenChanged = true;
      }
    }
    if (tokenChanged) await _saveTokens(tokens);

    final links = await _loadLinks();
    var linkChanged = false;
    for (var i = 0; i < links.length; i++) {
      final l = links[i];
      if (l.studentId == studentId && l.status == 'active') {
        links[i] = l.copyWith(classId: newClassId, className: newClassName);
        linkChanged = true;
      }
    }
    if (linkChanged) await _saveLinks(links);
  }

  /// Öğrencinin Aktif / Mevcut Tokenını Getirme
  Future<ParentTokenModel?> getActiveTokenForStudent(int studentId) async {
    final tokens = await _loadTokens();
    final matches = tokens.where((t) => t.studentId == studentId && t.status == 'active').toList();
    if (matches.isEmpty) return null;

    final token = matches.first;
    // Eğer süresi dolmuşsa durumunu güncelle
    if (token.isExpired) {
      final updated = token.copyWith(status: 'expired');
      final index = tokens.indexWhere((t) => t.id == token.id);
      if (index != -1) {
        tokens[index] = updated;
        await _saveTokens(tokens);
      }
      return null;
    }
    return token;
  }

  /// Sınıfa Ait Tüm Öğrencilerin Aktif Tokenlarını Getirme (Varsa Getir, Yoksa Anında Üret)
  Future<Map<int, ParentTokenModel>> getOrGenerateTokensForClass({
    required ClassModel classModel,
    required List<StudentModel> students,
    required TeacherProfileModel teacher,
  }) async {
    final tokens = await _loadTokens();
    final now = DateTime.now();
    final result = <int, ParentTokenModel>{};
    bool needsSave = false;

    // 1. Mevcut geçerli tokenları topla
    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.classId == classModel.id && token.status == 'active') {
        if (token.expiresAt.isBefore(now)) {
          tokens[i] = token.copyWith(status: 'expired');
          needsSave = true;
        } else {
          result[token.studentId] = token;
        }
      }
    }

    // 2. Kodu olmayan veya süresi dolmuş öğrencileri bul
    final missing = students.where((s) => s.id != null && !result.containsKey(s.id)).toList();
    if (missing.isNotEmpty) {
      final classTag = _sanitizeClassName(classModel.name);
      final expiresAt = ParentTokenModel.noExpiry;
      final existingCodes = tokens.map((t) => t.code).toSet();

      for (int i = 0; i < missing.length; i++) {
        final student = missing[i];
        String formattedCode;
        do {
          final randomDigits = _generateRandomCodeDigits();
          formattedCode = 'SC-$classTag-$randomDigits';
        } while (existingCodes.contains(formattedCode));
        existingCodes.add(formattedCode);

        final codeHash = ParentTokenModel.generateSha256(formattedCode);
        final secondFactorHash = ParentTokenModel.generateSha256(student.schoolNumber.toString());
        final tokenId = 'tok_${student.id}_${now.millisecondsSinceEpoch}_$i';

        final qrMap = {
          'action': 'sinifcepte_parent_link',
          'version': '2.0',
          'token_id': tokenId,
          'code': formattedCode,
          'school_id': teacher.schoolId ?? '',
          'school_name': teacher.schoolName,
          'class_id': classModel.id ?? 0,
          'class_name': classModel.name,
          'student_id': student.id ?? 0,
          'student_name': student.fullName,
          'expires_at': expiresAt.toIso8601String(),
        };

        final newToken = ParentTokenModel(
          id: tokenId,
          schoolId: teacher.schoolId ?? '',
          schoolName: teacher.schoolName,
          classId: classModel.id ?? 0,
          className: classModel.name,
          studentId: student.id ?? 0,
          studentName: student.fullName,
          studentNumber: student.schoolNumber,
          code: formattedCode,
          codeHash: codeHash,
          secondFactorHash: secondFactorHash,
          createdAt: now,
          expiresAt: expiresAt,
          status: 'active',
          linkedParentCount: 0,
          maxLinkedParents: 2,
          qrPayload: jsonEncode(qrMap),
        );

        tokens.insert(0, newToken);
        result[student.id!] = newToken;
        needsSave = true;
      }
    }

    if (needsSave) {
      if (tokens.length > _maxStoredTokens) {
        tokens.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        tokens.removeRange(_maxStoredTokens, tokens.length);
      }
      await _saveTokens(tokens);
    }

    return result;
  }

  /// Sınıfa Ait Tüm Öğrencilerin Aktif Tokenlarını Getirme
  Future<Map<int, ParentTokenModel>> getActiveTokensForClass(int classId) async {
    final tokens = await _loadTokens();
    final now = DateTime.now();
    final result = <int, ParentTokenModel>{};
    bool needsSave = false;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (token.classId == classId && token.status == 'active') {
        if (token.expiresAt.isBefore(now)) {
          tokens[i] = token.copyWith(status: 'expired');
          needsSave = true;
        } else {
          result[token.studentId] = token;
        }
      }
    }

    if (needsSave) {
      await _saveTokens(tokens);
    }
    return result;
  }

  /// Tokenı İptal Etme (Revoke)
  Future<bool> revokeToken(String tokenId, {String actorRole = 'teacher'}) async {
    final tokens = await _loadTokens();
    final index = tokens.indexWhere((t) => t.id == tokenId);
    if (index != -1) {
      final old = tokens[index];
      tokens[index] = old.copyWith(status: 'revoked');
      await _saveTokens(tokens);

      await _logAudit(
        actorId: actorRole,
        actorRole: actorRole,
        action: 'token_revoked',
        targetId: old.id,
        details: 'Kod: ${old.code} iptal edildi',
      );
      return true;
    }
    return false;
  }

  /// Veli Tarafından Girilen Kodu ve 2. Faktörü (Okul No) Doğrulama
  Future<TokenVerificationResult> verifyToken({
    required String inputCode,
    required String inputStudentNumber,
  }) async {
    final cleanCode = ParentTokenModel.normalizeCode(inputCode);
    final cleanNumber = inputStudentNumber.replaceAll(' ', '').trim();

    if (cleanCode.isEmpty) {
      return TokenVerificationResult.failure('Lütfen referans kodunu girin.');
    }
    if (cleanNumber.isEmpty) {
      return TokenVerificationResult.failure('Lütfen öğrencinin okul numarasını girin.');
    }

    final tokens = await _loadTokens();

    // 1. Kod Hash Eşleşmesi
    //
    // Yalnızca hash karşılaştırılır. Eski sürümdeki düz metin yedeği
    // kaldırıldı: bulut tarafında düz kod hiç saklanmadığı için orada zaten
    // imkânsızdı, yerelde tutulması ise iki depoyu farklı güvenlik
    // seviyesinde bırakıyordu.
    final inputCodeHash = ParentTokenModel.generateSha256(cleanCode);
    final matchingTokens = tokens.where((t) => t.codeHash == inputCodeHash).toList();

    if (matchingTokens.isEmpty) {
      return TokenVerificationResult.failure('Geçersiz referans kodu. Lütfen öğretmeninizin verdiği kodu kontrol edin.');
    }

    final token = matchingTokens.first;

    // 2. Statü Kontrolü
    if (token.status == 'revoked') {
      return TokenVerificationResult.failure('Bu referans kodu öğretmen tarafından iptal edilmiş. Lütfen yeni kod isteyin.');
    }
    if (token.isExpired || token.status == 'expired') {
      return TokenVerificationResult.failure('Bu referans kodunun 7 günlük süresi dolmuş. Lütfen öğretmeninizden güncel kod isteyin.');
    }
    if (token.linkedParentCount >= token.maxLinkedParents || token.status == 'used') {
      return TokenVerificationResult.failure('Bu referans koduna izin verilen maksimum veli sayısı (${token.maxLinkedParents}) bağlanmış.');
    }

    // 3. İkinci Faktör Doğrulaması (Öğrenci No Hash Kontrolü)
    // Burada da yalnızca hash karşılaştırılır (bkz. 1. adımdaki gerekçe).
    final inputNumberHash = ParentTokenModel.generateSha256(cleanNumber);
    final isNumberValid = token.secondFactorHash == inputNumberHash;

    if (!isNumberValid) {
      return TokenVerificationResult.failure('Öğrenci okul numarası eşleşmedi! Güvenlik nedeniyle bağlantı kurulamadı.');
    }

    return TokenVerificationResult.success(token);
  }

  /// Veli ile Öğrenciyi Eşleştirme (parent_links oluşturma)
  /// Veli ile öğrenciyi eşleştirir (yerel `parent_links` kaydı).
  ///
  /// [classCloudId] ve [studentCloudId] ZORUNLUDUR: bunlar boş kalırsa
  /// `ParentLinkModel.hasCloudBinding` false döner ve velinin tüm bulut
  /// sorguları (duyurular, kadro, mesajlar) sessizce boş liste verir.
  /// Veli ekranında "öğretmen eklenmemiş" yazmasının sebebi buydu —
  /// kadro bulutta duruyordu ama veli hiç sormuyordu.
  Future<ParentLinkModel?> linkParent({
    required ParentTokenModel token,
    required String parentUserId,
    required String parentName,
    String? parentPhone,
    required String relation, // 'Anne', 'Baba', 'Vasi', 'Diğer'
    required String classCloudId,
    required String studentCloudId,
    String teacherUid = '',
  }) async {
    try {
      final links = await _loadLinks();

      // Aynı veli zaten bağlı mı kontrol et
      final existingIndex = links.indexWhere(
        (l) => l.parentUserId == parentUserId && l.studentId == token.studentId && l.status == 'active',
      );
      if (existingIndex != -1) {
        return links[existingIndex];
      }

      final newLink = ParentLinkModel(
        id: 'link_${token.studentId}_${DateTime.now().millisecondsSinceEpoch}',
        parentUserId: parentUserId,
        parentName: parentName.trim().isNotEmpty ? parentName.trim() : 'Veli',
        parentPhone: parentPhone?.trim(),
        studentId: token.studentId,
        studentName: token.studentName,
        studentNumber: token.studentNumber,
        schoolId: token.schoolId,
        schoolName: token.schoolName,
        classId: token.classId,
        className: token.className,
        relation: relation,
        linkedAt: DateTime.now(),
        linkedViaTokenCode: token.code,
        status: 'active',
        classCloudId: classCloudId,
        studentCloudId: studentCloudId,
        teacherUid: teacherUid,
      );

      links.add(newLink);
      await _saveLinks(links);

      // Token kullanım sayacını artır
      final tokens = await _loadTokens();
      final tokenIndex = tokens.indexWhere((t) => t.id == token.id);
      if (tokenIndex != -1) {
        final newCount = tokens[tokenIndex].linkedParentCount + 1;
        final newStatus = newCount >= tokens[tokenIndex].maxLinkedParents ? 'used' : 'active';
        tokens[tokenIndex] = tokens[tokenIndex].copyWith(
          linkedParentCount: newCount,
          status: newStatus,
        );
        await _saveTokens(tokens);
      }

      await _logAudit(
        actorId: parentUserId,
        actorRole: 'parent',
        action: 'parent_link_created',
        targetId: 'student_${token.studentId}',
        details: '$relation ($parentName) bağlandı',
      );

      return newLink;
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository linkParent hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Tek Adımda Doğrulama ve Veliye Bağlama
  Future<Map<String, dynamic>> verifyAndLinkParent({
    required String code,
    required int studentNumber,
    required String parentName,
    String? parentPhone,
    required String relation,
    String? parentUserId,
  }) async {
    try {
      final result = await verifyToken(
        inputCode: code,
        inputStudentNumber: studentNumber.toString(),
      );

      if (!result.isSuccess || result.token == null) {
        return {
          'success': false,
          'message': result.errorMessage ?? 'Referans kodu doğrulanamadı.',
        };
      }

      final userId = parentUserId ?? await getOrCreateLocalParentUserId();
      final tokenTeacherUid = result.token!.teacherUid;
      final link = await linkParent(
        token: result.token!,
        parentUserId: userId,
        parentName: parentName,
        parentPhone: parentPhone,
        relation: relation,
        teacherUid: tokenTeacherUid,
        classCloudId: CloudIds.isValidUid(tokenTeacherUid)
            ? CloudIds.classId(
                teacherUid: tokenTeacherUid,
                localClassId: result.token!.classId,
              )
            : '',
        studentCloudId: CloudIds.isValidUid(tokenTeacherUid)
            ? CloudIds.studentId(
                teacherUid: tokenTeacherUid,
                localStudentId: result.token!.studentId,
              )
            : '',
      );

      if (link != null) {
        return {
          'success': true,
          'message': '${result.token!.studentName} (${result.token!.className}) başarıyla bağlandı!',
          'link': link,
        };
      } else {
        return {
          'success': false,
          'message': 'Bağlantı kaydı oluşturulamadı.',
        };
      }
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository verifyAndLinkParent hatası: $e\n$stackTrace');
      return {
        'success': false,
        'message': 'Beklenmeyen bir hata oluştu: $e',
      };
    }
  }

  /// Belirli Bir Öğrenciye Bağlı Velileri Getirme (Öğretmen Görünümü)
  /// Bir sınıftaki TÜM bağlı velileri getirir.
  ///
  /// Öğretmenin mesaj kutusu bunu kullanır: hangi veliyle yazışabileceğini
  /// görmesi için sınıf genelinde bakması gerekir.
  Future<List<ParentLinkModel>> getLinkedParentsForClass(int classId) async {
    final links = await _loadLinks();
    return links
        .where((l) => l.classId == classId && l.status == 'active')
        .toList()
      ..sort((a, b) => a.studentName.compareTo(b.studentName));
  }

  Future<List<ParentLinkModel>> getLinkedParentsForStudent(int studentId) async {
    final links = await _loadLinks();
    return links.where((l) => l.studentId == studentId && l.status == 'active').toList();
  }

  /// Belirli Bir Veliye Bağlı Öğrencileri / Çocukları Getirme (Veli Görünümü)
  Future<List<ParentLinkModel>> getParentLinksForParent(String parentUserId) async {
    final links = await _loadLinks();
    return links.where((l) => l.parentUserId == parentUserId && l.status == 'active').toList();
  }

  /// Cihazdaki Yerel Veli Kullanıcı Kimliğini Getir veya Oluştur
  Future<String> getOrCreateLocalParentUserId() async {
    try {
      final prefs = await PrefsService.instance();
      if (prefs == null) return 'puser_default';
      var parentId = prefs.getString(PrefsKeys.localParentId);
      if (parentId == null || parentId.isEmpty) {
        parentId = 'puser_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString(PrefsKeys.localParentId, parentId);
      }
      return parentId;
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository getOrCreateLocalParentUserId hatası: $e\n$stackTrace');
      return 'puser_default';
    }
  }

  /// Bu Cihazdaki Velinin Bağlı Tüm Çocuklarını Getirme.
  ///
  /// [parentUid] verilirse (Google girişi yapmış veli) o kimliğe ait bağlar
  /// döner. Verilmezse eski cihaz-yerel kimliğe düşer — Faz 1 öncesinde
  /// kurulmuş bağların kaybolmaması için.
  Future<List<ParentLinkModel>> getMyConnectedChildren({String? parentUid}) async {
    final parentId = (parentUid != null && parentUid.isNotEmpty)
        ? parentUid
        : await getOrCreateLocalParentUserId();
    return getParentLinksForParent(parentId);
  }

  /// Veli tarafında, bulut doğrulaması başarılı olduktan sonra bağı yerele
  /// yazar.
  ///
  /// Bu kayıt bir **önbellektir**: yetkinin kaynağı buluttaki
  /// `parent_links` dokümanıdır ve kural motoru tarafından korunur. Yerel
  /// kopya yalnızca ağ yokken çocuk listesinin görünmesini sağlar.
  /// Bulut kimlikleri eksik kalmış bağları onarır.
  ///
  /// `classCloudId` / `studentCloudId` alanları sonradan eklendi; daha
  /// önce kurulmuş bağlarda bunlar boştur. Boş oldukları sürece
  /// `hasCloudBinding` false döner ve velinin duyuru, kadro ve mesaj
  /// sorguları sunucuya hiç gitmeden boş liste verir — veli ekranında
  /// "öğretmen eklenmemiş" yazmasının sebebi buydu.
  ///
  /// Onarım cihazda yapılır: öğretmen kimliği bağın kendi token koduna
  /// bakılarak değil, [teacherUidResolver] ile dışarıdan çözülür
  /// (buluttaki token kaydı bu bilgiyi taşır).
  ///
  /// Onarılan bağ sayısını döndürür.
  Future<int> repairMissingCloudIds({
    required Future<String> Function(ParentLinkModel link) teacherUidResolver,
  }) async {
    final links = await _loadLinks();
    var repaired = 0;

    for (var i = 0; i < links.length; i++) {
      final link = links[i];
      if (link.hasCloudBinding) continue;
      if (link.status != 'active') continue;

      final uid = await teacherUidResolver(link);
      if (!CloudIds.isValidUid(uid)) continue;

      links[i] = link.copyWith(
        teacherUid: uid,
        classCloudId: CloudIds.classId(
          teacherUid: uid,
          localClassId: link.classId,
        ),
        studentCloudId: CloudIds.studentId(
          teacherUid: uid,
          localStudentId: link.studentId,
        ),
      );
      repaired++;
    }

    if (repaired > 0) await _saveLinks(links);
    return repaired;
  }

  Future<void> cacheParentLinkLocally(ParentLinkModel link) async {
    try {
      final links = await _loadLinks();

      // Aynı bağ zaten varsa güncelle (kimlik deterministiktir).
      final index = links.indexWhere((l) => l.id == link.id);
      if (index != -1) {
        links[index] = link;
      } else {
        links.add(link);
      }
      await _saveLinks(links);
    } catch (e, stackTrace) {
      debugPrint('cacheParentLinkLocally hatası: $e\n$stackTrace');
    }
  }

  /// Veli Bağlantısını Kaldırma (Sadece Öğretmen veya Veli Kendisi)
  Future<bool> removeParentLink(
    String linkId, {
    required String actorId,
    required String actorRole,
    required String reason,
  }) async {
    try {
      final links = await _loadLinks();
      final index = links.indexWhere((l) => l.id == linkId);
      if (index != -1) {
        final old = links[index];
        links[index] = old.copyWith(status: 'archived');
        await _saveLinks(links);

        await _logAudit(
          actorId: actorId,
          actorRole: actorRole,
          action: 'parent_link_removed',
          targetId: linkId,
          details: 'Neden: $reason (${old.relation}: ${old.parentName})',
        );
        return true;
      }
      return false;
    } catch (e, stackTrace) {
      debugPrint('ParentTokenRepository removeParentLink hatası: $e\n$stackTrace');
      return false;
    }
  }
}
