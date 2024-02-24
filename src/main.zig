const std = @import("std");

const Vec3 = struct { x: f32, y: f32, z: f32 };
const Color = struct { r: u8, g: u8, b: u8, a: u8 };

const NO_CELL: u8 = 0;
const BRANCH_CELL: u8 = 1;
const LEAF_CELL: u8 = 2;

// const Branch = struct {
//     parent: ?*Branch,
//     length: f32,
//     max_length: f32,
//     diameter: f32,
//     direction: Vec3,
//     growth_rate: f32,
//     children: std.ArrayList(*Branch),
//     leaves: std.ArrayList(Leaf),
// };

// const Leaf = struct {
//     size: f32,
//     position: f32,
//     color: Color,
// };

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// var trunk: Branch = Branch{ .parent = null, .length = 0.1, .max_length = 150, .diameter = 0.1, .direction = Vec3{ .x = 0, .y = 0, .z = 1 }, .growth_rate = 1, .children = std.ArrayList(*Branch).init(allocator), .leaves = std.ArrayList(Leaf).init(allocator) };

const MAX_WIDTH = 4096;
const MAX_HEIGHT = 4096;

var SCENE_BUFFER = [_:0]u8{0} ** (MAX_WIDTH * MAX_HEIGHT);

const OUTPUT_BUFFER_SIZE: u32 = MAX_WIDTH * MAX_HEIGHT * 4;
var OUTPUT_BUFFER = [_:0]u8{0} ** OUTPUT_BUFFER_SIZE;

var width: u32 = 0;
var height: u32 = 0;

var prng = std.rand.DefaultPrng.init(0);
var random = prng.random();
var rand_seed: u64 = 0;

var hour: u32 = 0;

extern fn debug_print(message: [*]const u8, length: u8) void;

export fn set_rand_seed(s: u64) void {
    prng = std.rand.DefaultPrng.init(s);
    random = prng.random();
}

export fn set_window_dimensions(w: u32, h: u32) void {
    width = w;
    height = h;

    for (0..height) |i| {
        for (0..width) |j| {
            SCENE_BUFFER[i * width + j] = NO_CELL;
        }
    }
}

export fn get_output_buffer_pointer() *[OUTPUT_BUFFER_SIZE]u8 {
    return &OUTPUT_BUFFER;
}

var last_pixels_set = std.ArrayList(u32).init(allocator);

const Cell = struct { type: u8, x: u32, y: u32, direction: f32, apical_distance: f32 };
var cells = std.ArrayList(Cell).init(allocator);

fn render_tree() void {
    // for (last_pixels_set.items) |pixel_offset| {
    //     OUTPUT_BUFFER[pixel_offset] = 0;
    //     OUTPUT_BUFFER[pixel_offset + 1] = 0;
    //     OUTPUT_BUFFER[pixel_offset + 2] = 0;
    //     OUTPUT_BUFFER[pixel_offset + 3] = 0;
    // }

    // last_pixels_set.clearRetainingCapacity();

    // for (cells.items) |c| {
    //     if (c.type != NO_CELL) {
    //     }
    // }
}

const PI = 3.14;

export fn init() void {}

