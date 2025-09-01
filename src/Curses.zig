const std = @import("std");

pub const c = @cImport({
    @cInclude("ncurses.h");
    @cInclude("locale.h");
});

const Self = @This();

pub fn init() Self {
    _ = c.setlocale(c.LC_ALL, "");

    _ = c.initscr();
    _ = c.cbreak();
    _ = c.noecho();
    _ = c.keypad(c.stdscr, true);
    _ = c.use_default_colors();
    _ = c.start_color();

    _ = c.init_pair(1, c.COLOR_BLUE, -1);

    return Self{};
}

pub fn deinit(self: *Self) void {
    _ = self;

    _ = c.endwin();
}

pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) !void {
    _ = self;

    var buf: [4096]u8 = undefined;
    const formatted = try std.fmt.bufPrint(&buf, fmt, args);

    if (formatted.len < buf.len) {
        buf[formatted.len] = 0;
        _ = c.printw("%s", buf[0 .. formatted.len + 1].ptr);
    } else {
        _ = c.printw("%.*s", @as(c_int, @intCast(formatted.len)), formatted.ptr);
    }
}

pub fn get_char(self: *Self) u16 {
    _ = self;

    return @as(u16, @intCast(c.getch()));
}

pub fn attr_on(self: *Self, attr: c_int) void {
    _ = self;

    _ = c.attron(attr);
}

pub fn attr_off(self: *Self, attr: c_int) void {
    _ = self;

    _ = c.attroff(attr);
}

pub fn refresh(self: *Self) void {
    _ = self;

    _ = c.refresh();
}

pub fn clear(self: *Self) void {
    _ = self;

    _ = c.clear();
}

pub fn move(self: *Self, y: c_int, x: c_int) void {
    _ = self;

    _ = c.move(y, x);
}

pub fn get_y(self: *Self) c_int {
    _ = self;

    return c.getcury(c.stdscr);
}

pub fn get_x(self: *Self) c_int {
    _ = self;

    return c.getcurx(c.stdscr);
}

pub const Dialog = struct {
    allocator: std.mem.Allocator,
    value: []const u8,

    pub fn init(allocator: std.mem.Allocator, h: u32, w: u32, name: []const u8, comptime validate: fn (value: []const u8) bool) Dialog {
        const start_y = @divFloor(@as(u32, @intCast(c.LINES)) - h, 2);
        const start_x = @divFloor(@as(u32, @intCast(c.COLS)) - w, 2);

        const window = c.newwin(@as(c_int, @intCast(h)), @as(c_int, @intCast(w)), @as(c_int, @intCast(start_y)), @as(c_int, @intCast(start_x)));
        defer _ = c.delwin(window);

        if (window == null) {
            @panic("Failed to create window");
        }

        _ = c.box(window, 0, 0);
        _ = c.mvwprintw(window, 1, 2, name.ptr);
        _ = c.mvwprintw(window, @as(c_int, @intCast(h)) - 2, 2, "<Enter> when done");

        _ = c.wrefresh(window);

        _ = c.echo();
        _ = c.curs_set(1);

        var buf: [256]u8 = undefined;

        _ = c.mvwgetnstr(window, 2, 2, buf[0..], buf.len - 2);

        _ = c.noecho();

        var len: usize = 0;
        while (len < buf.len and buf[len] != 0) {
            len += 1;
        }

        if (!validate(buf[0..len])) {
            return Dialog.init(allocator, h, w, "Invalid value, please try again.", validate);
        }

        const mem = allocator.alloc(u8, len) catch @panic("Failed to allocate memory");
        std.mem.copyForwards(u8, mem, buf[0..len]);

        return .{
            .allocator = allocator,
            .value = mem,
        };
    }

    pub fn deinit(self: *Dialog) void {
        self.allocator.free(self.value);
    }
};
