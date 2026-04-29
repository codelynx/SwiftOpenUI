package com.example.swiftopenui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.material3.*
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.horizontalScroll
import androidx.compose.runtime.*
import kotlin.math.roundToInt
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.draw.alpha
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.draw.clip
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
@OptIn(ExperimentalMaterial3Api::class)
object ComposeRenderHost {

    /// Callback invoked when a button is clicked. Set by MainActivity.
    var onButtonClick: ((Long) -> String?)? = null

    /// Callback invoked when text input changes. Set by MainActivity.
    var onTextInput: ((Long, String) -> String?)? = null

    /// Callback invoked when toggle changes. Set by MainActivity.
    var onToggleChange: ((Long, Boolean) -> String?)? = null

    /// Callback invoked when slider changes. Set by MainActivity.
    var onSliderChange: ((Long, Double) -> String?)? = null

    /// Callback invoked when focus changes. Set by MainActivity.
    var onFocusChange: ((Long, Boolean) -> Unit)? = null

    /// Callback invoked on drag events (phase 0=changed, 1=ended).
    var onDragEvent: ((Long, Int, Double, Double, Double, Double) -> String?)? = null

    /// The back button nodeId from the current NavigationStack, or 0 if at root.
    /// Updated each time a navigationStack node is rendered.
    var currentBackNodeId: Long = 0

    /// Callback to update the root JSON (used by system back button).
    var onJsonUpdate: ((String) -> Unit)? = null

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

        // Drag gesture: wrap in pointer input handler
        val hasDrag = props.optString("onDrag", "") == "true" && nodeId != 0L
        val dragModifier = if (hasDrag) {
            Modifier.pointerInput(nodeId) {
                var startX = 0f; var startY = 0f
                detectDragGestures(
                    onDragStart = { offset -> startX = offset.x; startY = offset.y },
                    onDrag = { change, _ ->
                        change.consume()
                        val d = density
                        val nj = onDragEvent?.invoke(nodeId, 0,
                            (startX / d).toDouble(), (startY / d).toDouble(),
                            (change.position.x / d).toDouble(), (change.position.y / d).toDouble())
                        if (nj != null) onNewJson(nj)
                    },
                    onDragEnd = {
                        // onEnded with last known position (approximate)
                        onDragEvent?.invoke(nodeId, 1,
                            (startX / density).toDouble(), (startY / density).toDouble(),
                            (startX / density).toDouble(), (startY / density).toDouble())
                    }
                )
            }
        } else Modifier

        // Layout handling (Swift-driven absolute positioning)
        val layout = if (node.has("layout")) node.getJSONObject("layout") else null
        var layoutModifier = Modifier as Modifier
        if (layout != null) {
            val lx = layout.optDouble("x", Double.NaN)
            val ly = layout.optDouble("y", Double.NaN)
            val lw = layout.optDouble("width", Double.NaN)
            val lh = layout.optDouble("height", Double.NaN)
            if (!lx.isNaN() && !ly.isNaN()) {
                layoutModifier = layoutModifier.absoluteOffset(lx.dp, ly.dp)
            }
            if (!lw.isNaN()) {
                layoutModifier = layoutModifier.width(lw.dp)
            }
            if (!lh.isNaN()) {
                layoutModifier = layoutModifier.height(lh.dp)
            }
        }

