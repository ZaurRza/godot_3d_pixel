/**************************************************************************/
/*  pixel_nodes.cpp                                                       */
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

#include "pixel_nodes.h"

#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/script_language.h"
#include "scene/main/window.h"

static bool pixel_has_frame_callbacks(const Variant &p_script) {
	Ref<Script> script = p_script;
	while (script.is_valid()) {
		if (script->has_method(SNAME("_process")) || script->has_method(SNAME("_physics_process"))) {
			return true;
		}
		script = script->get_base_script();
	}
	return false;
}

static bool pixel_has_static_parent(Node *p_node) {
	for (Node *parent = p_node->get_parent(); parent; parent = parent->get_parent()) {
		if (Object::cast_to<PixelObject3D>(parent)) {
			return true;
		}
	}
	return false;
}

void PixelObject3D::set_script(const Variant &p_script) {
	ERR_FAIL_COND_MSG(p_script.get_type() != Variant::NIL && !p_script.is_null(), "PixelObject3D is decorative. Use PixelEntity3D for scripted assets.");
	Node3D::set_script(p_script);
}

void PixelPiece3D::set_script(const Variant &p_script) {
	ERR_FAIL_COND_MSG(pixel_has_frame_callbacks(p_script), "Pixel pieces use explicit call() methods, not _process() or _physics_process().");
	ERR_FAIL_COND_MSG(pixel_has_static_parent(this) && !p_script.is_null(), "Decorative object pieces cannot have scripts.");
	MeshInstance3D::set_script(p_script);
}

void PixelPiece3D::_notification(int p_what) {
	if (p_what == NOTIFICATION_READY) {
		// Also covers scripts hot-reloaded after assignment. call() remains available.
		set_process(false);
		set_physics_process(false);
		if (!Engine::get_singleton()->is_editor_hint() && pixel_has_static_parent(this)) {
			MeshInstance3D::set_script(Variant());
		}
	}
}

void PixelAnchor3D::set_script(const Variant &p_script) {
	ERR_FAIL_COND_MSG(pixel_has_frame_callbacks(p_script), "Pixel anchors use explicit call() methods, not per-frame callbacks.");
	Marker3D::set_script(p_script);
}

void PixelAnchor3D::_notification(int p_what) {
	if (p_what == NOTIFICATION_READY) {
		set_process(false);
		set_physics_process(false);
	}
}

void PixelWorld3D::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_resolution", "resolution"), &PixelWorld3D::set_resolution);
	ClassDB::bind_method(D_METHOD("get_resolution"), &PixelWorld3D::get_resolution);
	ClassDB::bind_method(D_METHOD("apply_pixel_profile"), &PixelWorld3D::apply_pixel_profile);
	ADD_PROPERTY(PropertyInfo(Variant::VECTOR2I, "resolution"), "set_resolution", "get_resolution");
}

void PixelWorld3D::set_resolution(Vector2i p_resolution) {
	ERR_FAIL_COND(p_resolution.x < 64 || p_resolution.y < 64 || p_resolution.x > 1920 || p_resolution.y > 1080);
	resolution = p_resolution;
	if (is_inside_tree()) {
		apply_pixel_profile();
	}
}

void PixelWorld3D::_notification(int p_what) {
	if (p_what == NOTIFICATION_READY) {
		apply_pixel_profile();
	}
}

void PixelWorld3D::apply_pixel_profile() {
	if (!is_inside_tree() || Engine::get_singleton()->is_editor_hint()) {
		return;
	}
	Viewport *viewport = get_viewport();
	Window *window = Object::cast_to<Window>(viewport);
	if (window) {
		window->set_content_scale_size(resolution);
		window->set_content_scale_mode(Window::CONTENT_SCALE_MODE_VIEWPORT);
		window->set_content_scale_aspect(Window::CONTENT_SCALE_ASPECT_KEEP);
		window->set_content_scale_stretch(Window::CONTENT_SCALE_STRETCH_INTEGER);
	} else if (SubViewport *sub = Object::cast_to<SubViewport>(viewport)) {
		sub->set_size(resolution);
	}
	viewport->set_msaa_3d(Viewport::MSAA_DISABLED);
	viewport->set_screen_space_aa(Viewport::SCREEN_SPACE_AA_DISABLED);
	viewport->set_use_taa(false);
}

PixelCamera3D::PixelCamera3D() {
	set_projection(PROJECTION_ORTHOGONAL);
	set_size(12.0);
	set_rotation_degrees(Vector3(-35.264, 45.0, 0.0));
	set_position(Vector3(10.0, 10.0, 10.0));
}

