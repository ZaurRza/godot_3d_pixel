extends SceneTree
## Run with the demo project as --path. Optional screenshot path follows --.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load("res://world.tscn") as PackedScene
	assert(packed != null)
	var world := packed.instantiate() as PixelWorld3D
	root.add_child(world)
	current_scene = world
	await process_frame
	assert(root.content_scale_size == Vector2i(480, 270))
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT)
	assert(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER)
	assert(root.get_camera_3d() == world.get_node("Camera"))
	assert(world.get_child_count() > 30)
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		var args := OS.get_cmdline_user_args()
		if not args.is_empty():
			assert(root.get_texture().get_image().save_png(args[0]) == OK)
	print("PIXEL_STUDIO_DEMO_SMOKE_OK")
	quit()
