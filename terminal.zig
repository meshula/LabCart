

const std = @import("std");
pub const ArrayList = std.ArrayList;
const sdtx  = @import("sokol").debugtext;
const palette = @import("palette.zig");
const print = @import("std").debug.print;


// font indices
const KC853 = 0;
const KC854 = 1;
const Z1013 = 2;
const CPC   = 3;
const C64   = 4;
const ORIC  = 5;

var init_sdtx : bool = true;

pub fn init_text_system() void {
    // setup sokol-debugtext with all builtin fonts
    var sdtx_desc: sdtx.Desc = .{};
    sdtx_desc.fonts[KC853] = sdtx.fontKc853();
    sdtx_desc.fonts[KC854] = sdtx.fontKc854();
    sdtx_desc.fonts[Z1013] = sdtx.fontZ1013();
    sdtx_desc.fonts[CPC]   = sdtx.fontCpc();
    sdtx_desc.fonts[C64]   = sdtx.fontC64();
    sdtx_desc.fonts[ORIC]  = sdtx.fontOric();
    sdtx.setup(sdtx_desc);
    init_sdtx = false;
}


pub const Terminal = struct {
    buffer : ArrayList(u8),     // text buffer
    cbuffer : ArrayList(u8),    // palette indices
    w : u8 = 0,
    visible_h : u8 = 0,
    next_write_y : u32 = 0,
    first_visible_y : u32 = 0,
    buffer_height : u32 = 0,
    buffer_len : u32 = 0,

    pub fn init(alloc: std.mem.Allocator, width: u8, height: u8, buff_height: u32) Terminal {
        var buff_len = width * (height + buff_height);
        var buff = ArrayList(u8).initCapacity(alloc, buff_len)
            catch unreachable;
        buff.appendNTimes(0, width * (height + buff_height)) catch unreachable;
        var cbuff = ArrayList(u8).initCapacity(alloc, buff_len)
            catch unreachable;
        cbuff.appendNTimes(0, width * (height + buff_height)) catch unreachable;

        return Terminal{
            .buffer = buff,
            .cbuffer = cbuff,
            .w = width,
            .visible_h = height,
            .buffer_height = buff_height,
            .buffer_len = buff_len,
        };
    }

    pub fn append_line(t: *Terminal, line: [] const u8, col: u8) void {
        // replace the line at cursor if line isn't empty
        if (line.len > 0) {
            var max_len = line.len;
            if (max_len > t.w) {
                max_len = t.w;
            }
            var addr = (t.next_write_y * t.w) % t.buffer_len;
            //print("append at y {d}, width {d}, bh {d}, addr {d}\n", .{t.next_write_y, t.w, t.buffer_height, addr});
            var i : u32 = 0;
            while (i < max_len) {
                t.buffer.items[addr + i] = line[i];
                t.cbuffer.items[addr + i] = col;
                i += 1;
            }
            while (i < max_len) {
                t.buffer.items[addr + i] = 0;
                t.cbuffer.items[addr + i] = 0;
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
        var x: u8 = 0;
        var y: u8 = 0;
        var addr: u32 = (t.first_visible_y * t.w) % t.buffer_len;
        while (y < t.visible_h) {
            while (x < t.w) {
                var c: u8 = t.buffer.items[addr + x];
                if (c == 0) {
                    break;
                }
                var col = palette.pico8(t.cbuffer.items[addr + x]);
                sdtx.color3b(col.r, col.g, col.b);
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

