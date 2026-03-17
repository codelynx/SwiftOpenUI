package com.example.swiftopenui

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.*
import org.json.JSONObject
import org.json.JSONArray

/// Decodes a JSON render tree from Swift and creates Android Views.
object RenderHost {

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
        val props = if (node.has("props")) node.getJSONObject("props") else JSONObject()
        val children = if (node.has("children")) node.getJSONArray("children") else JSONArray()

        return when (type) {
            "window" -> createContainer(context, children, LinearLayout.VERTICAL)
            "text" -> createText(context, props)
            "button" -> createButton(context, props, children)
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
    }

    private fun createText(context: Context, props: JSONObject): TextView {
        return TextView(context).apply {
            text = props.optString("content", "")
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }
    }

    private fun createButton(context: Context, props: JSONObject, children: JSONArray): Button {
        return Button(context).apply {
            text = props.optString("label", "Button")
            isAllCaps = false
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
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
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
            gravity = when {
                alignment.contains("top") -> Gravity.TOP
                alignment.contains("bottom") -> Gravity.BOTTOM
                else -> Gravity.CENTER_VERTICAL
            }
            for (i in 0 until children.length()) {
                val child = createView(context, children.getJSONObject(i))
                val params = LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
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
                val child = createView(context, children.getJSONObject(i))
                val params = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    FrameLayout.LayoutParams.WRAP_CONTENT,
                    Gravity.CENTER
                )
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
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dpToPx(context, 20)
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
        val child = if (children.length() > 0) createView(context, children.getJSONObject(0)) else View(context)
        // Simple border via background drawable would be complex; skip for now
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
