"""Run UI checks in a disposable editor project (no installed addons required)."""
import argparse
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("godot", type=Path)
parser.add_argument("--visual", action="store_true", help="Render the shader playground and capture the editor viewport")
args = parser.parse_args()
module = Path(__file__).resolve().parents[1]
project = module.parents[1] / ".pixel_studio_checks"
addon = project / "addons" / "pixel_smoke"
addon.mkdir(parents=True, exist_ok=True)
shutil.copyfile(module / "editor" / "pixel_studio.gd", addon / "pixel_studio.gd")
shutil.copyfile(module / "tests" / "editor_smoke.gd", addon / "smoke.gd")
(addon / "plugin.cfg").write_text('[plugin]\nname="Pixel smoke"\ndescription="Validation"\nauthor="Pixel Studio"\nversion="1"\nscript="smoke.gd"\n')
(project / "project.godot").write_text('config_version=5\n[application]\nconfig/name="Pixel Studio checks"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n[editor_plugins]\nenabled=PackedStringArray("res://addons/pixel_smoke/plugin.cfg")\n')
command = [str(args.godot.resolve()), "--editor", "--path", str(project), "--quit-after", "600"]
if args.visual:
    command += ["--position", "-10000,-10000", "--resolution", "1280x800", "--", "--capture-editor"]
else:
    command.append("--headless")
result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=120)
output = result.stdout + result.stderr
print(output)
if result.returncode or "PIXEL_STUDIO_EDITOR_SMOKE_OK" not in output or "SCRIPT ERROR" in output or "ERROR:" in output:
    raise SystemExit(1)
