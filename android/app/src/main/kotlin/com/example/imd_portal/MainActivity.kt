package com.example.imd_portal

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: FlutterFragmentActivity() {
    private val PDF_CHANNEL = "com.imd.portal/pdf_renderer"
    private val INSTALL_CHANNEL = "com.imd.portal/installer"
    private val INSTALL_REQUEST_CODE = 8899

    private var pendingApkPath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // PDF First-page rendering channel for Devanagari OCR
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PDF_CHANNEL).setMethodCallHandler { call, result ->
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

        // Native Android APK Installer Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "installApk") {
                val apkPath = call.argument<String>("apkPath")
                if (apkPath == null) {
                    result.error("INVALID_PATH", "APK path cannot be null", null)
                    return@setMethodCallHandler
                }

                try {
                    val apkFile = File(apkPath)
                    if (!apkFile.exists() || apkFile.length() == 0L) {
                        result.error("FILE_NOT_FOUND", "APK file does not exist", null)
                        return@setMethodCallHandler
                    }

                    // On Android 8.0+ (Oreo), check if app is permitted to install unknown apps
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (!packageManager.canRequestPackageInstalls()) {
                            pendingApkPath = apkPath
                            val permIntent = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivityForResult(permIntent, INSTALL_REQUEST_CODE)
                            result.success("PERMISSION_REQUESTED")
                            return@setMethodCallHandler
                        }
                    }

                    // Launch package installer
                    triggerInstallIntent(apkFile)
                    result.success("SUCCESS")
                } catch (e: Exception) {
                    result.error("INSTALL_ERROR", e.localizedMessage ?: "Unknown installation error", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun triggerInstallIntent(apkFile: File) {
        apkFile.setReadable(true, false)
        val contentUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile
        )

        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(contentUri, "application/vnd.android.package-archive")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        startActivity(installIntent)
    }

    override fun onResume() {
        super.onResume()
        // If returning from settings after granting permission, auto-launch the installer
        checkAndResumePendingInstall()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == INSTALL_REQUEST_CODE) {
            checkAndResumePendingInstall()
        }
    }

    private fun checkAndResumePendingInstall() {
        val path = pendingApkPath ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (packageManager.canRequestPackageInstalls()) {
                pendingApkPath = null
                val file = File(path)
                if (file.exists() && file.length() > 0L) {
                    try {
                        triggerInstallIntent(file)
                    } catch (_: Exception) {
                        // User can retry via install button
                    }
                }
            }
        }
    }
}
