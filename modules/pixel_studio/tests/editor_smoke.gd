@tool
extends "res://addons/pixel_smoke/pixel_studio.gd"


func _enter_tree() -> void:
	super._enter_tree()
	_run_checks.call_deferred()


func _get_plugin_name() -> String:
	return "Pixel Studio Smoke"


func _run_checks() -> void:
	await get_tree().process_frame
	for i in SECTIONS.size():
		_show_section(i)
		assert(content.get_child_count() > 0)
		if i == 5:
			assert(material.shader.code.contains("void light()"))
		if i == 8:
			assert(graph_steps.size() == 2)
			_connect_graph("Step1", 0, "Step0", 0)
			assert(graph_steps[1]["next"] == 0)
			_delete_graph_nodes([&"Step0"])
			assert(graph_steps.size() == 1 and graph_steps[0]["next"] == -1)
		if ClassDB.class_exists("PixelWorld3D") and i not in [4, 5]:
			var asset := _make_asset()
			var packed := PackedScene.new()
			assert(packed.pack(asset) == OK)
			asset.free()
			var instance := packed.instantiate()
			assert(instance != null)
			if i == 2:
				assert(instance.get_node("Skeleton3D/BodyRig/Body") != null)
			if i == 7:
				assert(instance.get("temporary_scene") != null)
				assert(instance.get_signal_connection_list("started").size() == 1)
				assert(instance.get_node("AnimationPlayer").get_signal_connection_list("animation_finished").size() == 1)
			instance.free()
	if ClassDB.class_exists("PixelWorld3D"):
		_show_section(2)
		var model := _make_asset()
		EditorInterface.call("add_root_node", model)
		assert(EditorInterface.get_edited_scene_root() == model)
		var skeleton := model.get_node("Skeleton3D") as Skeleton3D
		var original_bones := skeleton.get_bone_count()
		_add_bone()
		assert(skeleton.get_bone_count() == original_bones + 1)
		var history := get_undo_redo().get_history_undo_redo(get_undo_redo().get_object_history_id(model))
		history.undo()
		assert(skeleton.get_bone_count() == original_bones)
		history.redo()
		assert(skeleton.get_bone_count() == original_bones + 1)
		var original_children := model.get_child_count()
		_add_piece()
		assert(model.get_child_count() == original_children + 1)
		history.undo()
		assert(model.get_child_count() == original_children)
		history.redo()
		assert(model.get_child_count() == original_children + 1)
	if "--capture-editor" in OS.get_cmdline_user_args():
		_show_section(5)
		if is_instance_valid(native_dock):
			native_dock.call("make_visible")
		else:
			EditorInterface.set_main_screen_editor(_get_plugin_name())
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var capture := screen.get_viewport().get_texture().get_image()
		assert(capture.save_png("res://editor-preview.png") == OK)
	print("PIXEL_STUDIO_EDITOR_SMOKE_OK")
	get_tree().quit()
