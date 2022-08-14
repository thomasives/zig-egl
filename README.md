# zig-egl
Thin, type-safe zig wrapper for EGL

## Usage

Add as package in build.zig:
```
exe.addPackage(.{
    .name = "egl",
    .path = .{ .path = "/path/to/zig-egl/index.zig" }
});
```

Then in your program:

```
...
const egl = @import("egl");

const egl_display = egl.getDisplay(native_display) orelse return error.NoEglDisplay;
...
const config_attribs = comptime egl.Config.AttribList.make(.{ .red_size = 8, .renderable_type = .{ .opengl = true } });
const configs = egl_display.choseConfig(alloc, config_attribs);
```

Most functions are available as a method on the egl_display object and will log errors with std.log.

## Current State
Very much WIP.

Wrappers are being implemented on demand.  API may change in the future.  Pull requests welcome.
