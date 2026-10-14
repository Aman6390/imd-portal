package com.example.imd_portal

import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.imd.portal/pdf_renderer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "renderFirstPage") {
                val pdfPath = call.argument<String>("pdfPath")
                if (pdfPath == null) {
                    result.error("INVALID_PATH", "PDF path cannot be null", null)
                    return@setMethodCallHandler
                }
                try {
                    val pdfFile = File(pdfPath)
                    if (!pdfFile.exists() || pdfFile.length() == 0L) {
                        result.error("FILE_NOT_FOUND", "PDF file does not exist or is empty", null)
                        return@setMethodCallHandler
                    }
                    val fileDescriptor = ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY)
                    val renderer = PdfRenderer(fileDescriptor)
                    if (renderer.pageCount > 0) {
                        val page = renderer.openPage(0)
                        val width = page.width * 2
                        val height = page.height * 2
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        bitmap.eraseColor(android.graphics.Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        page.close()
                        renderer.close()
                        fileDescriptor.close()

                        val outputFile = File(cacheDir, "ocr_page_0.jpg")
                        val fos = FileOutputStream(outputFile)
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 92, fos)
                        fos.flush()
                        fos.close()
                        result.success(outputFile.absolutePath)
                    } else {
                        renderer.close()
                        fileDescriptor.close()
                        result.error("EMPTY_PDF", "PDF contains no pages", null)
                    }
                } catch (e: Exception) {
                    result.error("RENDER_ERROR", e.localizedMessage ?: "Unknown rendering error", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
