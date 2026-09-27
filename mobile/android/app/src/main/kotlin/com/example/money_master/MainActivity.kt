package com.example.money_master

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth (biometric app lock) requires a FragmentActivity host on Android.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Keep balances out of the recent-apps preview. Unlike FLAG_SECURE,
        // this still lets the user take screenshots of the app. Android 13+.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }
}
