#!/usr/bin/env python3
"""
AnimateShader Real OpenGL GLSL Validator & Iris Spec Checker
------------------------------------------------------------
1. Creates a headless Mesa EGL OpenGL 3.3+ Compatibility Profile context.
2. Expands Iris/OptiFine `#include` directives and validates balanced `#if`/`#endif`.
3. Compiles and links every vertex + fragment shader program across world0, world-1,
   and world1 under multiple option & profile permutations.
4. Validates RENDERTARGETS vs fragment `layout(location = N) out` counts and
   verifies shaders.properties / settings.glsl / lang/*.lang consistency.
"""

import ctypes
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHADERS_DIR = ROOT / "shaders"


# ---------------------------------------------------------------------------
# Headless Mesa EGL + OpenGL 3.3+ Compatibility Context
# ---------------------------------------------------------------------------
class HeadlessGL:
    GL_VERTEX_SHADER = 0x8B31
    GL_FRAGMENT_SHADER = 0x8B30
    GL_COMPILE_STATUS = 0x8B81
    GL_LINK_STATUS = 0x8B82
    GL_INFO_LOG_LENGTH = 0x8B84

    def __init__(self):
        os.environ["LIBGL_ALWAYS_SOFTWARE"] = "1"
        os.environ["EGL_PLATFORM"] = "surfaceless"
        self.egl = ctypes.CDLL("libEGL.so.1")
        self.gl = ctypes.CDLL("libGL.so.1")

        self.egl.eglGetPlatformDisplay.restype = ctypes.c_void_p
        self.egl.eglGetPlatformDisplay.argtypes = [ctypes.c_uint, ctypes.c_void_p, ctypes.c_void_p]
        self.egl.eglInitialize.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_int)]
        self.egl.eglChooseConfig.argtypes = [
            ctypes.c_void_p, ctypes.POINTER(ctypes.c_int),
            ctypes.POINTER(ctypes.c_void_p), ctypes.c_int, ctypes.POINTER(ctypes.c_int)
        ]
        self.egl.eglCreateContext.restype = ctypes.c_void_p
        self.egl.eglCreateContext.argtypes = [
            ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.POINTER(ctypes.c_int)
        ]
        self.egl.eglMakeCurrent.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]

        dpy = self.egl.eglGetPlatformDisplay(0x31DD, None, None)  # EGL_PLATFORM_SURFACELESS_MESA
        maj, min_ = ctypes.c_int(), ctypes.c_int()
        if not self.egl.eglInitialize(dpy, ctypes.byref(maj), ctypes.byref(min_)):
            raise RuntimeError("Failed to initialize Mesa surfaceless EGL")

        self.egl.eglBindAPI(0x30A2)  # EGL_OPENGL_API
        attrs = (ctypes.c_int * 7)(0x3033, 0x0001, 0x3040, 0x0008, 0x3038, 0, 0)
        cfg = ctypes.c_void_p()
        num = ctypes.c_int()
        self.egl.eglChooseConfig(dpy, attrs, ctypes.byref(cfg), 1, ctypes.byref(num))
        if num.value < 1:
            raise RuntimeError("No EGL OpenGL config found")

        ctx_attrs = (ctypes.c_int * 7)(0x3098, 3, 0x30FB, 3, 0x30FD, 0x00000002, 0x3038)
        ctx = self.egl.eglCreateContext(dpy, cfg, None, ctx_attrs)
        if not ctx or not self.egl.eglMakeCurrent(dpy, None, None, ctx):
            raise RuntimeError("Failed to create OpenGL 3.3 compatibility context")

        # Bind GL shader functions
        self.gl.glGetString.restype = ctypes.c_char_p
        self.gl.glCreateShader.restype = ctypes.c_uint
        self.gl.glCreateShader.argtypes = [ctypes.c_uint]
        self.gl.glShaderSource.argtypes = [
            ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_char_p), ctypes.POINTER(ctypes.c_int)
        ]
        self.gl.glCompileShader.argtypes = [ctypes.c_uint]
        self.gl.glGetShaderiv.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)]
        self.gl.glGetShaderInfoLog.argtypes = [
            ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.c_char_p
        ]
        self.gl.glDeleteShader.argtypes = [ctypes.c_uint]

        self.gl.glCreateProgram.restype = ctypes.c_uint
        self.gl.glAttachShader.argtypes = [ctypes.c_uint, ctypes.c_uint]
        self.gl.glLinkProgram.argtypes = [ctypes.c_uint]
        self.gl.glGetProgramiv.argtypes = [ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_int)]
        self.gl.glGetProgramInfoLog.argtypes = [
            ctypes.c_uint, ctypes.c_int, ctypes.POINTER(ctypes.c_int), ctypes.c_char_p
        ]
        self.gl.glDeleteProgram.argtypes = [ctypes.c_uint]

        ver = self.gl.glGetString(0x1F02).decode("utf-8", errors="replace")
        glsl = self.gl.glGetString(0x8B8C).decode("utf-8", errors="replace")
        print(f"[OpenGL] {ver} | GLSL {glsl}")

    def compile_shader(self, source: str, shader_type: int):
        sh = self.gl.glCreateShader(shader_type)
        encoded = source.encode("utf-8")
        c_str = ctypes.c_char_p(encoded)
        length = ctypes.c_int(len(encoded))
        self.gl.glShaderSource(sh, 1, ctypes.byref(c_str), ctypes.byref(length))
        self.gl.glCompileShader(sh)

        status = ctypes.c_int()
        self.gl.glGetShaderiv(sh, self.GL_COMPILE_STATUS, ctypes.byref(status))
        log_len = ctypes.c_int()
        self.gl.glGetShaderiv(sh, self.GL_INFO_LOG_LENGTH, ctypes.byref(log_len))
        log = ""
        if log_len.value > 1:
            buf = ctypes.create_string_buffer(log_len.value)
            self.gl.glGetShaderInfoLog(sh, log_len.value, None, buf)
            log = buf.value.decode("utf-8", errors="replace").strip()
        return sh, bool(status.value), log

    def link_program(self, vs_src: str, fs_src: str):
        vs, vs_ok, vs_log = self.compile_shader(vs_src, self.GL_VERTEX_SHADER)
        fs, fs_ok, fs_log = self.compile_shader(fs_src, self.GL_FRAGMENT_SHADER)
        if not vs_ok or not fs_ok:
            self.gl.glDeleteShader(vs)
            self.gl.glDeleteShader(fs)
            return False, vs_log, fs_log, ""

        prog = self.gl.glCreateProgram()
        self.gl.glAttachShader(prog, vs)
        self.gl.glAttachShader(prog, fs)
        self.gl.glLinkProgram(prog)

        status = ctypes.c_int()
        self.gl.glGetProgramiv(prog, self.GL_LINK_STATUS, ctypes.byref(status))
        log_len = ctypes.c_int()
        self.gl.glGetProgramiv(prog, self.GL_INFO_LOG_LENGTH, ctypes.byref(log_len))
        link_log = ""
        if log_len.value > 1:
            buf = ctypes.create_string_buffer(log_len.value)
            self.gl.glGetProgramInfoLog(prog, log_len.value, None, buf)
            link_log = buf.value.decode("utf-8", errors="replace").strip()

        self.gl.glDeleteProgram(prog)
        self.gl.glDeleteShader(vs)
        self.gl.glDeleteShader(fs)
        return bool(status.value), vs_log, fs_log, link_log


