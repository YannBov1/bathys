class_name BathysI18n
extends Node

signal language_changed
const PREFERENCE_PATH := "user://language.cfg"
var french_messages: Dictionary = {}
var language: String = "en"

static func text(message: String) -> String:
	return TranslationServer.translate(message)

func _ready() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Data/i18n/fr.json"))
	if parsed is Dictionary:
		french_messages = parsed
	var french := Translation.new()
	french.locale = "fr"
	for message: String in french_messages:
		french.add_message(message, str(french_messages[message]))
	TranslationServer.add_translation(french)
	var preferences := ConfigFile.new()
	if preferences.load(PREFERENCE_PATH) == OK:
		var saved: String = str(preferences.get_value("interface", "language", "en"))
		if saved in ["en", "fr"]:
			language = saved
	TranslationServer.set_locale(language)
	update_document_language()

func set_language(value: String, persist: bool = true) -> void:
	if value not in ["en", "fr"]:
		return
	language = value
	TranslationServer.set_locale(language)
	if persist:
		var preferences := ConfigFile.new()
		preferences.set_value("interface", "language", language)
		preferences.save(PREFERENCE_PATH)
	update_document_language()
	language_changed.emit()

func update_document_language() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("document.documentElement.lang = '" + language + "';", true)
