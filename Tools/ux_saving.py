from pathlib import Path
p=Path('Scripts/Main.gd');s=p.read_text()
s=s.replace('accept_plan(FileAccess.get_file_as_string(PLAN_PATH))','accept_plan(FileAccess.get_file_as_string(PLAN_PATH), true)')
s=s.replace('func accept_plan(text: String) -> void:', 'func accept_plan(text: String, from_device: bool = false) -> void:')
s=s.replace('\tsaved_state = JSON.stringify(plan)\n\tupdate_saved_state()\n\tvar name_input', '\tif from_device:\n\t\tsaved_state = JSON.stringify(plan)\n\tupdate_saved_state()\n\tvar name_input',1)
s=s.replace('\taccept_plan(str(args[0]))\n\tsave_plan()', '\taccept_plan(str(args[0]))')
s=s.replace('func update_saved_state() -> void:\n\tif save_state_label', '''func update_saved_state() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.bathysHasChanges = " + ("true" if JSON.stringify(plan) != saved_state else "false"), true)
	if save_state_label''',1)
s=s.replace('\tset_playback_available(false)\n\nfunc scroll_column','''	set_playback_available(false)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.addEventListener('beforeunload', function(e) { if(window.bathysHasChanges) { e.preventDefault(); e.returnValue = ''; } });", true)

func scroll_column''',1)
p.write_text(s)
p=Path('Tests/UiSmoke.gd');s=p.read_text().replace('all ten live physiology readouts are visible','all ten physiology readouts remain available');p.write_text(s)
