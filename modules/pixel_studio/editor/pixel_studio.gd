@tool
extends EditorPlugin
## Built into the editor by the pixel_studio module; no project addon installation.

const SECTIONS = ["Сцены", "Объекты", "Манекены", "Энтити", "Анимации", "Шейдеры", "UI", "Кат-сцены", "ИИ", "Частицы"]
const DESCRIPTIONS = [
	"Составляйте мир из вложенных сцен. PixelWorld3D задаёт низкое разрешение и целочисленное масштабирование при запуске.",
	"Декорации без скриптов: многогранники, материалы и коллизия. Сохранённую сцену можно многократно использовать в мире.",
	"Персонажи и существа: составная модель, Skeleton3D, кости и BoneAttachment3D для снаряжения.",
	"Интерактивные предметы: модель, несколько точек крепления, коллизия и логика на корневом узле.",
	"Анимации манекенов и энтити. Редактируйте дорожки костей, деталей и точек крепления в AnimationPlayer.",
	"Живой стенд материала. Квантование цвета и освещения; затем откройте шейдер в штатном редакторе.",
	"Экранный интерфейс на Control: контейнеры, текст, инвентарь. Сцену UI можно вложить в мир или кат-сцену.",
	"Кат-сцена живёт внутри текущего мира. start(player_camera) переключает только указанный viewport; finish() возвращает камеру.",
	"Граф действий: соединяйте выходы со входами. Один advance() выполняет один шаг; action_requested подключается к игровой логике.",
	"Переиспользуемые GPUParticles3D. Вкладывайте эффект в сцену, деталь, точку крепления или кость."
]
const ROOT_TYPES = ["PixelWorld3D", "PixelObject3D", "PixelMannequin3D", "PixelEntity3D", "", "", "Control", "PixelCutscene3D", "PixelBrain3D", "GPUParticles3D"]
const ACTIONS = ["search_object", "find_path", "try_hit_player", "show_ui", "custom_action"]
const PIXEL_SHADER = """shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec4 base_color : source_color = vec4(0.42, 0.68, 0.34, 1.0);
uniform float color_steps : hint_range(2.0, 32.0, 1.0) = 8.0;
uniform float light_steps : hint_range(2.0, 8.0, 1.0) = 4.0;
void fragment() {
	ALBEDO = floor(base_color.rgb * color_steps + 0.5) / color_steps;
	ROUGHNESS = 1.0;
}
void light() {
	float shade = floor(max(dot(NORMAL, LIGHT), 0.0) * light_steps) / light_steps;
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * shade / PI;
}
"""

var screen: VBoxContainer
var content: VBoxContainer
var section := 0
var path_field: LineEdit
var status: Label
var shape: OptionButton
var tint: ColorPickerButton
var grid: SpinBox
var preview: SubViewport
var material: ShaderMaterial
var graph_view: GraphEdit
var graph_steps: Array[Dictionary] = []
var graph_action: OptionButton
var native_dock: Node


func _enter_tree() -> void:
	screen = VBoxContainer.new()
	screen.name = "PixelStudio"
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Godot master supports native main-screen docks. The fallback permits UI smoke tests on 4.7.
	if ClassDB.class_exists("EditorDock") and ClassDB.class_has_integer_constant("EditorDock", "DOCK_SLOT_MAIN_SCREEN"):
		native_dock = ClassDB.instantiate("EditorDock")
		native_dock.set("title", _get_plugin_name())
		native_dock.set("layout_key", _get_plugin_name().replace(" ", ""))
		native_dock.set("default_slot", ClassDB.class_get_integer_constant("EditorDock", "DOCK_SLOT_MAIN_SCREEN"))
		native_dock.set("available_layouts", ClassDB.class_get_integer_constant("EditorDock", "DOCK_LAYOUT_MAIN_SCREEN"))
		native_dock.add_child(screen)
		call("add_dock", native_dock)
	else:
		EditorInterface.get_editor_main_screen().add_child(screen)
		screen.hide()
	var heading := Label.new()
	heading.text = "PIXEL STUDIO   /   3D Pixel Art"
	heading.add_theme_font_size_override("font_size", 24)
	screen.add_child(heading)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(split)
	var navigation := ItemList.new()
	navigation.custom_minimum_size.x = 160
	navigation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for title in SECTIONS:
		navigation.add_item(title)
	navigation.item_selected.connect(_show_section)
	split.add_child(navigation)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen.add_child(status)
	navigation.select(0)
	_show_section(0)


