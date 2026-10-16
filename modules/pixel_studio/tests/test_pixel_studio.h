/**************************************************************************/
/*  test_pixel_studio.h                                                   */
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

#include "scene/main/scene_tree.h"
#include "scene/main/window.h"
#include "tests/test_macros.h"

#include "modules/gdscript/gdscript.h"
#include "modules/pixel_studio/pixel_nodes.h"

namespace TestPixelStudio {

TEST_CASE("[PixelStudio] Graph ownership, cycles and termination") {
	Ref<PixelBehaviorGraph> graph;
	graph.instantiate();
	TypedArray<Dictionary> steps;
	Dictionary step;
	step["action"] = "find_path";
	step["next"] = 0;
	steps.push_back(step);
	graph->set_steps(steps);
	step["action"] = "";
	CHECK(String(graph->get_step(0)["action"]) == "find_path");
	PixelBrain3D *brain = memnew(PixelBrain3D);
	brain->set_graph(graph);
	CHECK_FALSE(brain->is_processing());
	for (int i = 0; i < 100; i++) {
		CHECK(brain->advance());
	}
	step["action"] = "show_ui";
	step["next"] = -1;
	graph->set_steps(steps);
	brain->reset();
	CHECK(brain->advance());
	CHECK_FALSE(brain->advance());
	memdelete(brain);
}

TEST_CASE("[PixelStudio] Piece rejects frame callbacks, keeps explicit methods") {
	GDScriptLanguage::get_singleton()->init();
	Ref<GDScript> frame_script;
	frame_script.instantiate();
	frame_script->set_source_code("extends PixelPiece3D\nfunc _process(delta):\n\tpass\n");
	REQUIRE(frame_script->reload() == OK);
	PixelPiece3D *piece = memnew(PixelPiece3D);
	ERR_PRINT_OFF;
	piece->set_script(frame_script);
	ERR_PRINT_ON;
	CHECK(piece->get_script().is_null());
	Ref<GDScript> explicit_script;
	explicit_script.instantiate();
	explicit_script->set_source_code("extends PixelPiece3D\nfunc interact():\n\treturn 42\n");
	REQUIRE(explicit_script->reload() == OK);
	piece->set_script(explicit_script);
	CHECK(int(piece->call("interact")) == 42);
	memdelete(piece);
}

TEST_CASE("[SceneTree][PixelStudio] Cutscene affects only one viewport") {
	SubViewport *first = memnew(SubViewport);
	SubViewport *second = memnew(SubViewport);
	SceneTree::get_singleton()->get_root()->add_child(first);
	SceneTree::get_singleton()->get_root()->add_child(second);
	Camera3D *player = memnew(Camera3D);
	Camera3D *other_player = memnew(Camera3D);
	first->add_child(player);
	second->add_child(other_player);
	player->make_current();
	other_player->make_current();
	PixelCutscene3D *cutscene = memnew(PixelCutscene3D);
	Ref<PackedScene> temporary;
	temporary.instantiate();
	Node3D *prop = memnew(Node3D);
	prop->set_name("TemporaryProp");
	REQUIRE(temporary->pack(prop) == OK);
	memdelete(prop);
	cutscene->set_temporary_scene(temporary);
	Ref<PackedScene> aftermath;
	aftermath.instantiate();
	Node3D *permanent = memnew(Node3D);
	permanent->set_name("Aftermath");
	REQUIRE(aftermath->pack(permanent) == OK);
	memdelete(permanent);
	cutscene->set_after_scene(aftermath);
	Camera3D *camera = memnew(Camera3D);
	camera->set_name("Camera");
	cutscene->add_child(camera);
	cutscene->set_camera_path(NodePath("Camera"));
	first->add_child(cutscene);
	player->make_current();
	ERR_PRINT_OFF;
	CHECK_FALSE(cutscene->start(other_player));
	ERR_PRINT_ON;
	CHECK(other_player->is_current());
	CHECK(cutscene->start(player));
	CHECK(camera->is_current());
	CHECK(other_player->is_current());
	Node *temporary_node = cutscene->get_node(NodePath("TemporaryProp"));
	REQUIRE(temporary_node);
	cutscene->finish();
	CHECK(temporary_node->is_queued_for_deletion());
	CHECK(player->is_current());
	CHECK_FALSE(cutscene->is_playing());
	CHECK(first->get_node_or_null(NodePath("Aftermath")) != nullptr);
	int count_after_finish = first->get_child_count();
	cutscene->finish();
	CHECK(first->get_child_count() == count_after_finish);
	memdelete(first);
	memdelete(second);
}

TEST_CASE("[SceneTree][PixelStudio] World configures a pixel viewport") {
	SubViewport *viewport = memnew(SubViewport);
	SceneTree::get_singleton()->get_root()->add_child(viewport);
	PixelWorld3D *world = memnew(PixelWorld3D);
	viewport->add_child(world);
	CHECK(viewport->get_size() == Vector2i(480, 270));
	world->set_resolution(Vector2i(320, 180));
	CHECK(viewport->get_size() == Vector2i(320, 180));
	ERR_PRINT_OFF;
	world->set_resolution(Vector2i(0, 0));
	ERR_PRINT_ON;
	CHECK(world->get_resolution() == Vector2i(320, 180));
	CHECK(viewport->get_msaa_3d() == Viewport::MSAA_DISABLED);
	memdelete(viewport);
}

} // namespace TestPixelStudio