# ---------------------------------------------------------------------------
# Iris Preprocessor (`#include` expansion + option overrides + `#if` check)
# ---------------------------------------------------------------------------
INCLUDE_RE = re.compile(r'^\s*#include\s+"([^"]+)"\s*$')
DEFINE_BOOL_RE = re.compile(r'^(\s*)#define\s+([A-Z0-9_]+)(\s*(?://.*)?)$')
DEFINE_VAL_RE = re.compile(r'^(\s*)#define\s+([A-Z0-9_]+)\s+([^\s/]+)(.*)$')


def apply_overrides(text: str, overrides: dict) -> str:
    if not overrides:
        return text
    out_lines = []
    for line in text.splitlines():
        m_val = DEFINE_VAL_RE.match(line)
        m_bool = DEFINE_BOOL_RE.match(line)
        replaced = False
        if m_val and m_val.group(2) in overrides:
            name = m_val.group(2)
            val = overrides[name]
            if val is False:
                out_lines.append(f"// #define {name} (disabled by validator)")
            elif val is True:
                out_lines.append(f"#define {name}")
            else:
                out_lines.append(f"#define {name} {val}")
            replaced = True
        elif m_bool and m_bool.group(2) in overrides:
            name = m_bool.group(2)
            val = overrides[name]
            if val is False:
                out_lines.append(f"// #define {name} (disabled by validator)")
            elif val is True:
                out_lines.append(f"#define {name}")
            else:
                out_lines.append(f"#define {name} {val}")
            replaced = True
        if not replaced:
            out_lines.append(line)
    return "\n".join(out_lines) + "\n"


