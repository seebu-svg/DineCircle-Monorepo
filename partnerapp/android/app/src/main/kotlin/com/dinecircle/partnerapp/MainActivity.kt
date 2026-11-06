package com.dinecircle.partnerapp

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.ceil
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    private val saveRequest = 7301

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.dinecircle.partnerapp/qr_studio").setMethodCallHandler { call, result ->
            if (call.method != "export") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pending != null) {
                result.error("busy", "An export is already open.", null)
                return@setMethodCallHandler
            }
            val png = call.argument<ByteArray>("png")
            if (png == null || png.isEmpty() || png.size > 32 * 1024 * 1024) {
                result.error("invalid", "Invalid card image.", null)
                return@setMethodCallHandler
            }
            val pdf = call.argument<Boolean>("pdf") == true
            val share = call.argument<Boolean>("share") == true
            val stem = (call.argument<String>("filename") ?: "dinecircle-qr")
                .replace(Regex("[^a-zA-Z0-9_-]"), "").take(100)
            val name = "$stem.${if (pdf) "pdf" else "png"}"
            val mime = if (pdf) "application/pdf" else "image/png"
            pending = result
            worker.execute {
                try {
                    val bytes = if (pdf) makePdf(png) else png
                    runOnUiThread {
                        if (isDestroyed) return@runOnUiThread
                        try {
                            if (share) {
                                val directory = File(cacheDir, "qr_studio").apply { mkdirs() }
                                directory.listFiles()?.filter {
                                    System.currentTimeMillis() - it.lastModified() > 86400000
                                }?.forEach { it.delete() }
                                val file = File(directory, "${System.currentTimeMillis()}-$name")
                                file.writeBytes(bytes)
                                val uri = FileProvider.getUriForFile(this,
                                    "$packageName.qr_studio", file)
                                val intent = Intent(Intent.ACTION_SEND).apply {
                                    type = mime
                                    putExtra(Intent.EXTRA_STREAM, uri)
                                    clipData = ClipData.newRawUri(name, uri)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }
                                startActivity(Intent.createChooser(intent, "Share QR card"))
                                finishExport("shared")
                            } else {
                                pendingBytes = bytes
                                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                    addCategory(Intent.CATEGORY_OPENABLE)
                                    type = mime
                                    putExtra(Intent.EXTRA_TITLE, name)
                                }, saveRequest)
                            }
                        } catch (error: Exception) { failExport(error) }
                    }
                } catch (error: Exception) { runOnUiThread { failExport(error) } }
            }
        }
    }

    // A 105mm card, 5mm white margins, at least A6 height. Taller accessible
    // layouts extend the page instead of shrinking the QR's physical size.
    private fun makePdf(png: ByteArray): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(png, 0, png.size)
            ?: throw IllegalArgumentException("Could not decode card image.")
        try {
            val mm = 72f / 25.4f
            val width = ceil(105 * mm).toInt()
            val margin = 5 * mm
            val contentWidth = width - 2 * margin
            val contentHeight = contentWidth * bitmap.height / bitmap.width
            val height = ceil(max(148 * mm, contentHeight + 2 * margin)).toInt()
            val document = PdfDocument()
            try {
                val page = document.startPage(PdfDocument.PageInfo.Builder(width, height, 1).create())
                page.canvas.drawColor(Color.WHITE)
                page.canvas.drawBitmap(bitmap, null,
                    RectF(margin, margin, margin + contentWidth, margin + contentHeight),
                    Paint().apply { isFilterBitmap = false })
                document.finishPage(page)
                return ByteArrayOutputStream().use { output ->
                    document.writeTo(output)
                    output.toByteArray()
                }
            } finally { document.close() }
        } finally { bitmap.recycle() }
    }

    @Deprecated("Activity result callback retained for FlutterActivity interoperability")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveRequest || pending == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finishExport(null)
            return
        }
        val bytes = pendingBytes ?: run {
            failExport(IllegalStateException("Card export was interrupted."))
            return
        }
        worker.execute {
            try {
                contentResolver.openOutputStream(uri, "w")?.use { it.write(bytes) }
                    ?: throw IllegalStateException("Could not open the selected destination.")
                runOnUiThread { finishExport("saved") }
            } catch (error: Exception) { runOnUiThread { failExport(error) } }
        }
    }

    private fun finishExport(outcome: String?) {
        val result = pending
        pending = null
        pendingBytes = null
        result?.success(outcome)
    }

    private fun failExport(error: Exception) {
        val result = pending
        pending = null
        pendingBytes = null
        result?.error("export_failed", error.localizedMessage, null)
    }

    override fun onDestroy() {
        if (pending != null) failExport(IllegalStateException("Card export was interrupted."))
        worker.shutdown()
        super.onDestroy()
    }
}
