package com.zakoflare.uptime_kuma_app

import android.Manifest
import android.app.ActivityManager
import android.content.ComponentName
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

/**
 * Native side of three features:
 *
 *  * launcher icon switching via `activity-alias` components,
 *  * publishing a user-supplied alert tone so the notification channel can
 *    read it (app-private files are invisible to `system_server`),
 *  * pinning a custom bitmap icon as a home-screen shortcut, which is the only
 *    way to get a user image onto the launcher without rebuilding the APK.
 */
class MainActivity : FlutterActivity() {

    private val iconChannel = "com.zakoflare.uptimekuma/icon"
    private val mediaChannel = "com.zakoflare.uptimekuma/media"
    private val appChannel = "com.zakoflare.uptimekuma/app"
    private val linkChannelName = "com.zakoflare.uptimekuma/links"
    private val serviceChannelName = "com.zakoflare.uptimekuma/service"

    /// Held so `onNewIntent` can push a link into the running Flutter engine.
    private var linkChannel: MethodChannel? = null
    private var pendingLink: String? = null

    private companion object {
        const val REQ_SOUND = 0x5CE1
    }

    private val aliases = linkedMapOf(
        "default" to "IconDefault",
        "emerald" to "IconEmerald",
        "midnight" to "IconMidnight",
        "crimson" to "IconCrimson",
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, iconChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getIcon" -> result.success(currentVariant())
                    "setIcon" -> {
                        val variant = call.argument<String>("variant") ?: "default"
                        result.success(applyVariant(variant))
                    }
                    "pinIcon" -> {
                        val path = call.argument<String>("path")
                        result.success(if (path == null) false else pinIcon(path))
                    }
                    "setTaskIcon" -> {
                        val path = call.argument<String>("path")
                        result.success(if (path == null) false else applyTaskIcon(path))
                    }
                    "clearTaskIcon" -> {
                        clearTaskIcon()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "publishSound" -> {
                        val path = call.argument<String>("path")
                        val name = call.argument<String>("name") ?: "UptimeKumaAlert"
                        if (path == null) {
                            result.success(null)
                        } else {
                            publishSoundFlow(path, name, result)
                        }
                    }
                    "recoverSound" -> {
                        val uri = call.argument<String>("uri")
                        result.success(if (uri == null) null else recoverSound(uri))
                    }
                    "deleteSound" -> {
                        val uri = call.argument<String>("uri")
                        if (uri != null) {
                            try {
                                contentResolver.delete(Uri.parse(uri), null, null)
                            } catch (_: Exception) {
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, appChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "apkSigningHash" -> result.success(signingHash())
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, serviceChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        MonitorForegroundService.start(
                            this,
                            call.argument<String>("title") ?: "UptimeKumaAPP",
                            call.argument<String>("body") ?: "",
                        )
                        result.success(true)
                    }
                    "stop" -> {
                        MonitorForegroundService.stop(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Deep links: a shared `uptimekuma://…` string opened from a browser or
        // a chat app lands here.
        linkChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, linkChannelName)
            .also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getInitialLink" -> {
                            result.success(pendingLink ?: coldStartLink())
                            pendingLink = null
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    private fun coldStartLink(): String? {
        val data = intent?.data?.toString() ?: return null
        return if (data.startsWith("uptimekuma://")) data else null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val data = intent.data?.toString() ?: return
        if (!data.startsWith("uptimekuma://")) return
        val channel = linkChannel
        if (channel == null) {
            pendingLink = data
        } else {
            channel.invokeMethod("onLink", data)
        }
    }

    // --- icons -------------------------------------------------------------

    private fun componentFor(alias: String) = ComponentName(this, "$packageName.$alias")

    private fun isEnabled(alias: String): Boolean {
        val state = packageManager.getComponentEnabledSetting(componentFor(alias))
        if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) return true
        if (state == PackageManager.COMPONENT_ENABLED_STATE_DISABLED) return false
        // COMPONENT_ENABLED_STATE_DEFAULT: fall back to the manifest declaration.
        return alias == "IconDefault"
    }

    private fun currentVariant(): String {
        for ((variant, alias) in aliases) {
            if (isEnabled(alias)) return variant
        }
        return "default"
    }

    private fun applyVariant(variant: String): Boolean {
        val target = aliases[variant] ?: return false
        return try {
            for ((_, alias) in aliases) {
                val state = if (alias == target) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                }
                packageManager.setComponentEnabledSetting(
                    componentFor(alias),
                    state,
                    PackageManager.DONT_KILL_APP,
                )
            }
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Pins a shortcut whose icon is the user's image. */
    private fun pinIcon(path: String): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return try {
            val manager = getSystemService(ShortcutManager::class.java) ?: return false
            if (!manager.isRequestPinShortcutSupported) return false

            val bitmap = decodeSquare(path) ?: return false
            val shortcutId = "uk_custom_icon"
            // Point the shortcut at whichever launcher alias is currently
            // enabled, otherwise tapping it can resolve to nothing.
            val target = currentLaunchComponent()
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                component = target
            }
            val shortcut = ShortcutInfo.Builder(this, shortcutId)
                .setShortLabel(getString(R.string.app_name))
                .setLongLabel(getString(R.string.app_name))
                .setActivity(target)
                .setIcon(Icon.createWithBitmap(bitmap))
                .setIntent(intent)
                .build()

            // Refresh an existing shortcut so repeated applies update in place.
            if (manager.pinnedShortcuts.any { it.id == shortcutId }) {
                manager.updateShortcuts(listOf(shortcut))
                return true
            }
            manager.requestPinShortcut(shortcut, null)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Android has no API to replace the launcher icon of an installed package,
     * but the recents card is a plain bitmap we can swap at runtime. Doing it
     * means a user-supplied icon is at least visible somewhere system-drawn,
     * not just inside the app.
     */
    private fun applyTaskIcon(path: String): Boolean {
        val bitmap = decodeSquare(path) ?: return false
        return try {
            // The (label, bitmap) constructor still works everywhere; the
            // Builder variant only accepts a drawable resource id.
            @Suppress("DEPRECATION")
            val description =
                ActivityManager.TaskDescription(getString(R.string.app_name), bitmap)
            setTaskDescription(description)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** Drops the custom recents-card icon again. */
    private fun clearTaskIcon(): Boolean = try {
        @Suppress("DEPRECATION")
        setTaskDescription(ActivityManager.TaskDescription(getString(R.string.app_name)))
        true
    } catch (e: Exception) {
        false
    }

    /** The activity-alias the launcher currently shows. */
    private fun currentLaunchComponent(): ComponentName {
        for ((_, alias) in aliases) {
            if (isEnabled(alias)) return componentFor(alias)
        }
        return componentFor("IconDefault")
    }

    private fun decodeSquare(path: String): Bitmap? {
        val raw = BitmapFactory.decodeFile(path) ?: return null
        val side = minOf(raw.width, raw.height)
        val cropped = Bitmap.createBitmap(
            raw,
            (raw.width - side) / 2,
            (raw.height - side) / 2,
            side,
            side,
        )
        val out = Bitmap.createBitmap(432, 432, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawBitmap(
            cropped,
            null,
            android.graphics.Rect(0, 0, 432, 432),
            android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG),
        )
        return out
    }

    // --- sounds ------------------------------------------------------------

    private var soundResult: MethodChannel.Result? = null
    private var soundSource: String? = null
    private var soundDisplayName: String? = null

    /**
     * On Android 9 and below the shared media store is off limits without
     * `WRITE_EXTERNAL_STORAGE`, so ask for it first and answer the original
     * channel call once the dialog is dismissed.
     */
    /**
     * Copies a previously published tone back out of the media store.
     *
     * Older builds only stored the `content://` URI and lost the private copy,
     * which left previews with nothing to play (MediaPlayer cannot open a
     * media-store URI through audioplayers). This restores a real file.
     */
    private fun recoverSound(uriString: String): String? {
        return try {
            val uri = Uri.parse(uriString)
            val dir = File(filesDir, "sounds").apply { mkdirs() }
            val target = File(dir, "recovered_${System.currentTimeMillis()}.wav")
            contentResolver.openInputStream(uri)?.use { input ->
                target.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            if (target.length() > 0) target.absolutePath else null
        } catch (e: Exception) {
            null
        }
    }

    private fun publishSoundFlow(path: String, displayName: String, result: MethodChannel.Result) {
        val needsPermission = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
            PackageManager.PERMISSION_GRANTED
        if (!needsPermission) {
            result.success(publishSound(path, displayName))
            return
        }
        soundResult = result
        soundSource = path
        soundDisplayName = displayName
        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), REQ_SOUND)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_SOUND) return
        val pending = soundResult ?: return
        soundResult = null
        val path = soundSource
        val name = soundDisplayName ?: "UptimeKumaAlert"
        soundSource = null
        soundDisplayName = null
        if (path == null) {
            pending.success(null)
            return
        }
        val granted =
            grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending.success(if (granted) publishSound(path, name) else null)
    }

    /**
     * Copies [path] into the shared notification sounds collection and returns
     * the resulting `content://` URI, which the system can read when it plays
     * the channel sound.
     */
    private fun publishSound(path: String, displayName: String): String? {
        val source = File(path)
        if (!source.exists()) return null
        val mime = when (source.extension.lowercase()) {
            "mp3" -> "audio/mpeg"
            "ogg" -> "audio/ogg"
            "m4a" -> "audio/mp4"
            "aac" -> "audio/aac"
            "flac" -> "audio/flac"
            else -> "audio/wav"
        }
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
                put(MediaStore.Audio.Media.MIME_TYPE, mime)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
                put(MediaStore.Audio.Media.IS_RINGTONE, 0)
                put(MediaStore.Audio.Media.IS_ALARM, 0)
                put(MediaStore.Audio.Media.IS_MUSIC, 0)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Audio.Media.RELATIVE_PATH, "Notifications")
                }
            }
            val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            }
            val uri = contentResolver.insert(collection, values) ?: return null
            contentResolver.openOutputStream(uri)?.use { out ->
                source.inputStream().use { input -> input.copyTo(out) }
            } ?: return null
            uri.toString()
        } catch (e: Exception) {
            null
        }
    }

    // --- about -------------------------------------------------------------

    /** SHA-256 of the APK signing certificate. */
    private fun signingHash(): String? {
        return try {
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                packageManager.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES,
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
            }
            val signature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.signingInfo?.apkContentsSigners?.firstOrNull()
            } else {
                @Suppress("DEPRECATION")
                info.signatures?.firstOrNull()
            } ?: return null
            val digest = MessageDigest.getInstance("SHA-256")
            digest.update(signature.toByteArray())
            digest.digest().joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        }
    }
}
