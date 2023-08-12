local love = love
local lg = love.graphics
local lm = love.math

local R3 = require "R3"

local function clamp(v, a, b)
  return math.min(math.max(v, a), b)
end

lg.setMeshCullMode("back")
lg.setFrontFaceWinding("ccw")
lg.setDepthMode("less", true)

local vertexFormat = {
  { "VertexPosition", "float", 3 },
  { "VertexTexCoord", "float", 2 },
  { "VertexColor",    "float", 3 }
  -- {"VertexNormal", "float", 3}
}

local colors = {
  ["0 0 1"] = { 0, 1, 0 },     -- 1 Front   green
  ["-1 0 0"] = { 1, 0.41, 0 }, -- 2 Left    orange
  ["1 0 0"] = { 1, 0, 0 },     -- 3 Right   red
  ["0 1 0"] = { 1, 1, 1 },     -- 4 Up      white
  ["0 -1 0"] = { 1, 1, 0 },    -- 5 Down    yellow
  ["0 0 -1"] = { 0, 0, 1 },    -- 6 Back    yellow
}
colors.front = colors["0 0 1"]
colors.back = colors["0 0 -1"]
colors.left = colors["-1 0 0"]
colors.right = colors["1 0 0"]
colors.up = colors["0 1 0"]
colors.down = colors["0 -1 0"]

local stickerImage = lg.newImage("images/sticker.png")
local floorImage = lg.newImage("images/floor.png")
floorImage:setWrap("repeat")

local fogShader = lg.newShader("shaders/fog.glsl")

local function cubeMesh(x, y, z)
  local n = -0.5
  local p = 0.5
  local mesh = lg.newMesh(vertexFormat, {
    -- front
    { n, n, n, 0, 0, unpack(colors.front) },
    { p, n, n, 1, 0, unpack(colors.front) },
    { p, p, n, 1, 1, unpack(colors.front) },
    { n, p, n, 0, 1, unpack(colors.front) },
    -- back
    { n, n, p, 0, 0, unpack(colors.back) },
    { n, p, p, 0, 1, unpack(colors.back) },
    { p, p, p, 1, 1, unpack(colors.back) },
    { p, n, p, 1, 0, unpack(colors.back) },
    -- right
    { p, n, n, 0, 0, unpack(colors.right) },
    { p, n, p, 1, 0, unpack(colors.right) },
    { p, p, p, 1, 1, unpack(colors.right) },
    { p, p, n, 0, 1, unpack(colors.right) },
    -- left
    { n, n, n, 0, 0, unpack(colors.left) },
    { n, p, n, 0, 1, unpack(colors.left) },
    { n, p, p, 1, 1, unpack(colors.left) },
    { n, n, p, 1, 0, unpack(colors.left) },
    -- up
    { n, p, n, 0, 0, unpack(colors.up) },
    { p, p, n, 0, 1, unpack(colors.up) },
    { p, p, p, 1, 1, unpack(colors.up) },
    { n, p, p, 1, 0, unpack(colors.up) },
    -- down
    { n, n, p, 1, 0, unpack(colors.down) },
    { p, n, p, 1, 1, unpack(colors.down) },
    { p, n, n, 0, 1, unpack(colors.down) },
    { n, n, n, 0, 0, unpack(colors.down) },
  }, "triangles")
  mesh:setTexture(stickerImage)
  mesh:setVertexMap({
    -- front
    1, 2, 3, 3, 4, 1,
    -- back
    5, 6, 7, 7, 8, 5,
    -- right
    9, 10, 11, 11, 12, 9,
    -- left
    13, 14, 15, 15, 16, 13,
    -- up
    17, 18, 19, 19, 20, 17,
    -- down
    21, 22, 23, 23, 24, 21,
  })
  return mesh
end

local test = cubeMesh()

local gridSize = 30
local floor = lg.newMesh(vertexFormat, {
  { -gridSize, 0, -gridSize, -gridSize + 0.5, gridSize + 0.5,  1, 1, 1 },
  { gridSize,  0, -gridSize, gridSize + 0.5,  gridSize + 0.5,  1, 1, 1 },
  { gridSize,  0, gridSize,  gridSize + 0.5,  -gridSize + 0.5, 1, 1, 1 },
  { -gridSize, 0, gridSize,  -gridSize + 0.5, -gridSize + 0.5, 1, 1, 1 },
}, "fan")
floor:setTexture(floorImage)

fogShader:send("fogStartRadius", 5)
fogShader:send("fogEndRadius", gridSize)

local projectionMat = R3.new_origin(true, lg.getWidth(), lg.getHeight(), 0.1, math.rad(90))

local camera = {
  x = 4,
  y = 5,
  z = -4,
  rotH = math.pi / 4,
  rotV = -0.5,
  matrix = lm.newTransform()
}
local orbitRadius = 6

local isOrbiting = false
local orbitSensitivity = 0.006

local pieces

local function generateRubik()
  pieces = {}

  for x = -1, 1 do
    for y = -1, 1 do
      for z = -1, 1 do
        if x ~= 0 or y ~= 0 or z ~= 0 then
          local p = {
            mesh = cubeMesh(),
            x = x,
            y = y,
            z = z
          }
          table.insert(pieces, p)
        end
      end
    end
  end
end

local rubikPosition = {
  x = 0,
  y = 3,
  z = 0
}

generateRubik()

lg.setBackgroundColor(0.8, 0.8, 0.8)

function love.mousemoved(x, y, dx, dy)
  isOrbiting = love.mouse.isDown(2)
  if isOrbiting then
    camera.rotH = (camera.rotH - dx * orbitSensitivity) % (math.pi * 2)
    camera.rotV = clamp(camera.rotV - dy * orbitSensitivity, -math.pi / 2, math.pi / 2)
  end
end

function love.draw()
  camera.x = rubikPosition.x + math.sin(camera.rotH) * math.cos(camera.rotV) * orbitRadius
  camera.y = rubikPosition.y - math.sin(camera.rotV) * orbitRadius
  camera.z = rubikPosition.z - math.cos(camera.rotH) * math.cos(camera.rotV) * orbitRadius

  camera.matrix =
      R3.translate(camera.x, camera.y, camera.z) *     --move the camera
      R3.rotate(R3.aa_to_quat(0, 1, 0, camera.rotH)) * --rotate the camera
      R3.rotate(R3.aa_to_quat(1, 0, 0, camera.rotV))   --rotate the camera
  camera.matrix = camera.matrix:inverse()

  lg.replaceTransform(projectionMat) -- projection matrix
  lg.applyTransform(camera.matrix)   -- view matrix

  lg.setShader(fogShader)
  lg.draw(floor)
  lg.setShader()

  -- lg.push()
  -- lg.applyTransform(R3.translate(0, 0, 0))
  -- --lg.applyTransform(R3.rotate(R3.aa_to_quat(1, 1, 0, love.timer.getTime())))
  -- lg.draw(test)
  -- lg.pop()

  lg.push()
  lg.applyTransform(R3.translate(rubikPosition.x, rubikPosition.y, rubikPosition.z))
  for _, p in ipairs(pieces) do
    lg.push()
    lg.applyTransform(R3.translate(p.x, p.y, p.z))
    lg.draw(p.mesh)
    lg.pop()
  end
  lg.pop()
end