        Box(modifier = dragModifier.then(layoutModifier)) {
            when (type) {
                "window" -> {
                    RenderContainer(children, onNewJson)
                    if (props.optString("clearFocus", "") == "true") {
                        val focusManager = androidx.compose.ui.platform.LocalFocusManager.current
                        LaunchedEffect(Unit) { focusManager.clearFocus() }
                    }
                }
                "text" -> RenderText(props)
                "button" -> RenderButton(nodeId, props, children, onNewJson)
                "textfield" -> RenderTextField(nodeId, props, focusModifier, onNewJson)
                "securefield" -> RenderSecureField(nodeId, props, focusModifier, onNewJson)
                "texteditor" -> RenderTextEditor(nodeId, props, focusModifier, onNewJson)
                "toggle" -> RenderToggle(nodeId, props, onNewJson)
                "slider" -> RenderSlider(nodeId, props, onNewJson)
                "vstack" -> RenderVStack(node, props, children, onNewJson)
                "hstack" -> RenderHStack(node, props, children, onNewJson)
                "zstack" -> RenderZStack(children, onNewJson)
                "scrollview" -> RenderScrollView(props, children, onNewJson)
                "list" -> RenderList(children, onNewJson)
                "progressview" -> RenderProgressView(props)
                "filledShape" -> RenderFilledShape(props)
                "strokedShape" -> RenderStrokedShape(props)
                "clipShape" -> RenderClipShape(props, children, onNewJson)
                "sheet" -> RenderSheet(nodeId, children, onNewJson)
                "alert" -> RenderAlert(nodeId, props, children, onNewJson)
                "spacer" -> Spacer(modifier = Modifier.height(0.dp))
                "divider" -> HorizontalDivider(color = Color(0xFFCCCCCC), thickness = 1.dp)
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

            // Global pass for modal children (sheets, alerts).
            // This ensures they are rendered even by leaf views that ignore children.
            for (i in 0 until children.length()) {
                val child = children.getJSONObject(i)
                if (isModalType(child.optString("type", ""))) {
                    RenderNode(child, onNewJson)
                }
            }
        }

        // Apply programmatic focus after composition.
        // Only requestFocus for the focused node — do NOT clearFocus for others,
        // as clearFocus() clears ALL focus globally and would undo the requestFocus.
        if (focusedProp == "true") {
            LaunchedEffect(Unit) {
                focusRequester.requestFocus()
            }
        }
    }

