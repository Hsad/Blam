//
// dash
// Zig version: 0.10.1
// Author: Dash
// Date: 2023-7-10
//

const rl = @import("raylib");
//const rlm = @import("raylib-math");
const rlm = rl.math;

const std = @import("std");
const print = std.debug.print;

const int2 = struct { x: u32, z: u32 };

const Terrain = struct {
    mapscale: rl.Vector3,
    hmImageSize: int2,
    mapoffset: rl.Vector3,

    fn coordToPixel(self: *Terrain, coord: rl.Vector2) usize {
        const xcoordsafe = @max(0, @min(1, coord.x / self.mapscale.x));
        const x = iLerp(f64, 0, @floatFromInt(self.hmImageSize.x), xcoordsafe);
        const zcoordsafe = @max(0, @min(1, coord.y / self.mapscale.z));
        const z = iLerp(f64, 0, @floatFromInt(self.hmImageSize.z), zcoordsafe);

        return @as(u32, @intFromFloat(z)) * self.hmImageSize.x + @as(usize, @intFromFloat(x));
    }

    pub fn getGroundPoint(self: *Terrain, pixels: [*]rl.Color, coord: rl.Vector2) rl.Vector3 {
        //print("coord:{d}:{d}\n", .{ coord.x, coord.y });
        //print("pixelcoord:{d}\n", .{self.coordToPixel(coord)});
        var ht = rl.colorNormalize(pixels[self.coordToPixel(coord)]).x;
        ht = ht * self.mapscale.y;
        //print("height:{d}\n", .{ht});
        const groundpoint = rl.Vector3{ .x = coord.x, .y = ht, .z = coord.y };
        //groundpoint is the coodinate translated to pixel space, looked up for height,
        //then the coordiante xz is used with the height.
        //the input of xz should be in coordinate space to make my live easier in the future.
        return groundpoint;
    }

    pub fn getPreciseGroundPoint(self: *Terrain, pixels: [*]rl.Color, coord: rl.Vector2) rl.Vector3 {
        const xcoordsafe = @max(0, @min(1, coord.x / self.mapscale.x));
        const x = iLerp(f32, 0, @floatFromInt(self.hmImageSize.x), xcoordsafe);
        const zcoordsafe = @max(0, @min(1, coord.y / self.mapscale.z));
        const z = iLerp(f32, 0, @floatFromInt(self.hmImageSize.z), zcoordsafe);

        //x high, x low
        const xhigh = @ceil(x);
        const xlow = @floor(x);
        const xhInt = @as(u32, @intFromFloat(xhigh));
        const xlInt = @as(u32, @intFromFloat(xlow));
        //z high, z low
        const zhigh = @ceil(z);
        const zlow = @floor(z);
        const zhInt = @as(u32, @intFromFloat(zhigh));
        const zlInt = @as(u32, @intFromFloat(zlow));
        //print("\n(x)h:{d},l:{d}\n", .{ xhigh, xlow });
        //print("(z)h:{d},l:{d}\n", .{ zhigh, zlow });
        // I think I need to take two lerp points,
        // then from those two heights, lerp a third time
        const ahigh = rl.colorNormalize(pixels[zhInt * self.hmImageSize.x + xhInt]).x;
        const alow = rl.colorNormalize(pixels[zhInt * self.hmImageSize.x + xlInt]).x;
        var a = iLerp(f32, alow, ahigh, x - xlow);
        //print("a:{d}", .{a});
        const bhigh = rl.colorNormalize(pixels[zlInt * self.hmImageSize.x + xhInt]).x;
        const blow = rl.colorNormalize(pixels[zlInt * self.hmImageSize.x + xlInt]).x;
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
    color: rl.Color = rl.Color.green,

    fn randomMove(self: *Agent) void {
        if (rl.getRandomValue(0, 100) < 10) {
            self.vel.x = @as(f32, @floatFromInt(rl.getRandomValue(-1, 1))) * 0.01;
            self.vel.z = @as(f32, @floatFromInt(rl.getRandomValue(-1, 1))) * 0.01;
        }
        self.loc.x += self.vel.x;
        self.loc.y += self.vel.y;
        self.loc.z += self.vel.z;
    }
    fn chaseMove(self: *Agent, target: rl.Vector3) void {
        const xdiff = target.x - self.loc.x;
        const zdiff = target.z - self.loc.z;

        //lazy mahattan normalizeation
        if (xdiff + zdiff == 0) {
            return;
        }
        const xvel = xdiff * (0.002 / (@abs(xdiff) + @abs(zdiff)));
        const zvel = zdiff * (0.002 / (@abs(xdiff) + @abs(zdiff)));

        //print("xvel:{d}\n", .{xvel});

        self.vel.x = xvel;
        self.vel.z = zvel;

        self.loc.x += self.vel.x;
        self.loc.y += self.vel.y;
        self.loc.z += self.vel.z;
    }

    fn floor(self: *Agent, ground: *Terrain, pixels: [*]rl.Color) void {
        const x = self.loc.x;
        const z = self.loc.z;

        const y = ground.getPreciseGroundPoint(pixels, rl.Vector2{ .x = x, .y = z }).y;
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
        rl.drawCapsule(self.loc, top, 0.02, 8, 3, self.color);
        top.y += 0.025;
        rl.drawCapsule(self.loc, top, 0.01, 8, 3, self.color);
    }
    fn drawModel(self: *Agent, model: rl.Model) void {
        const top = self.loc;
        rl.drawModel(model, top, 0.03, self.color);
    }
    //fn drawInstanced(self: *Agent, model: rl.Model, agentcnt: usize) void {
    //    var mtx: rl.Matrix = rlm.matrixTranslate(self.loc.x, self.loc.y, self.loc.z);

    //    //rl.modelMatrixSet(model.meshes[0], mtx);
    //    var mat: rl.Material = model.materials[0];
    //    rl.drawMeshInstanced(model.meshes[0], mat, mtx, agentcnt);
    //}
};

const SkyBall = struct {
    loc: rl.Vector3,
    trans: rl.Matrix,
    //fn setMatrix(self: *SkyBall) void {
    //    self.trans = rlm.matrixTranslate(self.loc.x, self.loc.y, self.loc.z);
    //}
    //fn draw(self: *SkyBall) void {
    //    rl.drawSphere(self.loc, 0.05, 8, 8, rl.Color.white);
    //}
};

////World
//components
//mask
//systems

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const ally = gpa.allocator();
const World = struct {
    //components
    //not sure how to make a resizable array
    loc: std.ArrayList(i32) = std.ArrayList(i32).init(ally),
    mask: std.ArrayList(u32) = std.ArrayList(u32).init(ally),
    arch: std.MultiArrayList(Agent) = std.MultiArrayList(Agent){},
    balls: std.MultiArrayList(SkyBall) = std.MultiArrayList(SkyBall){},
    //I think I want to make a new MultiArrayList for each architype
    //and then have a mask that indexes to each MultiArrayList
    //instead of iterating through every item in the sparse array
    //supposedly faster
    //Maybe a combo of these two is best, architypes for common types
    //and the general arrays for uncommon component combinations
    //that way you can pack the majority of things together
    //
    //Interesting idea, Systems own the component arrays
    //And the selection of which system owns the compoent is based off
    //of which system writes to the compoennt
    //reminds me of my early neuron flow system

    //Now should systems be in here, or should they be their own thing
    //I almost think they could be in here
    //categories of Input, Update, Draw

    //fn input(self: *World) void{}
    fn update(self: *World) void {
        //skyballs
        //in the future need to filter by mask
        const slice = self.balls.slice();
        const locs = slice.items(.loc);
        const trans = slice.items(.trans);

        for (locs, 0..) |loc, i| {
            _ = loc;
            _ = trans;
            _ = i;
            //trans[i] = rlm.matrixTranslate(loc.x, loc.y, loc.z);
        }
    }
    fn draw(self: *World, zomb: rl.Model) void {
        //var balltrans = self.balls.items(.trans);
        //var mat: rl.Material = zomb.materials[0];
        //rl.drawMeshInstanced(zomb.meshes[0], mat, balltrans, @intCast(i32, balltrans.len));
        const ballloc = self.balls.items(.loc);
        for (ballloc) |loc| {
            //rl.drawSphere(loc, 0.1, rl.Color.red);
            rl.drawModel(zomb, loc, 0.03, rl.Color.red);
        }
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 1920;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    //rl.SetConfigFlags(.FLAG_WINDOW_RESIZABLE);
    //rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------
    //

    const ZombieModel: rl.Model = rl.loadModel("models/Zombie.obj");
    //var ZombieModel: rl.Model = rl.loadModelFromMesh(rl.genMeshCylinder(0.1, 0.5, 8));
    //ZombieModel.materials[0].maps[0].color = rl.Color.red;
    //ZombieModel.materials[0].maps[0].shader = rl.loadShader(, "")
    //var ZombieShader = rl.loadShader()
    //var ZombieMaterial: rl.Material = rl.loadMaterialDefault();

    //Initilize ECS
    var world = World{};
    //try world.balls.ensureTotalCapacity(ally, 500);
    try world.balls.resize(ally, 500);
    var xx: usize = 0;
    while (xx < world.balls.len) : (xx += 1) {
        const x = @as(f32, @floatFromInt(rl.getRandomValue(90, 110)));
        const y = @as(f32, @floatFromInt(rl.getRandomValue(5, 10)));
        const z = @as(f32, @floatFromInt(rl.getRandomValue(90, 110)));
        world.balls.set(xx, SkyBall{ .loc = rl.Vector3{ .x = x, .y = y, .z = z }, .trans = rlm.matrixIdentity() });
    }

    //const img = rl.LoadImage("C:/Misc/Projects/ColoradoGeoMap/Evergreen2.png");
    //const img = rl.LoadImage("~/Omni/Projects/ColoradoGeoMap/Evergreen2.png");
    //const img = rl.LoadImage("textures/tex.png");
    //const img = rl.LoadImage("textures/1294.png");

    const img = rl.loadImage("textures/Coop.png");
    //const img = rl.LoadImage("textures/EvergreenH.png");
    //const img = rl.GenImageGradientH(256, 256, rl.Color.WHITE, rl.Color.BLACK);

    //print("w:{d}, h:{d}", .{ img.width, img.height });

    //const pixels = @ptrCast([*]rl.Color, @alignCast(@alignOf(rl.Color), img.data.?));
    //const pixels = @as([*]rl.Color, @ptrCast(img.data.?));
    const pixels = @as([*]rl.Color, @ptrCast(img.data));

    // chat
    // Zig code for setting the camera mode using UpdateCamera
    var camera: rl.Camera = rl.Camera3D{
        .position = rl.Vector3{ .x = 0.0, .y = 2.0, .z = 4.0 },
        .target = rl.Vector3{ .x = 0.0, .y = 2.0, .z = 0.0 },
        .up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 60.0,
        .projection = rl.CameraProjection.camera_perspective,
    };
    var cameraMode = rl.CameraMode.camera_first_person;

    //// Begin copy of heightmap code
    //var camera: rl.Camera = rl.Camera3D{
    //    .position = rl.Vector3{ .x = 1.0, .y = 5.0, .z = 1.0 },
    //    .target = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
    //    .up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 },
    //    .fovy = 45.0,
    //    .projection = rl.CameraProjection.camera_perspective,
    //    //.projection = 0,
    //};
    const viewMatrix: rl.Matrix = rl.getCameraMatrix(camera);

    //const demoimage = rl.LoadImage("C:/Misc/Projects/ColoradoGeoMap/EvergreenCompositeSmooshed.png");
    //const demoimage = rl.LoadImage("resources/textures/tex.png");
    //const demoimage = rl.LoadImage("resources/textures/1294.png");
    const demoimage = rl.loadImage("textures/CoopColor.png");
    //const demoimage = rl.LoadImage("textures/EvergreenC.png");
    //const demoimage = rl.GenImageGradientH(256, 256, rl.Color.WHITE, rl.Color.BLACK);
    const demotexture = rl.loadTextureFromImage(demoimage);
    //const demotexture = rl.LoadTextureFromImage(img);

    // Global map values..
    const mapscale: rl.Vector3 = rl.Vector3{ .x = 200, .y = 5, .z = 200 };
    //the dimentions of the heightmap | int
    //var heightmapSize: rl.Vector2 = rl.Vector2{ .x = img.width, .y = img.height };
    const heightmapSize: int2 = int2{
        .x = @as(u16, @truncate(@as(u32, @bitCast(img.width)))),
        .z = @as(u16, @truncate(@as(u32, @bitCast(img.height)))) - 1, // -1 to prevent segfalt
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
    //rl.setCameraMode(camera, rl.CameraMode.camera_first_person);
    //rl.SetCameraMode(camera, rl.CameraMode.CAMERA_FREE);
    //rl.SetCameraMode(camera, rl.CameraMode.CAMERA_CUSTOM);

    //const cam = @ptrCast([*]rl.Camera, @alignCast(@alignOf(rl.Camera), &camera));
    //rl.updateCamera(&camera);

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
    var camcoords = rl.Vector2{ .x = mapscale.x / 2, .y = mapscale.z / 2 };
    //camcoords = rl.Vector2{ .x = 1, .y = 1 };
    var camy: f32 = 0;
    const eyeheight: f32 = 0.1;
    var gndpnt: f32 = 0.0;
    var fallspd: f32 = 0.0;

    camera.position.x = camcoords.x;
    camera.position.z = camcoords.y;

    //var campos = rl.Vector3{ .x = 0, .y = 0, .z = 0 };
    //var camrot = rl.Vector3{ .x = 0, .y = 0, .z = 0 };
    //

    var agentorange = Agent{};
    agentorange.color = rl.Color.orange;

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
    const horde: []Agent = try allocator.alloc(Agent, 500); //5fps
    const survivors: []Agent = try allocator.alloc(Agent, 100);
    bond.color = rl.Color.blue;
    bond.loc.x = 0.5;
    for (horde, 0..) |_, i| {
        horde[i].loc.x = @as(f32, @floatFromInt(rl.getRandomValue(0, @as(u32, @intFromFloat(mapscale.x))))) / 10;
        horde[i].loc.z = @as(f32, @floatFromInt(rl.getRandomValue(0, @as(u32, @intFromFloat(mapscale.z))))) / 10;
        horde[i].loc.x += mapscale.x / 2;
        horde[i].loc.z += mapscale.z / 2;
        horde[i].color = rl.Color{ .r = 20, .g = 100, .b = 40, .a = 255 };
    }
    for (survivors, 0..) |_, i| {
        survivors[i].loc.x = @as(f32, @floatFromInt(rl.getRandomValue(0, @as(u32, @intFromFloat(mapscale.x))))) / 10;
        survivors[i].loc.z = @as(f32, @floatFromInt(rl.getRandomValue(0, @as(u32, @intFromFloat(mapscale.z))))) / 10;
        survivors[i].loc.x += mapscale.x / 2;
        survivors[i].loc.z += mapscale.z / 2;
        survivors[i].color = rl.Color{ .r = 220, .g = 100, .b = 140, .a = 255 };
    }

    const cube = rl.genMeshCube(1, 1, 1);
    var cubetransform = rlm.matrixIdentity();
    const cubetranslation = rlm.matrixTranslate(0, 0, 0);
    const cubeaxis = rl.Vector3{ .x = 0, .y = 1, .z = 0 }; //rlm.vector3Normalize(rl); //rlm.matrixIdentity();
    const cubeangle: f32 = 0;
    const cuberotation = rlm.matrixRotate(cubeaxis, cubeangle);
    cubetransform = rlm.matrixMultiply(cuberotation, cubetranslation);
    _ = cube;

    const matDefault: rl.Material = rl.loadMaterialDefault();

    matDefault.maps[0].color = rl.Color.blue;
    //model.materials[0].maps[rl.MaterialMapIndex.material_map_albedo].texture = demotexture;
    //material_map_albedo = 0,

    //print("rl.PI:{d}", .{rlm.vector3Length(camera.position)});

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Switch camera mode with keys (1, 2, 3, 4)
        if (rl.isKeyPressed(rl.KeyboardKey.key_one)) {
            cameraMode = rl.CameraMode.camera_free;
            camera.up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_two)) {
            cameraMode = rl.CameraMode.camera_first_person;
            camera.up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_three)) {
            cameraMode = rl.CameraMode.camera_third_person;
            camera.up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_four)) {
            cameraMode = rl.CameraMode.camera_orbital;
            camera.up = rl.Vector3{ .x = 0.0, .y = 1.0, .z = 0.0 };
        }
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

        // Update camera based on current mode
        rl.updateCamera(&camera, cameraMode);

        //rl.updateCamera(&camera);

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

        for (horde, 0..) |_, i| {
            horde[i].chaseMove(camera.position);
            horde[i].floor(&terry, pixels);
        }
        for (survivors, 0..) |_, i| {
            survivors[i].chaseMove(camera.position);
            survivors[i].floor(&terry, pixels);
        }
        bond.chaseMove(camera.position);
        bond.floor(&terry, pixels);

        //ECS UPDATE
        world.update();
        // Now I need a detection system so zombies can chase, and survivors can avoid

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();

        rl.clearBackground(rl.Color.white);

        rl.beginMode3D(camera);

        rl.drawModel(model, mapPosition, 1.0, rl.Color.white);
        rl.drawGrid(20, 1.0);
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
        bond.draw();
        agentorange.draw();
        for (horde, 0..) |_, i| {
            //horde[i].draw();
            horde[i].drawModel(ZombieModel);
            //horde[i].drawInstanced(ZombieModel, horde.len);
        }
        for (survivors, 0..) |_, i| {
            //survivors[i].draw();
            survivors[i].drawModel(ZombieModel);
        }
        //
        var gr = camera.target;
        gr.y += 1;
        //rl.drawCapsule(camera.target, gr, 1, 8, 4, rl.color.red);
        //print("cam.targ:{}|{}|{}", .{ camera.target.x, camera.target.y, camera.target.z });
        //
        // ECS DRAW
        world.draw(ZombieModel);

        rl.endMode3D();

        //const fpsString = try std.fmt.allocPrint(allocator, "fps:{d}", .{rl.getFPS()});
        //rl.drawText(fpsString.ptr, 20, 20, 20, rl.Color.gray);

        const fpsString = try std.fmt.allocPrintZ(allocator, "fps:{d}", .{rl.getFPS()});
        defer allocator.free(fpsString);
        rl.drawText(fpsString, 20, 20, 20, rl.Color.gray);

        //rl.drawText("Hi Dash", 190, 200, 20, rl.lIGHTGRAY);
        //

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
