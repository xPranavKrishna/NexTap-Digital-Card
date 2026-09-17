package com.nextap.nextap

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "nextap/hce"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "hasNfcHardware" ->
                        result.success(
                            packageManager.hasSystemFeature(PackageManager.FEATURE_NFC)
                        )

                    "isHceSupported" ->
                        result.success(
                            packageManager.hasSystemFeature(
                                PackageManager.FEATURE_NFC_HOST_CARD_EMULATION
                            )
                        )

                    "openNfcSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_NFC_SETTINGS))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("NO_SETTINGS", e.message, null)
                        }
                    }

                    "startHce" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrEmpty()) {
                            result.error("BAD_ARG", "url missing", null)
                        } else if (!packageManager.hasSystemFeature(
                                PackageManager.FEATURE_NFC_HOST_CARD_EMULATION
                            )
                        ) {
                            result.success(false)
                        } else {
                            NdefHostApduService.setUrl(url)
                            // While NexTap is in the foreground, ask Android to
                            // route NFC to us instead of any other wallet app.
                            try {
                                val adapter = NfcAdapter.getDefaultAdapter(this)
                                if (adapter != null) {
                                    CardEmulation.getInstance(adapter)
                                        .setPreferredService(
                                            this,
                                            ComponentName(
                                                this,
                                                NdefHostApduService::class.java
                                            )
                                        )
                                }
                            } catch (_: Exception) {
                                // not fatal - HCE still works, just not preferred
                            }
                            result.success(true)
                        }
                    }

                    "stopHce" -> {
                        NdefHostApduService.setUrl(null)
                        try {
                            val adapter = NfcAdapter.getDefaultAdapter(this)
                            if (adapter != null) {
                                CardEmulation.getInstance(adapter)
                                    .unsetPreferredService(this)
                            }
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
