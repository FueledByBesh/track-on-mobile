package com.trackon.trackon_android

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private lateinit var healthChannel: HealthConnectChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        healthChannel = HealthConnectChannel(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.trackon/health")
            .setMethodCallHandler { call, result ->
                healthChannel.handle(call, result)
            }
    }
}
