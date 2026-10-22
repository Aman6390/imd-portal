package com.example.imd_portal

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.location.Location
import android.location.LocationManager
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
    private val LOCATION_CHANNEL = "com.imd.portal/location"
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

                // Render in a background thread to prevent any UI blocking
                Thread {
                    var fileDescriptor: ParcelFileDescriptor? = null
                    var renderer: PdfRenderer? = null
                    var page: PdfRenderer.Page? = null
                    var bitmap: Bitmap? = null
                    try {
                        val pdfFile = File(pdfPath)
                        if (!pdfFile.exists() || pdfFile.length() == 0L) {
                            runOnUiThread { result.error("FILE_NOT_FOUND", "PDF file does not exist or is empty", null) }
                            return@Thread
                        }
                        fileDescriptor = ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY)
                        renderer = PdfRenderer(fileDescriptor)
                        if (renderer.pageCount > 0) {
                            page = renderer.openPage(0)

                            // Optimal dimension scaling to prevent OutOfMemoryError and maximize OCR accuracy
                            val maxDim = 1600
                            val rawW = page.width
                            val rawH = page.height
                            val scale = if (rawW > rawH) {
                                if (rawW > maxDim) maxDim.toFloat() / rawW else 1.5f
                            } else {
                                if (rawH > maxDim) maxDim.toFloat() / rawH else 1.5f
                            }
                            val targetW = (rawW * scale).toInt().coerceAtLeast(1)
                            val targetH = (rawH * scale).toInt().coerceAtLeast(1)

                            bitmap = Bitmap.createBitmap(targetW, targetH, Bitmap.Config.ARGB_8888)
                            bitmap.eraseColor(android.graphics.Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

                            val outputFile = File(cacheDir, "ocr_page_${System.currentTimeMillis()}.jpg")
                            val fos = FileOutputStream(outputFile)
                            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, fos)
                            fos.flush()
                            fos.close()

                            runOnUiThread { result.success(outputFile.absolutePath) }
                        } else {
                            runOnUiThread { result.error("EMPTY_PDF", "PDF contains no pages", null) }
                        }
                    } catch (t: Throwable) {
                        runOnUiThread { result.error("RENDER_ERROR", t.localizedMessage ?: "Unknown rendering error", null) }
                    } finally {
                        try { page?.close() } catch (_: Throwable) {}
                        try { renderer?.close() } catch (_: Throwable) {}
                        try { fileDescriptor?.close() } catch (_: Throwable) {}
                        try { bitmap?.recycle() } catch (_: Throwable) {}
                    }
                }.start()
            } else if (call.method == "openPdf") {
                val pdfPath = call.argument<String>("pdfPath")
                if (pdfPath == null) {
                    result.error("INVALID_PATH", "PDF path cannot be null", null)
                    return@setMethodCallHandler
                }
                try {
                    val pdfFile = File(pdfPath)
                    if (!pdfFile.exists() || pdfFile.length() == 0L) {
                        result.error("FILE_NOT_FOUND", "PDF file does not exist", null)
                        return@setMethodCallHandler
                    }
                    pdfFile.setReadable(true, false)
                    val contentUri = FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        pdfFile
                    )
                    val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                        setDataAndType(contentUri, "application/pdf")
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
                    }
                    startActivity(viewIntent)
                    result.success("SUCCESS")
                } catch (e: Exception) {
                    result.error("OPEN_ERROR", e.localizedMessage ?: "Could not open PDF viewer", null)
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
                            savePendingApkPath(apkPath)
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

        // Native Location Channel for device GPS / Network location
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getDeviceLocation") {
                try {
                    val hasFine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
                    val hasCoarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

                    if (!hasFine && !hasCoarse) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 7722)
                        }
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    if (locationManager == null) {
                        result.success(null)
                        return@setMethodCallHandler
                    }

                    val providers = listOf(
                        LocationManager.GPS_PROVIDER,
                        LocationManager.NETWORK_PROVIDER,
                        LocationManager.PASSIVE_PROVIDER
                    )

                    var bestLocation: Location? = null
                    for (provider in providers) {
                        try {
                            if (locationManager.isProviderEnabled(provider)) {
                                val loc = locationManager.getLastKnownLocation(provider)
                                if (loc != null && (bestLocation == null || loc.time > bestLocation.time)) {
                                    bestLocation = loc
                                }
                            }
                        } catch (_: SecurityException) {}
                    }

                    if (bestLocation != null) {
                        result.success(mapOf(
                            "latitude" to bestLocation.latitude,
                            "longitude" to bestLocation.longitude
                        ))
                    } else {
                        result.success(null)
                    }
                } catch (t: Throwable) {
                    result.success(null)
                }
            } else if (call.method == "requestLocationPermission") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    requestPermissions(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION), 7722)
                }
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun savePendingApkPath(path: String?) {
        val prefs = getSharedPreferences("imd_installer_prefs", Context.MODE_PRIVATE)
        if (path == null) {
            prefs.edit().remove("pending_apk_path").apply()
        } else {
            prefs.edit().putString("pending_apk_path", path).apply()
        }
    }

    private fun getPendingApkPath(): String? {
        val prefs = getSharedPreferences("imd_installer_prefs", Context.MODE_PRIVATE)
        return prefs.getString("pending_apk_path", null)
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
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            putExtra(Intent.EXTRA_NOT_UNKNOWN_SOURCE, true)
        }

        // Grant URI permission explicitly to all package installer handlers
        val resInfoList = packageManager.queryIntentActivities(installIntent, PackageManager.MATCH_DEFAULT_ONLY)
        for (resolveInfo in resInfoList) {
            val pkg = resolveInfo.activityInfo.packageName
            grantUriPermission(pkg, contentUri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
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
        val path = pendingApkPath ?: getPendingApkPath() ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            if (packageManager.canRequestPackageInstalls()) {
                pendingApkPath = null
                savePendingApkPath(null)
                val file = File(path)
                if (file.exists() && file.length() > 1000000L) {
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
