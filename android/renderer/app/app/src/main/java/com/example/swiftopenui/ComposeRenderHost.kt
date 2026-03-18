package com.example.swiftopenui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.material3.Button
import androidx.compose.material3.Divider
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.json.JSONArray
import org.json.JSONObject

/// Compose-based renderer: JSON render tree → @Composable tree.
/// Replaces the imperative RenderHost for Compose-based rendering.
object ComposeRenderHost {

    /// Callback invoked when a button is clicked. Set by MainActivity.
    var onButtonClick: ((Long) -> String?)? = null

    /// Callback invoked when text input changes. Set by MainActivity.
    var onTextInput: ((Long, String) -> String?)? = null

    /// Callback invoked when focus changes. Set by MainActivity.
    var onFocusChange: ((Long, Boolean) -> Unit)? = null

    @Composable
    fun RenderFromJSON(json: String, onNewJson: (String) -> Unit) {
        val root = remember(json) { JSONObject(json) }
        RenderNode(root, onNewJson)
    }

    @Composable
    private fun RenderNode(node: JSONObject, onNewJson: (String) -> Unit) {
        val type = node.getString("type")
        val nodeId = node.optString("id", "0").toLongOrNull() ?: 0L
        val props = if (node.has("props")) node.getJSONObject("props") else JSONObject()
        val children = if (node.has("children")) node.getJSONArray("children") else JSONArray()
        val focusedProp = props.optString("focused", "")

        // Focus handling
        val focusRequester = remember { FocusRequester() }
        var focusModifier = Modifier as Modifier
        if (focusedProp.isNotEmpty() && nodeId != 0L) {
            focusModifier = Modifier
                .focusRequester(focusRequester)
                .onFocusChanged { state ->
                    onFocusChange?.invoke(nodeId, state.isFocused)
                }
        }

        when (type) {
            "window" -> RenderContainer(children, onNewJson)
            "text" -> RenderText(props)
            "button" -> RenderButton(nodeId, props, children, onNewJson)
            "textfield" -> RenderTextField(nodeId, props, focusModifier, onNewJson)
            "vstack" -> RenderVStack(props, children, onNewJson)
            "hstack" -> RenderHStack(props, children, onNewJson)
            "zstack" -> RenderZStack(children, onNewJson)
            "spacer" -> Spacer(modifier = Modifier.height(0.dp)) // weight applied in Row/Column scope
            "divider" -> Divider(color = Color(0xFFCCCCCC), thickness = 1.dp)
            "color" -> RenderColor(props)
            "empty" -> {}
            "group" -> RenderContainer(children, onNewJson)
            "padding" -> RenderPadding(props, children, onNewJson)
            "frame" -> RenderFrame(props, children, onNewJson)
            "foregroundColor" -> RenderForegroundColor(props, children, onNewJson)
            "backgroundColor" -> RenderBackgroundColor(props, children, onNewJson)
            "font" -> RenderFont(props, children, onNewJson)
            "border" -> RenderBorder(props, children, onNewJson)
            "opacity" -> RenderOpacity(props, children, onNewJson)
            "offset" -> RenderOffset(props, children, onNewJson)
            "scaleEffect" -> RenderScale(props, children, onNewJson)
            "navigationStack" -> RenderNavigationStack(props, children, onNewJson)
            "navigationLink" -> RenderNavigationLink(nodeId, props, onNewJson)
            else -> Text("[$type]")
        }

        // Apply programmatic focus after composition
        if (focusedProp == "true") {
            LaunchedEffect(Unit) {
                focusRequester.requestFocus()
            }
        } else if (focusedProp == "false") {
            val focusManager = LocalFocusManager.current
            LaunchedEffect(Unit) {
                focusManager.clearFocus()
            }
        }
    }

    @Composable
    private fun RenderText(props: JSONObject) {
        val color = LocalContentColor.current
        val style = LocalTextStyle.current
        Text(
            text = props.optString("content", ""),
            color = color,
            style = style.copy(fontSize = style.fontSize.takeIf { it.isSp } ?: 16.sp)
        )
    }

    @Composable
    private fun RenderButton(nodeId: Long, props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        Button(onClick = {
            if (nodeId != 0L) {
                val newJson = onButtonClick?.invoke(nodeId)
                if (newJson != null) onNewJson(newJson)
            }
        }) {
            Text(props.optString("label", "Button"))
        }
    }

