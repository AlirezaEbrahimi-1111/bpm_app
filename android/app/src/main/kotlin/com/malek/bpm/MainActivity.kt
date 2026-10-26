package com.malek.bpm

import android.content.Intent
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
    }

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
