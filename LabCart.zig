
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
const print = @import("std").debug.print;

var raw = std.heap.GeneralPurposeAllocator(.{}){};
pub const ALLOCATOR = &raw.allocator;

pub const ArrayList = std.ArrayList;

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

    terminal: ?*Terminal = null,

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

// +----------------------------------------------+ (0 - wrap) % buffer_height
// |                                              |
// |                                              |
// |                                              |
// |                                              |
// |                                              |
// |- - -  -                                 - - -| first_visible_y
// |                                              |
// |                                              |
// |                                             -| next_write_y
// |                                              |
// |                                              |
// |                                         - - -| scrolly + h
// |                                              |
// |                                              |
// |                                              |
// |                                              |
// +----------------------------------------------+ buffer_height

pub const Terminal = struct {
    buffer : ArrayList(u8),
    w : u8 = 0,
    visible_h : u8 = 0,
    next_write_y : u32 = 0,
    first_visible_y : u32 = 0,
    buffer_height : u32 = 0,
    wrap : u32 = 0,
    buffer_len : u32 = 0,

    pub fn init(width: u8, height: u8, buff_height: u32) Terminal {
        var buff_len = width * (height + buff_height);
        var buff = ArrayList(u8).initCapacity(ALLOCATOR, buff_len) 
            catch unreachable;

        buff.appendNTimes(0, width * (height + buff_height)) catch unreachable;
        print("buffer len alloc: {d}\n", .{buff.items.len});

        return Terminal{
            .buffer = buff,
            .w = width,
            .visible_h = height,
            .buffer_height = buff_height,
            .buffer_len = buff_len,
        };
    }

    pub fn append_line(t: *Terminal, line: [] const u8) void {
        // replace the line at cursor if line isn't empty
        if (line.len > 0) {
            var max_len = line.len;
            if (max_len > t.w) {
                max_len = t.w;
            }
            var addr = (t.next_write_y * t.w) % t.buffer_len;
            print("append at y {d}, width {d}, bh {d}, addr {d}\n", .{t.next_write_y, t.w, t.buffer_height, addr});
            var i : u32 = 0;
            while (i < max_len) {
                t.buffer.items[addr + i] = line[i];
                i += 1;
            }
            while (i < max_len) {
                t.buffer.items[addr + i] = 0;
                i += 1;
            }
        }

        // inc next_write_y
        t.next_write_y += 1;
    }
    
    pub fn constrain_visible(t: *Terminal) void {
        // if it's visible do nothing
        if ((t.next_write_y > t.first_visible_y) and
            (t.next_write_y < (t.first_visible_y + t.visible_h))) {
            return;
        }
        // if bringing the previous page into view would go beyond the buffer
        // start, set visible to zero
        if (t.next_write_y < t.first_visible_y) {
            if (t.next_write_y < t.visible_h) {
                t.first_visible_y = 0;
                return;
            }
        }
        // reveal the page preceding the new line
        t.first_visible_y = t.next_write_y - t.visible_h;
    }

    pub fn render(t: *Terminal) void {
        sdtx.font(C64);
        sdtx.color3b(1,1,1);
        var x: u8 = 0;
        var y: u8 = 0;
        var addr: u32 = (t.first_visible_y * t.w) % t.buffer_len;
        while (y < t.visible_h) {
            while (x < t.w) {
                var c: u8 = t.buffer.items[addr + x];
                if (c == 0) {
                    break;
                }
                sdtx.putc(c);
                x += 1;
            }
            sdtx.crlf();
            y += 1;
            addr = ((t.first_visible_y + y) * t.w) % t.buffer_len;
            //print("{s}\n", .{t.buffer.items[addr..addr+t.w]});
            x = 0;
        }
    }

    pub fn dump(t: *Terminal) void {
        var y: u32 = 0;
        while (y < 10) {
            var addr: u32 = (y * t.w);
            print("{s}\n", .{t.buffer.items[addr..addr+t.w]});
            y += 1;
        }
    }

};



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

var text_buff: [256]u8 = [_]u8{0} ** 256;

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

        var submitted : u1 = 0;
        if ((ui.mu_textbox_ex(mu_context, &text_buff, 255, 0) & ui.MU_RES_SUBMIT) != 0) {
            ui.mu_set_focus(mu_context, mu_context.?.last_id);
            submitted = 1;
        }
        if (submitted == 1) {
            Terminal.append_line(state.terminal.?, &text_buff);
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
    //printFont(C64,   "C64:\n",         0x79, 0x86, 0xcb);
    // printFont(ORIC,  "Oric Atmos:\n",  0xff, 0x98, 0x00);

    Terminal.render(state.terminal.?);


    // do the actual rendering
    sg.beginDefaultPass(state.pass_action, sapp.width(), sapp.height());
    sgl.draw();
    sdtx.draw();
    ui.microui_draw_pass();
    sg.endPass();
    sg.commit();
}


fn key_map(char: sapp.Keycode) c_int {
    return switch(@intToEnum(sapp.Keycode, @enumToInt(char) & 511)) {
        sapp.Keycode.LEFT_SHIFT => ui.MU_KEY_SHIFT,
        sapp.Keycode.RIGHT_SHIFT => ui.MU_KEY_SHIFT,
        sapp.Keycode.LEFT_CONTROL => ui.MU_KEY_CTRL,
        sapp.Keycode.RIGHT_CONTROL => ui.MU_KEY_CTRL,
        sapp.Keycode.LEFT_ALT => ui.MU_KEY_ALT,
        sapp.Keycode.RIGHT_ALT => ui.MU_KEY_ALT,
        sapp.Keycode.ENTER => ui.MU_KEY_RETURN,
        sapp.Keycode.BACKSPACE => ui.MU_KEY_BACKSPACE,
        else => 0,
    };
}

export fn input(ev: ?*const sapp.Event) void {
    const event = ev.?;
    if (event.type == .MOUSE_MOVE) {
        state.mouse_x = event.mouse_x;
        state.mouse_y = event.mouse_y;
        ui.mu_input_mousemove(mu_context,
            @floatToInt(c_int, event.mouse_x), @floatToInt(c_int, event.mouse_y));
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
    else if (event.type == .KEY_DOWN) {
        ui.mu_input_keydown(mu_context, key_map(event.key_code));
    }
    else if (event.type == .KEY_UP) {
        ui.mu_input_keyup(mu_context, key_map(event.key_code));
    }
    else if (event.type == .CHAR) {
        var txt: [2]u8 = .{ @intCast(u8, (event.char_code & 255)), 0 };
        ui.mu_input_text(mu_context, &txt);
    }

//     switch (ev->type) {
//         case SAPP_EVENTTYPE_MOUSE_SCROLL:
//             mu_input_mousewheel(&state.mu_ctx, (int)ev->first_visible_y);
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

    state.terminal = &Terminal.init(40, 24, 24);
    Terminal.append_line(state.terminal.?, "Hello world 1");
    Terminal.append_line(state.terminal.?, "Hello world 2");
    Terminal.append_line(state.terminal.?, "Hello world 3");
    Terminal.append_line(state.terminal.?, "Hello world 4");
    Terminal.append_line(state.terminal.?, "Hello world 5");
    Terminal.append_line(state.terminal.?, "Hello world 6");
    Terminal.append_line(state.terminal.?, "Hello world 7");
    Terminal.append_line(state.terminal.?, "Hello world 8");
    Terminal.append_line(state.terminal.?, "Hello world 9");
    Terminal.dump(state.terminal.?);

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


