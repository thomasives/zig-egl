const std = @import("std");

const c = struct {
    pub usingnamespace @cImport({
        // TODO  Do something less sketchy here
        @cDefine("EGL_CAST(type, value)", "value");
        @cInclude("epoxy/egl.h");
    });
};

comptime {
    std.testing.refAllDecls(@This());
}

fn logError(name: []const u8) void {
    var error_code = c.eglGetError();
    const desc = switch (error_code) {
        c.EGL_SUCCESS => unreachable,
        c.EGL_NOT_INITIALIZED => "not initialized",
        c.EGL_BAD_ACCESS => "bad access",
        c.EGL_BAD_ALLOC => "bad alloc",
        c.EGL_BAD_ATTRIBUTE => "bad attribute",
        c.EGL_BAD_CONTEXT => "bad context",
        c.EGL_BAD_CONFIG => "bad config",
        c.EGL_BAD_CURRENT_SURFACE => "bad current surface",
        c.EGL_BAD_DISPLAY => "bad display",
        c.EGL_BAD_SURFACE => "bad surface",
        c.EGL_BAD_MATCH => "bad match",
        c.EGL_BAD_PARAMETER => "bad parameter",
        c.EGL_BAD_NATIVE_PIXMAP => "bad native pixmap",
        c.EGL_BAD_NATIVE_WINDOW => "bad native window",
        c.EGL_CONTEXT_LOST => "context lost",
        else => "unknown error",
    };

    std.log.scoped(.EGL).err("{s} generated error: {x} \"{s}\" ", .{ name, error_code, desc });
}

pub const NativeDisplay = ?*anyopaque;
pub const NativeWindow = ?*anyopaque;

pub fn getDisplay(native: NativeDisplay) ?*Display {
    const display = if (native) |ptr| c.eglGetDisplay(ptr) else c.eglGetDisplay(@intToPtr(NativeDisplay, c.EGL_DEFAULT_DISPLAY));

    if (display == @intToPtr(?*anyopaque, c.EGL_NO_DISPLAY)) return null;

    return @ptrCast(*Display, display);
}

pub const Api = enum(c_uint) {
    opengl = c.EGL_OPENGL_API,
    opengl_es = c.EGL_OPENGL_ES_API,
    openvg = c.EGL_OPENVG_API,
};

pub fn bindApi(api: Api) bool {
    if (c.eglBindAPI(@enumToInt(api)) != c.EGL_TRUE) {
        logError("eglBindApi");
        return false;
    }

    return true;
}

pub const Version = struct {
    major: i32,
    minor: i32,
};

pub const Display = opaque {
    pub fn initialize(display: *Display) ?Version {
        var version: Version = undefined;
        if (c.eglInitialize(display, &version.major, &version.minor) != c.EGL_TRUE) {
            logError("eglInitialize");
            return null;
        }

        return version;
    }

    pub fn createContext(display: *Display, config: *Config, attribs: Context.AttribList) ?*Context {
        const context = c.eglCreateContext(display, config, @intToPtr(?*anyopaque, c.EGL_NO_CONTEXT), attribs.data.ptr);

        if (context == @intToPtr(?*anyopaque, c.EGL_NO_CONTEXT)) {
            logError("eglCreateContext");
            return null;
        }

        return @ptrCast(*Context, context);
    }

    pub fn makeCurrent(display: *Display, draw: *Surface, read: *Surface, context: *Context) bool {
        if (c.eglMakeCurrent(display, draw, read, context) != c.EGL_TRUE) {
            logError("eglMakeCurrent");
            return false;
        }

        return true;
    }

    pub fn swapBuffers(display: *Display, surface: *Surface) bool {
        if (c.eglSwapBuffers(display, surface) != c.EGL_TRUE) {
            logError("eglSwapBuffers");
            return false;
        }

        return true;
    }

    pub fn chooseConfig(display: *Display, alloc: std.mem.Allocator, attribs: Config.AttribList) error{ OutOfMemory, EglFailure }![]const *Config {
        var num_config: c.EGLint = undefined;
        if (c.eglChooseConfig(display, attribs.data.ptr, null, 0, &num_config) != c.EGL_TRUE) {
            logError("eglChooseConfig");
            return error.EglFailure;
        }

        var configs = try alloc.alloc(*Config, @intCast(usize, num_config));
        if (c.eglChooseConfig(display, attribs.data.ptr, @ptrCast([*c]?*anyopaque, configs.ptr), num_config, &num_config) != c.EGL_TRUE) {
            logError("eglChooseConfig");
            return error.EglFailure;
        }

        return configs;
    }

    pub fn createWindowSurface(display: *Display, config: *Config, window: NativeWindow, attribs: ?Surface.AttribList) ?*Surface {
        const surface = c.eglCreateWindowSurface(display, config, @ptrToInt(window), if (attribs) |list| list.data.ptr else null);

        if (surface == @intToPtr(?*anyopaque, c.EGL_NO_SURFACE)) return null;

        return @ptrCast(*Surface, surface);
    }

    pub fn getConfigAttrib(display: *Display, config: *Config, comptime attrib: Config.Attrib) error{EglFailure}!Config.TypeOf(attrib) {
        var raw_value: c.EGLint = undefined;
        if (c.eglGetConfigAttrib(display, config, @enumToInt(@as(Config.AttribList.Attrib, attrib)), &raw_value) != c.EGL_TRUE) {
            logError();
            return error.EglFailure;
        }

        const ty = Config.TypeOf(attrib);

        switch (@typeInfo(ty)) {
            .Struct => return ty.fromInt(raw_value),
            .Enum => return @intToEnum(ty, raw_value),
            .Int => return @intCast(ty, raw_value),
            else => unreachable,
        }
    }
};

