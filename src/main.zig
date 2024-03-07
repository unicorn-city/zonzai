const std = @import("std");

const Color = struct { r: u8, g: u8, b: u8, a: u8 };

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

const MAX_WIDTH = 4096;
const MAX_HEIGHT = 4096;

const CELL_SIZE = 5;

const OUTPUT_BUFFER_SIZE: u32 = MAX_WIDTH * MAX_HEIGHT * 4;
var OUTPUT_BUFFER = [_:0]u8{0} ** OUTPUT_BUFFER_SIZE;

var SCENE_BUFFER = [_:0]u8{0} ** (MAX_WIDTH * MAX_HEIGHT);
var TEMP_SCENE_BUFFER = [_:0]u8{0} ** (MAX_WIDTH * MAX_HEIGHT);

var width: u32 = 0;
var height: u32 = 0;

var scene_width: u32 = 0;
var scene_height: u32 = 0;

var paused: bool = false;
var step: u32 = 0;

var dragging: bool = false;
var mouseX: u32 = 0;
var mouseY: u32 = 0;

var SELECTED_PATTERN_BUFFER = [_]u8{ 'o', '!' } ++ [_]u8{0} ** 998;

// NOTE: Usage -
// const msg = std.fmt.allocPrint(allocator, "", .{ }) catch return;
// defer allocator.free(msg);
// debug_print(msg.ptr, @intCast(msg.len));
extern fn debug_print(message: [*]const u8, length: u8) void;

export fn alloc(length: u8) [*]const u8 {
    const memory = allocator.alloc(u8, length) catch unreachable;
    return memory.ptr;
}

export fn set_window_dimensions(w: u32, h: u32) void {
    width = w;
    height = h;

    scene_width = width / CELL_SIZE;
    scene_height = height / CELL_SIZE;
}

export fn get_output_buffer_pointer() *[OUTPUT_BUFFER_SIZE]u8 {
    return &OUTPUT_BUFFER;
}

export fn pause() bool {
    paused = !paused;
    return paused;
}

export fn clear() void {
    @memset(&SCENE_BUFFER, 0);
}

export fn click() void {
    place_cells();
}

export fn set_dragging(isDragging: bool) void {
    dragging = isDragging;
}

export fn move_mouse(x: u32, y: u32) void {
    mouseX = x;
    mouseY = y;
}

export fn select_pattern(rle: [*]const u8) void {
    @memcpy(&SELECTED_PATTERN_BUFFER, rle);
}

export fn setup() void {
    var y: usize = scene_height / 2;
    const x: usize = scene_width / 2;
    SCENE_BUFFER[(y * scene_width + x)] = 1;

    y += 1;
    SCENE_BUFFER[(y * scene_width + x)] = 1;

    y += 1;
    SCENE_BUFFER[(y * scene_width + x)] = 1;
}

fn place_cells() void {
    var dx: usize = 0;
    var dy: usize = 0;
    var run_count: usize = 0;
    var cell_value: u8 = 0;
    for (SELECTED_PATTERN_BUFFER) |code| {
        switch (code) {
            '0'...'9' => {
                run_count *= 10;
                run_count += code - '0';
                continue;
            },
            'o' => {
                cell_value = 1;
            },
            'b' => {
                cell_value = 0;
            },
            '!' => {
                break;
            },
            '$' => {
                dy += 1;
                dx = 0;
                run_count = 0;
                continue;
            },
            else => unreachable,
        }

        for (0..@max(1, run_count)) |_| {
            SCENE_BUFFER[(mouseY / CELL_SIZE + dy) * scene_width + mouseX / CELL_SIZE + dx] = cell_value;
            dx += 1;
        }
        run_count = 0;
    }
}

export fn draw() void {
    @memset(&OUTPUT_BUFFER, 0);

    // Draw cursor
    {
        const sx = mouseX / CELL_SIZE;
        const sy = mouseY / CELL_SIZE;
        for (0..CELL_SIZE) |c_xi| {
            for (0..CELL_SIZE) |c_yi| {
                const x = sx * CELL_SIZE + c_xi;
                const y = sy * CELL_SIZE + c_yi;
                draw_pixel(x, y, .{ .r = 255, .g = 255, .b = 255, .a = 150 });
            }
        }
    }

    // Draw (live) cells
    for (0..scene_width * scene_height) |c_i| {
        if (SCENE_BUFFER[c_i] == 1) {
            const sx = c_i % scene_width;
            const sy = c_i / scene_width;
            for (0..CELL_SIZE) |c_xi| {
                for (0..CELL_SIZE) |c_yi| {
                    const x = sx * CELL_SIZE + c_xi;
                    const y = sy * CELL_SIZE + c_yi;
                    draw_pixel(x, y, .{ .r = 0, .g = 255, .b = 255, .a = 255 });
                }
            }
        }
    }

    if (!paused) {
        for (0..scene_width * scene_height) |c_i| {
            var live_neighbors: usize = 0;

            const i_c_i: isize = @intCast(c_i);
            const i_scene_width: isize = @intCast(scene_width);

            // zig fmt: off
            const neighbors = [8]isize{
                i_c_i + 1,
                i_c_i - 1,
                i_c_i + i_scene_width,
                i_c_i - i_scene_width,
                i_c_i + i_scene_width + 1,
                i_c_i + i_scene_width - 1,
                i_c_i - i_scene_width + 1,
                i_c_i - i_scene_width - 1
            };
            // zig fmt: on

            for (neighbors) |n| {
                if (SCENE_BUFFER[@intCast(@mod(n, @as(isize, @intCast(scene_height * scene_width))))] == 1) {
                    live_neighbors += 1;
                }
            }

            if (SCENE_BUFFER[c_i] == 1) {
                if (live_neighbors < 2) {
                    TEMP_SCENE_BUFFER[c_i] = 0;
                } else if (live_neighbors > 3) {
                    TEMP_SCENE_BUFFER[c_i] = 0;
                } else {
                    TEMP_SCENE_BUFFER[c_i] = 1;
                }
            } else if (SCENE_BUFFER[c_i] == 0) {
                if (live_neighbors == 3) {
                    TEMP_SCENE_BUFFER[c_i] = 1;
                } else {
                    TEMP_SCENE_BUFFER[c_i] = 0;
                }
            }
        }

        SCENE_BUFFER = TEMP_SCENE_BUFFER;
        step += 1;
    }

    if (dragging) {
        place_cells();
    }
}

fn draw_pixel(x: u32, y: u32, c: Color) void {
    if (y < height and x < width) {
        const pixel: u32 = (height - y - 1) * width + x;
        const pixel_offset: u32 = pixel * 4;

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
