const std = @import("std");
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const print = std.debug.print;
const expect = std.testing.expect;
const assert = std.debug.assert;
const min = std.math.min;
const max = std.math.max;

const Vec2i = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Vec2i {
        return Vec2i{ .x = x, .y = y };
    }

    pub fn compMin(self: Vec2i, other: Vec2i) Vec2i {
        return Vec2i.init(min(self.x, other.x), min(self.y, other.y));
    }

    pub fn compMax(self: Vec2i, other: Vec2i) Vec2i {
        return Vec2i.init(max(self.x, other.x), max(self.y, other.y));
    }

    pub fn fromVec2f(other: Vec2f) Vec2i {
        return Vec2i.init(@floatToInt(i32, other.x), @floatToInt(i32, other.y));
    }
};

const Vec2f = struct {
    x: f32,
    y: f32,

    pub fn init(x: f32, y: f32) Vec2f {
        return Vec2f{ .x = x, .y = y };
    }

    pub fn fromVec2i(other: Vec2i) Vec2f {
        return Vec2f.init(@intToFloat(f32, other.x), @intToFloat(f32, other.y));
    }

    pub fn map(a: Vec2f, s1: Vec2f, e1: Vec2f, s2: Vec2f, e2: Vec2f) Vec2f {
        return Vec2f.init(
            mapf(f32, a.x, s1.x, e1.x, s2.x, e2.x),
            mapf(f32, a.y, s1.y, e1.y, s2.y, e2.y)
        );
    }
};

const Vec3f = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn init(x: f32, y: f32, z: f32) Vec3f {
        return Vec3f{ .x = x, .y = y, .z = z };
    }

    pub fn mul(self: Vec3f, scalar: f32) Vec3f {
        return Vec3f.init(self.x * scalar, self.y * scalar, self.z * scalar);
    }

    pub fn add(self: Vec3f, other: Vec3f) Vec3f {
        return Vec3f.init(self.x + other.x, self.y + other.y, self.z + other.z);
    }

    pub fn pow(self: Vec3f, exponent: f32) Vec3f {
        return Vec3f.init(std.math.pow(f32, self.x, exponent), std.math.pow(f32, self.y, exponent), std.math.pow(f32, self.z, exponent));
    }
};

const Vertex = struct {
    position: Vec2f,
    texcoord: Vec2f,
    color: Vec3f,

    pub fn init(position: Vec2f, texcoord: Vec2f, color: Vec3f) Vertex {
        return Vertex{ .position = position, .texcoord = texcoord, .color = color };
    }
};

const Rect2Di = struct {
    min: Vec2i,
    max: Vec2i,
};

const Rect2Df = struct {
    min: Vec2f,
    max: Vec2f,
};

const Image = struct {
    allocator: *Allocator,
    buffer: []Vec3f,
    width: u32,
    height: u32,

    pub fn init(allocator: *Allocator, width: u32, height: u32) Allocator.Error!Image {
        assert(width > 0 and height > 0);
        var buffer = try allocator.alloc(Vec3f, width * height);
        for (buffer) |_, i| { buffer[i] = Vec3f.init(0, 0, 0); }
        return Image {
            .allocator = allocator,
            .buffer = buffer,
            .width = width,
            .height = height,
        };
    }

    pub fn deinit(self: Image) void {
        self.allocator.free(self.buffer);
    }

    pub fn index(self: Image, x: u32, y: u32) *Vec3f {
        assert(x < self.width and x >= 0 and y < self.height and y >= 0);
        return &self.buffer[x + y * self.width];
    }
};

