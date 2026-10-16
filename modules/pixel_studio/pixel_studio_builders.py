def embed_editor(target, source, env):
    from pathlib import Path

    data = Path(str(source[0])).read_bytes()
    # A byte array keeps UTF-8 and quotes intact on all supported compilers.
    rows = [", ".join(str(b) for b in data[i:i + 24]) for i in range(0, len(data), 24)]
    Path(str(target[0])).write_text(
        "// Generated; edit editor/pixel_studio.gd instead.\n"
        "static const unsigned char pixel_studio_editor_source[] = {\n"
        + ",\n".join(rows) + ", 0\n};\n", encoding="utf-8"
    )
