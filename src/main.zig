//
// dash
// Zig version: 0.10.1
// Author: Dash
// Date: 2023-7-10
//

const rl = @import("raylib");
const rlm = @import("raylib-math");

const std = @import("std");
const print = std.debug.print;

const int2 = struct { x: u32, z: u32 };

const Terrain = struct {
    mapscale: rl.Vector3,
    hmImageSize: int2,
    mapoffset: rl.Vector3,

    fn coordToPixel(self: *Terrain, coord: rl.Vector2) usize {
        var xcoordsafe = @max(0, @min(1, coord.x / self.mapscale.x));
        var x = iLerp(f64, 0, @intToFloat(f64, self.hmImageSize.x), xcoordsafe);
        var zcoordsafe = @max(0, @min(1, coord.y / self.mapscale.z));
        var z = iLerp(f64, 0, @intToFloat(f64, self.hmImageSize.z), zcoordsafe);

        return @floatToInt(u32, z) * self.hmImageSize.x + @floatToInt(u32, x);
    }

    pub fn getGroundPoint(self: *Terrain, pixels: [*]rl.Color, coord: rl.Vector2) rl.Vector3 {
        //print("coord:{d}:{d}\n", .{ coord.x, coord.y });
        //print("pixelcoord:{d}\n", .{self.coordToPixel(coord)});
        var ht = rl.colorNormalize(pixels[self.coordToPixel(coord)]).x;
        ht = ht * self.mapscale.y;
        //print("height:{d}\n", .{ht});
        var groundpoint = rl.Vector3{ .x = coord.x, .y = ht, .z = coord.y };
        //groundpoint is the coodinate translated to pixel space, looked up for height,
        //then the coordiante xz is used with the height.
        //the input of xz should be in coordinate space to make my live easier in the future.
        return groundpoint;
    }

    pub fn getPreciseGroundPoint(self: *Terrain, pixels: [*]rl.Color, coord: rl.Vector2) rl.Vector3 {
        var xcoordsafe = @max(0, @min(1, coord.x / self.mapscale.x));
        var x = iLerp(f32, 0, @intToFloat(f32, self.hmImageSize.x), xcoordsafe);
        var zcoordsafe = @max(0, @min(1, coord.y / self.mapscale.z));
        var z = iLerp(f32, 0, @intToFloat(f32, self.hmImageSize.z), zcoordsafe);

        //x high, x low
        var xhigh = @ceil(x);
        var xlow = @floor(x);
        var xhInt = @floatToInt(u32, xhigh);
        var xlInt = @floatToInt(u32, xlow);
        //z high, z low
        var zhigh = @ceil(z);
        var zlow = @floor(z);
        var zhInt = @floatToInt(u32, zhigh);
        var zlInt = @floatToInt(u32, zlow);
        //print("\n(x)h:{d},l:{d}\n", .{ xhigh, xlow });
        //print("(z)h:{d},l:{d}\n", .{ zhigh, zlow });
        // I think I need to take two lerp points,
        // then from those two heights, lerp a third time
        var ahigh = rl.colorNormalize(pixels[zhInt * self.hmImageSize.x + xhInt]).x;
        var alow = rl.colorNormalize(pixels[zhInt * self.hmImageSize.x + xlInt]).x;
        var a = iLerp(f32, alow, ahigh, x - xlow);
        //print("a:{d}", .{a});
        var bhigh = rl.colorNormalize(pixels[zlInt * self.hmImageSize.x + xhInt]).x;
        var blow = rl.colorNormalize(pixels[zlInt * self.hmImageSize.x + xlInt]).x;
        var b = iLerp(f32, blow, bhigh, x - xlow);
        //print("b:{d}", .{b});
        var c = iLerp(f32, b, a, z - zlow);

        //_ = rl.raymath.Clamp();

        a *= self.mapscale.y;
        b *= self.mapscale.y;
        c *= self.mapscale.y;
        return rl.Vector3{ .x = coord.x, .y = c, .z = coord.y };
    }
};

