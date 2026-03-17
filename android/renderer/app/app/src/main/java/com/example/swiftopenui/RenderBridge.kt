package com.example.swiftopenui

/// JNI bridge to Swift BackendAndroid.
class RenderBridge {
    /// Render a named example to a JSON render tree.
    external fun nativeRenderApp(name: String): String

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
