package com.example.flutter_application_1

import android.content.Context
import android.view.WindowManager
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val keyboardChannel = "oht_control/keyboard"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, keyboardChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "show" -> {
                        forceShowKeyboard()
                        result.success(null)
                    }
                    "hide" -> {
                        hideKeyboard()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun forceShowKeyboard() {
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE or
                WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE
        )
        val view = currentFocus ?: window.decorView
        view.postDelayed({
            val inputMethodManager =
                getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
            inputMethodManager.showSoftInput(view, InputMethodManager.SHOW_FORCED)
        }, 80)
    }

    private fun hideKeyboard() {
        val view = currentFocus ?: window.decorView
        val inputMethodManager =
            getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        inputMethodManager.hideSoftInputFromWindow(view.windowToken, 0)
    }
}
