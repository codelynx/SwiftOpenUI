package com.example.swiftopenui

import android.app.Activity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.view.Gravity
import android.graphics.Color
import android.util.Log

class MainActivity : Activity() {
    companion object {
        const val TAG = "SwiftOpenUI"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val exampleName = intent.getStringExtra("example") ?: "HelloWorld"
        Log.d(TAG, "Starting example: $exampleName")

        val view = try {
            if (!RenderBridge.isLoaded) {
                throw UnsatisfiedLinkError(RenderBridge.loadError ?: "Unknown load error")
            }
            val bridge = RenderBridge()
            val json = bridge.nativeRenderApp(exampleName)
            Log.d(TAG, "JSON length: ${json.length}")
            val rendered = RenderHost.renderFromJSON(this, json)
            Log.d(TAG, "Render complete")
            rendered
        } catch (e: UnsatisfiedLinkError) {
            TextView(this).apply {
                text = "Failed to load Swift library:\n${e.message}"
                setTextColor(Color.RED)
                setPadding(32, 32, 32, 32)
                textSize = 16f
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}", e)
            TextView(this).apply {
                text = "Error:\n${e.message}"
                setTextColor(Color.RED)
                setPadding(32, 32, 32, 32)
                textSize = 14f
            }
        }

        val scrollView = ScrollView(this).apply {
            fitsSystemWindows = true
            addView(view, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ))
        }
        setContentView(scrollView)
    }
}
