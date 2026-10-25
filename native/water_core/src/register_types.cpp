#include "gen_core.h"
#include "water_core.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

void initialize_water_core(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	GDREGISTER_CLASS(WaterCore);
	GDREGISTER_CLASS(GenCore);
}

void uninitialize_water_core(ModuleInitializationLevel level) {
}

extern "C" {
GDExtensionBool GDE_EXPORT water_core_init(GDExtensionInterfaceGetProcAddress get_proc_address, const GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	godot::GDExtensionBinding::InitObject init_obj(get_proc_address, library, initialization);
	init_obj.register_initializer(initialize_water_core);
	init_obj.register_terminator(uninitialize_water_core);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init_obj.init();
}
}
