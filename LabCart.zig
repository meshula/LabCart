
// LabCart.zig
// sokol/microui boilerplate

const std = @import("std");
const sg    = @import("sokol").gfx;
const sapp  = @import("sokol").app;
const sgapp = @import("sokol").app_gfx_glue;
const sdtx  = @import("sokol").debugtext;
const sgl   = @import("sokol").gl;
const ui = @cImport({ @cInclude("sgl-microui.h"); });
const test_lua = @import("LabCartLua.zig");

var raw = std.heap.GeneralPurposeAllocator(.{}){};
pub const ALLOCATOR = &raw.allocator;

var mu_context : ?*ui.mu_Context = null;

// font indices
const KC853 = 0;
const KC854 = 1;
const Z1013 = 2;
const CPC   = 3;
const C64   = 4;
const ORIC  = 5;

const CartState = struct {
    pass_action: sg.PassAction = .{},
    sgl_pipeline: sgl.Pipeline = .{},
    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    frame_count: f32 = 0,

    options: struct {
        check_one: i32 = 0,
        check_two: i32 = 0,
    } = .{},
};
var state = CartState{};

pub fn drawPoint(x_ndc: f32, y_ndc:f32, ptsize:f32, col:Color_u8) void {
    const off = ptsize/2;

    sgl.v2fC3b(x_ndc - off, y_ndc - off, col.r, col.g, col.b);
    sgl.v2fC3b(x_ndc - off, y_ndc + off, col.r, col.g, col.b);
    sgl.v2fC3b(x_ndc + off, y_ndc + off, col.r, col.g, col.b);
    sgl.v2fC3b(x_ndc + off, y_ndc - off, col.r, col.g, col.b);
}

pub const Color_u8 = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 1,

    pub fn to_float(self: @This()) sg.Color {
        return .{
            .r = @intToFloat(f32, self.r)/255.0,
            .g = @intToFloat(f32, self.g)/255.0,
            .b = @intToFloat(f32, self.b)/255.0,
            .a = @intToFloat(f32, self.a)/255.0,
        };
    }
};

pub const palette = struct {
    pub const fg: Color_u8 = .{
        .r = 69,
        .g = 157, 
        .b = 132,
        .a = 1,
    };
    pub const fg_f = fg.to_float();

    pub const fg_alt: Color_u8 = .{
        .r = 11,
        .g = 6, 
        .b = 12,
        .a = 1,
    };
    pub const fg_alt_f = fg_alt.to_float();

    pub const bg: Color_u8 = .{
        .r = 25,
        .g = 50, 
        .b = 78,
        .a = 1,
    };
    pub const bg_f = bg.to_float();

    pub const highlight: Color_u8 = .{
        .r = 227,
        .g = 180, 
        .b = 0,
        .a = 1,
    };
    pub const highlight_f = highlight.to_float();
};


export fn init() void {
    sg.setup(.{ 
        .context = sgapp.context()
    });
    sgl.setup(.{
        .sample_count = sapp.sampleCount()
    });

    // set up pipeline state as needed for typical 3d rendering
    state.sgl_pipeline = sgl.makePipeline(.{
        .depth = .{
            .write_enabled = true,
            .compare = .LESS_EQUAL,
        },
        .cull_mode = .BACK,
    });

    const attachment: sg.ColorState = .{
        .blend = .{
            .enabled = true,
            .src_factor_rgb = .SRC_ALPHA,
            .dst_factor_rgb = .ONE_MINUS_SRC_ALPHA,
        }};
 
    var desc: sg.PipelineDesc = .{};
    desc.colors[0] = attachment;

    var ui_pip = sgl.makePipeline(desc);

    // setup sokol-debugtext with all builtin fonts
    var sdtx_desc: sdtx.Desc = .{};
    sdtx_desc.fonts[KC853] = sdtx.fontKc853();
    sdtx_desc.fonts[KC854] = sdtx.fontKc854();
    sdtx_desc.fonts[Z1013] = sdtx.fontZ1013();
    sdtx_desc.fonts[CPC]   = sdtx.fontCpc();
    sdtx_desc.fonts[C64]   = sdtx.fontC64();
    sdtx_desc.fonts[ORIC]  = sdtx.fontOric();
    sdtx.setup(sdtx_desc);

    // clear screen pass action
    state.pass_action.colors[0] = .{ .action = .CLEAR, .value = palette.bg_f};

    mu_context = ui.microui_init(&ui_pip);
}

// print all characters in a font
fn printFont(font_index: u32, title: [:0]const u8, r: u8, g: u8, b: u8) void {
    sdtx.font(font_index);
    sdtx.color3b(r, g, b);
    sdtx.puts(title);
    var c: u16 = 32;
    while (c < 256): (c += 1) {
        sdtx.putc(@intCast(u8, c));
        if (((c + 1) & 63) == 0) {
            sdtx.crlf();
        }
    }
    sdtx.crlf();
}

fn drawTriangle() void {
    sgl.defaults();
    sgl.beginTriangles();
    sgl.v2fC3b( 0.0,  0.5, 255, 0, 0);
    sgl.v2fC3b(-0.5, -0.5, 0, 0, 255);
    sgl.v2fC3b( 0.5, -0.5, 0, 255, 0);
    sgl.end();
}

