const std = @import("std");

pub const c = @cImport({
    @cInclude("ncurses.h");
    @cInclude("locale.h");
});

const Self = @This();

pub fn init() Self {
    _ = c.setlocale(c.LC_ALL, "");

    _ = c.initscr();
    _ = c.raw();
    _ = c.noecho();
    _ = c.keypad(c.stdscr, true);
    _ = c.use_default_colors();
    _ = c.start_color();

    _ = c.init_pair(1, c.COLOR_BLUE, -1);

    return Self{};
}

pub fn deinit(self: Self) void {
    _ = self;

    _ = c.endwin();
}

pub fn print(self: Self, comptime fmt: []const u8, args: anytype) !void {
    _ = self;

    var buf: [256]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buf, fmt, args);

    if (formatted.len < buf.len) {
        buf[formatted.len] = 0;
        _ = c.printw("%s", buf[0 .. formatted.len + 1].ptr);
    } else {
        _ = c.printw("%.*s", @as(c_int, @intCast(formatted.len)), formatted.ptr);
    }
}

pub fn get_char(self: Self) u16 {
    _ = self;

    return @as(u16, @intCast(c.getch()));
}

pub fn attr_on(self: Self, attr: c_int) void {
    _ = self;

    _ = c.attron(attr);
}

pub fn attr_off(self: Self, attr: c_int) void {
    _ = self;

    _ = c.attroff(attr);
}

pub fn refresh(self: Self) void {
    _ = self;

    _ = c.refresh();
}
