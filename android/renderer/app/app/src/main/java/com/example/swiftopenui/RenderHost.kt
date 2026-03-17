package com.example.swiftopenui

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.LayerDrawable
import android.text.Editable
import android.text.TextWatcher
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.*
import org.json.JSONObject
import org.json.JSONArray

/// Decodes a JSON render tree from Swift and creates Android Views.
object RenderHost {

    /// Callback invoked when a button is clicked. Set by MainActivity.
    /// Returns new JSON if state changed, null otherwise.
    var onButtonClick: ((Long) -> String?)? = null

    /// Callback invoked when text input changes. Set by MainActivity.
    /// Returns new JSON if state changed, null otherwise.
    var onTextInput: ((Long, String) -> String?)? = null

    /// Callback invoked when focus changes. Set by MainActivity.
    /// Does not return JSON — focus changes don't trigger rebuilds.
    var onFocusChange: ((Long, Boolean) -> Unit)? = null

    /// Input state snapshots keyed by node ID. Saved before rebuild,
    /// restored after rebuild to preserve cursor, selection, and focus.
    private val inputSnapshots = mutableMapOf<Long, InputSnapshot>()

    /// Set to true during programmatic setText to suppress TextWatcher feedback.
    private var suppressTextWatcher = false

    data class InputSnapshot(
        val selectionStart: Int,
        val selectionEnd: Int,
        val hasFocus: Boolean
    )

    fun renderFromJSON(context: Context, json: String): View {
        return try {
            val root = JSONObject(json)
            createView(context, root)
        } catch (e: Exception) {
            TextView(context).apply {
                text = "Render error: ${e.message}"
                setTextColor(Color.RED)
            }
        }
    }

    private fun createView(context: Context, node: JSONObject): View {
        val type = node.getString("type")
        val nodeId = node.optLong("id", 0L)
        val props = if (node.has("props")) node.getJSONObject("props") else JSONObject()
        val children = if (node.has("children")) node.getJSONArray("children") else JSONArray()

        val view = when (type) {
            "window" -> createContainer(context, children, LinearLayout.VERTICAL)
            "text" -> createText(context, props)
            "button" -> createButton(context, nodeId, props, children)
            "textfield" -> createTextField(context, nodeId, props)
            "vstack" -> createVStack(context, props, children)
            "hstack" -> createHStack(context, props, children)
            "zstack" -> createZStack(context, children)
            "spacer" -> createSpacer(context)
            "divider" -> createDivider(context)
            "color" -> createColorView(context, props)
            "empty" -> View(context)
            "group" -> createContainer(context, children, LinearLayout.VERTICAL)
            "padding" -> createPadding(context, props, children)
            "frame" -> createFrame(context, props, children)
            "foregroundColor" -> createForegroundColor(context, props, children)
            "backgroundColor" -> createBackgroundColor(context, props, children)
            "font" -> createFont(context, props, children)
            "border" -> createBorder(context, props, children)
            else -> TextView(context).apply { text = "[$type]" }
        }

        // Apply focus binding if present (set by .focused() modifier)
        applyFocusProps(view, nodeId, props)

        return view
    }

    /// Apply focus behavior to a view after creation.
    ///
    /// If a "focused" prop exists (from .focused() modifier):
    /// - Wire OnFocusChangeListener → Swift nativeOnFocusChange
    /// - "true": requestFocus (programmatic focus from @FocusState)
    /// - "false": clearFocus + remove snapshot (programmatic unfocus)
    ///
    /// If no "focused" prop but an InputSnapshot exists with hasFocus:
    /// - Restore focus from snapshot (e.g. text field without .focused())
    private fun applyFocusProps(view: View, nodeId: Long, props: JSONObject) {
        val focusedProp = props.optString("focused", "")

        if (focusedProp.isNotEmpty()) {
            // Node has .focused() modifier — wire focus listener
            if (nodeId != 0L) {
                view.isFocusable = true
                view.isFocusableInTouchMode = true
                view.setOnFocusChangeListener { _, hasFocus ->
                    onFocusChange?.invoke(nodeId, hasFocus)
                }
            }

            if (focusedProp == "true") {
                view.post { view.requestFocus() }
            } else {
                // Programmatic unfocus — clear snapshot and focus
                inputSnapshots.remove(nodeId)
                if (view.hasFocus()) {
                    view.post { view.clearFocus() }
                }
            }
        } else {
            // No .focused() modifier — fall back to snapshot-based focus restore
            val snapshot = inputSnapshots.remove(nodeId)
            if (snapshot != null && snapshot.hasFocus) {
                view.post { view.requestFocus() }
            }
        }
    }

