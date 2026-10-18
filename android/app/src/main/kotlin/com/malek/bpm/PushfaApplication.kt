package com.malek.bpm

import android.app.Application
import com.pushfa.sdk.Pushfa
import com.pushfa.sdk.PushfaConfig

/**
 * فازِ ۰ (Push) — راه‌اندازیِ SDKِ پوشفا، همان‌جایی که مستنداتِ خودشان
 * توصیه می‌کنند (Application.onCreate، نه MainActivity).
 */
class PushfaApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        Pushfa.initialize(
            this,
            PushfaConfig(
                apiPublicKey = "b6rw8amzhqWhfB9HxqYsMRxsJd",
                smallIconResId = R.mipmap.ic_launcher,
                notificationChannelId = "malekbpm_notifications",
                notificationChannelName = "اعلان‌های ملک BPM"
            )
        ) { }
    }
}