export fn frame() void
{
    const ww = sapp.widthf();
    const wh = sapp.heightf();
    sgl.viewportf(0,0,ww,wh, true);

    ui.microui_begin();
    
    if (
        ui.mu_begin_window(
            mu_context,
            "Settings",
            ui.mu_rect(350, 40, 300, 200)
        ) 
        != 0
    )
    {
        if (ui.mu_button(mu_context, "Button1") != 0) {
            //printf("Button1 pressed\n");
        }
        ui.mu_label(mu_context, "A label");
        if (ui.mu_begin_popup(mu_context, "My Popup") != 0) {
             ui.mu_label(mu_context, "Hello world!");
             ui.mu_end_popup(mu_context);
        }

        ui.mu_layout_row(mu_context, 1, &([1]c_int{ 0 }), 0);
        inline for (std.meta.fields(@TypeOf(state.options))) 
                |field| 
        {
            var name = @ptrCast([*c]const u8, field.name);
            switch (field.field_type) {
                i32 => {
                    _ = ui.mu_checkbox(
                        mu_context,
                        name,
                        @ptrCast([*c]c_int, &@field(state.options, field.name))
                    );
                },
                else => {
                    ui.mu_label(mu_context, name);
                }
            }
        }

        ui.mu_end_window(mu_context);
    }
    
    ui.microui_end();

    ui.microui_render(sapp.width(), sapp.height());

    // draw mouse cursor location
    var mx: f32 = state.mouse_x / sapp.widthf();
    var my: f32 = state.mouse_y / sapp.heightf();
    sgl.beginQuads();
    drawPoint(2 * mx - 1, 
              1 - (2 * my), 
              0.02, palette.highlight);
    sgl.end();

    state.frame_count+=1;

    // set virtual canvas size to half display size so that
    // glyphs are 16x16 display pixels
    sdtx.canvas(sapp.widthf()*0.5, sapp.heightf()*0.5);
    sdtx.origin(0.0, 2.0);
    sdtx.home();

    // draw all font characters
    // printFont(KC853, "KC85/3:\n",      0xf4, 0x43, 0x36);
    // printFont(KC854, "KC85/4:\n",      0x21, 0x96, 0xf3);
    // printFont(Z1013, "Z1013:\n",       0x4c, 0xaf, 0x50);
    // printFont(CPC,   "Amstrad CPC:\n", 0xff, 0xeb, 0x3b);
    printFont(C64,   "C64:\n",         0x79, 0x86, 0xcb);
    // printFont(ORIC,  "Oric Atmos:\n",  0xff, 0x98, 0x00);

    // do the actual rendering
    sg.beginDefaultPass(state.pass_action, sapp.width(), sapp.height());
    sgl.draw();
    sdtx.draw();
    ui.microui_draw_pass();
    sg.endPass();
    sg.commit();
}

export fn input(ev: ?*const sapp.Event) void {
    const event = ev.?;
    if (event.type == .MOUSE_MOVE) {
        state.mouse_x = event.mouse_x;
        state.mouse_y = event.mouse_y;
        ui.mu_input_mousemove(mu_context, @floatToInt(c_int, event.mouse_x), @floatToInt(c_int, event.mouse_y));
    }
    else if (event.type == .MOUSE_DOWN) {
        state.mouse_x = event.mouse_x;
        state.mouse_y = event.mouse_y;
        const buttons : u5 = @intCast(u5, @enumToInt(event.mouse_button));
        const shifted_buttons : u32 = @shlExact(@intCast(u32, 1), buttons);
        ui.mu_input_mousedown(mu_context, 
            @floatToInt(c_int, event.mouse_x), 
            @floatToInt(c_int, event.mouse_y), 
            @intCast(c_int, shifted_buttons));
    }
    else if (event.type == .MOUSE_UP) {
        state.mouse_x = event.mouse_x;
        state.mouse_y = event.mouse_y;
        const buttons : u5 = @intCast(u5, @enumToInt(event.mouse_button));
        const shifted_buttons : u32 = @shlExact(@intCast(u32, 1), buttons);
        ui.mu_input_mouseup(mu_context, 
            @floatToInt(c_int, event.mouse_x), 
            @floatToInt(c_int, event.mouse_y), 
            @intCast(c_int, shifted_buttons));
     }

//     switch (ev->type) {
//         case SAPP_EVENTTYPE_MOUSE_SCROLL:
//             mu_input_mousewheel(&state.mu_ctx, (int)ev->scroll_y);
//             break;
//         case SAPP_EVENTTYPE_KEY_DOWN:
//             mu_input_keydown(&state.mu_ctx, key_map[ev->key_code & 511]);
//             break;
//         case SAPP_EVENTTYPE_KEY_UP:
//             mu_input_keyup(&state.mu_ctx, key_map[ev->key_code & 511]);
//             break;
//         case SAPP_EVENTTYPE_CHAR:
//             {
//                 char txt[2] = { (char)(ev->char_code & 255), 0 };
//                 mu_input_text(&state.mu_ctx, txt);
//             }
//             break;
//         default:
//             break;
//     }
// }

}

export fn cleanup() void {
    sdtx.shutdown();
    sgl.shutdown();
    sg.shutdown();
}

pub fn main() !void {
    var args = std.process.args();

    // ignore the app name, always first in args
    _ = args.next(ALLOCATOR);

    test_lua.test_lua();

    sapp.run(.{
        .init_cb = init,
        .frame_cb = frame,
        .event_cb = input,
        .cleanup_cb = cleanup,
        .width = 1024,
        .height = 1024,
        .icon = .{
            .sokol_default = true,
        },
        .window_title = "LabCart"
    });
}