    private fun createText(context: Context, props: JSONObject): TextView {
        return TextView(context).apply {
            text = props.optString("content", "")
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTextColor(Color.BLACK)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun createButton(context: Context, nodeId: Long, props: JSONObject, children: JSONArray): Button {
        return Button(context).apply {
            text = props.optString("label", "Button")
            isAllCaps = false
            if (nodeId != 0L) {
                setOnClickListener {
                    onButtonClick?.invoke(nodeId)
                }
            }
        }
    }

    private fun createTextField(context: Context, nodeId: Long, props: JSONObject): EditText {
        val placeholder = props.optString("placeholder", "")
        val text = props.optString("text", "")

        return EditText(context).apply {
            hint = placeholder
            setSingleLine(true)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )

            // Set initial text without triggering the watcher
            suppressTextWatcher = true
            setText(text)
            suppressTextWatcher = false

            // Restore cursor/selection from snapshot (but NOT focus —
            // focus is managed by applyFocusProps which runs after creation)
            val snapshot = inputSnapshots[nodeId]
            if (snapshot != null) {
                val len = getText().length
                setSelection(
                    snapshot.selectionStart.coerceIn(0, len),
                    snapshot.selectionEnd.coerceIn(0, len)
                )
            }

            // Wire TextWatcher — sends text changes to Swift immediately
            if (nodeId != 0L) {
                addTextChangedListener(object : TextWatcher {
                    override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                    override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                    override fun afterTextChanged(s: Editable?) {
                        if (suppressTextWatcher) return
                        val newText = s?.toString() ?: ""

                        // Save input state before the rebuild replaces this view
                        inputSnapshots[nodeId] = InputSnapshot(
                            selectionStart = selectionStart,
                            selectionEnd = selectionEnd,
                            hasFocus = hasFocus()
                        )

                        onTextInput?.invoke(nodeId, newText)
                    }
                })
            }
        }
    }

    private fun createVStack(context: Context, props: JSONObject, children: JSONArray): LinearLayout {
        val spacing = props.optInt("spacing", 0)
        val alignment = props.optString("alignment", "center")

        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            gravity = when {
                alignment.contains("leading") -> Gravity.START
                alignment.contains("trailing") -> Gravity.END
                else -> Gravity.CENTER_HORIZONTAL
            }
            for (i in 0 until children.length()) {
                val child = createView(context, children.getJSONObject(i))
                val childLp = child.layoutParams
                val params = LinearLayout.LayoutParams(
                    childLp?.width ?: LinearLayout.LayoutParams.WRAP_CONTENT,
                    childLp?.height ?: LinearLayout.LayoutParams.WRAP_CONTENT
                )
                if (i > 0 && spacing > 0) {
                    params.topMargin = dpToPx(context, spacing)
                }
                addView(child, params)
            }
        }
    }

