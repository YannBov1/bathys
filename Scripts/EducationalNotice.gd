class_name BathysEducationalNotice
extends AcceptDialog

signal agreed

const NOTICE := "Bathys is an educational simulator.\n\nDo not use this app to plan, validate or carry out a real dive. Calculations, maps and examples may contain errors and omit real-world conditions.\n\nSurvey elevations and the water level are illustrative. This app does not replace training, certified equipment or professional guidance."
var language_picker: OptionButton
var body: VBoxContainer

func _ready() -> void:
	name = "EducationalNotice"
	borderless = true
	unresizable = true
	wrap_controls = false
	dialog_close_on_escape = false
	add_theme_constant_override("buttons_min_height", 44)
	get_label().hide()
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	add_child(body)
	var heading := BathysUiStyle.wrapped("Educational use only", 21, BathysUiStyle.AQUA)
	body.add_child(heading)
	language_picker = OptionButton.new()
	language_picker.name = "NoticeLanguage"
	language_picker.add_icon_item(preload("res://Assets/Icons/flag-en.svg"), "English")
	language_picker.add_icon_item(preload("res://Assets/Icons/flag-fr.svg"), "Français")
	language_picker.item_selected.connect(func(index: int) -> void: get_node("/root/I18n").set_language(["en", "fr"][index]))
	body.add_child(language_picker)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var message := BathysUiStyle.wrapped(NOTICE, 15, BathysUiStyle.TEXT)
	message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(message)
	get_ok_button().custom_minimum_size.y = 44
	get_ok_button().add_theme_font_size_override("font_size", 14)
	confirmed.connect(func() -> void: agreed.emit())
	get_node("/root/I18n").language_changed.connect(update_language)
	get_tree().root.size_changed.connect(fit)
	update_language()

func show_notice(required: bool = true) -> void:
	ok_button_text = "I understand and agree" if required else "Close"
	dialog_close_on_escape = not required
	fit()
	popup_centered(size)
	get_ok_button().grab_focus()

func update_language() -> void:
	language_picker.select(1 if get_node("/root/I18n").language == "fr" else 0)
	if visible: fit()

func fit() -> void:
	var available: Vector2i = get_tree().root.size
	var width: int = mini(520, available.x - 24)
	var height: int = mini(460, available.y - 24)
	body.custom_minimum_size = Vector2(maxi(200, width - 32), maxi(180, height - 88))
	body.reset_size()
	size = Vector2i(width, height)
	position = (available - size) / 2