func _exit_tree() -> void:
	if is_instance_valid(native_dock):
		call("remove_dock", native_dock)
		native_dock.queue_free()
	elif is_instance_valid(screen):
		screen.queue_free()


func _has_main_screen() -> bool:
	return not ClassDB.class_exists("EditorDock") or not ClassDB.class_has_integer_constant("EditorDock", "DOCK_SLOT_MAIN_SCREEN")


func _get_plugin_name() -> String:
	return "Pixel Studio"


func _make_visible(visible: bool) -> void:
	if is_instance_valid(screen):
		screen.visible = visible


func _label(text: String, parent: Node = null) -> Label:
	if parent == null:
		parent = content
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _button(text: String, callback: Callable, parent: Node = null) -> Button:
	if parent == null:
		parent = content
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _native(type: String) -> Node:
	return ClassDB.instantiate(type) as Node


func _show_section(index: int) -> void:
	section = index
	preview = null
	graph_view = null
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	_label(SECTIONS[index]).add_theme_font_size_override("font_size", 22)
	_label(DESCRIPTIONS[index])
	status.text = ""
	if index == 4:
		_button("Добавить AnimationPlayer и клип idle в текущую сцену", _add_animation)
		_button("Открыть AnimationPlayer текущей сцены", _open_animation)
		_label("Выберите кость, деталь или точку крепления в дереве. Ключи позиции, поворота и масштаба добавляются через инспектор. Покадровые скрипты деталей не нужны.")
		return
	path_field = LineEdit.new()
	path_field.placeholder_text = "res://pixel_assets/name.tscn"
	path_field.text = "res://pixel_assets/" + ["world", "object", "mannequin", "entity", "animation", "material", "interface", "cutscene", "brain", "particles"][index] + (".tres" if index == 5 else ".tscn")
	content.add_child(path_field)
	_button("Сохранить новую заготовку и открыть", _create_asset)
	if index in [1, 2, 3]:
		_build_model_tools()
	elif index == 0:
		_label("Профиль по умолчанию: 480 × 270, orthographic, целочисленный масштаб, без TAA / MSAA. Разрешение меняется на PixelWorld3D. Нажмите F6 для запуска сохранённого мира.")
		_button("Открыть текущую сцену в 3D", func(): EditorInterface.set_main_screen_editor("3D"))
	elif index == 5:
		_build_shader_tools()
	elif index == 6:
		_button("Редактировать текущий UI в 2D", func(): EditorInterface.set_main_screen_editor("2D"))
		_label("Заготовка содержит панель, текст и сетку слотов. 2D используется как рабочая область интерфейса, отдельный 2D-игровой режим не входит в профиль Pixel Studio.")
	elif index == 7:
		_label("В заготовке: камера, зона Area3D, временная сцена и AnimationPlayer. Зона сама не запускает ролик: подключите body_entered или вызовите start() из сценария. После finish() временная сцена удаляется, after_cast_scene добавляется рядом с кат-сценой.")
	elif index == 8:
		_build_graph_tools()
	elif index == 9:
		_label("Заготовка использует кубические частицы и ограничение 32 штуки. Материал, скорость, время жизни и объём эмиссии доступны в инспекторе.")


func _build_model_tools() -> void:
	_label("Конструктор текущей сцены")
	shape = OptionButton.new()
	for title in ["Куб", "Призма", "Цилиндр (6 граней)", "Сфера (низкая детализация)"]:
		shape.add_item(title)
	content.add_child(shape)
	tint = ColorPickerButton.new()
	tint.color = Color("87b879")
	content.add_child(tint)
	grid = SpinBox.new()
	grid.min_value = 0.0625
	grid.max_value = 4.0
	grid.step = 0.0625
	grid.value = 0.25
	grid.prefix = "Сетка: "
	content.add_child(grid)
	_button("Добавить многогранник", _add_piece)
	_button("Привязать выбранные детали к сетке", _snap_selection)
	_button("Поставить вторую выбранную деталь на первую", _stack_selection)
	_button("Применить цвет к выбранным деталям", _color_selection)
	_button("Добавить коробочную коллизию выбранных деталей", _add_collision)
	if section == 2:
		_button("Добавить кость в Skeleton3D", _add_bone)
		_button("Добавить крепление к последней кости", _add_bone_attachment)
	if section == 3:
		_button("Добавить точку крепления", _add_anchor)
	_label("Позиция, вращение, масштаб, свечение и скрипт — в инспекторе. Добавление и изменения поддерживают Undo / Redo. Детали со скриптами вызываются через call(); логика персонажа живёт на корне.")


