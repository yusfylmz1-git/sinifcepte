package com.sinifcepte.sinifcepte

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// WhatsApp paylaşımı ve Belgeler klasörü seçicisi.
///
/// Okul sınıf listesini WhatsApp'tan atar; Android "Son dosyalar"
/// bu PDF'i göstermez. Paylaşım ya da WhatsApp Belgeler klasörü gerekir.
class MainActivity : FlutterActivity() {
    private val channelName = "sinifcepte/incoming_share"
    private var channel: MethodChannel? = null
    private var pendingPath: String? = null
    private var pickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        )
        channel = methodChannel
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> {
                    val path = pendingPath
                    pendingPath = null
                    result.success(path)
                }
                "listRecentDocuments" -> result.success(WhatsAppDocuments.listAll(this))
                "hasWhatsAppFolderGrant" ->
                    result.success(WhatsAppDocuments.hasTreeGrant(this))
                "pickInWhatsAppFolder" -> {
                    pickResult = result
                    startActivityForResult(WhatsAppDocuments.openDocumentIntent(), REQ_PICK_DOC)
                }
                "grantWhatsAppFolder" -> {
                    pickResult = result
                    startActivityForResult(WhatsAppDocuments.openTreeIntent(), REQ_PICK_TREE)
                }
                else -> result.notImplemented()
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

    @Deprecated("startActivityForResult, FlutterActivity uyumu için")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK_DOC && requestCode != REQ_PICK_TREE) return

        val pending = pickResult
        pickResult = null

        if (resultCode != Activity.RESULT_OK) {
            pending?.success(null)
            return
        }

        if (requestCode == REQ_PICK_TREE) {
            val uri = data?.data
            if (uri != null) WhatsAppDocuments.persistTree(this, uri)
            pending?.success(WhatsAppDocuments.listAll(this))
            return
        }

        val uri = data?.data
        if (uri == null) {
            pending?.success(null)
            return
        }
        val name = WhatsAppDocuments.queryDisplayName(this, uri) ?: "sinif_listesi"
        val path = WhatsAppDocuments.copyUriToCache(this, uri, name)
        pending?.success(path)
    }

    private fun captureShare(intent: Intent?) {
        if (intent == null) return
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_SEND -> extraStream(intent)
            Intent.ACTION_VIEW -> intent.data
            else -> null
        }
        if (uri == null) return
        val name = WhatsAppDocuments.queryDisplayName(this, uri) ?: "sinif_listesi"
        val path = WhatsAppDocuments.copyUriToCache(this, uri, name) ?: return
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

    companion object {
        private const val REQ_PICK_DOC = 7711
        private const val REQ_PICK_TREE = 7712
    }
}
