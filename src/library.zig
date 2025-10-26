const std = @import("std");
const Curses = @import("Curses.zig");

pub const Entry = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    value: *u64,

    pub fn printTreeString(self: Entry, curses: *Curses) void {
        curses.print("{s}: {X}\n", .{ self.name, self.value.* }) catch @panic("Failed to print entry");
    }

    pub fn init(allocator: std.mem.Allocator, name: []const u8, value: u64) !Entry {
        const name_alloc = try allocator.dupe(u8, name);
        const value_alloc = try allocator.create(u64);
        value_alloc.* = value;
        return .{
            .allocator = allocator,
            .name = name_alloc,
            .value = value_alloc,
        };
    }

    pub fn deinit(self: *Entry) void {
        self.allocator.free(self.name);
        self.allocator.destroy(self.value);
    }
};

pub const Unit = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    children: std.ArrayList(Node),

    pub fn printTreeString(self: Unit, curses: *Curses, padding: usize, is_last: bool) void {
        curses.attr_on(Curses.c.COLOR_PAIR(1));
        curses.attr_on(Curses.c.A_BOLD);
        curses.print(" {s}\n", .{self.name}) catch @panic("Failed to print unit");
        curses.attr_off(Curses.c.A_BOLD);
        curses.attr_off(Curses.c.COLOR_PAIR(1));

        const padding_alloc = genPadding(self.allocator, padding, is_last) catch @panic("Failed to generate padding");
        defer self.allocator.free(padding_alloc);

        for (self.children.items, 0..) |child, i| {
            const is_last_child = i == self.children.items.len - 1;
            const branch = if (is_last_child) "└── " else "├── ";

            curses.print("{s}{s}", .{ padding_alloc, branch }) catch @panic("Failed to print indent");

            const padding_mod: usize = if (is_last_child) 4 else 3;
            const new_padding: usize = padding + padding_mod;
            child.printTreeString(curses, new_padding, is_last_child);
        }
    }

    pub fn deinit(self: *Unit) void {
        for (self.children.items) |*child| {
            child.deinit();
        }

        self.children.deinit();
        self.allocator.free(self.name);
    }

    pub fn init(allocator: std.mem.Allocator, name: []const u8) !Unit {
        const name_alloc = try allocator.dupe(u8, name);
        const children = std.ArrayList(Node).init(allocator);
        return .{
            .allocator = allocator,
            .name = name_alloc,
            .children = children,
        };
    }
};

pub const Node = union(enum) {
    Entry: Entry,
    Unit: Unit,

    pub fn printTreeString(self: Node, curses: *Curses, padding: usize, is_last: bool) void {
        switch (self) {
            .Unit => |unit| unit.printTreeString(curses, padding, is_last),
            .Entry => |entry| entry.printTreeString(curses),
        }
    }

    pub fn deinit(self: *Node) void {
        switch (self.*) {
            inline else => |*node| node.deinit(),
        }
    }
};

fn genPadding(allocator: std.mem.Allocator, depth: usize, is_last: bool) ![]const u8 {
    if (depth == 0) return "";

    var result = try std.ArrayList(u8).initCapacity(allocator, depth);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < depth) : (i += 1) {
        if (i % 3 == 0 and !is_last) {
            try result.appendSlice("│ ");
        } else {
            try result.append(' ');
        }
    }

    return result.toOwnedSlice();
}

pub fn printTree(curses: *Curses, tree: Node) void {
    tree.printTreeString(curses, 0, false);
}

fn findNodeByYRecursive(node: *Node, target_y: i32, current_y: *i32) ?*Node {
    if (current_y.* == target_y) {
        return node;
    }
    current_y.* += 1;

    if (node.* == .Unit) {
        for (node.Unit.children.items) |*child| {
            if (findNodeByYRecursive(child, target_y, current_y)) |found| {
                return found;
            }
        }
    }

    return null;
}

pub fn findNodeByY(tree: *Node, y: i32) ?*Node {
    var current_y: i32 = 0;
    return findNodeByYRecursive(tree, y, &current_y);
}

pub const ParentSearchResult = struct {
    parent: *Unit,
    index: usize,
};

fn findParentRecursive(target: *const Node, parent_candidate: *Unit) ?ParentSearchResult {
    for (parent_candidate.children.items, 0..) |*child, i| {
        if (child == target) {
            return ParentSearchResult{
                .parent = parent_candidate,
                .index = i,
            };
        }

        if (child.* == .Unit) {
            if (findParentRecursive(target, &child.Unit)) |found| {
                return found;
            }
        }
    }

    return null;
}

pub fn findParent(root: *Node, target: *const Node) ?ParentSearchResult {
    if (root == target) return null; // Root has no parent
    if (root.* != .Unit) return null; // Root must be a unit to have children
    return findParentRecursive(target, &root.Unit);
}