def expand_includes(file_path: Path, overrides: dict, stack=None) -> str:
    if stack is None:
        stack = []
    resolved = file_path.resolve()
    if resolved in stack:
        raise RuntimeError(f"Circular #include detected: {resolved}")
    if not resolved.exists():
        raise FileNotFoundError(f"Missing included file: {resolved}")

    text = resolved.read_text(encoding="utf-8")
    if resolved.name == "settings.glsl":
        text = apply_overrides(text, overrides)

    out_lines = []
    for idx, line in enumerate(text.splitlines(), 1):
        m = INCLUDE_RE.match(line)
        if m:
            inc = m.group(1)
            inc_path = (SHADERS_DIR / inc.lstrip("/")) if inc.startswith("/") else (resolved.parent / inc)
            out_lines.append(f"// BEGIN INCLUDE {inc}")
            out_lines.append(expand_includes(inc_path, overrides, stack + [resolved]))
            out_lines.append(f"// END INCLUDE {inc}")
        else:
            out_lines.append(line)
    return "\n".join(out_lines) + "\n"


def check_balanced_conditionals(path: Path) -> list:
    errors = []
    depth = 0
    for idx, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if re.match(r"^#\s*(if|ifdef|ifndef)\b", line):
            depth += 1
        elif re.match(r"^#\s*endif\b", line):
            depth -= 1
            if depth < 0:
                errors.append(f"{path.relative_to(ROOT)}:{idx}: stray #endif without matching #if")
    if depth != 0:
        errors.append(f"{path.relative_to(ROOT)}: unbalanced #if/#endif (remaining depth {depth})")
    return errors


def check_rendertargets(fsh_path: Path, expanded_src: str) -> list:
    errors = []
    name = fsh_path.stem
    if name in ("shadow", "final"):
        return errors
    rt_match = re.search(r"/\*\s*RENDERTARGETS:\s*([0-9,\s]+)\*/", expanded_src)
    outs = re.findall(r"layout\s*\(\s*location\s*=\s*(\d+)\s*\)\s*out\s+vec4", expanded_src)
    if not rt_match:
        errors.append(f"{fsh_path.relative_to(ROOT)}: missing /* RENDERTARGETS: ... */ directive")
        return errors
    targets = [t.strip() for t in rt_match.group(1).split(",") if t.strip()]
    if len(targets) != len(outs):
        errors.append(
            f"{fsh_path.relative_to(ROOT)}: RENDERTARGETS has {len(targets)} buffers ({targets}), "
            f"but shader declares {len(outs)} layout outputs ({outs})"
        )
    expected_locs = [str(i) for i in range(len(targets))]
    if sorted(outs, key=int) != expected_locs:
        errors.append(
            f"{fsh_path.relative_to(ROOT)}: layout(location = ...) indices {outs} do not match {expected_locs}"
        )
    return errors


