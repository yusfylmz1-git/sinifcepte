package com.sinifcepte.sinifcepte

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import java.io.File
import java.io.FileOutputStream

/// WhatsApp sınıf listesi PDF'leri Android "Son dosyalar"da görünmez.
/// Bu yardımcı, Belgeler klasörünü doğrudan açar ve okunabilen kopyaları listeler.
object WhatsAppDocuments {
    const val PREFS = "sinifcepte_share"
    const val KEY_TREE = "whatsapp_tree_uri"

    private val documentIds = listOf(
        "primary:Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents",
        "primary:Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Documents",
        "primary:WhatsApp/Media/WhatsApp Documents",
        "primary:Download",
    )

    fun supportedName(name: String): Boolean {
        val n = name.lowercase()
        return n.endsWith(".pdf") || n.endsWith(".xlsx") || n.endsWith(".xls")
    }

    fun initialUri(): Uri {
        for (id in documentIds) {
            val path = documentIdToPath(id) ?: continue
            if (File(path).exists()) {
                return DocumentsContract.buildDocumentUri(
                    "com.android.externalstorage.documents",
                    id,
                )
            }
        }
        return DocumentsContract.buildDocumentUri(
            "com.android.externalstorage.documents",
            documentIds.first(),
        )
    }

    fun openDocumentIntent(): Intent {
        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/pdf",
                    "application/vnd.ms-excel",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    "application/octet-stream",
                ),
            )
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri())
            }
        }
    }

    fun openTreeIntent(): Intent {
        return Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, initialUri())
            }
        }
    }

    fun persistTree(context: Context, uri: Uri) {
        try {
            context.contentResolver.takePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TREE, uri.toString())
            .apply()
    }

    fun hasTreeGrant(context: Context): Boolean {
        val stored = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TREE, null)
        return !stored.isNullOrBlank()
    }

    fun listAll(context: Context): List<Map<String, Any?>> {
        val out = LinkedHashMap<String, Map<String, Any?>>()

        fun add(name: String, path: String, modified: Long, source: String, size: Long) {
            if (!supportedName(name)) return
            val key = "$name|$size"
            val prev = out[key]
            if (prev == null || (prev["modified"] as Long) < modified) {
                out[key] = mapOf(
                    "name" to name,
                    "path" to path,
                    "modified" to modified,
                    "source" to source,
                    "size" to size,
                )
            }
        }

        val tree = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TREE, null)
        if (!tree.isNullOrBlank()) {
            try {
                listTree(context, Uri.parse(tree)).forEach { item ->
                    add(
                        item["name"] as String,
                        item["path"] as String,
                        item["modified"] as Long,
                        "whatsapp",
                        item["size"] as Long,
                    )
                }
            } catch (_: Exception) {
            }
        }

        for (dir in candidateDirs()) {
            val files = dir.listFiles() ?: continue
            val source = if (dir.absolutePath.contains("WhatsApp", ignoreCase = true)) {
                "whatsapp"
            } else {
                "download"
            }
            for (file in files) {
                if (!file.isFile) continue
                add(file.name, file.absolutePath, file.lastModified(), source, file.length())
            }
        }

        context.cacheDir.listFiles()?.forEach { file ->
            if (!file.isFile) return@forEach
            if (!file.name.startsWith("incoming_share_")) return@forEach
            val display = file.name.removePrefix("incoming_share_")
            add(display, file.absolutePath, file.lastModified(), "shared", file.length())
        }

        return out.values.sortedWith(
            compareBy<Map<String, Any?>> { if (it["source"] == "whatsapp") 0 else 1 }
                .thenByDescending { it["modified"] as Long },
        ).take(50)
    }

    fun copyUriToCache(context: Context, uri: Uri, displayName: String): String? {
        return try {
            val safe = displayName.replace(Regex("[^A-Za-z0-9._-]"), "_")
            val dest = File(context.cacheDir, "incoming_share_$safe")
            context.contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(dest).use { output -> input.copyTo(output) }
            } ?: return null
            if (dest.length() == 0L) return null
            dest.absolutePath
        } catch (_: Exception) {
            null
        }
    }

    fun queryDisplayName(context: Context, uri: Uri): String? {
        val cursor = context.contentResolver.query(
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

    private fun listTree(context: Context, treeUri: Uri): List<Map<String, Any?>> {
        val treeId = DocumentsContract.getTreeDocumentId(treeUri)
        val children = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, treeId)
        val items = mutableListOf<Map<String, Any?>>()
        val cursor = context.contentResolver.query(
            children,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                DocumentsContract.Document.COLUMN_SIZE,
            ),
            null,
            null,
            null,
        ) ?: return items
        cursor.use {
            val idIdx = it.getColumnIndex(DocumentsContract.Document.COLUMN_DOCUMENT_ID)
            val nameIdx = it.getColumnIndex(DocumentsContract.Document.COLUMN_DISPLAY_NAME)
            val modIdx = it.getColumnIndex(DocumentsContract.Document.COLUMN_LAST_MODIFIED)
            val sizeIdx = it.getColumnIndex(DocumentsContract.Document.COLUMN_SIZE)
            while (it.moveToNext()) {
                val name = if (nameIdx >= 0) it.getString(nameIdx) ?: continue else continue
                if (!supportedName(name)) continue
                val docId = if (idIdx >= 0) it.getString(idIdx) ?: continue else continue
                val docUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, docId)
                val path = copyUriToCache(context, docUri, name) ?: continue
                val modified = if (modIdx >= 0) it.getLong(modIdx) else 0L
                val size = if (sizeIdx >= 0) it.getLong(sizeIdx) else 0L
                items.add(
                    mapOf(
                        "name" to name,
                        "path" to path,
                        "modified" to modified,
                        "size" to size,
                    ),
                )
            }
        }
        return items
    }

    private fun candidateDirs(): List<File> {
        val root = Environment.getExternalStorageDirectory()
        return listOf(
            File(root, "Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents"),
            File(root, "Android/media/com.whatsapp.w4b/WhatsApp Business/Media/WhatsApp Business Documents"),
            File(root, "WhatsApp/Media/WhatsApp Documents"),
            File(root, "Download"),
            File(root, "Downloads"),
        )
    }

    private fun documentIdToPath(id: String): String? {
        if (!id.startsWith("primary:")) return null
        return File(Environment.getExternalStorageDirectory(), id.removePrefix("primary:")).absolutePath
    }
}
