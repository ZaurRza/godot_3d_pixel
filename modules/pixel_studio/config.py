def can_build(env, platform):
    env.module_add_dependencies("pixel_studio", ["gdscript"])
    return not env["disable_3d"] and not env["disable_physics_3d"]


def configure(env):
    pass