pub const Config = opaque {
    pub const Attrib = AttribList.Attrib;
    pub const TypeOf = AttribList.TypeOf;

    pub const AttribList = AttributeList(&[_]AttribDesc{
        .{ .name = "alpha_mask_size", .id = c.EGL_ALPHA_MASK_SIZE, .ty = i32 },
        .{ .name = "alpha_size", .id = c.EGL_ALPHA_SIZE, .ty = i32 },
        .{ .name = "bind_to_texture_rgb", .id = c.EGL_BIND_TO_TEXTURE_RGB, .ty = bool },
        .{ .name = "bind_to_texture_rgba", .id = c.EGL_BIND_TO_TEXTURE_RGBA, .ty = bool },
        .{ .name = "blue_size", .id = c.EGL_BLUE_SIZE, .ty = i32 },
        .{ .name = "buffer_size", .id = c.EGL_BUFFER_SIZE, .ty = i32 },
        .{ .name = "color_buffer_type", .id = c.EGL_COLOR_BUFFER_TYPE, .ty = ColorBufferType },
        .{ .name = "config_caveat", .id = c.EGL_CONFIG_CAVEAT, .ty = ConfigCaveat },
        .{ .name = "config_id", .id = c.EGL_CONFIG_ID, .ty = i32 },
        .{ .name = "conformant", .id = c.EGL_CONFORMANT, .ty = ApiMask },
        .{ .name = "depth_size", .id = c.EGL_DEPTH_SIZE, .ty = i32 },
        .{ .name = "green_size", .id = c.EGL_GREEN_SIZE, .ty = i32 },
        .{ .name = "level", .id = c.EGL_LEVEL, .ty = i32 },
        .{ .name = "luminance_size", .id = c.EGL_LUMINANCE_SIZE, .ty = i32 },
        // .{ .name = "match_native_pixmap", .id = c.EGL_MATCH_NATIVE_PIXMAP, .ty = *anyopaque },
        .{ .name = "native_renderable", .id = c.EGL_NATIVE_RENDERABLE, .ty = bool },
        .{ .name = "max_swap_interval", .id = c.EGL_MAX_SWAP_INTERVAL, .ty = i32 },
        .{ .name = "min_swap_interval", .id = c.EGL_MIN_SWAP_INTERVAL, .ty = i32 },
        .{ .name = "red_size", .id = c.EGL_RED_SIZE, .ty = i32 },
        .{ .name = "sample_buffers", .id = c.EGL_SAMPLE_BUFFERS, .ty = i32 },
        .{ .name = "samples", .id = c.EGL_SAMPLES, .ty = i32 },
        .{ .name = "stencil_size", .id = c.EGL_STENCIL_SIZE, .ty = i32 },
        .{ .name = "renderable_type", .id = c.EGL_RENDERABLE_TYPE, .ty = ApiMask },
        .{ .name = "surface_type", .id = c.EGL_SURFACE_TYPE, .ty = SurfaceType },
        .{ .name = "transparent_type", .id = c.EGL_TRANSPARENT_TYPE, .ty = TransparentType },
        .{ .name = "transparent_red_value", .id = c.EGL_TRANSPARENT_RED_VALUE, .ty = i32 },
        .{ .name = "transparent_green_value", .id = c.EGL_TRANSPARENT_GREEN_VALUE, .ty = i32 },
        .{ .name = "transparent_blue_value", .id = c.EGL_TRANSPARENT_BLUE_VALUE, .ty = i32 },
    });

    pub const ColorBufferType = enum(c.EGLint) {
        rgb_buffer = c.EGL_RGB_BUFFER,
        lumiance_buffer = c.EGL_LUMINANCE_BUFFER,
    };

    pub const ConfigCaveat = enum(c.EGLint) {
        dont_care = c.EGL_DONT_CARE,
        none = c.EGL_NONE,
        slow = c.EGL_SLOW_CONFIG,
        non_conformant = c.EGL_NON_CONFORMANT_CONFIG,
    };

    pub const ApiMask = struct {
        opengl: bool = false,
        opengl_es: bool = false,
        opengl_es2: bool = false,
        openvg: bool = false,

        pub fn toInt(self: @This()) c.EGLint {
            var val: c.EGLint = 0;
            if (self.opengl) val |= c.EGL_OPENGL_BIT;
            if (self.opengl_es) val |= c.EGL_OPENGL_ES_BIT;
            if (self.opengl_es2) val |= c.EGL_OPENGL_ES2_BIT;
            if (self.openvg) val |= c.EGL_OPENGL_BIT;
            return val;
        }

        pub fn fromInt(val: c.EGLint) @This() {
            return .{
                .opengl = val & c.EGL_OPENGL_BIT != 0,
                .opengl_es = val & c.EGL_OPENGL_ES_BIT != 0,
                .opengl_es2 = val & c.EGL_OPENGL_ES2_BIT != 0,
                .openvg = val & c.EGL_OPENVG_BIT != 0,
            };
        }
    };

    pub const SurfaceType = struct {
        multisample_resolve_box: bool = false,
        pbuffer: bool = false,
        pixmap: bool = false,
        swap_behavior_preserved: bool = false,
        vg_colorspace_linear: bool = false,
        window: bool = false,

        pub fn toInt(self: @This()) c.EGLint {
            var val: c.EGLint = 0;
            if (self.multisample_resolve_box) val |= c.EGL_MULTISAMPLE_RESOLVE_BOX_BIT;
            if (self.pbuffer) val |= c.EGL_PBUFFER_BIT;
            if (self.pixmap) val |= c.EGL_PIXMAP_BIT;
            if (self.swap_behavior_preserved) val |= c.EGL_SWAP_BEHAVIOR_PRESERVED_BIT;
            if (self.vg_colorspace_linear) val |= c.EGL_VG_COLORSPACE_LINEAR_BIT;
            if (self.window) val |= c.EGL_WINDOW_BIT;
            return val;
        }

        pub fn fromInt(val: c.EGLint) @This() {
            return .{
                .multisample_resolve_box = val & c.EGL_MULTISAMPLE_RESOLVE_BOX_BIT != 0,
                .pbuffer = val & c.EGL_PBUFFER_BIT != 0,
                .pixmap = val & c.EGL_PIXMAP_BIT != 0,
                .swap_behavior_preserved = val & c.EGL_SWAP_BEHAVIOR_PRESERVED_BIT != 0,
                .vg_colorspace_linear = val & c.EGL_VG_COLORSPACE_LINEAR_BIT != 0,
                .window = val & c.EGL_WINDOW_BIT != 0,
            };
        }
    };

    pub const TransparentType = enum(c.EGLint) {
        none = c.EGL_NONE,
        rgb = c.EGL_TRANSPARENT_RGB,
    };
};

