package com.malek.bpm

import android.content.Intent
import android.os.Bundle
import com.pushfa.sdk.Pushfa
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * فازِ ۰ (Push) — پلِ MethodChannel بینِ دارت و SDKِ نیتیوِ پوشفا، چون
 * این سرویس SDK فلاترِ رسمی ندارد.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "ir.itmalek.bpm/pushfa"
    private var channel: MethodChannel? = null
    private var pendingDeepLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel = ch

        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSubscriberId" -> result.success(Pushfa.getSubscriberId())
                "addAlias" -> {
                    val label = call.argument<String>("label") ?: ""
                    val value = call.argument<String>("value") ?: ""
                    Pushfa.addAlias(label, value) { }
                    result.success(null)
                }
                "removeAlias" -> {
                    val label = call.argument<String>("label") ?: ""
                    Pushfa.removeAlias(label) { }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // 🔧 اگر همین کلیک روی نوتیف باعثِ باز شدنِ اپ شده (نه فقط
        // رفتن به پیش‌زمینه)، دیپ‌لینکِ آن را همین الان به دارت می‌دهیم
        pendingDeepLink?.let {
            ch.invokeMethod("onDeepLink", it)
            pendingDeepLink = null
        }
    }

    // 🔧 رفعِ باگ: بدونِ ثبتِ موفق، SDK فقط یک «پروفایل» می‌سازد ولی هرگز
    // به «مشترکِ Push» واقعی تبدیل نمی‌شود (توکنِ FCM ثبت نمی‌شود) —
    // یعنی addAlias روی کاربری اجرا می‌شود که اصلاً عضوِ هیچ کانالِ
    // Push ای نیست، و سرور با CUSTOM_ALIAS_NOT_FOUND رد می‌کند.
    private var pushRegistered = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
        if (!Pushfa.areNotificationsEnabled(this)) {
            Pushfa.requestNotificationPermission(this)
        }
    }

    // 🔧 به‌جایِ تکیه‌کردن رویِ callbackِ دقیقِ نتیجه‌یِ مجوز (که ممکن
    // است SDK از APIِ جدیدترِ اندروید استفاده کند و این Activity هرگز
    // callback را نگیرد)، هر بار اپ به‌جلو می‌آید چک می‌کنیم — این
    // دقیقاً بعدِ بستنِ دیالوگِ مجوز هم (چه Allow چه Deny) اجرا می‌شود
    override fun onResume() {
        super.onResume()
        if (!pushRegistered && Pushfa.areNotificationsEnabled(this)) {
            pushRegistered = true
            Pushfa.registerForPush { }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val targetUrl = intent?.getStringExtra(Pushfa.EXTRA_TARGET_URL) ?: return
        val ch = channel
        if (ch != null) {
            ch.invokeMethod("onDeepLink", targetUrl)
        } else {
            // موتورِ فلاتر هنوز آماده نیست (اپ تازه از صفر باز شده) —
            // وقتی configureFlutterEngine اجرا شد، همین مقدار فرستاده می‌شود
            pendingDeepLink = targetUrl
        }
    }
}