    @Composable
    private fun RenderTextField(nodeId: Long, props: JSONObject, focusModifier: Modifier, onNewJson: (String) -> Unit) {
        val placeholder = props.optString("placeholder", "")
        val text = props.optString("text", "")

        // Use TextFieldValue to preserve cursor position, selection, and
        // IME composition across external updates from Swift JSON.
        var tfValue by remember {
            mutableStateOf(TextFieldValue(text, TextRange(text.length)))
        }

        // When Swift sends new text (e.g. after "Clear All" button), update
        // the value while preserving cursor position where possible.
        LaunchedEffect(text) {
            if (text != tfValue.text) {
                tfValue = tfValue.copy(
                    text = text,
                    selection = TextRange(text.length.coerceAtMost(tfValue.selection.start),
                                          text.length.coerceAtMost(tfValue.selection.end))
                )
            }
        }

        BasicTextField(
            value = tfValue,
            onValueChange = { newValue ->
                tfValue = newValue
                if (nodeId != 0L && newValue.text != text) {
                    val newJson = onTextInput?.invoke(nodeId, newValue.text)
                    if (newJson != null) onNewJson(newJson)
                }
            },
            modifier = focusModifier
                .fillMaxWidth()
                .border(1.dp, Color.Gray)
                .padding(8.dp),
            textStyle = TextStyle(fontSize = 16.sp),
            decorationBox = { innerTextField ->
                Box {
                    if (tfValue.text.isEmpty()) {
                        Text(placeholder, color = Color.Gray, fontSize = 16.sp)
                    }
                    innerTextField()
                }
            }
        )
    }

    @Composable
    private fun RenderVStack(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val spacing = props.optInt("spacing", 0)
        val alignment = props.optString("alignment", "center")

        val hAlign = when {
            alignment.contains("leading") -> Alignment.Start
            alignment.contains("trailing") -> Alignment.End
            else -> Alignment.CenterHorizontally
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(spacing.dp),
            horizontalAlignment = hAlign
        ) {
            RenderChildren(children, onNewJson)
        }
    }

    @Composable
    private fun RenderHStack(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val spacing = props.optInt("spacing", 0)
        val alignment = props.optString("alignment", "center")

        val vAlign = when {
            alignment.contains("top") -> Alignment.Top
            alignment.contains("bottom") -> Alignment.Bottom
            else -> Alignment.CenterVertically
        }

        // Center if no Spacer children (SwiftUI HStack centers content by default).
        // If Spacers are present, they handle distribution via Modifier.weight.
        val hasSpacer = (0 until children.length()).any { children.getJSONObject(it).getString("type") == "spacer" }
        val arrangement = if (hasSpacer) {
            Arrangement.spacedBy(spacing.dp)
        } else {
            Arrangement.spacedBy(spacing.dp, Alignment.CenterHorizontally)
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = arrangement,
            verticalAlignment = vAlign
        ) {
            RenderChildren(children, onNewJson)
        }
    }

    @Composable
    private fun RenderZStack(children: JSONArray, onNewJson: (String) -> Unit) {
        Box(modifier = Modifier.fillMaxWidth()) {
            for (i in 0 until children.length()) {
                val child = children.getJSONObject(i)
                val childType = child.getString("type")
                if (childType == "color") {
                    Box(modifier = Modifier.matchParentSize()) {
                        RenderNode(child, onNewJson)
                    }
                } else {
                    Box(modifier = Modifier.align(Alignment.Center)) {
                        RenderNode(child, onNewJson)
                    }
                }
            }
        }
    }

    @Composable
    private fun RenderColor(props: JSONObject) {
        val color = propsToColor(props)
        Box(modifier = Modifier
            .fillMaxSize()
            .background(color))
    }