def check_settings_and_properties() -> list:
    errors = []
    settings_text = (SHADERS_DIR / "lib" / "settings.glsl").read_text(encoding="utf-8")
    props_text = (SHADERS_DIR / "shaders.properties").read_text(encoding="utf-8")

    # Collect all defined options (defines + configurable consts)
    defined_opts = set()
    bool_opts = set()
    for line in settings_text.splitlines():
        s = line.strip()
        if s.startswith("#define ") and not s.startswith("#define ANIMATE_"):
            parts = s.split()
            opt = parts[1]
            defined_opts.add(opt)
            if len(parts) == 2 or parts[2].startswith("//"):
                bool_opts.add(opt)
        elif re.match(r"^const\s+(int|float)\s+(\w+)\s*=.*//\s*\[", s):
            m = re.match(r"^const\s+(int|float)\s+(\w+)", s)
            defined_opts.add(m.group(2))

    # Check every boolean option is referenced by #ifdef or #ifndef across shaders
    all_glsl = "\n".join(
        p.read_text(encoding="utf-8")
        for p in SHADERS_DIR.rglob("*")
        if p.suffix in (".glsl", ".vsh", ".fsh")
    )
    for bopt in sorted(bool_opts):
        if not re.search(rf"#\s*(ifdef|ifndef)\s+{re.escape(bopt)}\b", all_glsl):
            errors.append(f"Boolean option {bopt} is never tested with #ifdef or #ifndef (Iris won't register it)")

    # Check every option referenced in shaders.properties screen/sliders/profiles exists in settings.glsl
    for idx, line in enumerate(props_text.splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        if s.startswith("screen.") or s.startswith("screen ") or s.startswith("screen="):
            if ".columns" in s.split("=")[0]:
                continue
            rhs = s.split("=", 1)[1]
            for tok in rhs.split():
                if tok.startswith("[") or tok.startswith("<") or tok == "*":
                    continue
                if tok not in defined_opts:
                    errors.append(f"shaders.properties:{idx}: unknown screen option '{tok}'")
        elif s.startswith("sliders"):
            rhs = s.split("=", 1)[1]
            for tok in rhs.split():
                if tok not in defined_opts:
                    errors.append(f"shaders.properties:{idx}: unknown slider option '{tok}'")
        elif s.startswith("profile."):
            rhs = s.split("=", 1)[1]
            for tok in rhs.split():
                if tok.startswith("!program.") or tok.startswith("profile."):
                    continue
                opt = tok.lstrip("!").split("=")[0].split(":")[0]
                if opt not in defined_opts:
                    errors.append(f"shaders.properties:{idx}: unknown profile option '{opt}'")

    # Check lang files cover all options
    for lang_name in ("zh_cn.lang", "en_us.lang"):
        lang_text = (SHADERS_DIR / "lang" / lang_name).read_text(encoding="utf-8")
        for opt in sorted(defined_opts):
            if f"option.{opt}=" not in lang_text:
                errors.append(f"lang/{lang_name}: missing label 'option.{opt}='")

    return errors


def main():
    print("=== AnimateShader Validation Suite ===")

    # 1. Check balanced #if/#endif across every shader file
    preproc_errors = []
    for p in sorted(SHADERS_DIR.rglob("*")):
        if p.suffix in (".glsl", ".vsh", ".fsh"):
            preproc_errors.extend(check_balanced_conditionals(p))

    if preproc_errors:
        print("Preprocessor balance errors:")
        for e in preproc_errors:
            print("  ERROR:", e)
        sys.exit(1)
    print("[OK] Balanced #if/#endif verified across all GLSL/VSH/FSH files.")

    # 2. Validate shaders.properties, settings.glsl, and lang/*.lang consistency
    meta_errors = check_settings_and_properties()
    if meta_errors:
        print("Metadata/settings errors:")
        for e in meta_errors:
            print("  ERROR:", e)
        sys.exit(1)
    print("[OK] shaders.properties, settings.glsl, and zh_cn/en_us lang files are 100% consistent.")

    # 3. Compile & link every dimension program under multiple option permutations
    gl = HeadlessGL()

    permutations = [
        ("BALANCED_DEFAULT", {}),
        ("PERFORMANCE_PRESET", {
            "SHADOW_QUALITY": 0, "CLOUD_QUALITY": 0, "SSAO_ENABLED": False,
            "WATER_SSR": False, "ANAMORPHIC_STREAK": False,
        }),
        ("FANTASY_ULTRA_SAKURA", {
            "SHADOW_QUALITY": 2, "CLOUD_QUALITY": 2, "COLOR_PALETTE": 1,
            "ANIME_SHADING_STYLE": 2,
        }),
        ("EMERALD_GHIBLI_SMOOTH", {
            "COLOR_PALETTE": 2, "ANIME_SHADING_STYLE": 0,
            "NIGHT_SHADOWS": False, "COLORED_SHADOWS": False,
        }),
        ("ETHEREAL_VIOLET_MINIMAL_FX", {
            "COLOR_PALETTE": 3, "BLOOM_ENABLED": False, "GODRAYS_ENABLED": False,
            "ANIME_CLOUDS": False, "FANTASY_AURORA": False, "MILKY_WAY": False,
            "SHOOTING_STARS": False, "WAVING_FOLIAGE": False, "FOLIAGE_SSS": False,
            "DYNAMIC_HANDLIGHT": False, "WET_REFLECTIONS": False,
            "WATER_CAUSTICS": False, "WATER_SPARKLES": False, "SUN_LENS_FLARE": False,
        }),
    ]

    total_programs = 0
    failures = 0
    rt_checked = set()

    for perm_name, overrides in permutations:
        perm_count = 0
        for dim in ("world0", "world-1", "world1"):
            dim_dir = SHADERS_DIR / dim
            vsh_files = sorted(dim_dir.glob("*.vsh"))
            for vsh_path in vsh_files:
                fsh_path = vsh_path.with_suffix(".fsh")
                if not fsh_path.exists():
                    print(f"  ERROR: Missing fragment pair for {vsh_path}")
                    failures += 1
                    continue

                vs_src = expand_includes(vsh_path, overrides)
                fs_src = expand_includes(fsh_path, overrides)

                if perm_name == "BALANCED_DEFAULT" and fsh_path not in rt_checked:
                    rt_checked.add(fsh_path)
                    rt_errs = check_rendertargets(fsh_path, fs_src)
                    for e in rt_errs:
                        print("  ERROR:", e)
                        failures += 1

                ok, vs_log, fs_log, link_log = gl.link_program(vs_src, fs_src)
                perm_count += 1
                total_programs += 1
                if not ok:
                    failures += 1
                    print(f"  FAIL [{perm_name}] {dim}/{vsh_path.stem}:")
                    if vs_log:
                        print(f"    VSH: {vs_log}")
                    if fs_log:
                        print(f"    FSH: {fs_log}")
                    if link_log:
                        print(f"    LINK: {link_log}")
        print(f"[{'OK' if failures == 0 else 'ERR'}] Permutation '{perm_name}': compiled & linked {perm_count} shader programs.")

    if failures > 0:
        print(f"\nValidation FAILED with {failures} error(s).")
        sys.exit(1)

    print(f"\nALL CHECKS PASSED! Successfully compiled & linked {total_programs} shader program builds with ZERO errors.")


if __name__ == "__main__":
    main()