func _make_piece(kind: int = 0) -> MeshInstance3D:
	var piece := _native("PixelPiece3D") as MeshInstance3D
	piece.name = "Piece"
	match kind:
		0: piece.mesh = BoxMesh.new()
		1: piece.mesh = PrismMesh.new()
		2:
			var cylinder := CylinderMesh.new()
			cylinder.radial_segments = 6
			piece.mesh = cylinder
		3:
			var sphere := SphereMesh.new()
			sphere.radial_segments = 8
			sphere.rings = 4
			piece.mesh = sphere
	var surface := StandardMaterial3D.new()
	surface.albedo_color = Color("87b879")
	surface.roughness = 1.0
	surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	piece.material_override = surface
	return piece


func _adopt(parent: Node, child: Node, child_name: String = "") -> Node:
	if not child_name.is_empty():
		child.name = child_name
	parent.add_child(child, true)
	return child


func _own_children(parent: Node, root: Node) -> void:
	for child in parent.get_children():
		child.owner = root
		_own_children(child, root)


func _animation_player() -> AnimationPlayer:
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 1.0
	clip.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("idle", clip)
	player.add_animation_library("", library)
	return player


func _make_asset() -> Node:
	var root: Node
	if section == 6:
		root = Control.new()
		root.name = "PixelUI"
		root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var panel := PanelContainer.new()
		panel.position = Vector2(12, 12)
		_adopt(root, panel, "Inventory")
		var column := VBoxContainer.new()
		_adopt(panel, column, "Layout")
		_label("Инвентарь", column)
		var slots := GridContainer.new()
		slots.columns = 4
		_adopt(column, slots, "Slots")
		for i in 8:
			var slot := Button.new()
			slot.text = str(i + 1)
			slot.custom_minimum_size = Vector2(32, 32)
			_adopt(slots, slot, "Slot" + str(i + 1))
	elif section == 9:
		var particles := GPUParticles3D.new()
		particles.name = "PixelParticles"
		particles.amount = 32
		particles.lifetime = 0.8
		particles.fixed_fps = 12
		var process := ParticleProcessMaterial.new()
		process.initial_velocity_min = 1.0
		process.initial_velocity_max = 2.0
		process.direction = Vector3.UP
		process.gravity = Vector3(0, -2, 0)
		particles.process_material = process
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.08
		particles.draw_pass_1 = cube
		root = particles
	elif section == 8:
		root = _native("PixelBrain3D")
		root.name = "PixelBrain"
		var behavior := ClassDB.instantiate("PixelBehaviorGraph") as Resource
		behavior.set("steps", graph_steps)
		root.set("graph", behavior)
	elif section == 7:
		root = _native("PixelCutscene3D")
		root.name = "PixelCutscene"
		var camera := _native("PixelCamera3D") as Camera3D
		camera.current = false
		_adopt(root, camera, "Camera")
		root.set("camera_path", NodePath("Camera"))
		var props := Node3D.new()
		props.name = "TemporaryProps"
		var marker := _make_piece(1)
		marker.position.y = 1.0
		_adopt(props, marker, "Marker")
		_own_children(props, props)
		var temporary := PackedScene.new()
		temporary.pack(props)
		props.free()
		root.set("temporary_scene", temporary)
		var area := Area3D.new()
		_adopt(root, area, "TriggerZone")
		var collision := CollisionShape3D.new()
		collision.shape = BoxShape3D.new()
		_adopt(area, collision, "Shape")
		var player := _animation_player()
		var clip := player.get_animation("idle")
		clip.loop_mode = Animation.LOOP_NONE
		clip.length = 3.0
		var track := clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(track, NodePath("Camera"))
		clip.position_track_insert_key(track, 0.0, camera.position)
		clip.position_track_insert_key(track, 3.0, camera.position + Vector3(2, 0, 0))
		_adopt(root, player)
		root.connect("started", Callable(player, "play").bind("idle"), CONNECT_PERSIST)
		player.connect("animation_finished", Callable(root, "finish").unbind(1), CONNECT_PERSIST)
	else:
		root = _native(ROOT_TYPES[section])
		root.name = ["PixelWorld", "PixelObject", "PixelMannequin", "PixelEntity"][section]
		if section == 0:
			var camera := _native("PixelCamera3D") as Camera3D
			camera.current = true
			_adopt(root, camera, "Camera")
			var sun := DirectionalLight3D.new()
			sun.rotation_degrees = Vector3(-55, -30, 0)
			sun.shadow_enabled = true
			_adopt(root, sun, "Sun")
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color("202d38")
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color("a5bfc1")
			environment.environment.ambient_light_energy = 0.5
			_adopt(root, environment, "Environment")
			var ground := _native("PixelObject3D")
			_adopt(root, ground, "Ground")
			var tile := _make_piece()
			tile.scale = Vector3(10, 0.25, 10)
			tile.position.y = -0.25
			_adopt(ground, tile, "Tile")
			var prop := _make_piece(1)
			prop.position.y = 0.5
			_adopt(root, prop, "Sample")
		else:
			if section == 2:
				var skeleton := Skeleton3D.new()
				skeleton.add_bone("root")
				skeleton.add_bone("hand_r")
				skeleton.set_bone_parent(1, 0)
				skeleton.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0.75, 0.3, 0)))
				skeleton.set_bone_pose_position(1, Vector3(0.75, 0.3, 0))
				_adopt(root, skeleton, "Skeleton3D")
				var attachment := BoneAttachment3D.new()
				attachment.bone_name = "hand_r"
				_adopt(skeleton, attachment, "HandSocket")
				var body_attachment := BoneAttachment3D.new()
				body_attachment.bone_name = "root"
				_adopt(skeleton, body_attachment, "BodyRig")
				var body := _make_piece()
				body.scale = Vector3(0.6, 0.9, 0.35)
				body.position.y = 0.6
				_adopt(body_attachment, body, "Body")
				var head := _make_piece()
				head.scale = Vector3.ONE * 0.4
				head.position.y = 1.3
				_adopt(body_attachment, head, "Head")
				_adopt(root, _animation_player())
			elif section == 3:
				_adopt(root, _make_piece(), "Body")
				_adopt(root, _native("PixelAnchor3D"), "Grip")
				_adopt(root, _animation_player())
			else:
				_adopt(root, _make_piece(), "Body")
	_own_children(root, root)
	return root


