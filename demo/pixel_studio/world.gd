extends PixelWorld3D
## Small deterministic scene demonstrating the rendering profile, not a benchmark.

var palette: Dictionary = {}


func _ready() -> void:
	_box(self, Vector3(0, -0.3, 0), Vector3(11, 0.5, 9), Color("526c45"))
	for x in range(-4, 5):
		for z in range(-3, 4):
			if abs(x) < 2 or z == 0:
				_box(self, Vector3(x, -0.015, z), Vector3(0.93, 0.08, 0.93), Color("92937a") if (x + z) % 2 else Color("a0a18a"))
	for point in [Vector3(-3, 0, -2), Vector3(3, 0, -2.5), Vector3(-4, 0, 2), Vector3(4, 0, 2.5)]:
		_tree(point)
	for point in [Vector3(-2.2, 0, 1.5), Vector3(2.2, 0, 1.5), Vector3(-2.2, 0, -1.5), Vector3(2.2, 0, -1.5)]:
		_pillar(point)
	_box(self, Vector3(0, 0.15, -1.5), Vector3(1.5, 0.3, 1.5), Color("667779"))
	_box(self, Vector3(0, 0.45, -1.5), Vector3(1, 0.35, 1), Color("91a4a0"))
	var crystal := PixelPiece3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.55, 1.0, 0.55)
	crystal.mesh = prism
	crystal.material_override = _material(Color("64d9da"))
	crystal.position = Vector3(0, 1.1, -1.5)
	crystal.rotation_degrees.y = 45
	add_child(crystal)
	var mannequin := PixelMannequin3D.new()
	mannequin.name = "Visitor"
	add_child(mannequin)
	_box(mannequin, Vector3(0.25, 0.65, 1.1), Vector3(0.45, 0.65, 0.3), Color("536e9b"))
	_box(mannequin, Vector3(0.25, 1.15, 1.1), Vector3.ONE * 0.35, Color("d6b58b"))
	_box(mannequin, Vector3(0.1, 0.2, 1.1), Vector3(0.15, 0.4, 0.2), Color("364452"))
	_box(mannequin, Vector3(0.4, 0.2, 1.1), Vector3(0.15, 0.4, 0.2), Color("364452"))
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var label := Label.new()
	label.text = "PIXEL STUDIO\n480 x 270 / first world"
	label.position = Vector2(12, 10)
	label.add_theme_font_size_override("font_size", 12)
	canvas.add_child(label)


func _material(color: Color) -> StandardMaterial3D:
	if not palette.has(color):
		var surface := StandardMaterial3D.new()
		surface.albedo_color = color
		surface.roughness = 1.0
		surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		palette[color] = surface
	return palette[color]


func _box(parent: Node, center: Vector3, dimensions: Vector3, color: Color) -> void:
	var piece := PixelPiece3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	piece.mesh = box
	piece.position = center
	piece.material_override = _material(color)
	parent.add_child(piece)


func _tree(point: Vector3) -> void:
	var tree := PixelObject3D.new()
	tree.position = point
	add_child(tree)
	_box(tree, Vector3(0, 0.7, 0), Vector3(0.3, 1.4, 0.3), Color("79664d"))
	for i in 3:
		var leaves := PixelPiece3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 8
		sphere.rings = 4
		sphere.radius = 0.8 - i * 0.12
		sphere.height = 1.3
		leaves.mesh = sphere
		leaves.material_override = _material([Color("78984d"), Color("8fae58"), Color("a5bf6a")][i])
		leaves.position = Vector3(0.12 * i, 1.25 + i * 0.45, 0)
		tree.add_child(leaves)


func _pillar(point: Vector3) -> void:
	var pillar := PixelObject3D.new()
	pillar.position = point
	add_child(pillar)
	_box(pillar, Vector3(0, 0.1, 0), Vector3(0.75, 0.2, 0.75), Color("7d8a87"))
	_box(pillar, Vector3(0, 0.65, 0), Vector3(0.4, 1.1, 0.4), Color("a4afa2"))
	_box(pillar, Vector3(0, 1.3, 0), Vector3(0.65, 0.2, 0.65), Color("b7c0a9"))