    @Composable
    private fun RenderToggle(nodeId: Long, props: JSONObject, onNewJson: (String) -> Unit) {
        val label = props.optString("label", "")
        val isOn = props.optString("isOn", "false") == "true"
        
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth().padding(8.dp)
        ) {
            if (label.isNotEmpty()) {
                Text(label)
            }
            Switch(
                checked = isOn,
                onCheckedChange = { checked ->
                    if (nodeId != 0L) {
                        val newJson = onToggleChange?.invoke(nodeId, checked)
                        if (newJson != null) onNewJson(newJson)
                    }
                }
            )
        }
    }

    @Composable
    private fun RenderSlider(nodeId: Long, props: JSONObject, onNewJson: (String) -> Unit) {
        val value = props.optDouble("value", 0.0).toFloat()
        val min = props.optDouble("min", 0.0).toFloat()
        val max = props.optDouble("max", 1.0).toFloat()
        val step = props.optDouble("step", 0.0).toFloat()
        val steps = if (step > 0.0f) Math.max(0, ((max - min) / step).roundToInt() - 1) else 0

        Slider(
            value = value,
            onValueChange = { newValue ->
                if (nodeId != 0L) {
                    val newJson = onSliderChange?.invoke(nodeId, newValue.toDouble())
                    if (newJson != null) onNewJson(newJson)
                }
            },
            valueRange = min..max,
            steps = steps,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
        )
    }

    @Composable
    private fun RenderScrollView(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val axis = props.optString("axis", "vertical")
        
        when (axis) {
            "horizontal" -> {
                Row(modifier = Modifier.horizontalScroll(rememberScrollState())) {
                    RenderChildren(children, onNewJson)
                }
            }
            "both" -> {
                Box(modifier = Modifier.verticalScroll(rememberScrollState()).horizontalScroll(rememberScrollState())) {
                    Column {
                        RenderChildren(children, onNewJson)
                    }
                }
            }
            else -> {
                Column(modifier = Modifier.verticalScroll(rememberScrollState())) {
                    RenderChildren(children, onNewJson)
                }
            }
        }
    }

    @Composable
    private fun RenderList(children: JSONArray, onNewJson: (String) -> Unit) {
        // Filter out modal children for correct count and divider placement
        val filteredChildren = remember(children) {
            val list = mutableListOf<JSONObject>()
            for (i in 0 until children.length()) {
                val child = children.getJSONObject(i)
                if (!isModalType(child.optString("type", ""))) {
                    list.add(child)
                }
            }
            list
        }
        val itemCount = filteredChildren.size

        LazyColumn(modifier = Modifier.fillMaxSize()) {
            items(itemCount) { index ->
                val child = filteredChildren[index]
                Column(modifier = Modifier.fillMaxWidth()) {
                    Box(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                        RenderNode(child, onNewJson)
                    }
                    if (index < itemCount - 1) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 16.dp),
                            color = Color(0xFFCCCCCC),
                            thickness = 0.5.dp
                        )
                    }
                }
            }
        }
    }

    @Composable
    private fun RenderFilledShape(props: JSONObject) {
        val shape = propsToShape(props)
        val color = propsToColor(props)
        Box(modifier = Modifier.fillMaxSize().background(color, shape))
    }

    @Composable
    private fun RenderStrokedShape(props: JSONObject) {
        val shape = propsToShape(props)
        val color = propsToColor(props)
        val width = props.optDouble("lineWidth", 1.0).toFloat()
        Box(modifier = Modifier.fillMaxSize().border(width.dp, color, shape))
    }

    @Composable
    private fun RenderClipShape(props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        val shape = propsToShape(props)
        Box(modifier = Modifier.clip(shape)) {
            if (children.length() > 0) {
                RenderNode(children.getJSONObject(0), onNewJson)
            }
        }
    }

    @Composable
    private fun RenderSheet(nodeId: Long, children: JSONArray, onNewJson: (String) -> Unit) {
        if (children.length() > 0) {
            val content = children.getJSONObject(0)
            ModalBottomSheet(
                onDismissRequest = {
                    if (nodeId != 0L) {
                        val nj = onButtonClick?.invoke(nodeId)
                        if (nj != null) onNewJson(nj)
                    }
                }
            ) {
                Box(modifier = Modifier.padding(16.dp).navigationBarsPadding()) {
                    RenderNode(content, onNewJson)
                }
            }
        }
    }

    @Composable
    private fun RenderAlert(nodeId: Long, props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        AlertDialog(
            onDismissRequest = {
                if (nodeId != 0L) {
                    val nj = onButtonClick?.invoke(nodeId)
                    if (nj != null) onNewJson(nj)
                }
            },
            title = { Text(props.optString("title", "Alert")) },
            text = { Text(props.optString("message", "")) },
            confirmButton = {
                // If there are buttons, render them. Otherwise default to OK.
                if (children.length() > 0) {
                    Row {
                        for (i in 0 until children.length()) {
                            val btn = children.getJSONObject(i)
                            val btnProps = btn.getJSONObject("props")
                            val btnId = btn.optString("id", "0").toLongOrNull() ?: 0L
                            val role = btnProps.optString("role", "default")
                            
                            TextButton(
                                onClick = {
                                    if (btnId != 0L) {
                                        val nj = onButtonClick?.invoke(btnId)
                                        if (nj != null) onNewJson(nj)
                                    }
                                },
                                colors = if (role == "destructive") {
                                    ButtonDefaults.textButtonColors(contentColor = Color.Red)
                                } else {
                                    ButtonDefaults.textButtonColors()
                                }
                            ) {
                                Text(btnProps.optString("label", "OK"))
                            }
                        }
                    }
                } else {
                    TextButton(onClick = {
                        if (nodeId != 0L) {
                            val nj = onButtonClick?.invoke(nodeId)
                            if (nj != null) onNewJson(nj)
                        }
                    }) {
                        Text("OK")
                    }
                }
            }
        )
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
            singleLine = true,
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
    private fun RenderSecureField(nodeId: Long, props: JSONObject, focusModifier: Modifier, onNewJson: (String) -> Unit) {
        val placeholder = props.optString("placeholder", "")
        val text = props.optString("text", "")

        var tfValue by remember {
            mutableStateOf(TextFieldValue(text, TextRange(text.length)))
        }

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
            singleLine = true,
            visualTransformation = PasswordVisualTransformation(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
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
    private fun RenderTextEditor(nodeId: Long, props: JSONObject, focusModifier: Modifier, onNewJson: (String) -> Unit) {
        val text = props.optString("text", "")

        var tfValue by remember {
            mutableStateOf(TextFieldValue(text, TextRange(text.length)))
        }

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
            singleLine = false,
            modifier = focusModifier
                .fillMaxWidth()
                .border(1.dp, Color.Gray)
                .padding(8.dp)
                .heightIn(min = 100.dp),
            textStyle = TextStyle(fontSize = 16.sp)
        )
    }

    @Composable
    private fun RenderProgressView(props: JSONObject) {
        if (props.has("progress")) {
            val progressVal = props.optDouble("progress", 0.0).toFloat()
            LinearProgressIndicator(
                progress = { progressVal },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
            )
        } else {
            LinearProgressIndicator(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)
            )
        }
    }

    @Composable
    private fun RenderVStack(node: JSONObject, props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        if (node.has("layout")) {
            // Precision Layout: Swift-driven absolute positions.
            // Using a Box allows children to use absoluteOffset.
            Box(modifier = Modifier.fillMaxWidth()) {
                RenderChildren(children, onNewJson)
            }
        } else {
            // Fallback: Compose-driven layout
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
    }

    @Composable
    private fun RenderHStack(node: JSONObject, props: JSONObject, children: JSONArray, onNewJson: (String) -> Unit) {
        if (node.has("layout")) {
            // Precision Layout
            Box(modifier = Modifier.fillMaxWidth()) {
                RenderChildren(children, onNewJson)
            }
        } else {
            // Fallback: Compose-driven layout
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
    }

    @Composable
    private fun RenderZStack(children: JSONArray, onNewJson: (String) -> Unit) {
        Box(modifier = Modifier.fillMaxWidth()) {
            for (i in 0 until children.length()) {
                val child = children.getJSONObject(i)
                val childType = child.getString("type")
                if (isModalType(childType)) continue

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

        // Expose back node ID for system back button handling
        currentBackNodeId = if (showBack) backNodeId else 0

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
                val child = children.getJSONObject(i)
                if (!isModalType(child.optString("type", ""))) {
                    RenderNode(child, onNewJson)
                }
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
    private fun RenderChildren(children: JSONArray, onNewJson: (String) -> Unit) {
        for (i in 0 until children.length()) {
            val child = children.getJSONObject(i)
            if (!isModalType(child.optString("type", ""))) {
                RenderNode(child, onNewJson)
            }
        }
    }

    @Composable
    private fun ColumnScope.RenderChildren(children: JSONArray, onNewJson: (String) -> Unit) {
        for (i in 0 until children.length()) {
            val child = children.getJSONObject(i)
            val type = child.optString("type", "")
            if (type == "spacer") {
                Spacer(modifier = Modifier.weight(1f))
            } else if (!isModalType(type)) {
                RenderNode(child, onNewJson)
            }
        }
    }

    @Composable
    private fun RowScope.RenderChildren(children: JSONArray, onNewJson: (String) -> Unit) {
        for (i in 0 until children.length()) {
            val child = children.getJSONObject(i)
            val type = child.optString("type", "")
            if (type == "spacer") {
                Spacer(modifier = Modifier.weight(1f))
            } else if (!isModalType(type)) {
                RenderNode(child, onNewJson)
            }
        }
    }

    // MARK: - Helpers

    private fun isModalType(type: String): Boolean {
        return type == "sheet" || type == "alert"
    }

    /// A true inscribed circle shape for SwiftUI "Circle" semantics.
    /// Unlike CircleShape (which is an oval/pill), this always stays circular.
    private val TrueCircleShape = object : androidx.compose.ui.graphics.Shape {
        override fun createOutline(
            size: androidx.compose.ui.geometry.Size,
            layoutDirection: androidx.compose.ui.unit.LayoutDirection,
            density: androidx.compose.ui.unit.Density
        ): androidx.compose.ui.graphics.Outline {
            val minDim = kotlin.math.min(size.width, size.height)
            val rect = androidx.compose.ui.geometry.Rect(
                left = (size.width - minDim) / 2f,
                top = (size.height - minDim) / 2f,
                right = (size.width + minDim) / 2f,
                bottom = (size.height + minDim) / 2f
            )
            val path = androidx.compose.ui.graphics.Path()
            path.addOval(rect)
            return androidx.compose.ui.graphics.Outline.Generic(path)
        }
    }

    private fun propsToShape(props: JSONObject): androidx.compose.ui.graphics.Shape {
        val type = props.optString("shapeType", "rectangle")
        return when (type) {
            "circle" -> TrueCircleShape
            "capsule", "ellipse" -> androidx.compose.foundation.shape.CircleShape
            "roundedRectangle" -> {
                val radius = props.optDouble("cornerRadius", 0.0).toFloat()
                androidx.compose.foundation.shape.RoundedCornerShape(radius.dp)
            }
            else -> androidx.compose.ui.graphics.RectangleShape
        }
    }

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
