/**************************************************************************/
/*  register_types.cpp                                                    */
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

#include "register_types.h"

#include "pixel_nodes.h"

#include "core/object/class_db.h"

#ifdef TOOLS_ENABLED
#include "editor_source.gen.h"

#include "editor/plugins/editor_plugin.h"

#include "modules/gdscript/gdscript.h"

static EditorPlugin *create_pixel_studio_editor() {
	Ref<GDScript> script;
	script.instantiate();
	script->set_source_code(String::utf8(reinterpret_cast<const char *>(pixel_studio_editor_source)));
	Error error = script->reload();
	ERR_FAIL_COND_V_MSG(error != OK, memnew(EditorPlugin), "Cannot load the built-in Pixel Studio editor.");
	EditorPlugin *plugin = memnew(EditorPlugin);
	plugin->set_script(script);
	return plugin;
}
#endif

void initialize_pixel_studio_module(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_SCENE) {
		GDREGISTER_CLASS(PixelObject3D);
		GDREGISTER_CLASS(PixelEntity3D);
		GDREGISTER_CLASS(PixelMannequin3D);
		GDREGISTER_CLASS(PixelPiece3D);
		GDREGISTER_CLASS(PixelAnchor3D);
		GDREGISTER_CLASS(PixelWorld3D);
		GDREGISTER_CLASS(PixelCamera3D);
		GDREGISTER_CLASS(PixelCutscene3D);
		GDREGISTER_CLASS(PixelBehaviorGraph);
		GDREGISTER_CLASS(PixelBrain3D);
	}
#ifdef TOOLS_ENABLED
	if (p_level == MODULE_INITIALIZATION_LEVEL_EDITOR) {
		EditorPlugins::add_create_func(create_pixel_studio_editor);
	}
#endif
}

void uninitialize_pixel_studio_module(ModuleInitializationLevel p_level) {
}
