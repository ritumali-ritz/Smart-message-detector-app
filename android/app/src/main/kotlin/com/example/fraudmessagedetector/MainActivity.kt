package com.example.fraudmessagedetector

import android.content.Intent
import android.os.Bundle
import android.os.Build
import android.app.role.RoleManager
import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.fraudmessagedetector/share"
    private var sharedText: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Check if started with text selection
        if (intent.action == Intent.ACTION_PROCESS_TEXT) {
            sharedText = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT)?.toString()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedText" -> {
                    result.success(sharedText)
                    sharedText = null
                }
                "setDefaultSmsApp" -> {
                    val packageName = context.packageName
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val roleManager = getSystemService(RoleManager::class.java)
                        if (roleManager != null && roleManager.isRoleAvailable(RoleManager.ROLE_SMS)) {
                            if (!roleManager.isRoleHeld(RoleManager.ROLE_SMS)) {
                                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                                startActivityForResult(intent, 1001)
                                result.success(true)
                            } else {
                                // Already default
                                result.success(false)
                            }
                        } else {
                            result.error("ROLE_UNAVAILABLE", "SMS role is not available", null)
                        }
                    } else {
                        // Older versions
                        if (Telephony.Sms.getDefaultSmsPackage(context) != packageName) {
                            val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                            intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, packageName)
                            startActivity(intent)
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                }
                "openDefaultAppsSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        val intent = Intent(android.provider.Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error("NOT_SUPPORTED", "Not supported on this version", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
