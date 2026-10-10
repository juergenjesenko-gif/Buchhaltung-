package at.jesenko.buchhaltung

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Ordner für die automatische Sicherung über das Storage Access Framework
 * (Lastenheft L-7.2, L-7.8). Die Nutzerin wählt den Ordner einmal; die
 * Berechtigung wird dauerhaft übernommen. Kein Google-Konto, kein OAuth – die
 * App schreibt nur in den gewählten Ordner, den Upload übernimmt der
 * Dokumentanbieter (z. B. Google Drive, falls er Ordner anbietet).
 */
class BackupFolderChannel(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "buchhaltung/backup_folder")
    private val io = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "pickFile" -> pickFile(result)
            else -> io.execute {
                try {
                    val tree = Uri.parse(call.argument<String>("folder")!!)
                    val value: Any? = when (call.method) {
                        "isAvailable" -> isAvailable(tree)
                        "list" -> children(tree).keys.toList()
                        "write" -> write(tree, call.argument("name")!!, call.argument("bytes")!!)
                        "read" -> read(tree, call.argument("name")!!)
                        "delete" -> delete(tree, call.argument("name")!!)
                        else -> {
                            activity.runOnUiThread { result.notImplemented() }
                            return@execute
                        }
                    }
                    activity.runOnUiThread { result.success(value) }
                } catch (e: Exception) {
                    activity.runOnUiThread { result.error("IO", e.message, null) }
                }
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("BUSY", "Auswahl läuft bereits", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).addFlags(
            Intent.FLAG_GRANT_READ_URI_PERMISSION or
                Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
        )
        activity.startActivityForResult(intent, REQUEST_CODE)
    }

    /** Eine Datei wählen und ihren Inhalt liefern (Wiederherstellung). */
    private fun pickFile(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("BUSY", "Auswahl läuft bereits", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType("*/*")
        activity.startActivityForResult(intent, REQUEST_FILE)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == REQUEST_FILE) {
            val result = pending ?: return true
            pending = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(null)
                return true
            }
            io.execute {
                try {
                    val bytes = activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    activity.runOnUiThread { result.success(bytes) }
                } catch (e: Exception) {
                    activity.runOnUiThread { result.error("IO", e.message, null) }
                }
            }
            return true
        }
        if (requestCode != REQUEST_CODE) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        activity.contentResolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        result.success(mapOf("folder" to uri.toString(), "label" to (uri.lastPathSegment ?: "")))
        return true
    }

    private fun isAvailable(tree: Uri): Boolean {
        val granted = activity.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }
        if (!granted) return false
        return try {
            children(tree)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Name → Dokument-URI der Dateien im Ordner. */
    private fun children(tree: Uri): Map<String, Uri> {
        val parentId = DocumentsContract.getTreeDocumentId(tree)
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val out = mutableMapOf<String, Uri>()
        activity.contentResolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null, null, null,
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getString(0)
                val name = cursor.getString(1)
                out[name] = DocumentsContract.buildDocumentUriUsingTree(tree, id)
            }
        } ?: throw IllegalStateException("Ordner nicht lesbar")
        return out
    }

    private fun write(tree: Uri, name: String, bytes: ByteArray): Boolean {
        val existing = children(tree)[name]
        val target = existing ?: run {
            val parent = DocumentsContract.buildDocumentUriUsingTree(
                tree, DocumentsContract.getTreeDocumentId(tree),
            )
            DocumentsContract.createDocument(
                activity.contentResolver, parent, "application/octet-stream", name,
            ) ?: throw IllegalStateException("Datei konnte nicht angelegt werden")
        }
        activity.contentResolver.openOutputStream(target, "wt")?.use { it.write(bytes) }
            ?: throw IllegalStateException("Datei nicht beschreibbar")
        return true
    }

    private fun read(tree: Uri, name: String): ByteArray {
        val uri = children(tree)[name] ?: throw IllegalStateException("Datei fehlt: $name")
        return activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
            ?: throw IllegalStateException("Datei nicht lesbar")
    }

    private fun delete(tree: Uri, name: String): Boolean {
        val uri = children(tree)[name] ?: return true
        return DocumentsContract.deleteDocument(activity.contentResolver, uri)
    }

    companion object {
        private const val REQUEST_CODE = 4711
        private const val REQUEST_FILE = 4712
    }
}