    private fun createHStack(context: Context, props: JSONObject, children: JSONArray): LinearLayout {
        val spacing = props.optInt("spacing", 0)
        val alignment = props.optString("alignment", "center")

        return LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            gravity = when {
                alignment.contains("top") -> Gravity.TOP
                alignment.contains("bottom") -> Gravity.BOTTOM
                else -> Gravity.CENTER_VERTICAL
            }
            for (i in 0 until children.length()) {
                val child = createView(context, children.getJSONObject(i))
                val childLp = child.layoutParams
                val params = LinearLayout.LayoutParams(
                    childLp?.width ?: LinearLayout.LayoutParams.WRAP_CONTENT,
                    childLp?.height ?: LinearLayout.LayoutParams.WRAP_CONTENT
                )
                if (i > 0 && spacing > 0) {
                    params.leftMargin = dpToPx(context, spacing)
                }
                // Spacers get weight
                if (children.getJSONObject(i).getString("type") == "spacer") {
                    params.width = 0
                    params.weight = 1f
                }
                addView(child, params)
            }
        }
    }

    private fun createZStack(context: Context, children: JSONArray): FrameLayout {
        return FrameLayout(context).apply {
            for (i in 0 until children.length()) {
                val childNode = children.getJSONObject(i)
                val child = createView(context, childNode)
                val childType = childNode.getString("type")
                // Color views fill the ZStack; other views center
                val params = if (childType == "color") {
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT
                    )
                } else {
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        FrameLayout.LayoutParams.WRAP_CONTENT,
                        Gravity.CENTER
                    )
                }
                addView(child, params)
            }
        }
    }

    private fun createSpacer(context: Context): Space {
        return Space(context).apply {
            layoutParams = LinearLayout.LayoutParams(0, 0, 1f)
        }
    }

    private fun createDivider(context: Context): View {
        return View(context).apply {
            setBackgroundColor(Color.parseColor("#CCCCCC"))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(context, 1)
            )
        }
    }

    private fun createColorView(context: Context, props: JSONObject): View {
        val color = propsToColor(props)
        return View(context).apply {
            setBackgroundColor(color)
            layoutParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        }
    }

    private fun createContainer(context: Context, children: JSONArray, orientation: Int): LinearLayout {
        return LinearLayout(context).apply {
            this.orientation = orientation
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setPadding(16, 16, 16, 16)
            for (i in 0 until children.length()) {
                val child = createView(context, children.getJSONObject(i))
                addView(child)
            }
        }
    }

    private fun createPadding(context: Context, props: JSONObject, children: JSONArray): LinearLayout {
        val top = props.optInt("top", 0)
        val bottom = props.optInt("bottom", 0)
        val leading = props.optInt("leading", 0)
        val trailing = props.optInt("trailing", 0)

        return LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
            setPadding(
                dpToPx(context, leading),
                dpToPx(context, top),
                dpToPx(context, trailing),
                dpToPx(context, bottom)
            )
            if (children.length() > 0) {
                addView(createView(context, children.getJSONObject(0)))
            }
        }
    }

    private fun createFrame(context: Context, props: JSONObject, children: JSONArray): FrameLayout {
        val width = props.optDouble("width", -1.0)
        val height = props.optDouble("height", -1.0)

        return FrameLayout(context).apply {
            val w = if (width > 0) dpToPx(context, width.toInt()) else FrameLayout.LayoutParams.WRAP_CONTENT
            val h = if (height > 0) dpToPx(context, height.toInt()) else FrameLayout.LayoutParams.WRAP_CONTENT
            layoutParams = LinearLayout.LayoutParams(w, h)
            if (children.length() > 0) {
                addView(createView(context, children.getJSONObject(0)),
                    FrameLayout.LayoutParams(
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        FrameLayout.LayoutParams.MATCH_PARENT,
                        Gravity.CENTER
                    )
                )
            }
        }
    }

    private fun createForegroundColor(context: Context, props: JSONObject, children: JSONArray): View {
        val color = propsToColor(props)
        val child = if (children.length() > 0) createView(context, children.getJSONObject(0)) else View(context)
        applyTextColor(child, color)
        return child
    }

    private fun createBackgroundColor(context: Context, props: JSONObject, children: JSONArray): View {
        val color = propsToColor(props)
        val child = if (children.length() > 0) createView(context, children.getJSONObject(0)) else View(context)
        child.setBackgroundColor(color)
        return child
    }

    private fun createFont(context: Context, props: JSONObject, children: JSONArray): View {
        val size = props.optDouble("size", 17.0).toFloat()
        val weight = props.optString("weight", "normal")
        val child = if (children.length() > 0) createView(context, children.getJSONObject(0)) else View(context)
        applyFont(child, size, weight)
        return child
    }

    private fun createBorder(context: Context, props: JSONObject, children: JSONArray): View {
        val color = propsToColor(props)
        val width = props.optDouble("width", 1.0)
        val child = if (children.length() > 0) createView(context, children.getJSONObject(0)) else View(context)
        val border = GradientDrawable().apply {
            setStroke(dpToPx(context, width.toInt().coerceAtLeast(1)), color)
            setColor(Color.TRANSPARENT)
        }
        val existing = child.background
        child.background = if (existing != null) {
            LayerDrawable(arrayOf(existing, border))
        } else {
            border
        }
        return child
    }

    // MARK: - Helpers

    private fun propsToColor(props: JSONObject): Int {
        val r = (props.optDouble("r", 0.0) * 255).toInt()
        val g = (props.optDouble("g", 0.0) * 255).toInt()
        val b = (props.optDouble("b", 0.0) * 255).toInt()
        val a = (props.optDouble("a", 1.0) * 255).toInt()
        return Color.argb(a, r, g, b)
    }

    private fun applyTextColor(view: View, color: Int) {
        when (view) {
            is TextView -> view.setTextColor(color)
            is LinearLayout -> {
                for (i in 0 until view.childCount) {
                    applyTextColor(view.getChildAt(i), color)
                }
            }
        }
    }

    private fun applyFont(view: View, sizeSp: Float, weight: String) {
        when (view) {
            is TextView -> {
                view.setTextSize(TypedValue.COMPLEX_UNIT_SP, sizeSp)
                view.typeface = when (weight) {
                    "bold" -> Typeface.DEFAULT_BOLD
                    "semibold" -> Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                    "light" -> Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
                    else -> Typeface.DEFAULT
                }
            }
            is LinearLayout -> {
                for (i in 0 until view.childCount) {
                    applyFont(view.getChildAt(i), sizeSp, weight)
                }
            }
        }
    }

    private fun dpToPx(context: Context, dp: Int): Int {
        return (dp * context.resources.displayMetrics.density).toInt()
    }
}
