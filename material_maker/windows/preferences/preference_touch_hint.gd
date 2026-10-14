extends PanelContainer

var highlight : StyleBoxFlat

var t : Tween

func _ready() -> void:
	if not OS.get_name() == "Android":
		queue_free()
		return
	highlight = StyleBoxFlat.new()
	highlight.set_corner_radius_all(4)
	highlight.corner_detail = 3
	highlight.bg_color = Color.WEB_GRAY
	highlight.bg_color.a = 0.1
	highlight.set_expand_margin_all(4.0)

	var prefs : TabContainer = get_node("../TabContainer")
	for tab in prefs.get_children():
		for container in tab.get_child(0).get_children():
			if container is not Container:
				continue
			for control : Control in container.get_children():
				if control.get_script() in [BoolOption, EnumOption, FloatOption]:
					control.mouse_entered.connect(
							_pref_item_mouse_entered.bind(container, control.tooltip_text))
					container.mouse_entered.connect(
							_pref_item_mouse_entered.bind(container, control.tooltip_text))
					container.mouse_exited.connect(
							_pref_item_mouse_exited.bind(container))
					control.mouse_exited.connect(
							_pref_item_mouse_exited.bind(container))
					break

func _pref_item_mouse_entered(c : Container, hint : String) -> void:
	highlight.draw.call_deferred(c.get_parent().get_canvas_item(), c.get_rect())
	$MarginContainer/VBoxContainer/TouchHintLabel.text = hint.replacen("\n", " ")
	await get_tree().process_frame
	await get_tree().process_frame
	var x : VScrollBar = $MarginContainer/VBoxContainer.get_v_scroll_bar()
	if t:
		t.kill()
	# do not animate scroll if the text still fits
	if abs(x.max_value -  $MarginContainer/VBoxContainer.size.y) > 5.0:
		t = get_tree().create_tween()
		t.set_loops().set_trans(Tween.TRANS_LINEAR)
		t.tween_property(x, "value", x.max_value, 1.25).set_delay(2.0)
		t.tween_property(x, "value", 0.0, 0.8).set_delay(2.0)

func _pref_item_mouse_exited(c : Container) -> void:
	c.get_parent().queue_redraw()
	$MarginContainer/VBoxContainer/TouchHintLabel.text = ""
	await get_tree().process_frame
	if t:
		t.kill()