void PixelCutscene3D::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_camera_path", "path"), &PixelCutscene3D::set_camera_path);
	ClassDB::bind_method(D_METHOD("get_camera_path"), &PixelCutscene3D::get_camera_path);
	ClassDB::bind_method(D_METHOD("set_temporary_scene", "scene"), &PixelCutscene3D::set_temporary_scene);
	ClassDB::bind_method(D_METHOD("get_temporary_scene"), &PixelCutscene3D::get_temporary_scene);
	ClassDB::bind_method(D_METHOD("set_after_scene", "scene"), &PixelCutscene3D::set_after_scene);
	ClassDB::bind_method(D_METHOD("get_after_scene"), &PixelCutscene3D::get_after_scene);
	ClassDB::bind_method(D_METHOD("is_playing"), &PixelCutscene3D::is_playing);
	ClassDB::bind_method(D_METHOD("start", "player_camera"), &PixelCutscene3D::start);
	ClassDB::bind_method(D_METHOD("finish", "apply_after_scene"), &PixelCutscene3D::finish, DEFVAL(true));
	ADD_PROPERTY(PropertyInfo(Variant::NODE_PATH, "camera_path", PROPERTY_HINT_NODE_PATH_VALID_TYPES, "Camera3D"), "set_camera_path", "get_camera_path");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "temporary_scene", PROPERTY_HINT_RESOURCE_TYPE, "PackedScene"), "set_temporary_scene", "get_temporary_scene");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "after_cast_scene", PROPERTY_HINT_RESOURCE_TYPE, "PackedScene"), "set_after_scene", "get_after_scene");
	ADD_SIGNAL(MethodInfo("started"));
	ADD_SIGNAL(MethodInfo("finished"));
}

bool PixelCutscene3D::start(Camera3D *p_player_camera) {
	ERR_FAIL_COND_V(!is_inside_tree() || playing || !p_player_camera || !p_player_camera->is_inside_tree(), false);
	Camera3D *camera = Object::cast_to<Camera3D>(get_node_or_null(camera_path));
	// Never affect another local player's viewport, and never steal an inactive camera.
	ERR_FAIL_COND_V(!camera || camera == p_player_camera || camera->get_viewport() != p_player_camera->get_viewport() || !p_player_camera->is_current(), false);
	if (temporary_scene.is_valid()) {
		Node *props = temporary_scene->instantiate();
		ERR_FAIL_NULL_V(props, false);
		add_child(props);
		temporary_instance = props->get_instance_id();
	}
	previous_camera = p_player_camera->get_instance_id();
	active_camera = camera->get_instance_id();
	playing = true;
	show();
	camera->make_current();
	emit_signal(SNAME("started"));
	return true;
}

void PixelCutscene3D::finish(bool p_apply_after_scene) {
	if (!playing) {
		return;
	}
	playing = false;
	Node *props = Object::cast_to<Node>(ObjectDB::get_instance(temporary_instance));
	if (props) {
		props->queue_free();
	}
	temporary_instance = ObjectID();
	Camera3D *camera = Object::cast_to<Camera3D>(ObjectDB::get_instance(active_camera));
	Camera3D *previous = Object::cast_to<Camera3D>(ObjectDB::get_instance(previous_camera));
	if (camera && camera->is_inside_tree() && camera->is_current()) {
		if (previous && previous->is_inside_tree() && previous->get_viewport() == camera->get_viewport()) {
			previous->make_current();
		} else {
			camera->clear_current();
		}
	}
	hide();
	if (p_apply_after_scene && after_scene.is_valid() && get_parent()) {
		Node *aftermath = after_scene->instantiate();
		if (aftermath) {
			get_parent()->add_child(aftermath);
		}
	}
	emit_signal(SNAME("finished"));
}

void PixelCutscene3D::_notification(int p_what) {
	if (p_what == NOTIFICATION_READY && !Engine::get_singleton()->is_editor_hint()) {
		hide();
	} else if (p_what == NOTIFICATION_EXIT_TREE) {
		finish(false);
	}
}

void PixelBehaviorGraph::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_steps", "steps"), &PixelBehaviorGraph::set_steps);
	ClassDB::bind_method(D_METHOD("get_steps"), &PixelBehaviorGraph::get_steps);
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "steps", PROPERTY_HINT_ARRAY_TYPE, "Dictionary"), "set_steps", "get_steps");
}

void PixelBehaviorGraph::set_steps(const TypedArray<Dictionary> &p_steps) {
	steps = p_steps.duplicate(true);
	emit_changed();
}

Dictionary PixelBehaviorGraph::get_step(int p_index) const {
	ERR_FAIL_INDEX_V(p_index, steps.size(), Dictionary());
	Dictionary step = steps[p_index];
	return step.duplicate(true);
}

void PixelBrain3D::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_graph", "graph"), &PixelBrain3D::set_graph);
	ClassDB::bind_method(D_METHOD("get_graph"), &PixelBrain3D::get_graph);
	ClassDB::bind_method(D_METHOD("advance"), &PixelBrain3D::advance);
	ClassDB::bind_method(D_METHOD("reset"), &PixelBrain3D::reset);
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "graph", PROPERTY_HINT_RESOURCE_TYPE, "PixelBehaviorGraph"), "set_graph", "get_graph");
	ADD_SIGNAL(MethodInfo("action_requested", PropertyInfo(Variant::STRING_NAME, "action"), PropertyInfo(Variant::DICTIONARY, "parameters")));
}

void PixelBrain3D::set_graph(const Ref<PixelBehaviorGraph> &p_graph) {
	graph = p_graph;
	reset();
}

bool PixelBrain3D::advance() {
	// One bounded step per explicit tick, including graphs containing cycles.
	if (dispatching || graph.is_null()) {
		return false;
	}
	if (cursor < 0 || cursor >= graph->get_step_count()) {
		return false;
	}
	Dictionary step = graph->get_step(cursor);
	StringName action = step.get("action", StringName());
	if (action == StringName()) {
		return false;
	}
	cursor = step.get("next", -1);
	dispatching = true;
	emit_signal(SNAME("action_requested"), action, step.get("parameters", Dictionary()));
	dispatching = false;
	return true;
}
