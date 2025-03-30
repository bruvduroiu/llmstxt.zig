# 📕 llmstxt.zig

AI-first approach to documentation, based on [llms.txt](https://llmstxt.org). Continouously rebuilds your `llms.txt` file to keep in sync with your codebase.


⚠️ This is a work in progress, expect many things to be broken.

## Build from source

- needs `zig@0.14.0`

```
git clone https://github.com/bruvduroiu/llmstxt.zig
cd llmstxt.zig/
zig build
```

## Usage

```
./zig-out/bin/llmstxt_zig file.ext
```

## Examples

```python
from typing import Union

from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def read_root():
    return {"Hello": "World"}


@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    return {"item_id": item_id, "q": q}
```

Result:

```
File: test.py
Language: python

var app = FastAPI();
func read_root() -> void;
func read_item() -> void;
```


```zig
const std = @import("std");

const root = @import("root.zig");
const E = root.E;
const P3 = root.P3;
const Vec3 = root.Vec3;
const Sphere = root.Sphere;
const Ray = root.Ray;
const Interval = root.Interval;

pub const Hittable = union(enum) {
    const Self = @This();
    sphere: Sphere,

    pub fn initSphere(center: [3]E, radius: E) Self {
        return .{ .sphere = Sphere.init(center, radius) };
    }

    pub fn deinit(self: Self) void {
        switch (self) {
            inline else => |hittable| hittable.deinit(),
        }
    }

    pub const Collision = struct {
        const Inner = @This();
        pub const Face = enum { front, back };
        t: E,
        p: P3,
        normal: Vec3,
        face: Face,
    };

    pub fn collisionAt(self: Self, interval: Interval, ray: *const Ray) ?Collision {
        switch (self) {
            inline else => |hittable| return hittable.collisionAt(interval, ray),
        }
    }
};
```

Result:

```
File: /Users/bogdanbuduroiu/development/bruvduroiu/raytracing.zig/src/hittable.zig
Language: zig

var t;
var p;
var normal;
var face;
```
