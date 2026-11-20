package ir.soundify.soundify

import android.os.Build
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// AudioServiceFragmentActivity = FragmentActivity (needed by local_auth)
// + the activity audio_service needs for background playback.
class MainActivity : AudioServiceFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ir.soundify/security")
            .setMethodCallHandler { call, result ->
                if (call.method == "check") {
                    result.success(mapOf("rooted" to isRooted(), "emulator" to isEmulator()))
                } else if (call.method == "requestNotifications") {
                    // Android 13+: the media notification needs this runtime permission.
                    if (Build.VERSION.SDK_INT >= 33) {
                        requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 1001)
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun isRooted(): Boolean {
        val tags = Build.TAGS
        if (tags != null && tags.contains("test-keys")) return true
        val paths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/system/su",
            "/system/app/Superuser.apk", "/data/local/bin/su", "/data/local/xbin/su",
            "/su/bin/su", "/system/sd/xbin/su", "/system/bin/failsafe/su",
            "/data/adb/magisk", "/sbin/.magisk"
        )
        return paths.any { File(it).exists() }
    }

    private fun isEmulator(): Boolean {
        val fp = Build.FINGERPRINT.lowercase()
        val model = Build.MODEL.lowercase()
        val hw = Build.HARDWARE.lowercase()
        return fp.startsWith("generic") || fp.contains("emulator") || fp.contains("sdk_gphone") ||
            model.contains("emulator") || model.contains("android sdk built for") ||
            Build.MANUFACTURER.lowercase().contains("genymotion") ||
            hw.contains("goldfish") || hw.contains("ranchu") ||
            Build.PRODUCT.lowercase().let { it.contains("sdk") || it.contains("emulator") }
    }
}
