"""SCons launcher with an opt-in workaround for CLion's gcc-ar response-file bug."""

import argparse
import os
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--mingw-bin", type=Path, help="Directory containing g++.exe and ar.exe")
parser.add_argument("--direct-ar", action="store_true", help="Use ar/ranlib directly (use with lto=none)")
args, scons_args = parser.parse_known_args()
root = Path(__file__).resolve().parents[3]
os.chdir(root)
sys.path.insert(0, str(root / ".build_tools"))
if args.mingw_bin:
    mingw = args.mingw_bin.resolve()
    if not (mingw / "g++.exe").is_file() or not (mingw / "ar.exe").is_file():
        parser.error("--mingw-bin must contain g++.exe and ar.exe")
    os.environ["PATH"] = str(mingw) + os.pathsep + os.environ.get("PATH", "")

try:
    import SCons.Environment
    import SCons.Script
except ImportError:
    parser.error("Install SCons first: python -m pip install --target .build_tools scons")

if args.direct_ar:
    if any(arg.startswith("lto=") and arg != "lto=none" for arg in scons_args):
        parser.error("--direct-ar requires lto=none")
    scons_args.append("lto=none")
    original_setitem = SCons.Environment.Base.__setitem__

    def setitem(env, key, value):
        # Scoped to this build process; never change the installed compiler or SCons.
        if isinstance(value, str):
            if key == "AR":
                value = value.replace("gcc-ar", "ar")
            elif key == "RANLIB":
                value = value.replace("gcc-ranlib", "ranlib")
        return original_setitem(env, key, value)

    SCons.Environment.Base.__setitem__ = setitem

sys.argv = [sys.argv[0], *scons_args]
SCons.Script.main()
