package com.malek.bpm

import android.app.Notification
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 🔧 باز شدنِ مستقیمِ کار با لمسِ نوتیفیکیشن: سرور پوشِ متریکس را با
 * url = "malekbpm://task/<id>" می‌فرستد؛ اندروید با این لینک همین اکتیویتی
 * را باز می‌کند و لینک از طریقِ کانالِ زیر به فلاتر داده می‌شود.
 *  - getInitialLink: لینکی که اپ با آن (از حالتِ بسته) باز شده
 *  - onLink: لینکِ جدید وقتی اپ از قبل باز بوده (onNewIntent)
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var initialLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        initialLink = linkOf(intent)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "malekbpm/deeplink").also {
            it.setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(initialLink)
                    initialLink = null
                } else {
                    result.notImplemented()
                }
            }
        }
        // پوش‌های یک کار با بازشدنِ آن از نوارِ اعلان پاک می‌شوند (notification_tray.dart)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "malekbpm/notifications")
            .setMethodCallHandler { call, result ->
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                when (call.method) {
                    "hasActive" -> result.success(manager.activeNotifications.isNotEmpty())
                    "cancelMatching" -> {
                        val items = call.arguments as? List<*> ?: emptyList<Any>()
                        val wanted = items.mapNotNull { it as? Map<*, *> }
                            .map { normalize(it["title"]) to normalize(it["message"]) }
                            .toSet()
                        for (active in manager.activeNotifications) {
                            val extras = active.notification.extras
                            val title = normalize(extras.getCharSequence(Notification.EXTRA_TITLE))
                            val text = normalize(extras.getCharSequence(Notification.EXTRA_TEXT))
                            val bigText = normalize(extras.getCharSequence(Notification.EXTRA_BIG_TEXT))
                            if ((title to text) in wanted || (title to bigText) in wanted) {
                                manager.cancel(active.tag, active.id)
                            }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun normalize(value: Any?): String =
        value?.toString()?.trim()?.replace(Regex("\\s+"), " ") ?: ""

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        linkOf(intent)?.let { channel?.invokeMethod("onLink", it) }
    }

    private fun linkOf(intent: Intent?): String? {
        val data = intent?.data ?: return null
        return if (data.scheme == "malekbpm") data.toString() else null
    }
}