pub const Context = opaque {
    pub const AttribList = AttributeList(&[_]AttribDesc{
        .{ .name = "major_version", .id = c.EGL_CONTEXT_MAJOR_VERSION, .ty = i32 },
        .{ .name = "minor_version", .id = c.EGL_CONTEXT_MINOR_VERSION, .ty = i32 },
        .{ .name = "opengl_profile_mask", .id = c.EGL_CONTEXT_OPENGL_PROFILE_MASK, .ty = ProfileMask },
        .{ .name = "opengl_debug", .id = c.EGL_CONTEXT_OPENGL_DEBUG, .ty = bool },
        .{ .name = "opengl_forward_compatible", .id = c.EGL_CONTEXT_OPENGL_FORWARD_COMPATIBLE, .ty = bool },
        .{ .name = "opengl_robust_access", .id = c.EGL_CONTEXT_OPENGL_ROBUST_ACCESS, .ty = bool },
        .{ .name = "opengl_reset_notification_strategy", .id = c.EGL_CONTEXT_OPENGL_RESET_NOTIFICATION_STRATEGY, .ty = ResetNotificationStrategy },
    });

    pub const ProfileMask = struct {
        core: bool = false,
        compatibility: bool = false,

        pub fn toInt(self: @This()) c.EGLint {
            var val: c.EGLint = 0;
            if (self.core) val |= c.EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT;
            if (self.compatibility) val |= c.EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT;
            return val;
        }

        pub fn fromInt(val: c.EGLint) @This() {
            return .{
                .core = val & c.EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT,
                .compatibility = val & c.EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT,
            };
        }
    };

    pub const ResetNotificationStrategy = enum(c.EGLint) {
        lose_conext = c.EGL_LOSE_CONTEXT_ON_RESET,
        no_notification = c.EGL_NO_RESET_NOTIFICATION,
    };
};

