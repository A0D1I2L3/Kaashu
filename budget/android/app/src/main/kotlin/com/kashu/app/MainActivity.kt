package com.kashu.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterFragmentActivity() {
    private var pendingSharedUpiImagePath: String? = null
    private var upiMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        upiMethodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingSharedUpiImage" -> {
                    val path = pendingSharedUpiImagePath
                    pendingSharedUpiImagePath = null
                    result.success(path)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // A new image was shared while the app was already running. Store it
        // and poke Flutter so it scans immediately instead of waiting for the
        // app to resume.
        if (handleShareIntent(intent)) {
            upiMethodChannel?.invokeMethod("onUpiImageShared", null)
        }
    }

    private fun handleShareIntent(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_SEND) return false
        val type = intent.type ?: return false
        if (!type.startsWith("image/")) return false
        val uri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } catch (e: Exception) {
                null
            } ?: intent.getStringExtra(Intent.EXTRA_STREAM)?.let { Uri.parse(it) }
                ?: intent.clipData?.getItemAt(0)?.uri
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                ?: intent.getStringExtra(Intent.EXTRA_STREAM)?.let { Uri.parse(it) }
                ?: intent.clipData?.getItemAt(0)?.uri
        }
        if (uri == null) return false
        val path = copyUriToCache(uri) ?: return false
        pendingSharedUpiImagePath = path
        return true
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            val file = File(
                cacheDir,
                "shared_upi_screenshot_${System.currentTimeMillis()}.png",
            )
            FileOutputStream(file).use { output ->
                inputStream.use { input -> input.copyTo(output) }
            }
            file.absolutePath
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    companion object {
        private const val CHANNEL_NAME = "kashu.upi"
    }
}
