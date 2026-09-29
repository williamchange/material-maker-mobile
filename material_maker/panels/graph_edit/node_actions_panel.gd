class_name NodeActionsPanel
extends PanelContainer

## floating panel for node titlebar actions, mainly for touch.

static var sb_selection : StyleBoxFlat

var parent : MMGraphEdit
var selection_area : Rect2

var is_updating : bool = false
var is_theme_updating : bool = false

var selected_nodes : Array

const BUTTON_SIZE : Vector2 = Vector2(16, 16)
const H_PADDING : int = 16
const AREA_PADDING : int = 24
const PADDING : Vector2 = Vector2(
		AREA_PADDING + H_PADDING, -AREA_PADDING)

var container : VBoxContainer
var buttons : Dictionary[String, Button]

func _init(graph : MMGraphEdit) -> void:
	name = "TouchActionsPanel"
	parent = graph
	parent.add_child(self)
	scale = Vector2(2.5, 2.5)

func _ready() -> void:
	hide()
	init_stylebox()
	setup_signals()

	container = VBoxContainer.new()
	create_buttons()
	add_child(container)

	theme_type_variation = "MM_PanelMenuSubPanel"

func _notification(what : int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		if not is_node_ready():
			await ready
		update_button_icons()
		update_stylebox()

func setup_signals() -> void:
	parent.node_selected.connect(should_update_selection.unbind(1))
	parent.scroll_offset_changed.connect(should_update_selection.unbind(1))
	parent.node_deselected.connect(hide_panel.unbind(1))
	parent.begin_node_move.connect(hide_panel)
	parent.connection_drag_started.connect(hide_panel.unbind(3))
	parent.draw.connect(draw_selection_area)

func create_buttons() -> void:
	buttons.close = add_button(parent.remove_selection)
	buttons.minimize = add_button(parent.minimize_selection)
	buttons.randomize = add_button(parent._on_button_reroll_pressed)

	container.add_child(buttons.close)
	container.add_child(buttons.minimize)
	container.add_child(buttons.randomize)

func update_button_icons() -> void:
	buttons.close.icon = get_theme_icon("delete_2x", "MM_Icons")
	buttons.minimize.icon = get_theme_icon("minimize", "MM_Icons")
	buttons.randomize.icon = get_theme_icon("randomize", "MM_Icons")

func add_button(callback : Callable = Callable()) -> Button:
	var button = Button.new()
	button.custom_minimum_size = BUTTON_SIZE
	button.flat = true
	button.expand_icon = true
	button.pressed.connect(callback)
	return button

func init_stylebox() -> void:
	if not sb_selection:
		sb_selection = StyleBoxFlat.new()
		sb_selection.bg_color = Color(0.207, 0.207, 0.207, 1.0)
		sb_selection.border_color = Color(0.376, 0.376, 0.376, 1.0)
		sb_selection.set_border_width_all(2)
		sb_selection.set_corner_radius_all(4)
		sb_selection.corner_detail = 4

func update_stylebox() -> void:
	if not sb_selection:
		init_stylebox()
	var theme_path : String = mm_globals.main_window.theme.resource_path
	if "classic" in theme_path:
		sb_selection.bg_color = Color(0.204, 0.231, 0.31)
		sb_selection.border_color = Color(0.325, 0.463, 0.682)
	elif "dark" in theme_path:
		sb_selection.bg_color = Color(0.14, 0.14, 0.14, 1.0)
		sb_selection.border_color = Color(0.355, 0.355, 0.355, 1.0)
	else:
		sb_selection.bg_color = Color(0.521, 0.521, 0.521, 1.0)
		sb_selection.border_color = Color(0.23, 0.23, 0.23, 1.0)

func draw_selection_area() -> void:
	if selection_area.size != Vector2.ZERO and sb_selection and visible:
		var ci : RID = parent.get_canvas_item()
		sb_selection.draw(ci, selection_area.grow(AREA_PADDING))

func update_selection() -> void:
	if not is_node_ready():
		return
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		await get_tree().process_frame

	selected_nodes = parent.get_selected_nodes()
	if selected_nodes.is_empty():
		hide_panel()
		return

	for key : String in buttons:
		buttons[key].show()

	var nodes_rect : Rect2 = Rect2(0, 0, -1, -1)
	for n in selected_nodes:
		if nodes_rect.size == Vector2(-1, -1):
			nodes_rect = calc_node_rect(n)
		else:
			nodes_rect = nodes_rect.merge(calc_node_rect(n))

		if not n.tree_exiting.is_connected(should_update_selection):
			n.tree_exiting.connect(should_update_selection)

	position = nodes_rect.get_support(Vector2(1, -1))

	if selected_nodes.size() == 1:
		selection_area = Rect2()
		position.x += AREA_PADDING

		var node : MMGraphNodeMinimal = selected_nodes[0]
		if node.get_script() in [ MMGraphPortal, MMGraphReroute ]:
			buttons.minimize.hide()
			buttons.randomize.hide()
			position = node.position
			position.x += node.size.x * 0.5 * parent.zoom - size.x
			position.y += (node.size.y + H_PADDING) * parent.zoom
		else:
			var gen : MMGenBase = node.generator
			buttons.close.visible = gen.can_be_deleted()
			buttons.randomize.visible = gen.has_randomness()
	elif selected_nodes.size() > 1:
		selection_area = nodes_rect
		position += PADDING

		buttons.close.visible = node_selection_can_be_deleted()
		buttons.randomize.visible = node_selection_has_randomness()
		buttons.minimize.show()

	size = Vector2.ZERO
	show_panel()

func show_panel() -> void:
	show()
	move_to_front()
	parent.queue_redraw()
	is_updating = false

func hide_panel() -> void:
	hide()
	selection_area = Rect2()
	parent.queue_redraw()
	is_updating = false

func should_update_selection() -> void:
	if is_updating:
		return
	is_updating = true
	update_selection.call_deferred()

func calc_node_rect(n : GraphElement) -> Rect2:
	if n is MMGraphPortal:
		var r : Rect2 = n.get_rect_with_link()
		return Rect2(r.position * parent.zoom + n.position,
				r.size * parent.zoom)
	return Rect2(n.position, n.size * parent.zoom)

func node_selection_has_randomness() -> bool:
	for node in selected_nodes:
		var g : MMGenBase = node.generator
		if g and g.has_randomness():
			return true
	return false

func node_selection_can_be_deleted() -> bool:
	for node in selected_nodes:
		var g : MMGenBase = node.generator
		if g and g.can_be_deleted():
			return true
	return false
