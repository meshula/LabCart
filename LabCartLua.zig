
const std = @import("std");
const cout = std.io.getStdOut().writer();
var raw = std.heap.GeneralPurposeAllocator(.{}){};
pub const ALLOCATOR = &raw.allocator;


const lua = @cImport({
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

export fn add(s: ?*lua.lua_State) c_int {
    const a = lua.luaL_checkinteger(s, 1);
    const b = lua.luaL_checkinteger(s, 2);

    const c = a + b;

    lua.lua_pushinteger(s, c);
    return 1;
}

pub fn xest_lua() void {
    inline for (std.meta.declarations(lua)) |field| {
        std.debug.print("{s}", .{ field.name }); 
    }
}


pub const Lua = struct {
    state: ?*lua.lua_State = null,
};

pub fn init_lua() Lua {
    var s = Lua{};
    s.state = lua.luaL_newstate();
    lua.lua_pushboolean(s.state, 1); // force ignoring env vars
    lua.lua_setfield(s.state, lua.LUA_REGISTRYINDEX, "LUA_NOENV"); // ditto
    lua.luaL_openlibs(s.state);
    // can't compile the following line, reported on #1481
    //_ = lua.lua_gc(s.state, lua.LUA_GCGEN, 0, 0); // gc into generational mode
    return s;
}


pub fn test_lua() void {
    var ls = init_lua();

    lua.lua_register(ls.state, "zig_add", add);

    // TODO translate-c: luaL_dostring
    _ = lua.luaL_loadstring(ls.state, "print(zig_add(3, 5))");

    // TODO translate-c: lua_pcall
    _ = lua.lua_pcallk(ls.state, 0, lua.LUA_MULTRET, 0, 0, null);
}


