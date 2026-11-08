class_name BathysUiStyle
extends RefCounted

const BG := Color("071c29")
const PANEL := Color("0c2935")
const CARD := Color("113540")
const EDGE := Color("28515b")
const TEXT := Color("e6f8f4")
const MUTED := Color("91b6b9")
const AQUA := Color("71e5d9")

static func box(color: Color, border: Color = EDGE, radius: int = 10, padding: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 13
	for type: String in ["Button", "OptionButton", "LineEdit", "SpinBox", "TabContainer", "PopupMenu", "AcceptDialog"]:
		result.set_color("font_color", type, TEXT)
	for type: String in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type, box(CARD, EDGE, 7, 8))
		result.set_stylebox("hover", type, box(Color("1c4854"), AQUA, 7, 8))
		result.set_stylebox("pressed", type, box(Color("2d8e8c"), AQUA, 7, 8))
		result.set_stylebox("focus", type, box(Color(0,0,0,0), AQUA, 7, 8))
	result.set_stylebox("normal", "LineEdit", box(BG, EDGE, 5, 5))
	result.set_stylebox("focus", "LineEdit", box(BG, AQUA, 5, 5))
	result.set_stylebox("panel", "TabContainer", box(PANEL, EDGE, 8, 8))
	result.set_stylebox("tab_selected", "TabContainer", box(CARD, AQUA, 6, 9))
	result.set_stylebox("tab_unselected", "TabContainer", box(PANEL, EDGE, 6, 9))
	result.set_stylebox("panel", "AcceptDialog", box(PANEL, EDGE, 12, 16))
	result.set_constant("separation", "VBoxContainer", 7)
	result.set_constant("separation", "HBoxContainer", 7)
	return result

static func panel(color: Color = PANEL, padding: int = 10) -> PanelContainer:
	var node := PanelContainer.new()
	node.add_theme_stylebox_override("panel", box(color, EDGE, 10, padding))
	return node

static func column(parent: Node, separation: int = 7) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.add_theme_constant_override("separation", separation)
	parent.add_child(node)
	return node

static func wrapped(text: String, font_size: int = 12, color: Color = MUTED) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	return node