pub fn main() !void {
    const vertices = [_]Vertex{
        Vertex.init(Vec2f.init(-1, -1), Vec2f.init(0, 0), Vec3f.init(1, 0, 0)),
        Vertex.init(Vec2f.init(1, -1), Vec2f.init(1, 0), Vec3f.init(0, 1, 0)),
        Vertex.init(Vec2f.init(-1, 1), Vec2f.init(0, 1), Vec3f.init(0, 0, 1)),
        Vertex.init(Vec2f.init(1, 1), Vec2f.init(1, 1), Vec3f.init(1, 1, 1)),

        Vertex.init(Vec2f.init(0.15, 0.35), Vec2f.init(0, 0), Vec3f.init(1, 0, 1)),
        Vertex.init(Vec2f.init(0.6, 0.6), Vec2f.init(0, 0), Vec3f.init(0, 1, 1)),
        Vertex.init(Vec2f.init(0.3, 0.6), Vec2f.init(0, 0), Vec3f.init(1, 1, 0)),
        
        Vertex.init(Vec2f.init(-0.3, -0.6), Vec2f.init(0, 0), Vec3f.init(0.5, 0, 0.5)),
        Vertex.init(Vec2f.init(-0.15, -0.35), Vec2f.init(0, 0), Vec3f.init(1, 0, 0)),
        Vertex.init(Vec2f.init(-0.6, -0.6), Vec2f.init(0, 0), Vec3f.init(1, 0, 1)),
    };
    const indices = [_]u16{0, 2, 3, 0, 3, 1, 6, 5, 4, 9, 8, 7};

    assert(indices.len % 3 == 0);
    const WIDTH: u32 = 1024;
    const HEIGHT: u32 = 1024;

    const viewport = Rect2Di {
        .min = Vec2i.init(0, 0),
        .max = Vec2i.init(WIDTH - 1, HEIGHT - 1),
    };

    const clip = Rect2Df {
        .min = Vec2f.init(-1, -1),
        .max = Vec2f.init(1, 1),
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var image = try Image.init(&gpa.allocator, WIDTH, HEIGHT);
    defer image.deinit();

    var i: u32 = 0;
    while (i < indices.len) : (i += 3) {
        rasterizeTriangle(&image, viewport, clip, vertices[0..], indices[i..i + 3]);
    }

    // instead of doing a million tiny writes to the file, we'll create a "staging" buffer and do it all at once
    var pixels: []u8 = try gpa.allocator.alloc(u8, 3 * WIDTH * HEIGHT);
    for (image.buffer) |colorf, index| {
        assert(colorf.x >= 0 and colorf.x <= 1 and colorf.y >= 0 and colorf.y <= 1 and colorf.z >= 0 and colorf.z <= 1);
        pixels[index * 3 + 0] = @floatToInt(u8, colorf.x * 255);
        pixels[index * 3 + 1] = @floatToInt(u8, colorf.y * 255);
        pixels[index * 3 + 2] = @floatToInt(u8, colorf.z * 255);
    }

    const file = try std.fs.cwd().createFile(
        "output.ppm",
        .{.read = false},
    );
    defer file.close();

    const ppmHeader = try std.fmt.allocPrint(
        &gpa.allocator,
        "P6 {d} {d} 255\n",
        .{WIDTH, HEIGHT}
    );
    try file.writeAll(ppmHeader);
    try file.writeAll(pixels);
}

fn rasterizeTriangle(image: *Image, viewport: Rect2Di, clip: Rect2Df, vertices: []const Vertex, triIndices: []const u16) void {
    const triVerts: [3]Vertex = .{vertices[triIndices[0]], vertices[triIndices[1]], vertices[triIndices[2]]};
    const tri: [3]Vec2i = .{ 
        Vec2i.fromVec2f(Vec2f.map(triVerts[0].position, clip.min, clip.max, Vec2f.fromVec2i(viewport.min), Vec2f.fromVec2i(viewport.max))),
        Vec2i.fromVec2f(Vec2f.map(triVerts[1].position, clip.min, clip.max, Vec2f.fromVec2i(viewport.min), Vec2f.fromVec2i(viewport.max))),
        Vec2i.fromVec2f(Vec2f.map(triVerts[2].position, clip.min, clip.max, Vec2f.fromVec2i(viewport.min), Vec2f.fromVec2i(viewport.max))),
    };

    // actually twice the area of the tri
    const area = @intToFloat(f32, edgeFunction2D(tri[0], tri[1], tri[2]));
    
    if (area > 0) {
        const bboxTemp = triBoundingBox2D(tri);
        const bbox = Rect2Di {
            .min = bboxTemp.min.compMax(viewport.min),
            .max = bboxTemp.max.compMin(viewport.max),
        };
        
        var y = bbox.min.y;
        while (y <= bbox.max.y) : (y += 1) {
            var x = bbox.min.x;
            while (x <= bbox.max.x) : (x += 1) {
                const bary = barycentric2D(tri, area, Vec2i.init(x, y));

                // point is inside tri
                if (bary.x >= 0 and bary.y >= 0 and bary.z >= 0)
                {
                    const color = triVerts[0].color.mul(bary.x)
                        .add(triVerts[1].color.mul(bary.y))
                        .add(triVerts[2].color.mul(bary.z))
                        .pow(1 / 2.2);

                    image.index(@intCast(u32, x), @intCast(u32, y)).* = color;
                }
            }
        }
    }
}

fn barycentric2D(tri: [3]Vec2i, area: f32, p: Vec2i) Vec3f {
    const x = @intToFloat(f32, edgeFunction2D(tri[1], tri[2], p)) / area;
    const y = @intToFloat(f32, edgeFunction2D(tri[2], tri[0], p)) / area;
    return Vec3f {
        .x = x,
        .y = y,
        .z = 1.0 - x - y,
    };
}

fn edgeFunction2D(a: Vec2i, b: Vec2i, p: Vec2i) i32 {
    return (p.x - a.x) * (b.y - a.y) - (p.y - a.y) * (b.x - a.x);
}

fn triBoundingBox2D(tri: [3]Vec2i) Rect2Di {
    return Rect2Di {
        .min = tri[0].compMin(tri[1].compMin(tri[2])),
        .max = tri[0].compMax(tri[1].compMax(tri[2])),
    };
}

fn mapf(comptime T: type, a: T, s1: T, e1: T, s2: T, e2: T) T {
    return (a - s1) / (e1 - s1) * (e2 - s2) + s2;
}

fn abs(comptime T: type, val: T) T {
    return if (val < 0) -val else val;
}