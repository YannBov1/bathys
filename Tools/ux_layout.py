from pathlib import Path
p=Path('Scripts/Main.gd');s=p.read_text()
s=s.replace('var header_box: BoxContainer','var header_box: HFlowContainer\nvar bottom_panel: PanelContainer\nvar playback_controls: Array[Control] = []')
s=s.replace('var heading := BoxContainer.new()','var heading := HFlowContainer.new()')
s=s.replace('\tidentity.size_flags_horizontal = Control.SIZE_EXPAND_FILL','\tidentity.custom_minimum_size.x = 260\n\tidentity.size_flags_horizontal = Control.SIZE_EXPAND_FILL',1)
s=s.replace('\theader_box.vertical = get_viewport_rect().size.x < 700','')
s=s.replace('var bottom: PanelContainer = BathysUiStyle.panel(BG, 9)','var bottom: PanelContainer = BathysUiStyle.panel(BG, 9)\n\tbottom_panel = bottom',1)
s=s.replace('\tplayback.add_child(details_toggle)','\tplayback.add_child(details_toggle)\n\tplayback_controls.append(details_toggle)',1)
s=s.replace('\tplayback.add_child(controls)','\tplayback.add_child(controls)\n\tplayback_controls.append(controls)',1)
s=s.replace('\tplayback.add_child(plot_buttons)','\tplayback.add_child(plot_buttons)\n\tplayback_controls.append(plot_buttons)',1)
s=s.replace('\tplayback.add_child(plot_scroll)','\tplot_scroll.custom_minimum_size.y = 145\n\tplayback.add_child(plot_scroll)\n\tplayback_controls.append(plot_scroll)',1)
s=s.replace('\tset_bathymetry(false)\n\nfunc scroll_column','\tset_bathymetry(false)\n\tset_playback_available(false)\n\nfunc scroll_column',1)
s=s.replace('\tfeedback_label.visible = false\n\tselected_event', '\tfeedback_label.visible = false\n\tset_playback_available(false)\n\tselected_event',1)
s=s.replace('\tshow_frame(playback_time)\n\tstatus_label.text = "Simulation up to date"','\tshow_frame(playback_time)\n\tset_playback_available(true)\n\tstatus_label.text = "Simulation up to date"',1)
s=s.replace('\tinspection.popup(Rect2i(at, popup_size))','''	inspection.popup(Rect2i(at, popup_size))
	# Wrapped text needs a layout frame before the window can shrink to its content.
	await get_tree().process_frame
	if is_instance_valid(inspection):
		inspection.size = popup_size
		inspection.position = at''',1)
s += '''
func set_playback_available(available: bool) -> void:
	for control: Control in playback_controls:
		control.visible = available
	bottom_panel.custom_minimum_size.y = 400 if available else 170
	if not available:
		extra_label.visible = false
'''
p.write_text(s)
# Preserve pinch/zoom browser accessibility on each export.
p=Path('export_presets.cfg');s=p.read_text();s=s.replace('html/head_include="', 'html/head_include="<script>document.addEventListener(\\\"DOMContentLoaded\\\",()=>document.querySelector(\\\"meta[name=viewport]\\\").setAttribute(\\\"content\\\",\\\"width=device-width, initial-scale=1.0\\\"));</script>\\n',1);p.write_text(s)
