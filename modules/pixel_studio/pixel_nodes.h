/**************************************************************************/
/*  pixel_nodes.h                                                         */
/**************************************************************************/
/*                         This file is part of:                          */
/*                             GODOT ENGINE                               */
/*                        https://godotengine.org                         */
/**************************************************************************/
/* Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md). */
/* Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.                  */
/*                                                                        */
/* Permission is hereby granted, free of charge, to any person obtaining  */
/* a copy of this software and associated documentation files (the        */
/* "Software"), to deal in the Software without restriction, including    */
/* without limitation the rights to use, copy, modify, merge, publish,    */
/* distribute, sublicense, and/or sell copies of the Software, and to     */
/* permit persons to whom the Software is furnished to do so, subject to  */
/* the following conditions:                                              */
/*                                                                        */
/* The above copyright notice and this permission notice shall be         */
/* included in all copies or substantial portions of the Software.        */
/*                                                                        */
/* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,        */
/* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     */
/* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. */
/* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   */
/* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   */
/* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      */
/* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 */
/**************************************************************************/

#pragma once

#include "scene/3d/camera_3d.h"
#include "scene/3d/marker_3d.h"
#include "scene/3d/mesh_instance_3d.h"
#include "scene/resources/packed_scene.h"

// Decorative assets have no script lifecycle at all.
class PixelObject3D : public Node3D {
	GDCLASS(PixelObject3D, Node3D);

protected:
	static void _bind_methods() {}

public:
	void set_script(const Variant &p_script) override;
};

class PixelEntity3D : public Node3D {
	GDCLASS(PixelEntity3D, Node3D);

protected:
	static void _bind_methods() {}
};

class PixelMannequin3D : public PixelEntity3D {
	GDCLASS(PixelMannequin3D, PixelEntity3D);

protected:
	static void _bind_methods() {}
};

class PixelPiece3D : public MeshInstance3D {
	GDCLASS(PixelPiece3D, MeshInstance3D);

protected:
	static void _bind_methods() {}
	void _notification(int p_what);

public:
	void set_script(const Variant &p_script) override;
};

class PixelAnchor3D : public Marker3D {
	GDCLASS(PixelAnchor3D, Marker3D);

protected:
	static void _bind_methods() {}
	void _notification(int p_what);

public:
	void set_script(const Variant &p_script) override;
};

class PixelWorld3D : public Node3D {
	GDCLASS(PixelWorld3D, Node3D);
	Vector2i resolution = Vector2i(480, 270);

protected:
	static void _bind_methods();
	void _notification(int p_what);

public:
	void set_resolution(Vector2i p_resolution);
	Vector2i get_resolution() const { return resolution; }
	void apply_pixel_profile();
};

class PixelCamera3D : public Camera3D {
	GDCLASS(PixelCamera3D, Camera3D);

protected:
	static void _bind_methods() {}

public:
	PixelCamera3D();
};

class PixelCutscene3D : public Node3D {
	GDCLASS(PixelCutscene3D, Node3D);
	NodePath camera_path;
	Ref<PackedScene> after_scene;
	Ref<PackedScene> temporary_scene;
	ObjectID temporary_instance;
	ObjectID previous_camera;
	ObjectID active_camera;
	bool playing = false;

protected:
	static void _bind_methods();
	void _notification(int p_what);

public:
	void set_camera_path(const NodePath &p_path) { camera_path = p_path; }
	NodePath get_camera_path() const { return camera_path; }
	void set_temporary_scene(const Ref<PackedScene> &p_scene) { temporary_scene = p_scene; }
	Ref<PackedScene> get_temporary_scene() const { return temporary_scene; }
	void set_after_scene(const Ref<PackedScene> &p_scene) { after_scene = p_scene; }
	Ref<PackedScene> get_after_scene() const { return after_scene; }
	bool is_playing() const { return playing; }
	bool start(Camera3D *p_player_camera);
	void finish(bool p_apply_after_scene = true);
};

// Each graph step emits one action; project scripts provide game-specific behavior.
class PixelBehaviorGraph : public Resource {
	GDCLASS(PixelBehaviorGraph, Resource);
	TypedArray<Dictionary> steps;

protected:
	static void _bind_methods();

public:
	void set_steps(const TypedArray<Dictionary> &p_steps);
	TypedArray<Dictionary> get_steps() const { return steps.duplicate(true); }
	int get_step_count() const { return steps.size(); }
	Dictionary get_step(int p_index) const;
};

class PixelBrain3D : public Node {
	GDCLASS(PixelBrain3D, Node);
	Ref<PixelBehaviorGraph> graph;
	int cursor = 0;
	bool dispatching = false;

protected:
	static void _bind_methods();

public:
	void set_graph(const Ref<PixelBehaviorGraph> &p_graph);
	Ref<PixelBehaviorGraph> get_graph() const { return graph; }
	void reset() { cursor = 0; }
	bool advance();
};
