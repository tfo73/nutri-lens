package com.lenseat.app

import android.app.Activity
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.lenseat.app/speech"
    private val SPEECH_REQUEST = 100
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listen" -> {
                        pendingResult = result
                        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "tr-TR")
                            putExtra(RecognizerIntent.EXTRA_PROMPT, "Yemeği tarif edin...")
                            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        }
                        startActivityForResult(intent, SPEECH_REQUEST)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SPEECH_REQUEST) {
            val text = if (resultCode == Activity.RESULT_OK) {
                data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                    ?.firstOrNull() ?: ""
            } else ""
            pendingResult?.success(text)
            pendingResult = null
        }
    }
}
