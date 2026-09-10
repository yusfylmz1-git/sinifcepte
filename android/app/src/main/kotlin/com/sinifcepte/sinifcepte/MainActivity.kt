package com.sinifcepte.sinifcepte

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/// WhatsApp / Dosyalar paylaşımını Flutter'a iletir.
///
/// Okul sınıf listesini WhatsApp'tan atar; belge Android seçicisinde
/// görünmez. Öğretmen PDF'ye basıp Paylaş → SınıfCepte deyince burası
/// content URI'yi önbelleğe kopyalar.
class MainActivity : FlutterActivity() {
    private val channelName = "sinifcepte/incoming_share"
    private var channel: MethodChannel? = null
    private var pendingPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        )
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            if (call.method == "takePending") {
                val path = pendingPath
                pendingPath = null
                result.success(path)
            } else {
                result.notImplemented()
            }
        }
        pendingPath?.let { deliver(it) }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        captureShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureShare(intent)
    }

    private fun captureShare(intent: Intent?) {
        if (intent == null) return
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_SEND -> extraStream(intent)
            Intent.ACTION_VIEW -> intent.data
            else -> null
        }
        if (uri == null) return
        val path = copyToCache(uri) ?: return
        pendingPath = path
        deliver(path)
    }

    private fun extraStream(intent: Intent): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
    }

    private fun deliver(path: String) {
        channel?.invokeMethod("onSharedFile", path)
    }

    private fun copyToCache(uri: Uri): String? {
        return try {
            val rawName = queryDisplayName(uri) ?: "sinif_listesi"
            val safe = rawName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val dest = File(cacheDir, "incoming_share_$safe")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            } ?: return null
            if (dest.length() == 0L) return null
            dest.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        val cursor = contentResolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )
        cursor?.use {
            if (it.moveToFirst()) {
                val idx = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0) return it.getString(idx)
            }
        }
        return uri.lastPathSegment
    }
}
