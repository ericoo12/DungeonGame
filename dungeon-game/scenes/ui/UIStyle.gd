## Shared UI look for menus/overlays (InventoryOverlay, MainMenu): one palette and a
## few builders so every screen matches. Change a colour here and it changes everywhere.
class_name UIStyle
extends RefCounted

# --- Palette (sewer: dark slate + mossy borders, gold highlight) -------------
const COL_DIM := Color(0.0, 0.0, 0.0, 0.65)
const COL_PANEL := Color(0.078, 0.094, 0.102, 0.97)
const COL_PANEL_BORDER := Color(0.33, 0.41, 0.33)
const COL_INSET := Color(0.055, 0.066, 0.072)
const COL_SLOT := Color(0.12, 0.14, 0.15)
const COL_SLOT_HOVER := Color(0.16, 0.19, 0.19)
const COL_SLOT_BORDER := Color(0.24, 0.29, 0.27)
const COL_FOCUS := Color(0.91, 0.76, 0.36)
const COL_ACTIVE := Color(0.45, 0.78, 0.62)
const COL_PASSIVE := Color(0.56, 0.71, 0.87)
const COL_TITLE := Color(0.91, 0.76, 0.36)
const COL_TEXT := Color(0.88, 0.89, 0.86)
const COL_MUTED := Color(0.55, 0.58, 0.56)
const COL_GOOD := Color(0.55, 0.82, 0.49)
const COL_BAD := Color(0.88, 0.48, 0.42)


## Flat pixel-style box (no anti-aliasing, tiny corner radius).
static func box(fill: Color, border: Color, border_width: int, padding: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = border
	b.set_border_width_all(border_width)
	b.set_corner_radius_all(2)
	b.anti_aliasing = false
	b.set_content_margin_all(padding)
	return b


## Outlined label.
static func label(text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3 if font_size < 20 else 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func divider() -> HSeparator:
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = COL_SLOT_BORDER
	line.thickness = 2
	sep.add_theme_stylebox_override("separator", line)
	return sep


## Text button: slot-coloured, gold border + gold text when focused/hovered.
static func style_button(button: Button, font_size: int = 20) -> void:
	button.add_theme_stylebox_override("normal", box(COL_SLOT, COL_SLOT_BORDER, 2, 10))
	button.add_theme_stylebox_override("hover", box(COL_SLOT_HOVER, COL_FOCUS, 3, 10))
	button.add_theme_stylebox_override("pressed", box(COL_INSET, COL_FOCUS, 3, 10))
	button.add_theme_stylebox_override("focus", box(COL_SLOT_HOVER, COL_FOCUS, 3, 10))
	button.add_theme_stylebox_override("disabled", box(COL_INSET, COL_SLOT_BORDER, 2, 10))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", COL_TEXT)
	button.add_theme_color_override("font_hover_color", COL_FOCUS)
	button.add_theme_color_override("font_focus_color", COL_FOCUS)
	button.add_theme_color_override("font_pressed_color", COL_FOCUS)
	button.add_theme_color_override("font_hover_pressed_color", COL_FOCUS)
	button.add_theme_color_override("font_disabled_color", COL_MUTED)
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", 4)


## "Space", "I", ... for the first key bound to `action`.
static func action_key_text(action: String) -> String:
	var keys := action_keys(action)
	return keys[0] if not keys.is_empty() else "?"


## Every key bound to `action`, as display strings.
static func action_keys(action: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not InputMap.has_action(action):
		return out
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			out.append(OS.get_keycode_string(code))
	return out