pub const Surface = opaque {
    pub const AttribList = AttributeList(&[_]AttribDesc{
        .{ .name = "gl_colorspace", .id = c.EGL_GL_COLORSPACE, .ty = GlColorspace },
        .{ .name = "render_buffer", .id = c.EGL_RENDER_BUFFER, .ty = RenderBuffer },
        .{ .name = "vg_alpha_format", .id = c.EGL_VG_ALPHA_FORMAT, .ty = VgAlphaFormat },
        .{ .name = "vg_colorspace", .id = c.EGL_VG_COLORSPACE, .ty = VgColorspace },
    });

    pub const GlColorspace = enum(c.EGLint) {
        srgb = c.EGL_GL_COLORSPACE_SRGB,
        linear = c.EGL_GL_COLORSPACE_LINEAR,
    };

    pub const RenderBuffer = enum(c.EGLint) {
        back_buffer = c.EGL_BACK_BUFFER,
        single_buffer = c.EGL_SINGLE_BUFFER,
    };

    pub const VgAlphaFormat = enum(c.EGLint) {
        nonpre = c.EGL_VG_ALPHA_FORMAT_NONPRE,
        pre = c.EGL_VG_ALPHA_FORMAT_PRE,
    };

    pub const VgColorspace = enum(c.EGLint) {
        srgb = c.EGL_VG_COLORSPACE_sRGB,
        linear = c.EGL_VG_COLORSPACE_LINEAR,
    };
};

const AttribDesc = struct {
    name: []const u8,
    id: c.EGLint,
    ty: type,
};

fn AttributeList(comptime attrib_table: []const AttribDesc) type {
    return struct {
        data: []const c.EGLint,

        pub fn make(comptime attribs: anytype) @This() {
            const type_info = @typeInfo(@TypeOf(attribs)).Struct;

            comptime var data: []const c.EGLint = &[0]c.EGLint{};
            inline for (type_info.fields) |field| {
                const attrib_desc = blk: {
                    inline for (attrib_table) |desc| {
                        if (comptime std.mem.order(u8, field.name, desc.name) == .eq) break :blk desc;
                    }
                    @compileError("Unknown attribute: " ++ field.name);
                };

                const raw_value = @as(attrib_desc.ty, @field(attribs, field.name));
                const value = switch (@typeInfo(attrib_desc.ty)) {
                    .Int => @intCast(c.EGLint, raw_value),
                    .Struct => raw_value.toInt(),
                    .Enum => @enumToInt(raw_value),
                    else => unreachable,
                };

                data = data ++ [2]c.EGLint{ attrib_desc.id, value };
            }

            data = data ++ &[1]c.EGLint{c.EGL_NONE};

            return .{ .data = data };
        }

        pub fn TypeOf(comptime attrib: Attrib) type {
            inline for (attrib_table) |desc| {
                if (comptime std.mem.order(u8, @tagName(attrib), desc.name) == .eq) return desc.ty;
            }

            @compileError("Unknown attribute: " ++ @tagName(attrib));
        }

        const Attrib = blk: {
            var enumFields: [attrib_table.len]std.builtin.TypeInfo.EnumField = undefined;
            var decls = [_]std.builtin.TypeInfo.Declaration{};
            inline for (attrib_table) |desc, i| {
                enumFields[i] = .{
                    .name = desc.name,
                    .value = desc.id,
                };
            }

            break :blk @Type(.{
                .Enum = .{
                    .layout = .Auto,
                    .tag_type = c.EGLint,
                    .fields = &enumFields,
                    .decls = &decls,
                    .is_exhaustice = true,
                },
            });
        };
    };
}