func _create_asset() -> void:
	var path := path_field.text.strip_edges().simplify_path()
	var extension := ".tres" if section == 5 else ".tscn"
	if not path.begins_with("res://") or not path.ends_with(extension) or path.contains(".."):
		status.text = "Укажите путь внутри res:// с расширением " + extension
		return
	if FileAccess.file_exists(path):
		status.text = "Файл уже существует. Выберите новое имя: существующие ресурсы не перезаписываются."
		return
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		status.text = "Не удалось создать каталог: " + error_string(error)
		return
	if section == 5:
		error = ResourceSaver.save(material, path)
		if error == OK:
			EditorInterface.get_resource_filesystem().scan()
			EditorInterface.edit_resource(load(path))
	else:
		var root := _make_asset()
		var packed := PackedScene.new()
		error = packed.pack(root)
		root.free()
		if error == OK:
			error = ResourceSaver.save(packed, path)
		if error == OK:
			EditorInterface.get_resource_filesystem().scan()
			EditorInterface.open_scene_from_path(path)
	status.text = ("Создано: " + path) if error == OK else ("Ошибка сохранения: " + error_string(error))


func _scene() -> Node:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		status.text = "Сначала создайте или откройте сцену."
	return root


func _model_scene() -> Node:
	var root := _scene()
	if root != null and root.get_class() not in ["PixelObject3D", "PixelEntity3D", "PixelMannequin3D"]:
		status.text = "Откройте сцену объекта, манекена или энтити."
		return null
	return root


