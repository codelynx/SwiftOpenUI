package com.example.swiftopenui

import android.app.Activity
import android.os.Bundle
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.graphics.Color
import android.util.Log

class MainActivity : Activity() {
    companion object {
        const val TAG = "SwiftOpenUI"
        /// Application-scoped: session bridge survives Activity recreation.
        private val bridge = if (RenderBridge.isLoaded) RenderBridge() else null
    }

    private lateinit var scrollView: ScrollView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val exampleName = intent.getStringExtra("example") ?: "HelloWorld"
        Log.d(TAG, "Starting example: $exampleName")

        scrollView = ScrollView(this).apply {
            fitsSystemWindows = true
        }

        // Wire button click handler: Kotlin → Swift → returns new JSON
        RenderHost.onButtonClick = { nodeId ->
            Log.d(TAG, "Button clicked: nodeId=$nodeId")
            val newJson = bridge?.nativeOnButtonClick(nodeId)
            if (newJson != null) {
                Log.d(TAG, "State changed, re-rendering (${newJson.length} chars)")
                replaceContent(newJson)
            }
            newJson
        }

        val view = try {
            if (bridge == null) {
                throw UnsatisfiedLinkError(RenderBridge.loadError ?: "Unknown load error")
            }
            // Use session-based API — Swift reuses existing session if example matches
            val json = bridge.nativeCreateSession(exampleName)
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

        scrollView.addView(view, LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ))
        setContentView(scrollView)
    }

    private fun replaceContent(json: String) {
        runOnUiThread {
            scrollView.removeAllViews()
            val newView = RenderHost.renderFromJSON(this, json)
            scrollView.addView(newView, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ))
        }
    }
}
