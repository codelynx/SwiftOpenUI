package com.example.swiftopenui

/// JNI bridge to Swift BackendAndroid.
class RenderBridge {
    /// Legacy: render a named example to a JSON render tree (one-shot, no state).
    external fun nativeRenderApp(name: String): String

    /// Create a session for a named example. Returns initial JSON render tree.
    /// The session lives in Swift module scope (survives Activity recreation).
    external fun nativeCreateSession(name: String): String

    /// Handle a button click. Returns new JSON if @State changed, or null if not.
    external fun nativeOnButtonClick(nodeId: Long): String?

    /// Handle a text input change. Returns new JSON if @State changed, or null if not.
    external fun nativeOnTextInput(nodeId: Long, text: String): String?

    external fun nativeOnToggleChange(nodeId: Long, isOn: Boolean): String?

    external fun nativeOnSliderChange(nodeId: Long, value: Double): String?

    /// Handle a drag gesture event. Returns new JSON if @State changed.
    /// phase: 0 = changed (continuous), 1 = ended
    external fun nativeOnDragEvent(nodeId: Long, phase: Int, startX: Double, startY: Double, currentX: Double, currentY: Double): String?

    /// Notify Swift of a focus change. Does not return JSON — focus changes
    /// update @FocusState without triggering a rebuild.
    external fun nativeOnFocusChange(nodeId: Long, hasFocus: Boolean)

    companion object {
        private var loaded = false
        var loadError: String? = null

        init {
            try {
                System.loadLibrary("BackendAndroid")
                loaded = true
            } catch (e: UnsatisfiedLinkError) {
                loadError = e.message
            }
        }

        val isLoaded get() = loaded
    }
}
