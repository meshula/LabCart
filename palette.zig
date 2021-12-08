
pub const Color_f32 = struct {
    r: f32 = 0.0,
    g: f32 = 0.0,
    b: f32 = 0.0,
    a: f32 = 0.0,

    pub fn to_u8(self: @This()) Color_u8 {
        return .{
            .r = @floatToInt(u8, self.r*255.0),
            .g = @floatToInt(u8, self.g*255.0),
            .b = @floatToInt(u8, self.b*255.0),
            .a = @floatToInt(u8, self.a*255.0),
        };
    }
};

pub const Color_u8 = struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 1,

    pub fn to_f32(self: @This()) Color_f32 {
        return .{
            .r = @intToFloat(f32, self.r)/255.0,
            .g = @intToFloat(f32, self.g)/255.0,
            .b = @intToFloat(f32, self.b)/255.0,
            .a = @intToFloat(f32, self.a)/255.0,
        };
    }
};

pub fn pico8(i: u8) Color_u8 {
    return switch(i) {
        0 => return   .{ .r=0,   .g=0,   .b=0,   .a=255}, //       black
        1 => return   .{ .r=29,  .g=43,  .b=83,  .a=255}, //     dark-blue
        2 => return   .{ .r=126, .g=37,  .b=83,  .a=255}, //    dark-purple
        3 => return   .{ .r=0,   .g=135, .b=81,  .a=255}, //    dark-green
        4 => return   .{ .r=171, .g=82,  .b=54,  .a=255}, //       brown
        5 => return   .{ .r=95,  .g=87,  .b=79,  .a=255}, //     dark-grey
        6 => return   .{ .r=194, .g=195, .b=199, .a=255}, //     light-grey
        7 => return   .{ .r=255, .g=241, .b=232, .a=255}, //       white
        8 => return   .{ .r=255, .g=0,   .b=77,  .a=255}, //        red
        9 => return   .{ .r=255, .g=163, .b=0,   .a=255}, //       orange
        10 => return  .{ .r=255, .g=236, .b=39,  .a=255}, //       yellow
        11 => return  .{ .r=0,   .g=228, .b=54,  .a=255}, //       green
        12 => return  .{ .r=41,  .g=173, .b=255, .a=255}, //       blue
        13 => return  .{ .r=131, .g=118, .b=156, .a=255}, //     lavender
        14 => return  .{ .r=255, .g=119, .b=168, .a=255}, //       pink
        15 => return  .{ .r=255, .g=204, .b=170, .a=255}, //    light-peach
        128 => return .{ .r=41,  .g=24,  .b=20,  .a=255}, //   brownish-black
        129 => return .{ .r=17,  .g=29,  .b=53,  .a=255}, //    darker-blue
        130 => return .{ .r=66,  .g=33,  .b=54,  .a=255}, //    darker-purple
        131 => return .{ .r=18,  .g=83,  .b=89,  .a=255}, //     blue-green
        132 => return .{ .r=116, .g=47,  .b=41,  .a=255}, //     dark-brown
        133 => return .{ .r=73,  .g=51,  .b=59,  .a=255}, //    darker-grey
        134 => return .{ .r=162, .g=136, .b=121, .a=255}, //    medium-grey
        135 => return .{ .r=243, .g=239, .b=125, .a=255}, //    light-yellow
        136 => return .{ .r=190, .g=18,  .b=80,  .a=255}, //      dark-red
        137 => return .{ .r=255, .g=108, .b=36,  .a=255}, //     dark-orange
        138 => return .{ .r=168, .g=231, .b=46,  .a=255}, //      lime-green
        139 => return .{ .r=0,   .g=181, .b=67,  .a=255}, //     medium-green
        140 => return .{ .r=6,   .g=90,  .b=181, .a=255}, //      true-blue
        141 => return .{ .r=117, .g=70,  .b=101, .a=255}, //        mauve
        142 => return .{ .r=255, .g=110, .b=89,  .a=255}, //      dark-peach
        143 => return .{ .r=255, .g=157, .b=129, .a=255}, //        peach
        else => return .{ .r=0,  .g=0,   .b=0,   .a=255}, //        black
    };
}


pub const Palette = struct {
    pub const fg: Color_u8 = .{
        .r = 69,
        .g = 157,
        .b = 132,
        .a = 1,
    };
    pub const fg_f = fg.to_f32();

    pub const fg_alt: Color_u8 = .{
        .r = 11,
        .g = 6,
        .b = 12,
        .a = 1,
    };
    pub const fg_alt_f = fg_alt.to_f32();

    pub const bg: Color_u8 = .{
        .r = 25,
        .g = 50,
        .b = 78,
        .a = 1,
    };
    pub const bg_f = bg.to_f32();

    pub const highlight: Color_u8 = .{
        .r = 227,
        .g = 180,
        .b = 0,
        .a = 1,
    };
    pub const highlight_f = highlight.to_f32();
};