    @Composable
    private fun RenderContainer(children: JSONArray, onNewJson: (String) -> Unit) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            RenderChildren(children, onNewJson)
        }
    }

    @Composable
    private fun RenderPadding(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val top = props.optInt("top", 0)
        val bottom = props.optInt("bottom", 0)
        val leading = props.optInt("leading", 0)
        val trailing = props.optInt("trailing", 0)

        Box(modifier = Modifier.padding(
            start = leading.dp,
            top = top.dp,
            end = trailing.dp,
            bottom = bottom.dp
        )) {
            if (children.length() > 0) {
                RenderNode(children.getJSONObject(0), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderFrame(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val width = props.optDouble("width", -1.0)
        val height = props.optDouble("height", -1.0)

        var modifier = Modifier as Modifier
        if (width > 0) modifier = modifier.width(width.dp)
        if (height > 0) modifier = modifier.height(height.dp)

        Box(modifier = modifier, contentAlignment = Alignment.Center) {
            if (children.length() > 0) {
                RenderNode(children.getJSONObject(0), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderForegroundColor(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val color = propsToColor(props)
        CompositionLocalProvider(LocalContentColor provides color) {
            if (children.length() > 0) {
                RenderNode(children.getJSONObject(0), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderBackgroundColor(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val color = propsToColor(props)
        Box(modifier = Modifier.background(color)) {
            if (children.length() > 0) {
                RenderNode(children.getJSONObject(0), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderFont(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val size = props.optDouble("size", 17.0).toFloat()
        val weight = props.optString("weight", "normal")

        val fontWeight = when (weight) {
            "bold" -> FontWeight.Bold
            "semibold" -> FontWeight.SemiBold
            "light" -> FontWeight.Light
            else -> FontWeight.Normal
        }

        CompositionLocalProvider(
            LocalTextStyle provides TextStyle(fontSize = size.sp, fontWeight = fontWeight)
        ) {
            if (children.length() > 0) {
                RenderNode(children.getJSONObject(0), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderBorder(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val color = propsToColor(props)
        val width = props.optDouble("width", 1.0)

        Box(modifier = Modifier.border(width.dp, color)) {
            if (children.length() > 0) {
                RenderNode(children.getJSONObject(0), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderOpacity(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val opacity = props.optDouble("value", 1.0).toFloat()
        Box(modifier = Modifier.alpha(opacity)) {
            if (children.length() > 0) RenderNode(children.getJSONObject(0), onNewJson)
        }
    }

    @Composable
    private fun RenderOffset(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val x = props.optDouble("x", 0.0)
        val y = props.optDouble("y", 0.0)
        Box(modifier = Modifier.offset(x.dp, y.dp)) {
            if (children.length() > 0) RenderNode(children.getJSONObject(0), onNewJson)
        }
    }

    @Composable
    private fun RenderScale(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val scaleX = props.optDouble("scaleX", 1.0).toFloat()
        val scaleY = props.optDouble("scaleY", 1.0).toFloat()
        Box(modifier = Modifier.graphicsLayer(scaleX = scaleX, scaleY = scaleY)) {
            if (children.length() > 0) RenderNode(children.getJSONObject(0), onNewJson)
        }
    }

    @Composable
    private fun RenderNavigationStack(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val title = props.optString("title", "Home")
        val showBack = props.optString("showBack", "") == "true"
        val destTitle = props.optString("destTitle", "")
        val backNodeId = props.optString("backNodeId", "0").toLongOrNull() ?: 0L

        Column(modifier = Modifier.fillMaxWidth()) {
            // Header bar
            Row(
                modifier = Modifier.fillMaxWidth().background(Color(0xFFF0F0F0)).padding(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (showBack && backNodeId != 0L) {
                    Button(onClick = {
                        // Back button triggers Swift-side path pop via JNI
                        val newJson = onButtonClick?.invoke(backNodeId)
                        if (newJson != null) onNewJson(newJson)
                    }) {
                        Text("← Back")
                    }
                    Spacer(modifier = Modifier.width(8.dp))
                }
                Text(
                    text = if (showBack) destTitle else title,
                    style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 17.sp)
                )
            }
            // Content — Swift already resolved which view to show
            for (i in 0 until children.length()) {
                RenderNode(children.getJSONObject(i), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderNavigationLink(nodeId: Long, props: JSONObject, onNewJson: (String) -> Unit) {
        val label = props.optString("label", "Link")
        Button(onClick = {
            // Navigation links use static destinations in the current architecture.
            // Programmatic path-based navigation requires JNI bridge (future work).
            if (nodeId != 0L) {
                val newJson = onButtonClick?.invoke(nodeId)
                if (newJson != null) onNewJson(newJson)
            }
        }) {
            Text(label)
        }
    }

    @Composable
    private fun ColumnScope.RenderChildren(children: JSONArray, onNewJson: (String) -> Unit) {
        for (i in 0 until children.length()) {
            val child = children.getJSONObject(i)
            if (child.getString("type") == "spacer") {
                Spacer(modifier = Modifier.weight(1f))
            } else {
                RenderNode(child, onNewJson)
            }
        }
    }

    @Composable
    private fun RowScope.RenderChildren(children: JSONArray, onNewJson: (String) -> Unit) {
        for (i in 0 until children.length()) {
            val child = children.getJSONObject(i)
            if (child.getString("type") == "spacer") {
                Spacer(modifier = Modifier.weight(1f))
            } else {
                RenderNode(child, onNewJson)
            }
        }
    }

    // MARK: - Helpers

    private fun propsToColor(props: JSONObject): Color {
        val r = props.optDouble("r", 0.0).toFloat()
        val g = props.optDouble("g", 0.0).toFloat()
        val b = props.optDouble("b", 0.0).toFloat()
        val a = props.optDouble("a", 1.0).toFloat()
        return Color(r, g, b, a)
    }
}

/// CompositionLocal for propagating foreground color through the tree.
private val LocalContentColor = compositionLocalOf { Color.Black }

/// CompositionLocal for propagating text style through the tree.
private val LocalTextStyle = compositionLocalOf { TextStyle.Default }

/// Text that respects the local content color and text style.
@Composable
private fun RenderStyledText(text: String) {
    val color = LocalContentColor.current
    val style = LocalTextStyle.current
    Text(text = text, color = color, style = style)
}
