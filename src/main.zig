const std = @import("std");

const Vec3 = struct { x: f32, y: f32, z: f32};
const Color = struct { r: u8, g: u8, b: u8, a: u8 };

const Branch = struct {
  parent: ?*Branch,
  length: f32,
  max_length: f32,
  diameter: f32,
  direction: Vec3,
  growth_rate: f32,
  children: std.ArrayList(*Branch),
  leaves: std.ArrayList(Leaf),
};

const Leaf = struct {
  size: f32,
  position: f32,
  color: Color,
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var trunk: Branch = Branch{ 
  .parent = null,
  .length = 0.1, 
  .max_length = 150,
  .diameter = 0.1,
  .direction = Vec3{ .x = 0, .y = 0, .z = 1 },
  .growth_rate = 1, 
  .children = std.ArrayList(*Branch).init(allocator),
  .leaves = std.ArrayList(Leaf).init(allocator)
};

const MAX_WIDTH = 4096;
const MAX_HEIGHT = 4096;

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

export fn set_window_dimensions(w: u8, h: u8) void {
  width = w;
  height = h;
}

export fn get_output_buffer_pointer() *[OUTPUT_BUFFER_SIZE]u8 {
  return &OUTPUT_BUFFER;
}

var last_pixels_set = std.ArrayList(u32).init(allocator);

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
    if (e2 >= dy) { err += dy; x += sx; }
    if (e2 <= dx) { err += dx; y += sy; }
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

fn render_branch(branch: *Branch, baseX: f32, baseZ: f32) void {
  const endX = baseX + branch.length * branch.direction.x;
  const endZ = baseZ + branch.length * branch.direction.z;

  draw_line(@intFromFloat(baseX), @intFromFloat(baseZ), @intFromFloat(endX), @intFromFloat(endZ));

  for (branch.children.items) |child| {
    render_branch(child, endX, endZ); 
  }

  for (branch.leaves.items) |leaf| {
    draw_circle(
      @intFromFloat(baseX + branch.length * branch.direction.x * leaf.position), 
      @intFromFloat(baseZ + branch.length * branch.direction.z * leaf.position), 
      leaf.size,
      leaf.color
    );
  }
}

fn render_tree() void {
  for (last_pixels_set.items) |pixel_offset| {
    OUTPUT_BUFFER[pixel_offset] = 0;
    OUTPUT_BUFFER[pixel_offset + 1] = 0;
    OUTPUT_BUFFER[pixel_offset + 2] = 0;
    OUTPUT_BUFFER[pixel_offset + 3] = 0;
  }

  last_pixels_set.clearRetainingCapacity();

  const baseX: f32 = @as(f32, @floatFromInt(width)) / 2.0;
  const baseY: f32 = 0.0;

  render_branch(&trunk, baseX, baseY);
}

fn destroy_branch(branch: *Branch) void {
  while (branch.children.items.len > 0) {
      const child = branch.children.pop(); 
      destroy_branch(child);
  }

  while (branch.leaves.items.len > 0) {
      _ = branch.leaves.pop();
  }

  allocator.destroy(branch);
}

fn grow_branch(branch: *Branch, depth: u8, grew_new_branch: *bool) void {
  if (std.rand.Random.float(random, f32) < 0.001 and branch.parent != null and branch.children.items.len > 0) {
    const child = branch.children.pop(); 
    destroy_branch(child);
  }

  if (branch.length < branch.max_length) {
    branch.length += branch.growth_rate;
  }

  const day_of_year = (hour / 24) % 365;
  if (day_of_year > 60 and day_of_year < 260) {
    if (branch.leaves.items.len <= 1 and std.rand.Random.float(random, f32) < 0.005 and branch.parent != null) {
      const new_leaf = Leaf {
        .position = std.rand.Random.float(random, f32),
        .color = Color{ .r = 255, .g = 183 + @as(u8, @intFromFloat(std.rand.Random.float(random, f32) * 20)), .b = 197 + @as(u8, @intFromFloat(std.rand.Random.float(random, f32) * 20)), .a = 255 },
        .size = std.rand.Random.float(random, f32) * 10,
      };
      
      branch.leaves.append(new_leaf) catch return;
    }
  } else {
    if (branch.leaves.items.len > 0 and std.rand.Random.float(random, f32) < 0.05) {
      _ = branch.leaves.pop();
    }
  }

  if (!grew_new_branch.* and depth <= 3 and branch.children.items.len <= 3 and std.rand.Random.float(random, f32) < 0.05) {
    grew_new_branch.* = true;
    const new_branch_ptr = allocator.create(Branch) catch return;

    const r0 = std.rand.Random.float(random, f32);
    const r1 = std.rand.Random.float(random, f32);

    new_branch_ptr.* = Branch{
      .parent = &trunk,
      .length = 0.1, 
      .max_length = std.rand.Random.float(random, f32) * 200,
      .diameter = 0.1,
      .direction = Vec3{ .x = r0 * 2.0 - 1.0, .y = 0, .z = r1 * 1.5 - 0.5 },
      .growth_rate = std.rand.Random.float(random, f32), 
      .children = std.ArrayList(*Branch).init(allocator),
      .leaves = std.ArrayList(Leaf).init(allocator),
    };

    branch.children.append(new_branch_ptr) catch return;
  }

  for (branch.children.items) |child| {
    grow_branch(child, depth + 1, grew_new_branch); 
  }
}

export fn grow_tree() void {
  var grew_new_branch = false;
  // const random_number = std.fmt.allocPrint(allocator, "random number: {any}", .{f}) catch "failed to create string";
  // debug_print(@ptrCast(random_number), @intCast(random_number.len));

  grow_branch(&trunk, 0, &grew_new_branch);
  hour += 1;

  render_tree();
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
