
// LabCart.zig
// sokol/microui boilerplate

const std = @import("std");
pub const ArrayList = std.ArrayList;
const sg    = @import("sokol").gfx;
const sapp  = @import("sokol").app;
const sgapp = @import("sokol").app_gfx_glue;
const sdtx  = @import("sokol").debugtext;
const sgl   = @import("sokol").gl;
const ui = @cImport({ @cInclude("sgl-microui.h"); });
const test_lua = @import("LabCartLua.zig");
const print = @import("std").debug.print;
const palette = @import("palette.zig");
const terminal = @import("terminal.zig");
const Terminal = terminal.Terminal;
const lf = @cImport({ @cInclude("LabFont.h"); });

var raw = std.heap.GeneralPurposeAllocator(.{}){};
var ALLOCATOR : ?std.mem.Allocator = raw.allocator();
var font_japanese: ?*lf.LabFont = undefined;
var j_st: ?*lf.LabFontState = undefined;
var font_normal: ?*lf.LabFont = undefined;
var n_st: ?*lf.LabFontState = undefined;


var mu_context : ?*ui.mu_Context = null;

const CartState = struct {
    pass_action: sg.PassAction = .{},
    sgl_pipeline: sgl.Pipeline = .{},
    mouse_x: f32 = 0,
    mouse_y: f32 = 0,
    frame_count: f32 = 0,

    terminal: ?*Terminal = null,
    line_color: u8 = 0,

    options: struct {
        check_one: i32 = 0,
        check_two: i32 = 0,
    } = .{},
};
var state = CartState{};

pub fn drawPoint(x_ndc: f32, y_ndc:f32, ptsize:f32, col:palette.Color_u8) void {
    const off = ptsize/2;

    sgl.v2fC3b(x_ndc - off, y_ndc - off, col.r, col.g, col.b);
    sgl.v2fC3b(x_ndc - off, y_ndc + off, col.r, col.g, col.b);
    sgl.v2fC3b(x_ndc + off, y_ndc + off, col.r, col.g, col.b);
    sgl.v2fC3b(x_ndc + off, y_ndc - off, col.r, col.g, col.b);
}


export fn init() void {
    // setup sokol-gfx
    sg.setup(.{ 
        .context = sgapp.context()
    });

    // setup sokol-gl
    sgl.setup(.{
        .sample_count = sapp.sampleCount()
    });

   font_normal = lf.LabFontLoad("serif-normal",
        "/Users/nporcino/dev/LabCart/third-party/LabFont/resources/DroidSerif-Regular.ttf",
        lf.LabFontType { .type = lf.LabFontTypeTTF } );

   font_japanese = lf.LabFontLoad("sans-japanese",
        "/Users/nporcino/dev/LabCart/third-party/LabFont/resources/DroidSansJapanese.ttf",
        lf.LabFontType { .type = lf.LabFontTypeTTF } );

    var med_red: lf.struct_LabFontColor = lf.struct_LabFontColor{ 
        .rgba = [4]u8{32, 0, 0, 255}};

    var align_left = lf.LabFontAlign{.alignment = lf.LabFontAlignLeft};
    j_st = lf.LabFontStateBake_bind(font_japanese, 
        24, 
        &med_red, &align_left, 0, 0);

    n_st = lf.LabFontStateBake_bind(font_normal, 
        24,
        &med_red, &align_left, 0, 0); 

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

    terminal.init_text_system();

    // clear screen pass action
    var col = sg.Color{ .r = 0.3, .g = 0.4, .b = 0.5 };
    state.pass_action.colors[0] = .{ .action = .CLEAR, .value = col};

    mu_context = ui.microui_init(&ui_pip);
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

var last_x : u32 = 0;
var last_y : u32 = 0;

export fn frame() void
{
    const ww = sapp.widthf();
    const wh = sapp.heightf();
    sgl.defaults();
    sgl.matrixModeProjection();
    sgl.ortho(0, ww, wh, 0, -1, 1);
    sgl.scissorRect(0, 0, @floatToInt(i32, ww), @floatToInt(i32, wh), true);
    sgl.viewportf(0,0,ww,wh, true);

    drawTriangle();

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
            Terminal.append_line(state.terminal.?, &text_buff, state.line_color);
            Terminal.constrain_visible(state.terminal.?);
            state.line_color = state.line_color + 1;
            if (state.line_color == 15) {
                state.line_color = 128;
            }
            else if (state.line_color == 144) {
                state.line_color = 0;
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
              0.02, palette.Palette.highlight);
    sgl.end();

    state.frame_count+=1;

    // set virtual canvas size to half display size so that
    // glyphs are 16x16 display pixels
    sdtx.canvas(sapp.widthf()*0.5, sapp.heightf()*0.5);
    sdtx.origin(0.0, 2.0);
    sdtx.home();


    {
        var th = state.frame_count * 0.0075;
        th = @mod(th, 1.0) * 2.0 * 3.1415926539;
        var cos_th = @cos(th);
        var sin_th = @sin(th);

        Terminal.write_line(state.terminal.?, "     ", 7,
                            last_x, last_y);

        var x = 9.0 * cos_th + 10.0;
        var y = 9.0 * sin_th + 10.0;
        last_x = @floatToInt(u32, x);
        last_y = @floatToInt(u32, y);

        Terminal.write_line(state.terminal.?, "World", 7,
                            last_x, last_y);
    }

    Terminal.render(state.terminal.?);
    sgl.matrixModeProjection();
    sgl.ortho(0, ww, wh, 0, -1, 1);
    sgl.scissorRect(0, 0, @floatToInt(i32, ww), @floatToInt(i32, wh), true);
 
    sgl.enableTexture();
    
    //_ = lf.LabFontDraw("いろはにほへと ちりぬるを わかよたれそ つねならむ うゐのおくやま けふこえて あさきゆめみし ゑひもせす　京（ん）", 30, 400, j_st);

    _ = lf.LabFontDraw("Testing", 30, 460, n_st);
     sgl.matrixModeProjection();
    sgl.ortho(0, ww, wh, 0, -1, 1);
    sgl.scissorRect(0, 0, @floatToInt(i32, ww), @floatToInt(i32, wh), true);
    _ = lf.LabFontDraw("Testing 123", 30, 440, n_st);

    _ = lf.LabFontDraw("Testing", 30, 460, j_st);

    lf.LabFontCommitTexture();



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
    _ = args.next(ALLOCATOR.?);

    test_lua.test_lua();
    state.terminal = &Terminal.init(ALLOCATOR.?, 40, 24, 24);
    Terminal.append_line(state.terminal.?, "Hello world 1", 0);
    Terminal.append_line(state.terminal.?, "Hello world 2", 1);
    Terminal.append_line(state.terminal.?, "Hello world 3", 2);
    Terminal.append_line(state.terminal.?, "Hello world 4", 3);
    Terminal.append_line(state.terminal.?, "Hello world 5", 4);
    Terminal.append_line(state.terminal.?, "Hello world 6", 5);
    Terminal.append_line(state.terminal.?, "Hello world 7", 6);
    Terminal.append_line(state.terminal.?, "Hello world 8", 7);
    Terminal.append_line(state.terminal.?, "Hello world 9", 8);
    //Terminal.dump(state.terminal.?);
    state.line_color = 9;

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


