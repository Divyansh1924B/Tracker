package com.example.family_tracker

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.family_tracker/tracking"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val deviceName = call.argument<String>("deviceName")
                    val jwtToken = call.argument<String>("jwtToken")
                    val apiBaseUrl = call.argument<String>("apiBaseUrl")

                    // Automatically request Notification Permission on Android 13 (Tiramisu) and above
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                101
                            )
                        }
                    }

                    val intent = Intent(this, TrackingForegroundService::class.java).apply {
                        putExtra("deviceName", deviceName)
                        putExtra("jwtToken", jwtToken)
                        putExtra("apiBaseUrl", apiBaseUrl)
                    }

                    try {
                        ContextCompat.startForegroundService(this, intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_START_FAILED", e.message, null)
                    }
                }
                "stopService" -> {
                    val intent = Intent(this, TrackingForegroundService::class.java)
                    val stopped = stopService(intent)
                    result.success(stopped)
                }
                "isServiceRunning" -> {
                    result.success(TrackingForegroundService.isServiceRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