export fn grow_tree() void {
    hour += 1;

    if (cells.items.len == 0) {
        const x = @divFloor(width, 2);
        const y = 0;
        cells.append(Cell{ .type = BRANCH_CELL, .x = x, .y = y, .direction = 1.14, .apical_distance = 0 }) catch return;
        SCENE_BUFFER[y * width + x] = BRANCH_CELL;
    }

    for (cells.items) |c| {
        if (c.type == BRANCH_CELL) {
            var x: u32 = undefined;
            var y: u32 = undefined;
            var apical_distance = c.apical_distance;
            var direction = c.direction;

            const random_growth = std.rand.Random.float(random, f32);

            if (random_growth < 0.001) {
                direction = std.rand.Random.float(random, f32) * (2 * PI);

                const step: f32 = 2;
                const dx: f32 = @cos(direction);
                const dy: f32 = @sin(direction);

                // _ = step;
                // _ = dx;
                // _ = dy;
                x = @intCast(@max(0, @as(i32, @intCast(c.x)) + @as(i32, @intFromFloat(step * dx))));
                y = @intCast(@max(0, @as(i32, @intCast(c.y)) + @as(i32, @intFromFloat(step * dy))));
                apical_distance = 0;
            } else if (random_growth < (0.4 * (1 / @max(1, 10 * c.apical_distance)))) { // grow branch outwards
                direction = c.direction;

                if (std.rand.Random.float(random, f32) < 0.5) {
                    x = @intCast(@max(0, @as(i32, @intCast(c.x)) + @as(i32, if (@cos(c.direction) > 0) 1 else -1)));
                    y = c.y;
                } else {
                    y = @intCast(@max(0, @as(i32, @intCast(c.y)) + @as(i32, if (@sin(c.direction) > 0) 1 else -1)));
                    x = c.x;
                }
                apical_distance = c.apical_distance + 1;
            } else { // grow forward
                direction = c.direction;
                const threshold = 0.5;

                var move_x: i32 = 0;
                var move_y: i32 = 0;

                if (@abs(@cos(c.direction)) > threshold) {
                    move_x = if (@cos(c.direction) > 0) 1 else -1;
                }

                if (@abs(@sin(c.direction)) > threshold) {
                    move_y = if (@sin(c.direction) > 0) 1 else -1;
                }

                x = @intCast(@max(0, @as(i32, @intCast(c.x)) + move_x));
                y = @intCast(@max(0, @as(i32, @intCast(c.y)) + move_y));

                apical_distance = c.apical_distance;
            }

            if (y < height and x < width and SCENE_BUFFER[y * width + x] == NO_CELL) {
                cells.append(Cell{ .type = BRANCH_CELL, .x = x, .y = y, .direction = direction, .apical_distance = apical_distance }) catch return;
                SCENE_BUFFER[y * width + x] = BRANCH_CELL;
                draw_pixel(x, y, Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
            }
        }
    }

    // clear cells that are surrounded and so can't possibly grow for performance
    for (0..cells.items.len) |c_i| {
        if (c_i < cells.items.len) {
            const x = cells.items[c_i].x;
            const y = cells.items[c_i].y;
            if ((x > 0 and SCENE_BUFFER[y * width + (x - 1)] != NO_CELL) and
                (x < width - 1 and SCENE_BUFFER[(y) * width + (x + 1)] != NO_CELL) and
                (y > 0 and SCENE_BUFFER[(y - 1) * width + x] != NO_CELL) and
                (y < height - 1 and SCENE_BUFFER[(y + 1) * width + x] != NO_CELL) and
                (y > 0 and x > 0 and SCENE_BUFFER[(y - 1) * width + (x - 1)] != NO_CELL) and
                (y > 0 and x < width - 1 and SCENE_BUFFER[(y - 1) * width + (x + 1)] != NO_CELL) and
                (y < height - 1 and x > 0 and SCENE_BUFFER[(y + 1) * width + (x - 1)] != NO_CELL) and
                (y < height - 1 and x < width - 1 and SCENE_BUFFER[(y + 1) * width + (x + 1)] != NO_CELL))
            {
                defer _ = cells.swapRemove(c_i);
            }
        }
    }

    render_tree();
}

fn draw_pixel(x: u32, y: u32, c: Color) void {
    if (y < height and x < width) {
        const pixel: u32 = (height - y - 1) * width + x;
        const pixel_offset: u32 = pixel * 4;

        last_pixels_set.append(pixel_offset) catch return;

        OUTPUT_BUFFER[pixel_offset] = c.r;
        OUTPUT_BUFFER[pixel_offset + 1] = c.g;
        OUTPUT_BUFFER[pixel_offset + 2] = c.b;
        OUTPUT_BUFFER[pixel_offset + 3] = c.a;
    }
}

fn draw_line(x0: i32, y0: i32, x1: i32, y1: i32) void {
    var x = x0;
    var y = y0;
    const dx: i32 = @intCast(@abs(x1 - x0));
    const dy: i32 = -@as(i32, @intCast(@abs(y1 - y0)));
    const sx: i32 = if (x0 < x1) 1 else -1;
    const sy: i32 = if (y0 < y1) 1 else -1;
    var err = dx + dy;

    while (true) {
        if (x >= 0 and y >= 0) {
            draw_pixel(@intCast(x), @intCast(y), Color{ .r = 255, .g = 255, .b = 255, .a = 255 });
        }
        if (x == x1 and y == y1) break;
        const e2 = 2 * err;
        if (e2 >= dy) {
            err += dy;
            x += sx;
        }
        if (e2 <= dx) {
            err += dx;
            y += sy;
        }
    }
}

fn draw_horizontal_line(x1: i32, x2: i32, y: i32, color: Color) void {
    var x = x1;
    while (x <= x2) : (x += 1) {
        if (x >= 0 and y >= 0) {
            draw_pixel(@intCast(x), @intCast(y), color);
        }
    }
}

fn draw_circle(xc: i32, yc: i32, r: f32, color: Color) void {
    var x: i32 = 0;
    var y: i32 = @intFromFloat(r);
    var d: f32 = 3 - 2 * r;

    draw_horizontal_line(xc - y, xc + y, yc, color);

    while (y >= x) {
        x += 1;

        if (d > 0) {
            y -= 1;
            d = d + 4 * @as(f32, @floatFromInt(x - y)) + 10;
        } else {
            d = d + 4 * @as(f32, @floatFromInt(x)) + 6;
        }

        draw_horizontal_line(xc - x, xc + x, yc + y, color);
        draw_horizontal_line(xc - x, xc + x, yc - y, color);
        draw_horizontal_line(xc - y, xc + y, yc + x, color);
        draw_horizontal_line(xc - y, xc + y, yc - x, color);
    }
}

pub const os = struct {
    pub const system = struct {
        pub const fd_t = u8;
        pub const STDERR_FILENO = 1;
        pub const E = std.os.linux.E;

        pub fn getErrno(T: u32) E {
            _ = T;
            return .SUCCESS;
        }

        pub fn write(f: fd_t, ptr: [*]const u8, len: u32) u32 {
            _ = ptr;
            _ = f;
            return len;
        }
    };
};
