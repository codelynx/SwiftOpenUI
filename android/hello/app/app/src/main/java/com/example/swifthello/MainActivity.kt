package com.example.swifthello

import android.app.Activity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.TextView
import android.view.Gravity

class MainActivity : Activity() {

    // JNI function implemented in Swift
    external fun helloFromSwift(): String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val message = try {
            helloFromSwift()
        } catch (e: UnsatisfiedLinkError) {
            "Failed to load Swift library: ${e.message}"
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
        init {
            System.loadLibrary("SwiftHello")
        }
    }
}
