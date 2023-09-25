local love = love
local lg = love.graphics
local lm = love.math

local R3 = require "R3"
local vecMath = require "vecMath"

local function clamp(v, a, b)
  return math.min(math.max(v, a), b)
end

local function round(x)
  return math.floor(x + 0.5)
end

local function dist(x1, y1, x2, y2)
  return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function dot2D(x1, y1, x2, y2)
  return (x1 * x2) + (y1 * y2)
end

local function ccw2D(x1, y1, x2, y2, x3, y3)
  return (y2 - y1) * (x3 - x2) - (y3 - y2) * (x2 - x1) < 0
end

local function normalize2D(x, y)
  local len = math.sqrt(x ^ 2 + y ^ 2)
  return x / len, y / len
end

local function format3(x, y, z)
  if y == nil and z == nil and type(x) == "table" then
    x, y, z = x.x, x.y, x.z
  end
  return ("%d %d %d"):format(x, y, z)
end

local function translate3D(v)
  lg.applyTransform(R3.translate(v.x, v.y, v.z))
end

local function correctVec4(v)
  return {
    x = v[1] / v[4],
    y = v[2] / v[4],
    z = v[3] / v[4]
  }
end

local debugColors = {
  x = { 1, 0, 0 },
  y = { 0, 1, 0 },
  z = { 0, 0, 1 },
}

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
  ["0 0 1"] = { 0, 0, 1 },     -- Front   blue
  ["-1 0 0"] = { 1, 0.41, 0 }, -- Left    orange
  ["1 0 0"] = { 1, 0, 0 },     -- Right   red
  ["0 1 0"] = { 1, 1, 1 },     -- Up      white
  ["0 -1 0"] = { 1, 1, 0 },    -- Down    yellow
  ["0 0 -1"] = { 0, 1, 0 },    -- Back    green
}
colors.front = colors["0 0 1"]
colors.back = colors["0 0 -1"]
colors.left = colors["-1 0 0"]
colors.right = colors["1 0 0"]
colors.up = colors["0 1 0"]
colors.down = colors["0 -1 0"]

-- key is a 3d direction, value is the first index in the piece mesh for that face
local axisIndices = {
  ["0 0 1"] = 1,
  ["0 0 -1"] = 5,
  ["1 0 0"] = 9,
  ["-1 0 0"] = 13,
  ["0 1 0"] = 17,
  ["0 -1 0"] = 21,
}

local cubeState = {}
local function initState()
  for x = -1, 1 do
    for y = -1, 1 do
      for z = -1, 1 do
        if x ~= 0 or y ~= 0 or z ~= 0 then
          local piece = {}
          cubeState[format3(x, y, z)] = piece
          if x ~= 0 then
            local face = format3(x, 0, 0)
            piece[face] = colors[face]
          end
          if y ~= 0 then
            local face = format3(0, y, 0)
            piece[face] = colors[face]
          end
          if z ~= 0 then
            local face = format3(0, 0, z)
            piece[face] = colors[face]
          end
        end
      end
    end
  end
end

local stickerImage = lg.newImage("images/sticker.png")
local floorImage = lg.newImage("images/floor.png")
floorImage:setWrap("repeat")

local fogShader = lg.newShader("shaders/fog.glsl")

