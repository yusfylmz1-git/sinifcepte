import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// WhatsApp / indirme / paylaşım önbelleğinden bulunan sınıf listesi dosyası.
class RecentStudentDocument {
  final String name;
  final String path;
  final DateTime modified;
  final String source;
  final int size;

  const RecentStudentDocument({
    required this.name,
    required this.path,
    required this.modified,
    required this.source,
    required this.size,
  });

  bool get isWhatsApp => source == 'whatsapp';

  String get sourceLabel {
    switch (source) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'download':
        return 'İndirilenler';
      case 'shared':
        return 'Paylaşılan';
      default:
        return 'Dosya';
    }
  }

  /// WhatsApp önce, sonra en yeni tarih.
  ///
  /// Android "Son dosyalar" WhatsApp belgelerini karıştırır / gizler;
  /// öğretmen listesinde okulun attığı PDF en üstte durmalı.
  static List<RecentStudentDocument> sortForTeacher(
    List<RecentStudentDocument> items,
  ) {
    final copy = [...items];
    copy.sort((a, b) {
      final bySource = (a.isWhatsApp ? 0 : 1).compareTo(b.isWhatsApp ? 0 : 1);
      if (bySource != 0) return bySource;
      return b.modified.compareTo(a.modified);
    });
    return copy;
  }

  factory RecentStudentDocument.fromMap(Map<dynamic, dynamic> map) {
    final modifiedRaw = map['modified'];
    final modifiedMs = modifiedRaw is int
        ? modifiedRaw
        : (modifiedRaw is num ? modifiedRaw.toInt() : 0);
    final sizeRaw = map['size'];
    return RecentStudentDocument(
      name: (map['name'] as String?) ?? 'belge',
      path: (map['path'] as String?) ?? '',
      modified: DateTime.fromMillisecondsSinceEpoch(modifiedMs),
      source: (map['source'] as String?) ?? 'file',
      size: sizeRaw is int ? sizeRaw : (sizeRaw is num ? sizeRaw.toInt() : 0),
    );
  }
}

/// Android tarafında WhatsApp Belgeler klasörünü açar; Son dosyalar'a düşmez.
class RecentStudentDocuments {
  RecentStudentDocuments._();

  static const MethodChannel _channel = MethodChannel('sinifcepte/incoming_share');

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  static Future<List<RecentStudentDocument>> list() async {
    if (!_isAndroid) return const [];
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listRecentDocuments');
      if (raw == null) return const [];
      final items = <RecentStudentDocument>[];
      for (final row in raw) {
        if (row is Map) {
          final doc = RecentStudentDocument.fromMap(row);
          if (doc.path.isNotEmpty) items.add(doc);
        }
      }
      return RecentStudentDocument.sortForTeacher(items);
    } catch (e, stackTrace) {
      debugPrint('WhatsApp belge listesi okunamadı: $e\n$stackTrace');
      return const [];
    }
  }

  /// Sistem seçicisini WhatsApp Belgeler klasöründe açmayı dener.
  ///
  /// "Son" sekmesi değil; EXTRA_INITIAL_URI ile Belgeler yolu verilir.
  static Future<String?> pickInWhatsAppFolder() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('pickInWhatsAppFolder');
    } catch (e, stackTrace) {
      debugPrint('WhatsApp klasör seçici hatası: $e\n$stackTrace');
      return null;
    }
  }

  /// Bir kez klasör izni; sonraki açılışlarda liste dolu gelir.
  static Future<List<RecentStudentDocument>?> grantWhatsAppFolder() async {
    if (!_isAndroid) return null;
    try {
      final raw = await _channel.invokeMethod('grantWhatsAppFolder');
      if (raw == null) return null;
      if (raw is! List) return const [];
      final items = <RecentStudentDocument>[];
      for (final row in raw) {
        if (row is Map) {
          final doc = RecentStudentDocument.fromMap(row);
          if (doc.path.isNotEmpty) items.add(doc);
        }
      }
      return RecentStudentDocument.sortForTeacher(items);
    } catch (e, stackTrace) {
      debugPrint('WhatsApp klasör izni hatası: $e\n$stackTrace');
      return null;
    }
  }

  static Future<bool> hasFolderGrant() async {
    if (!_isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('hasWhatsAppFolderGrant') ?? false;
    } catch (_) {
      return false;
    }
  }
}
