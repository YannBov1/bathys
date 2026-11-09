from pathlib import Path
p=Path('Scripts/Main.gd');s=p.read_text().replace('\trefresh_route()\n\ttissue_scale_bar','\tupdate_route_summaries()\n\tfor card: Node in route_list.get_children():\n\t\tif card is PanelContainer:\n\t\t\t(card as PanelContainer).remove_theme_stylebox_override("panel")\n\ttissue_scale_bar',1)
s=s.replace('\tinspection = PopupPanel.new()\n\tadd_child(inspection)','\tinspection = PopupPanel.new()\n\tinspection.add_theme_stylebox_override("panel", BathysUiStyle.box(BathysUiStyle.CARD, AQUA, 10, 12))\n\tadd_child(inspection)',1)
s=s.replace('\tinspection.reset_size()\n\tvar viewport_size', '\tfor child: Node in body.get_children():\n\t\tif child is Label:\n\t\t\t(child as Label).custom_minimum_size.x = 290\n\tinspection.reset_size()\n\tvar viewport_size',1)
s=s.replace('var popup_size := Vector2i(inspection.get_contents_minimum_size())','var popup_size := Vector2i(320, 270)')
s=s.replace('\tcontent_box.vertical = narrow','\tcontent_box.vertical = narrow\n\tcontent_box.move_child(center_panel, 0 if narrow else 1)',1)
s=s.replace('\tvar gas:','\tvar gas:')
# Draft errors should not leave seek controls pointing at stale charts.
s=s.replace('\t\tmetric_label.text = "Simulation unavailable"','\t\tmetric_label.text = "Simulation unavailable"\n\t\tscrubber.set_value_no_signal(0)\n\t\tscrubber.max_value = 0',1)
# Avoid a misleading empty starting-gas dropdown.
s=s.replace('\tgas_selector(tank_list, plan, "initialTankId")','\tif not (plan["tanks"] as Array).is_empty():\n\t\tgas_selector(tank_list, plan, "initialTankId")',1)
p.write_text(s)
