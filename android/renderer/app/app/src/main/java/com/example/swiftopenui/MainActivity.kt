package com.example.swiftopenui

import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.displayCutoutPadding
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

class MainActivity : ComponentActivity() {
    companion object {
        const val TAG = "SwiftOpenUI"
        /// Application-scoped: session bridge survives Activity recreation.
        private val bridge = if (RenderBridge.isLoaded) RenderBridge() else null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Enable edge-to-edge display so statusBarsPadding works
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
        }

        val exampleName = intent.getStringExtra("example") ?: "HelloWorld"
        Log.d(TAG, "Starting example: $exampleName")

        // Wire callbacks: Kotlin → Swift
        ComposeRenderHost.onButtonClick = { nodeId ->
            Log.d(TAG, "Button clicked: nodeId=$nodeId")
            bridge?.nativeOnButtonClick(nodeId)
        }

        ComposeRenderHost.onTextInput = { nodeId, text ->
            bridge?.nativeOnTextInput(nodeId, text)
        }

        ComposeRenderHost.onToggleChange = { nodeId, isOn ->
            bridge?.nativeOnToggleChange(nodeId, isOn)
        }

        ComposeRenderHost.onSliderChange = { nodeId, value ->
            bridge?.nativeOnSliderChange(nodeId, value)
        }

        ComposeRenderHost.onFocusChange = { nodeId, hasFocus ->
            bridge?.nativeOnFocusChange(nodeId, hasFocus)
        }

        ComposeRenderHost.onDragEvent = { nodeId, phase, startX, startY, currentX, currentY ->
            bridge?.nativeOnDragEvent(nodeId, phase, startX, startY, currentX, currentY)
        }

        // System back button → NavigationStack pop
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val backId = ComposeRenderHost.currentBackNodeId
                if (backId != 0L) {
                    // Pop navigation via the same path as the "← Back" button
                    val newJson = ComposeRenderHost.onButtonClick?.invoke(backId)
                    if (newJson != null) {
                        ComposeRenderHost.onJsonUpdate?.invoke(newJson)
                    }
                } else {
                    // No navigation to pop — let the system handle it (finish Activity)
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                    isEnabled = true
                }
            }
        })

        val initialJson = try {
            if (bridge == null) {
                throw UnsatisfiedLinkError(RenderBridge.loadError ?: "Unknown load error")
            }
            val json = bridge.nativeCreateSession(exampleName)
            Log.d(TAG, "JSON length: ${json.length}")
            json
        } catch (e: Exception) {
            Log.e(TAG, "Error: ${e.message}", e)
            null
        }

        setContent {
            MaterialTheme {
                Surface(modifier = Modifier
                    .fillMaxSize()
                    .statusBarsPadding()
                    .displayCutoutPadding()
                ) {
                    if (initialJson != null) {
                        var currentJson by remember { mutableStateOf(initialJson) }

                        // Wire system back button JSON updates
                        ComposeRenderHost.onJsonUpdate = { newJson ->
                            Log.d(TAG, "State changed, re-rendering (${newJson.length} chars)")
                            currentJson = newJson
                        }

                        androidx.compose.foundation.layout.Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .verticalScroll(rememberScrollState())
                        ) {
                            ComposeRenderHost.RenderFromJSON(currentJson) { newJson ->
                                Log.d(TAG, "State changed, re-rendering (${newJson.length} chars)")
                                currentJson = newJson
                            }
                        }
                        Log.d(TAG, "Render complete")
                    } else {
                        Text(
                            text = "Failed to load Swift library:\n${RenderBridge.loadError ?: "Unknown error"}",
                            color = Color.Red
                        )
                    }
                }
            }
        }
    }
}
