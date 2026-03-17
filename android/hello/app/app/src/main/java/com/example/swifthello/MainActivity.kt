package com.example.swifthello

import android.app.Activity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import android.view.Gravity

class MainActivity : Activity() {

    // JNI function implemented in Swift
    private external fun helloFromSwift(): String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val message = if (nativeLoaded) {
            try {
                helloFromSwift()
            } catch (e: UnsatisfiedLinkError) {
                "JNI call failed: ${e.message}"
            }
        } else {
            "Failed to load Swift library: $loadError"
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(32, 32, 32, 32)
        }

        val textView = TextView(this).apply {
            text = message
            textSize = 24f
            gravity = Gravity.CENTER
        }

        layout.addView(textView)
        setContentView(layout)
    }

    companion object {
        private var nativeLoaded = false
        private var loadError: String? = null

        init {
            try {
                System.loadLibrary("SwiftHello")
                nativeLoaded = true
            } catch (e: UnsatisfiedLinkError) {
                loadError = e.message
            }
        }
    }
}