const Agent = struct {
    loc: rl.Vector3 = rl.Vector3{ .x = 1, .y = 0, .z = 1 },
    health: u8 = 0,
    vel: rl.Vector3 = rl.Vector3{ .x = 0, .y = 0, .z = 0 },

    fn randomMove(self: *Agent) void {
        if (rl.getRandomValue(0, 100) < 10) {
            self.vel.x = @intToFloat(f32, rl.getRandomValue(-1, 1)) * 0.01;
            self.vel.z = @intToFloat(f32, rl.getRandomValue(-1, 1)) * 0.01;
        }
        self.loc.x += self.vel.x;
        self.loc.y += self.vel.y;
        self.loc.z += self.vel.z;
    }
    fn chaseMove(self: *Agent, target: rl.Vector3) void {
        var xdiff = target.x - self.loc.x;
        var zdiff = target.z - self.loc.z;

        //lazy mahattan normalizeation
        if (xdiff + zdiff == 0) {
            return;
        }
        var xvel = xdiff * (0.002 / (@fabs(xdiff) + @fabs(zdiff)));
        var zvel = zdiff * (0.002 / (@fabs(xdiff) + @fabs(zdiff)));

        print("xvel:{d}\n", .{xvel});

        self.vel.x = xvel;
        self.vel.z = zvel;

        self.loc.x += self.vel.x;
        self.loc.y += self.vel.y;
        self.loc.z += self.vel.z;
    }

    fn floor(self: *Agent, ground: *Terrain, pixels: [*]rl.Color) void {
        var x = self.loc.x;
        var z = self.loc.z;

        var y = ground.getPreciseGroundPoint(pixels, rl.Vector2{ .x = x, .y = z }).y;
        if (y < self.loc.y) {
            self.vel.y -= 0.01;
        } else {
            self.vel.y = 0;
            self.loc.y = y;
        }
    }

    fn draw(self: *Agent) void {
        var top = self.loc;
        top.y += 0.06;
        rl.drawCapsule(self.loc, top, 0.02, 8, 3, rl.Color.orange);
        top.y += 0.025;
        rl.drawCapsule(self.loc, top, 0.01, 8, 3, rl.Color.orange);
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1920;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    //rl.SetConfigFlags(.FLAG_WINDOW_RESIZABLE);
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    //const img = rl.LoadImage("C:/Misc/Projects/ColoradoGeoMap/Evergreen2.png");
    //const img = rl.LoadImage("~/Omni/Projects/ColoradoGeoMap/Evergreen2.png");
    //const img = rl.LoadImage("textures/tex.png");
    //const img = rl.LoadImage("textures/1294.png");

    const img = rl.loadImage("textures/Coop.png");
    //const img = rl.LoadImage("textures/EvergreenH.png");
    //const img = rl.GenImageGradientH(256, 256, rl.Color.WHITE, rl.Color.BLACK);

    //print("w:{d}, h:{d}", .{ img.width, img.height });

    const pixels = @ptrCast([*]rl.Color, @alignCast(@alignOf(rl.Color), img.data.?));

    // Begin copy of heightmap code
    var camera: rl.Camera = rl.Camera3D{
        .position = rl.Vector3{ .x = 1.0, .y = 5.0, .z = 1.0 },
        .target = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = rl.CameraProjection.camera_perspective,
        //.projection = 0,
    };
    var viewMatrix: rl.Matrix = rl.getCameraMatrix(camera);

    //const demoimage = rl.LoadImage("C:/Misc/Projects/ColoradoGeoMap/EvergreenCompositeSmooshed.png");
    //const demoimage = rl.LoadImage("resources/textures/tex.png");
    //const demoimage = rl.LoadImage("resources/textures/1294.png");
    const demoimage = rl.loadImage("textures/CoopColor.png");
    //const demoimage = rl.LoadImage("textures/EvergreenC.png");
    //const demoimage = rl.GenImageGradientH(256, 256, rl.Color.WHITE, rl.Color.BLACK);
    const demotexture = rl.loadTextureFromImage(demoimage);
    //const demotexture = rl.LoadTextureFromImage(img);

    // Global map values..
    var mapscale: rl.Vector3 = rl.Vector3{ .x = 200, .y = 5, .z = 200 };
    //the dimentions of the heightmap | int
    //var heightmapSize: rl.Vector2 = rl.Vector2{ .x = img.width, .y = img.height };
    var heightmapSize: int2 = int2{
        .x = @truncate(u16, @bitCast(u32, img.width)),
        .z = @truncate(u16, @bitCast(u32, img.height)) - 1, // -1 to prevent segfalt
    };
    //print("imgsize:{d},{d}", .{ heightmapSize.x, heightmapSize.z });

    //const mesh = rl.GenMeshHeightmap(img, rl.Vector3{ .x = 16, .y = 1, .z = 20 });
    var mesh = rl.genMeshHeightmap(img, mapscale);

    //rl.UploadMesh(@ptrCast([*]rl.Mesh, @alignCast(@alignOf(rl.Mesh), mesh)), true);

    mesh.vertices[1] = 100;
    //print("mesh x:{d}", .{mesh.vertices[1]});
    rl.uploadMesh(&mesh, true);
    const model = rl.loadModelFromMesh(mesh);
    //model.materials[0].maps[rl.MaterialMap.MATERIAL_MAP_ALBEDO].texture = demotexture;
    model.materials[0].maps[0].texture = demotexture;
    //const mapPosition = rl.Vector3{ .x = -8.0, .y = 0, .z = -8.0 };
    //const mapPosition = rl.Vector3{ .x = -10.0, .y = 0, .z = -10.0 };
    const mapPosition = rl.Vector3{ .x = 0.0, .y = 0, .z = 0.0 };

    var terry = Terrain{ .mapscale = mapscale, .hmImageSize = heightmapSize, .mapoffset = mapPosition };

    rl.unloadImage(demoimage);

    rl.disableCursor();
    //rl.SetCameraMode(camera, rl.CameraMode.CAMERA_ORBITAL);
    rl.setCameraMode(camera, rl.CameraMode.camera_first_person);
    //rl.SetCameraMode(camera, rl.CameraMode.CAMERA_FREE);
    //rl.SetCameraMode(camera, rl.CameraMode.CAMERA_CUSTOM);

    //const cam = @ptrCast([*]rl.Camera, @alignCast(@alignOf(rl.Camera), &camera));
    rl.updateCamera(&camera);

    var samplecoords = rl.Vector2{ .x = 0, .y = 0 };
    var groundray: rl.Ray = rl.Ray{
        //.position = groundpoint,
        .position = terry.getGroundPoint(pixels, samplecoords),
        .direction = rl.Vector3{ .x = 0, .y = 1, .z = 0 },
    };

    //var groundProbe: rl.Ray = rl.Ray{
    //    .position = rl.Vector3{ .x = 0, .y = 10, .z = 0 },
    //    .direction = rl.Vector3{ .x = 0, .y = -1, .z = 0 },
    //};
    //var uhhTransform: rl.Matrix = rl.GetCameraMatrix(camera);
    var camcoords = rl.Vector2{ .x = 0, .y = 0 };
    var camy: f32 = 0;
    var eyeheight: f32 = 0.1;
    var gndpnt: f32 = 0.0;
    var fallspd: f32 = 0.0;

    //var campos = rl.Vector3{ .x = 0, .y = 0, .z = 0 };
    //var camrot = rl.Vector3{ .x = 0, .y = 0, .z = 0 };
    //

    var agentorange = Agent{};

    //var gpa = std.heap.GeneralPurposeAllocator(.{})();
    //const allocator = gpa.allocator();
    //defer _ = gpa.deinit();

    //const bytes = try allocator.alloc(u8, 100);
    //defer allocator.free(bytes);

    //const horde = try allocator.alloc(Agent, 100);
    //
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bond = try allocator.create(Agent);
    const horde: []Agent = try allocator.alloc(Agent, 100);
    horde[0].loc.x = 0.5;

    //print("rl.PI:{d}", .{rlm.vector3Length(camera.position)});

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        if (rl.isKeyDown(rl.KeyboardKey.key_right)) samplecoords.x += 0.02;
        if (rl.isKeyDown(rl.KeyboardKey.key_left)) samplecoords.x -= 0.02;
        if (rl.isKeyDown(rl.KeyboardKey.key_up)) samplecoords.y -= 0.02;
        if (rl.isKeyDown(rl.KeyboardKey.key_down)) samplecoords.y += 0.02;

        if (rl.isKeyDown(rl.KeyboardKey.key_right)) camera.target.x += 0.02;
        if (rl.isKeyDown(rl.KeyboardKey.key_left)) camera.target.x -= 0.02;
        if (rl.isKeyDown(rl.KeyboardKey.key_up)) camera.target.z -= 0.02;
        if (rl.isKeyDown(rl.KeyboardKey.key_down)) camera.target.z += 0.02;
        camera.target.y = groundray.position.y;
        //
        //if (rl.isKeyDown(rl.KeyboardKey.KEY_W)) camcoords.x += 0.05;
        //if (rl.isKeyDown(rl.KeyboardKey.KEY_S)) camcoords.x -= 0.05;
        //if (rl.isKeyDown(rl.KeyboardKey.KEY_A)) camcoords.y -= 0.05;
        //if (rl.isKeyDown(rl.KeyboardKey.KEY_D)) camcoords.y += 0.05;
        if (rl.isKeyDown(rl.KeyboardKey.key_space)) fallspd = 0.01;
        //
        rl.updateCamera(&camera);
        //var groundHit: rl.RayCollision = rl.GetRayCollisionMesh(groundProbe, mesh, uhhTransform);
        //rl.DrawRay(groundProbe, rl.BLUE);
        camcoords.x = camera.position.x;
        camcoords.y = camera.position.z;

        //camera.position.x = camcoords.x;
        //camera.position.z = camcoords.y;
        gndpnt = terry.getPreciseGroundPoint(pixels, camcoords).y + eyeheight;
        //print("Gndpnt:{d}", .{gndpnt});
        //print("Cam.y:{d}", .{camera.position.y});
        //var camy = camera.position.y;
        //print("Camy:{d}", .{camy});
        if (gndpnt < camy) {
            // apply gravity
            //print("yo", .{});
            fallspd -= 0.001;
            camy += fallspd;
        } else if (gndpnt > camy) {
            //print("hello\n", .{});
            camy = gndpnt;
            fallspd = 0;
        }
        if (fallspd > 0) {
            camy += fallspd;
        }
        camera.position.y = camy;
        //camera.angle.x = rl.GetMouseDelta().x * 0.05;
        //camera.angle.y = rl.GetMouseDelta().y * 0.05;
        _ = viewMatrix;
        //rl.CameraYaw(camera, 0.01, false);
        //camera.angle.x = 0;
        //camera.rotation.z = 0;
        //campos.x = camera.position.x;
        //campos.y = camera.position.y;
        //campos.z = camera.position.z;

        //camrot.x += rl.GetMouseDelta().x * 0.05;
        //camrot.y += rl.GetMouseDelta().y * 0.05;
        //camrot.z = 0;

        //rl.UpdateCameraPro(camera, campos, camrot, 0);

        //print("cam.y:{d}\n", .{camera.position.y});
        //print("gndpt:{d}\n", .{gndpnt});

        //zloc +%= rl.GetRandomValue(-1, 1);
        groundray.position = terry.getPreciseGroundPoint(pixels, samplecoords);

        //agentorange.randomMove();
        agentorange.chaseMove(camera.position);
        agentorange.floor(&terry, pixels);

        horde[0].chaseMove(camera.position);
        horde[0].floor(&terry, pixels);
        bond.chaseMove(camera.position);
        bond.floor(&terry, pixels);

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();

        rl.clearBackground(rl.Color.white);

        rl.beginMode3D(camera);

        rl.drawModel(model, mapPosition, 1.0, rl.Color.white);
        rl.drawGrid(20, 1.0);
        //rl.drawCube(rl.vector3{ .x = 1, .y = 0.5, .z = 0 }, 1, 1, 1, rl.BLUE);
        rl.drawRay(groundray, rl.Color.red);
        groundray.direction.x = -1;
        rl.drawRay(groundray, rl.Color.red);
        groundray.direction.x = 1;
        rl.drawRay(groundray, rl.Color.red);
        groundray.direction.x = 0;
        groundray.direction.z = -1;
        rl.drawRay(groundray, rl.Color.red);
        groundray.direction.z = 1;
        rl.drawRay(groundray, rl.Color.red);
        groundray.direction.z = 0;
        //
        agentorange.draw();
        horde[0].draw();
        bond.draw();
        //
        var gr = camera.target;
        gr.y += 1;
        //rl.drawCapsule(camera.target, gr, 1, 8, 4, rl.color.red);
        //print("cam.targ:{}|{}|{}", .{ camera.target.x, camera.target.y, camera.target.z });
        //
        rl.endMode3D();

        //rl.drawText("Hi Dash", 190, 200, 20, rl.lIGHTGRAY);

        // draw grid of bits
        //var x: u16 = 0;
        //while (x < 40) : (x += 1) {
        //    var y: u16 = 0;
        //    while (y < 40) : (y += 1) {
        //        rl.DrawRectangle(10 + (x * 10), 10 + (y * 10), 9, 9, rl.RED);
        //    }
        //}
        // Need data stream, mnist?
        // need encoder
        // need sdr to sdr feeding

        rl.endDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.closeWindow(); // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}

// precicese
pub fn pLerp(comptime T: type, a: T, b: T, t: T) T {
    std.debug.assert(t >= 0 and t <= 1);
    return (1 - t) * a + t * b;
}

// impercise
pub fn iLerp(comptime T: type, a: T, b: T, t: T) T {
    std.debug.assert(t >= 0 and t <= 1);
    return a + (b - a) * t;
}