local function cubeMesh(x, y, z)
  local n = -0.5
  local p = 0.5
  local mesh = lg.newMesh(vertexFormat, {
    -- back
    { n, n, p, 0, 0, unpack(colors.back) },
    { n, p, p, 0, 1, unpack(colors.back) },
    { p, p, p, 1, 1, unpack(colors.back) },
    { p, n, p, 1, 0, unpack(colors.back) },
    -- front
    { n, n, n, 0, 0, unpack(colors.front) },
    { p, n, n, 1, 0, unpack(colors.front) },
    { p, p, n, 1, 1, unpack(colors.front) },
    { n, p, n, 0, 1, unpack(colors.front) },
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

local sides = {
  { x = 1,  y = 0,  z = 0 },
  { x = -1, y = 0,  z = 0 },
  { x = 0,  y = 1,  z = 0 },
  { x = 0,  y = -1, z = 0 },
  { x = 0,  y = 0,  z = 1 },
  { x = 0,  y = 0,  z = -1 },
}

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

local projectionMatrix = R3.new_origin(true, lg.getWidth(), lg.getHeight(), 0.1, math.rad(90))

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

local isGrabbing = false
local isRotating = false
local rotatingAxis
local rotatingAxisLetter
local rotatingSlice
local rotatingAngle
local rotatingDir2D
local rotatingCCW

-- after we press the mouse on a piece and just before rotation starts,
-- we choose one of the two axes in this table
local rotationOptions

-- where the mouse was pressed when grabbing started
local rotationPressPos

-- start rotating after the mouse has moved this many pixels from `rotationPressPos`
local rotationStartRadius = 16

local poo

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

-- updates the colors of all the pieces' faces based on the state
local function updatePieceColors()
  for _, p in ipairs(pieces) do
    local part = cubeState[format3(p)]
    for axis, index in pairs(axisIndices) do
      local r, g, b = 0, 0, 0
      if part[axis] then
        r, g, b = unpack(part[axis])
      end
      for i = 0, 3 do
        p.mesh:setVertexAttribute(index + i, 3, r, g, b)
      end
    end
  end
end

local rubikPosition = {
  x = 0,
  y = 3,
  z = 0
}

local function updateCameraMatrix()
  camera.matrix =
      R3.translate(camera.x, camera.y, camera.z) *     --move the camera
      R3.rotate(R3.aa_to_quat(0, 1, 0, camera.rotH)) * --rotate the camera
      R3.rotate(R3.aa_to_quat(1, 0, 0, camera.rotV))   --rotate the camera
  camera.viewMatrix = camera.matrix:inverse()
end

local function castRay(x, y)
  -- this matrix converts screen space to world space
  -- (needed to get the position of the mouse on-screen in the world)
  local rayMatrix = lm.newTransform()
  rayMatrix:apply(projectionMatrix):apply(camera.viewMatrix)
  rayMatrix = rayMatrix:inverse()

  local ray = { position = camera }
  do
    local rayPos = { x, y, 0, 1 }
    local frustumPos = vecMath.mulMatrixVec4(rayMatrix, rayPos)

    ray.direction = vecMath.normalize(vecMath.sub(correctVec4(frustumPos), camera))
  end

  local aabb = {
    min = vecMath.sub(rubikPosition, { x = 1.5, y = 1.5, z = 1.5 }),
    max = vecMath.add(rubikPosition, { x = 1.5, y = 1.5, z = 1.5 }),
  }

  local intersect = vecMath.rayAABBIntersect(ray, aabb)
  return intersect
end

initState()
generateRubik()
updatePieceColors()

lg.setBackgroundColor(0.8, 0.8, 0.8)

function love.mousemoved(x, y, dx, dy)
  if isOrbiting then
    camera.rotH = (camera.rotH - dx * orbitSensitivity) % (math.pi * 2)
    camera.rotV = clamp(camera.rotV - dy * orbitSensitivity, -math.pi / 2, math.pi / 2)
  elseif isRotating then
    local d = dot2D(dx, dy, rotatingDir2D.x, rotatingDir2D.y)
    rotatingAngle = rotatingAngle + (d / 64 * (rotatingCCW and -1 or 1))
  elseif isGrabbing and not isRotating and dist(x, y, rotationPressPos.x, rotationPressPos.y) >= rotationStartRadius then
    -- this table will contain both rotation options, with the first one being the one closest to the mouse's moving direction.
    -- the second one will end up being the rotation axis.
    local options = {}
    for axis, screenPos in pairs(rotationOptions) do
      local dirX, dirY = normalize2D(screenPos.x - rotationPressPos.x, screenPos.y - rotationPressPos.y)
      table.insert(options, {
        axis = axis,
        screenPos = screenPos,
        dir2D = { x = dirX, y = dirY },
        product = math.abs(dot2D(x - rotationPressPos.x, y - rotationPressPos.y, screenPos.x - rotationPressPos.x,
          screenPos.y - rotationPressPos.y))
      })
    end
    table.sort(options, function(a, b)
      return a.product > b.product
    end)
    rotatingAxis = { x = 0, y = 0, z = 0 }
    rotatingAxis[options[2].axis] = 1
    rotatingSlice.x = rotatingSlice.x * rotatingAxis.x
    rotatingSlice.y = rotatingSlice.y * rotatingAxis.y
    rotatingSlice.z = rotatingSlice.z * rotatingAxis.z
    rotatingAxisLetter = options[2].axis
    rotatingDir2D = options[1].dir2D
    rotatingAngle = 0
    rotatingCCW = ccw2D(x, y, options[1].screenPos.x, options[1].screenPos.y, options[2].screenPos.x,
      options[2].screenPos.y)
    isRotating = true
  else
    updateCameraMatrix()
  end
end

function love.mousepressed(x, y, b)
  if b == 1 and not isOrbiting then
    local hitWorld = castRay(x, y)
    if hitWorld then
      local hit = vecMath.sub(hitWorld, rubikPosition)
      isGrabbing = true
      local rounded = {
        x = round(clamp(hit.x, -1.49, 1.49)),
        y = round(clamp(hit.y, -1.49, 1.49)),
        z = round(clamp(hit.z, -1.49, 1.49)),
      }
      local ax, ay, az = math.abs(hit.x), math.abs(hit.y), math.abs(hit.z)
      local normal = {
        x = (ax > ay and ax > az) and rounded.x or 0,
        y = (ay > ax and ay > az) and rounded.y or 0,
        z = (az > ax and az > ay) and rounded.z or 0,
      }
      poo = normal
      rotatingSlice = rounded

      -- for the two axes in `normal` that are zero, we will generate 2D projected points that match those axes' units.
      -- they will be used to decide the rotation that will happen
      rotationOptions = {}
      for axis, n in pairs(normal) do
        if n == 0 then
          local direction = { x = 0, y = 0, z = 0 }
          direction[axis] = 1
          local addedPosition = vecMath.add(hitWorld, direction)
          local vec4 = { addedPosition.x, addedPosition.y, addedPosition.z, 1 }
          local projected = correctVec4(vecMath.mulMatrixVec4(projectionMatrix * camera.viewMatrix, vec4))
          rotationOptions[axis] = projected
        end
      end

      rotationPressPos = { x = x, y = y }
    end
  elseif b == 2 and not isGrabbing then
    isOrbiting = true
  end
end

function love.mousereleased(x, y, b)
  if b == 1 and isGrabbing then
    isGrabbing = false
    isRotating = false
  elseif b == 2 and isOrbiting then
    isOrbiting = false
  end
end

function love.draw()
  lg.setColor(1, 1, 1)

  camera.x = rubikPosition.x + math.sin(camera.rotH) * math.cos(camera.rotV) * orbitRadius
  camera.y = rubikPosition.y - math.sin(camera.rotV) * orbitRadius
  camera.z = rubikPosition.z - math.cos(camera.rotH) * math.cos(camera.rotV) * orbitRadius

  updateCameraMatrix()

  lg.push()

  lg.replaceTransform(projectionMatrix) -- projection matrix
  lg.applyTransform(camera.viewMatrix)  -- view matrix

  lg.setShader(fogShader)
  lg.draw(floor)
  lg.setShader()

  lg.push()
  translate3D(rubikPosition)
  for _, p in ipairs(pieces) do
    lg.push()
    if isRotating and p[rotatingAxisLetter] == rotatingSlice[rotatingAxisLetter] then
      translate3D(rotatingSlice)
      lg.applyTransform(R3.rotate(R3.aa_to_quat(rotatingAxis.x, rotatingAxis.y, rotatingAxis.z, rotatingAngle)))
      translate3D(vecMath.sub(p, rotatingSlice))
    else
      translate3D(p)
    end
    lg.draw(p.mesh)
    lg.pop()
  end
  lg.pop()

  lg.pop()

  if poo then
    lg.setColor(0, 0, 0)
    lg.print(("x %.2f  y %.2f  z %.2f\nx %.2f  y %.2f  z %.2f")
      :format(poo.x, poo.y, poo.z, rotatingSlice.x, rotatingSlice.y, rotatingSlice.z))

    for axis, point in pairs(rotationOptions) do
      lg.setColor(debugColors[axis])
      lg.circle("fill", point.x, point.y, 5)
    end
  end
  if isRotating then
    lg.setColor(0, 0, 0)
    lg.print(("%s"):format(rotatingCCW), 0, 100)
  end
end
