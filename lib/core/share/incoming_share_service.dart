import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// WhatsApp / Dosyalar uygulamasından SınıfCepte'ye paylaşılan belge.
///
/// Okul, sınıf listesini neredeyse her zaman WhatsApp'tan atar. Android
/// seçicisinin "Son dosyalar" sekmesi WhatsApp belgelerini göstermez;
/// öğretmen PDF'ye basıp Paylaş → SınıfCepte deyince bu servis dosyayı
/// alır ve içe aktarma ekranına verir.
class IncomingShareService {
  IncomingShareService._();

  static final IncomingShareService instance = IncomingShareService._();

  static const MethodChannel _channel = MethodChannel('sinifcepte/incoming_share');

  final StreamController<String> _files = StreamController<String>.broadcast();

  bool _attached = false;
  int _previewListeners = 0;
  String? _pendingPath;
  String? _lastOffered;

  /// Öğretmen kromu hazır olduğunda (MainNavigation) paylaşımı açar.
  void Function(String path)? onNeedOpenPreview;

  /// İçe aktarma ekranı açıkken gelen paylaşımlar.
  Stream<String> get files => _files.stream;

  bool get previewListening => _previewListeners > 0;

  String? get pendingPath => _pendingPath;

  /// Platform kanalını bağlar. Birden fazla çağrı yutulur.
  Future<void> attach() async {
    if (_attached) return;
    if (kIsWeb) return;
    if (!(Platform.isAndroid || Platform.isIOS)) return;
    _attached = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSharedFile') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) _offer(path);
      }
    });

    try {
      final pending = await _channel.invokeMethod<String>('takePending');
      if (pending != null && pending.isNotEmpty) _offer(pending);
    } catch (e, stackTrace) {
      debugPrint('IncomingShare takePending: $e\n$stackTrace');
    }
  }

  void addPreviewListener() => _previewListeners++;

  void removePreviewListener() {
    if (_previewListeners > 0) _previewListeners--;
  }

  /// Bekleyen paylaşımı, henüz bir ekran üstlenmediyse açar.
  void consumePendingIfUnhandled() {
    final path = _pendingPath;
    if (path == null || path.isEmpty) return;
    if (_previewListeners > 0) return;
    _pendingPath = null;
    onNeedOpenPreview?.call(path);
  }

  /// İşlenmemiş yolu verir ve temizler.
  String? takePending() {
    final path = _pendingPath;
    _pendingPath = null;
    return path;
  }

  void _offer(String path) {
    if (path.isEmpty || path == _lastOffered) return;
    _lastOffered = path;

    if (_previewListeners > 0) {
      _pendingPath = null;
      _files.add(path);
      return;
    }

    final handler = onNeedOpenPreview;
    if (handler != null) {
      _pendingPath = null;
      handler(path);
    } else {
      _pendingPath = path;
    }
  }

  @visibleForTesting
  void debugOffer(String path) => _offer(path);

  @visibleForTesting
  void resetForTest() {
    _pendingPath = null;
    _lastOffered = null;
    _previewListeners = 0;
    onNeedOpenPreview = null;
  }
}