func _insert(parent: Node, node: Node, title: String) -> void:
	var root := _scene()
	if root == null:
		node.free()
		return
	var undo := get_undo_redo()
	undo.create_action(title, UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(parent, "add_child", node, true)
	undo.add_do_method(node, "set_owner", root)
	undo.add_do_method(self, "_own_children", node, root)
	undo.add_do_reference(node)
	undo.add_undo_method(parent, "remove_child", node)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	EditorInterface.inspect_object(node)
	status.text = title + " · Ctrl+Z — отмена"


func _add_piece() -> void:
	var root := _model_scene()
	if root != null:
		var piece := _make_piece(shape.selected)
		piece.material_override.albedo_color = tint.color
		_insert(root, piece, "Добавить деталь")


func _selected_pieces() -> Array[MeshInstance3D]:
	var pieces: Array[MeshInstance3D] = []
	var root := _model_scene()
	if root == null:
		return pieces
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node.get_class() == "PixelPiece3D" and root.is_ancestor_of(node) and node.owner == root:
			pieces.append(node)
	if pieces.is_empty():
		status.text = "Выберите детали PixelPiece3D в дереве текущей сцены."
	return pieces


func _snap_selection() -> void:
	var pieces := _selected_pieces()
	if pieces.is_empty():
		return
	var undo := get_undo_redo()
	undo.create_action("Привязать детали к сетке", UndoRedo.MERGE_DISABLE, _scene())
	for piece in pieces:
		undo.add_do_property(piece, "position", piece.position.snapped(Vector3.ONE * grid.value))
		undo.add_undo_property(piece, "position", piece.position)
	undo.commit_action()


func _stack_selection() -> void:
	var pieces := _selected_pieces()
	if pieces.size() != 2:
		status.text = "Выберите две детали: сначала опору, затем перемещаемую деталь."
		return
	var base: AABB = pieces[0].global_transform * pieces[0].get_aabb()
	var moving: AABB = pieces[1].global_transform * pieces[1].get_aabb()
	var destination := pieces[1].global_position + Vector3(base.get_center().x - moving.get_center().x, base.end.y - moving.position.y, base.get_center().z - moving.get_center().z)
	var undo := get_undo_redo()
	undo.create_action("Поставить деталь на опору", UndoRedo.MERGE_DISABLE, _scene())
	undo.add_do_property(pieces[1], "global_position", destination)
	undo.add_undo_property(pieces[1], "global_position", pieces[1].global_position)
	undo.commit_action()
	status.text = "Детали состыкованы по мировым габаритам. Для наклонных поверхностей уточните положение вручную."


func _color_selection() -> void:
	var pieces := _selected_pieces()
	if pieces.is_empty():
		return
	var undo := get_undo_redo()
	undo.create_action("Изменить цвет деталей", UndoRedo.MERGE_DISABLE, _scene())
	for piece in pieces:
		var surface := StandardMaterial3D.new()
		if piece.material_override is StandardMaterial3D:
			surface = piece.material_override.duplicate()
		surface.albedo_color = tint.color
		undo.add_do_property(piece, "material_override", surface)
		undo.add_undo_property(piece, "material_override", piece.material_override)
	undo.commit_action()


func _add_collision() -> void:
	var root := _model_scene()
	if root == null:
		return
	var pieces := _selected_pieces()
	if pieces.is_empty():
		return
	# Body is a sibling: disabled processing on a piece must not disable animated descendants.
	var body := StaticBody3D.new()
	body.name = "Collision"
	for piece in pieces:
		var shape_node := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = piece.get_aabb().size
		shape_node.shape = box
		shape_node.transform = root.global_transform.affine_inverse() * piece.global_transform
		shape_node.position += shape_node.basis * piece.get_aabb().get_center()
		_adopt(body, shape_node, "Shape")
	_insert(root, body, "Добавить коллизию")
	status.text = "Создан StaticBody3D по текущей позе деталей. Для движущегося тела замените на AnimatableBody3D / CharacterBody3D."


func _add_anchor() -> void:
	var root := _model_scene()
	if root == null:
		return
	if root.get_class() != "PixelEntity3D":
		status.text = "Точки крепления доступны в сцене PixelEntity3D. Для манекена используйте кости."
		return
	var anchor := _native("PixelAnchor3D")
	anchor.name = "Anchor"
	_insert(root, anchor, "Добавить точку крепления")


func _skeleton() -> Skeleton3D:
	var root := _model_scene()
	if root == null or root.get_class() != "PixelMannequin3D":
		status.text = "Откройте сцену манекена со Skeleton3D."
		return null
	return root.find_child("Skeleton3D", true, false) as Skeleton3D


func _add_bone() -> void:
	var skeleton := _skeleton()
	if skeleton == null:
		return
	var index := skeleton.get_bone_count()
	var bone_name := "bone_" + str(index)
	while skeleton.find_bone(bone_name) >= 0:
		bone_name += "_"
	var undo := get_undo_redo()
	undo.create_action("Добавить кость", UndoRedo.MERGE_DISABLE, _scene())
	undo.add_do_method(skeleton, "add_bone", bone_name)
	if index > 0:
		undo.add_do_method(skeleton, "set_bone_parent", index, 0)
	undo.add_undo_method(self, "_restore_bones", skeleton, _capture_bones(skeleton))
	undo.commit_action()
	EditorInterface.edit_node(skeleton)


func _capture_bones(skeleton: Skeleton3D) -> Array[Dictionary]:
	var bones: Array[Dictionary] = []
	for i in skeleton.get_bone_count():
		var metadata := {}
		for key in skeleton.get_bone_meta_list(i):
			metadata[key] = skeleton.get_bone_meta(i, key)
		bones.append({"name": skeleton.get_bone_name(i), "parent": skeleton.get_bone_parent(i), "rest": skeleton.get_bone_rest(i), "position": skeleton.get_bone_pose_position(i), "rotation": skeleton.get_bone_pose_rotation(i), "scale": skeleton.get_bone_pose_scale(i), "enabled": skeleton.is_bone_enabled(i), "metadata": metadata})
	return bones


func _restore_bones(skeleton: Skeleton3D, bones: Array[Dictionary]) -> void:
	skeleton.clear_bones()
	for bone in bones:
		skeleton.add_bone(bone["name"])
	for i in bones.size():
		var bone := bones[i]
		skeleton.set_bone_parent(i, bone["parent"])
		skeleton.set_bone_rest(i, bone["rest"])
		skeleton.set_bone_pose_position(i, bone["position"])
		skeleton.set_bone_pose_rotation(i, bone["rotation"])
		skeleton.set_bone_pose_scale(i, bone["scale"])
		skeleton.set_bone_enabled(i, bone["enabled"])
		for key in bone["metadata"]:
			skeleton.set_bone_meta(i, key, bone["metadata"][key])


func _add_bone_attachment() -> void:
	var skeleton := _skeleton()
	if skeleton == null or skeleton.get_bone_count() == 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "Socket"
	attachment.bone_name = skeleton.get_bone_name(skeleton.get_bone_count() - 1)
	_insert(skeleton, attachment, "Добавить крепление к кости")


func _add_animation() -> void:
	var root := _model_scene()
	if root == null:
		return
	if root.get_class() == "PixelObject3D":
		status.text = "Декорации статичны. Используйте манекен или энтити для анимации."
		return
	if root.find_child("AnimationPlayer", true, false):
		_open_animation()
		return
	_insert(root, _animation_player(), "Добавить анимацию")
	_open_animation()


func _open_animation() -> void:
	var root := _scene()
	if root == null:
		return
	var player := root.find_child("AnimationPlayer", true, false)
	if player:
		EditorInterface.edit_node(player)
	else:
		status.text = "В текущей сцене нет AnimationPlayer."


func _build_shader_tools() -> void:
	material = ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = PIXEL_SHADER
	var color := ColorPickerButton.new()
	color.color = Color("6bad57")
	color.color_changed.connect(func(value): material.set_shader_parameter("base_color", value))
	content.add_child(color)
	for setting in ["color_steps", "light_steps"]:
		var slider := HSlider.new()
		slider.min_value = 2
		slider.max_value = 32 if setting == "color_steps" else 8
		slider.step = 1
		slider.value = 8 if setting == "color_steps" else 4
		_label("Градации цвета" if setting == "color_steps" else "Ступени освещения")
		slider.value_changed.connect(_set_shader_parameter.bind(setting))
		content.add_child(slider)
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(480, 270)
	container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content.add_child(container)
	preview = SubViewport.new()
	preview.size = Vector2i(480, 270)
	preview.own_world_3d = true
	preview.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	container.add_child(preview)
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 8
	mesh.mesh = sphere
	mesh.material_override = material
	preview.add_child(mesh)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3
	camera.position = Vector3(0, 0, 4)
	preview.add_child(camera)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	preview.add_child(sun)
	_button("Открыть код шейдера", func(): EditorInterface.edit_resource(material.shader))
	_label("Сохраните материал как .tres и назначьте material_override детали. Здесь пикселизация идёт через низкое разрешение стенда; в игре — через PixelWorld3D.")


func _set_shader_parameter(value: float, parameter: String) -> void:
	material.set_shader_parameter(parameter, value)


func _build_graph_tools() -> void:
	graph_action = OptionButton.new()
	for action in ACTIONS:
		graph_action.add_item(action)
	content.add_child(graph_action)
	_button("Добавить действие", _add_graph_step)
	_button("Загрузить граф выбранного PixelBrain3D", _load_graph)
	_button("Применить граф к выбранному PixelBrain3D", _apply_graph)
	graph_view = GraphEdit.new()
	graph_view.custom_minimum_size = Vector2(500, 340)
	graph_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph_view.connection_request.connect(_connect_graph)
	graph_view.disconnection_request.connect(_disconnect_graph)
	graph_view.delete_nodes_request.connect(_delete_graph_nodes)
	content.add_child(graph_view)
	if graph_steps.is_empty():
		graph_steps.assign([
			{"action": "search_object", "next": 1, "position": Vector2(30, 40), "parameters": {}},
			{"action": "find_path", "next": -1, "position": Vector2(300, 100), "parameters": {}}
		])
	_draw_graph()
	_label("Это событийный каркас ИИ: названия действий — точки подключения ваших функций, а не готовый поиск пути или бой. Нет автоматического _process. Вызывайте advance() по событию или от общего планировщика.")


func _draw_graph() -> void:
	graph_view.clear_connections()
	for child in graph_view.get_children():
		if child is GraphNode:
			graph_view.remove_child(child)
			child.queue_free()
	for i in graph_steps.size():
		var node := GraphNode.new()
		node.name = "Step" + str(i)
		node.title = str(i) + " · " + str(graph_steps[i].get("action", "custom_action"))
		node.position_offset = graph_steps[i].get("position", Vector2(i * 220, 40))
		node.position_offset_changed.connect(_move_graph_node.bind(node, i))
		var label := Label.new()
		label.text = "Вход                         Далее"
		node.add_child(label)
		node.set_slot(0, true, 0, Color("87b879"), true, 0, Color("87b879"))
		graph_view.add_child(node)
	for i in graph_steps.size():
		var next := int(graph_steps[i].get("next", -1))
		if next >= 0 and next < graph_steps.size():
			graph_view.connect_node("Step" + str(i), 0, "Step" + str(next), 0)


func _move_graph_node(node: GraphNode, index: int) -> void:
	if index < graph_steps.size():
		graph_steps[index]["position"] = node.position_offset


func _connect_graph(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	var index := str(from).trim_prefix("Step").to_int()
	graph_steps[index]["next"] = str(to).trim_prefix("Step").to_int()
	_draw_graph()


func _disconnect_graph(from: StringName, _from_port: int, _to: StringName, _to_port: int) -> void:
	graph_steps[str(from).trim_prefix("Step").to_int()]["next"] = -1
	_draw_graph()


func _delete_graph_nodes(names: Array[StringName]) -> void:
	var deleted: Array[int] = []
	for node_name in names:
		deleted.append(str(node_name).trim_prefix("Step").to_int())
	var mapping := {}
	var remaining: Array[Dictionary] = []
	for i in graph_steps.size():
		if i not in deleted:
			mapping[i] = remaining.size()
			remaining.append(graph_steps[i].duplicate(true))
	for step in remaining:
		step["next"] = mapping.get(int(step.get("next", -1)), -1)
	graph_steps = remaining
	_draw_graph()


func _add_graph_step() -> void:
	graph_steps.append({"action": ACTIONS[graph_action.selected], "next": -1, "position": Vector2(50 + graph_steps.size() * 40, 150), "parameters": {}})
	_draw_graph()


func _selected_brain() -> Node:
	for node in EditorInterface.get_selection().get_selected_nodes():
		if node.get_class() == "PixelBrain3D":
			return node
	var root := _scene()
	if root and root.get_class() == "PixelBrain3D":
		return root
	status.text = "Выберите PixelBrain3D в дереве сцены."
	return null


func _load_graph() -> void:
	var brain := _selected_brain()
	if brain == null or brain.get("graph") == null:
		return
	graph_steps.assign(brain.get("graph").get("steps"))
	_draw_graph()


func _apply_graph() -> void:
	var brain := _selected_brain()
	if brain == null:
		return
	var behavior := ClassDB.instantiate("PixelBehaviorGraph") as Resource
	behavior.set("steps", graph_steps)
	var undo := get_undo_redo()
	undo.create_action("Применить граф ИИ", UndoRedo.MERGE_DISABLE, _scene())
	undo.add_do_property(brain, "graph", behavior)
	undo.add_undo_property(brain, "graph", brain.get("graph"))
	undo.commit_action()
	status.text = "Граф применён. Сохраните сцену: Ctrl+S."
