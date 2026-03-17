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
        Log.d(TAG, "Native loaded: ${RenderBridge.isLoaded}, error: ${RenderBridge.loadError}")

        val view = try {
            if (!RenderBridge.isLoaded) {
                throw UnsatisfiedLinkError(RenderBridge.loadError ?: "Unknown load error")
            }
            val bridge = RenderBridge()
            Log.d(TAG, "Calling nativeRenderApp...")
            val json = bridge.nativeRenderApp(exampleName)
            Log.d(TAG, "JSON length: ${json.length}, preview: ${json.take(200)}")

            // Debug: show the JSON directly to verify rendering works
            val debugLayout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setPadding(32, 32, 32, 32)
            }
            debugLayout.addView(TextView(this).apply {
                text = "Example: $exampleName"
                textSize = 20f
                setTextColor(Color.BLACK)
            })
            debugLayout.addView(TextView(this).apply {
                text = json.take(500)
                textSize = 12f
                setTextColor(Color.DKGRAY)
                setPadding(0, 16, 0, 16)
            })
            debugLayout.addView(android.view.View(this).apply {
                setBackgroundColor(Color.LTGRAY)
                layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 2)
            })
            val rendered = RenderHost.renderFromJSON(this, json)
            debugLayout.addView(rendered)
            Log.d(TAG, "Render complete")
            debugLayout as android.view.View
        } catch (e: UnsatisfiedLinkError) {
            Log.e(TAG, "Link error: ${e.message}", e)
            TextView(this).apply {
                text = "Failed to load Swift library:\n${e.message}"
                setTextColor(Color.RED)
                setPadding(32, 32, 32, 32)
                textSize = 16f
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}", e)
            TextView(this).apply {
                text = "Error:\n${e.message}\n\n${e.stackTraceToString()}"
                setTextColor(Color.RED)
                setPadding(32, 32, 32, 32)
                textSize = 14f
            }
        }

        setContentView(view)
    }
}
