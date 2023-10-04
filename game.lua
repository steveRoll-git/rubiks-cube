local love     = love
local lg       = love.graphics
local lm       = love.math

local R3       = require "R3"
local vecMath  = require "vecMath"
local deepCopy = require "deepCopy"
local flux     = require "flux"

local function lerp(a, b, t)
  return a + (b - a) * t
end

local function damp(a, b, rate, dt)
  return lerp(a, b, 1 - math.exp(-rate * dt))
end

local function clamp(v, a, b)
  return math.min(math.max(v, a), b)
end

local function round(x)
  return math.floor(x + 0.5)
end

local function sign(x)
  return x > 0 and 1 or -1
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

local function round3(t)
  return { round(t[1]), round(t[2]), round(t[3]) }
end

local function format3(x, y, z)
  if y == nil and z == nil and type(x) == "table" then
    x, y, z = x.x, x.y, x.z
  end
  return ("%d %d %d"):format(x, y, z)
end

local function fromStr3(s)
  local x, y, z = s:match(("(%-?%d+)"):rep(3, " "))
  return tonumber(x), tonumber(y), tonumber(z)
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

local function colorFromHex(h)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255 }
end

local debugColors = {
  x = { 1, 0, 0 },
  y = { 0, 1, 0 },
  z = { 0, 0, 1 },
}

local vertexFormat = {
  { "VertexPosition", "float", 3 },
  { "VertexTexCoord", "float", 2 },
  { "VertexColor",    "float", 3 }
  -- {"VertexNormal", "float", 3}
}

local ceilingVertexFormat = {
  { "VertexPosition", "float", 3 },
  { "VertexColor",    "float", 4 }
}

local colors = {
  colorFromHex "0045AD",
  colorFromHex "FF5900",
  colorFromHex "C60000",
  colorFromHex "FFFFFF",
  colorFromHex "FFD500",
  colorFromHex "009B50",
}

local axisColors = {
  ["0 0 1"] = 1,  -- Front   blue
  ["-1 0 0"] = 2, -- Left    orange
  ["1 0 0"] = 3,  -- Right   red
  ["0 1 0"] = 4,  -- Up      white
  ["0 -1 0"] = 5, -- Down    yellow
  ["0 0 -1"] = 6, -- Back    green
}

-- key is a 3d direction, value is the first index in the piece mesh for that face
local axisIndices = {
  ["0 0 1"] = 1,
  ["0 0 -1"] = 5,
  ["1 0 0"] = 9,
  ["-1 0 0"] = 13,
  ["0 1 0"] = 17,
  ["0 -1 0"] = 21,
}

local stickerImage = lg.newImage("images/sticker.png")
local floorImage = lg.newImage("images/floor.png")
floorImage:setWrap("repeat")

local function cubeMesh(x, y, z)
  local n = -0.5
  local p = 0.5
  local mesh = lg.newMesh(vertexFormat, {
    -- back
    { n, n, p, 0, 0, 0, 0, 0 },
    { n, p, p, 0, 1, 0, 0, 0 },
    { p, p, p, 1, 1, 0, 0, 0 },
    { p, n, p, 1, 0, 0, 0, 0 },
    -- front
    { n, n, n, 0, 0, 0, 0, 0 },
    { p, n, n, 1, 0, 0, 0, 0 },
    { p, p, n, 1, 1, 0, 0, 0 },
    { n, p, n, 0, 1, 0, 0, 0 },
    -- right
    { p, n, n, 0, 0, 0, 0, 0 },
    { p, n, p, 1, 0, 0, 0, 0 },
    { p, p, p, 1, 1, 0, 0, 0 },
    { p, p, n, 0, 1, 0, 0, 0 },
    -- left
    { n, n, n, 0, 0, 0, 0, 0 },
    { n, p, n, 0, 1, 0, 0, 0 },
    { n, p, p, 1, 1, 0, 0, 0 },
    { n, n, p, 1, 0, 0, 0, 0 },
    -- up
    { n, p, n, 0, 0, 0, 0, 0 },
    { p, p, n, 0, 1, 0, 0, 0 },
    { p, p, p, 1, 1, 0, 0, 0 },
    { n, p, p, 1, 0, 0, 0, 0 },
    -- down
    { n, n, p, 1, 0, 0, 0, 0 },
    { p, n, p, 1, 1, 0, 0, 0 },
    { p, n, n, 0, 1, 0, 0, 0 },
    { n, n, n, 0, 0, 0, 0, 0 },
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

local gridSize = 30
local floor = lg.newMesh(vertexFormat, {
  { -gridSize, 0, -gridSize, -gridSize + 0.5, gridSize + 0.5,  1, 1, 1 },
  { gridSize,  0, -gridSize, gridSize + 0.5,  gridSize + 0.5,  1, 1, 1 },
  { gridSize,  0, gridSize,  gridSize + 0.5,  -gridSize + 0.5, 1, 1, 1 },
  { -gridSize, 0, gridSize,  -gridSize + 0.5, -gridSize + 0.5, 1, 1, 1 },
}, "fan")
floor:setTexture(floorImage)

local ceiling
do
  local verts = {
    { 0, 0, 0, 1, 1, 1, 0.65 }
  }
  local radius = 14
  local segments = 16
  for i = 0, segments do
    local a = i / segments * math.pi * 2
    table.insert(verts, 2, { math.cos(a) * radius, 0, math.sin(a) * radius, 1, 1, 1, 0 })
  end
  ceiling = lg.newMesh(ceilingVertexFormat, verts, "fan")
end

local game = {}

function game:init()
  self.fogShader = lg.newShader("shaders/fog.glsl")
  self.fogShader:send("fogStartRadius", 5)
  self.fogShader:send("fogEndRadius", gridSize)

  self.projectionMatrix = R3.new_origin(true, lg.getWidth(), lg.getHeight(), 0.1, math.rad(90))

  self.camera = {
    x = 4,
    y = 5,
    z = -4,
    rotH = math.pi / 4,
    rotV = -0.5,
    matrix = lm.newTransform()
  }
  self.orbitRadius = 6

  self.isOrbiting = false
  self.orbitSensitivity = 0.006

  self.isGrabbing = false
  self.isRotating = false
  self.minFlickSpeed = 4

  -- after we press the mouse on a piece and just before rotation starts,
  -- we choose one of the two axes in this table
  self.rotationOptions = nil

  -- where the mouse was pressed when grabbing started
  self.rotationPressPos = nil

  -- start rotating after the mouse has moved this many pixels from `rotationPressPos`
  self.rotationStartRadius = 16

  self.pieces = nil

  self.rubikPosition = {
    x = 0,
    y = 3,
    z = 0
  }

  self.tweens = flux.group()

  self:initState()
  self:generateRubik()
  self:updatePieceColors()
end

function game:generateRubik()
  self.pieces = {}

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
          table.insert(self.pieces, p)
        end
      end
    end
  end
end

-- updates the colors of all the pieces' faces based on the state
function game:updatePieceColors()
  for _, p in ipairs(self.pieces) do
    local part = self.cubeState[format3(p)]
    for axis, index in pairs(axisIndices) do
      local r, g, b = 0, 0, 0
      if part[axis] then
        r, g, b = unpack(colors[part[axis]])
      end
      for i = 0, 3 do
        p.mesh:setVertexAttribute(index + i, 3, r, g, b)
      end
    end
  end
end

function game:updateCameraMatrix()
  self.camera.matrix =
      R3.translate(self.camera.x, self.camera.y, self.camera.z) * --move the camera
      R3.rotate(R3.aa_to_quat(0, 1, 0, self.camera.rotH)) *       --rotate the camera
      R3.rotate(R3.aa_to_quat(1, 0, 0, self.camera.rotV))         --rotate the camera
  self.camera.viewMatrix = self.camera.matrix:inverse()
end

function game:castRay(x, y)
  -- this matrix converts screen space to world space
  -- (needed to get the position of the mouse on-screen in the world)
  local rayMatrix = lm.newTransform()
  rayMatrix:apply(self.projectionMatrix):apply(self.camera.viewMatrix)
  rayMatrix = rayMatrix:inverse()

  local ray = { position = self.camera }
  do
    local rayPos = { x, y, 0, 1 }
    local frustumPos = vecMath.mulMatrixVec4(rayMatrix, rayPos)

    ray.direction = vecMath.normalize(vecMath.sub(correctVec4(frustumPos), self.camera))
  end

  local aabb = {
    min = vecMath.sub(self.rubikPosition, { x = 1.5, y = 1.5, z = 1.5 }),
    max = vecMath.add(self.rubikPosition, { x = 1.5, y = 1.5, z = 1.5 }),
  }

  local intersect = vecMath.rayAABBIntersect(ray, aabb)
  return intersect
end

function game:doRotation(direction)
  local matrix = R3.rotate(R3.aa_to_quat(self.rotatingAxis.x, self.rotatingAxis.y, self.rotatingAxis.z,
    math.pi / 2 * direction))

  local newState = deepCopy(self.cubeState)

  for p, faces in pairs(self.cubeState) do
    local px, py, pz = fromStr3(p)
    local pos = { x = px, y = py, z = pz }
    if pos[self.rotatingAxisLetter] == self.rotatingSlice[self.rotatingAxisLetter] then
      local rotatedPosition = vecMath.mulMatrixVec4(matrix, { pos.x, pos.y, pos.z, 1 })
      rotatedPosition = round3(rotatedPosition)
      local rp = format3(unpack(rotatedPosition))
      newState[rp] = {}
      for face, color in pairs(faces) do
        local fx, fy, fz = fromStr3(face)
        local rotatedFace = vecMath.mulMatrixVec4(matrix, { fx, fy, fz, 0 })
        rotatedFace = round3(rotatedFace)
        newState[rp][format3(unpack(rotatedFace))] = faces[face]
      end
    end
  end

  self.cubeState = newState
end

function game:initState()
  self.cubeState = {}
  for x = -1, 1 do
    for y = -1, 1 do
      for z = -1, 1 do
        if x ~= 0 or y ~= 0 or z ~= 0 then
          local piece = {}
          self.cubeState[format3(x, y, z)] = piece
          if x ~= 0 then
            local face = format3(x, 0, 0)
            piece[face] = axisColors[face]
          end
          if y ~= 0 then
            local face = format3(0, y, 0)
            piece[face] = axisColors[face]
          end
          if z ~= 0 then
            local face = format3(0, 0, z)
            piece[face] = axisColors[face]
          end
        end
      end
    end
  end
end

lg.setBackgroundColor(0.8, 0.8, 0.8)

function game:mousemoved(x, y, dx, dy)
  if self.isOrbiting then
    self.camera.rotH = (self.camera.rotH - dx * self.orbitSensitivity) % (math.pi * 2)
    self.camera.rotV = clamp(self.camera.rotV - dy * self.orbitSensitivity, -math.pi / 2, math.pi / 2)
  elseif self.isRotating then
    local d = dot2D(dx, dy, self.rotatingDir2D.x, self.rotatingDir2D.y)
    self.rotatingAngle = self.rotatingAngle + (d / 84 * (self.rotatingCCW and -1 or 1))
    self.rotatingSpeed = math.sqrt(dx ^ 2 + dy ^ 2)
  elseif self.isGrabbing and not self.isRotating and dist(x, y, self.rotationPressPos.x, self.rotationPressPos.y) >= self.rotationStartRadius then
    -- this table will contain both rotation options, with the first one being the one closest to the mouse's moving direction.
    -- the second one will end up being the rotation axis.
    local options = {}
    for axis, screenPos in pairs(self.rotationOptions) do
      local dirX, dirY = normalize2D(screenPos.x - self.rotationPressPos.x, screenPos.y - self.rotationPressPos.y)
      table.insert(options, {
        axis = axis,
        screenPos = screenPos,
        dir2D = { x = dirX, y = dirY },
        product = math.abs(dot2D(x - self.rotationPressPos.x, y - self.rotationPressPos.y,
          screenPos.x - self.rotationPressPos.x,
          screenPos.y - self.rotationPressPos.y))
      })
    end
    table.sort(options, function(a, b)
      return a.product > b.product
    end)
    self.rotatingAxis = { x = 0, y = 0, z = 0 }
    self.rotatingAxis[options[2].axis] = 1
    self.rotatingSlice.x = self.rotatingSlice.x * self.rotatingAxis.x
    self.rotatingSlice.y = self.rotatingSlice.y * self.rotatingAxis.y
    self.rotatingSlice.z = self.rotatingSlice.z * self.rotatingAxis.z
    self.rotatingAxisLetter = options[2].axis
    self.rotatingDir2D = options[1].dir2D
    self.rotatingAngle = 0
    self.visRotatingAngle = 0
    self.rotatingCCW = ccw2D(x, y, options[1].screenPos.x, options[1].screenPos.y, options[2].screenPos.x,
      options[2].screenPos.y)
    self.isRotating = true
  else
    self:updateCameraMatrix()
  end
end

function game:mousepressed(x, y, b)
  if b == 1 and not self.isOrbiting then
    local hitWorld = self:castRay(x, y)
    if hitWorld then
      local hit = vecMath.sub(hitWorld, self.rubikPosition)
      self.isGrabbing = true
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
      self.rotatingSlice = rounded

      -- for the two axes in `normal` that are zero, we will generate 2D projected points that match those axes' units.
      -- they will be used to decide the rotation that will happen
      self.rotationOptions = {}
      for axis, n in pairs(normal) do
        if n == 0 then
          local direction = { x = 0, y = 0, z = 0 }
          direction[axis] = 1
          local addedPosition = vecMath.add(hitWorld, direction)
          local vec4 = { addedPosition.x, addedPosition.y, addedPosition.z, 1 }
          local projected = correctVec4(vecMath.mulMatrixVec4(self.projectionMatrix * self.camera.viewMatrix, vec4))
          self.rotationOptions[axis] = projected
        end
      end

      self.rotationPressPos = { x = x, y = y }
    end
  elseif b == 2 and not self.isGrabbing then
    self.isOrbiting = true
  end
end

function game:mousereleased(x, y, b)
  if b == 1 and self.isGrabbing then
    if self.isRotating then
      if math.abs(self.rotatingAngle) > math.pi / 4 or self.rotatingSpeed >= self.minFlickSpeed then
        -- perform the rotation
        local direction = round((self.rotatingAngle + sign(self.rotatingAngle) * math.min(math.floor(self.rotatingSpeed / self.minFlickSpeed), 1)) /
          (math.pi / 2))
        self:doRotation(direction)
        self:updatePieceColors()
        self.visRotatingAngle = self.rotatingAngle - direction * math.pi / 2
      end
    end
    self.isGrabbing = false
    self.isRotating = false
    self.tweeningRotation = true
    self.tweens:to(self, math.max(math.abs(self.visRotatingAngle) / 4, 0.05), { visRotatingAngle = 0 }):oncomplete(function()
      self.tweeningRotation = false
    end)
  elseif b == 2 and self.isOrbiting then
    self.isOrbiting = false
  end
end

function game:update(dt)
  if self.isRotating then
    self.visRotatingAngle = damp(self.visRotatingAngle, self.rotatingAngle, 18, dt)
  end

  self.tweens:update(dt)
end

function game:draw()
  lg.setMeshCullMode("back")
  lg.setFrontFaceWinding("ccw")
  lg.setDepthMode("less", true)

  lg.setColor(1, 1, 1)

  self.camera.x = self.rubikPosition.x + math.sin(self.camera.rotH) * math.cos(self.camera.rotV) * self.orbitRadius
  self.camera.y = self.rubikPosition.y - math.sin(self.camera.rotV) * self.orbitRadius
  self.camera.z = self.rubikPosition.z - math.cos(self.camera.rotH) * math.cos(self.camera.rotV) * self.orbitRadius

  self:updateCameraMatrix()

  lg.push()

  lg.replaceTransform(self.projectionMatrix) -- projection matrix
  lg.applyTransform(self.camera.viewMatrix)  -- view matrix

  lg.setShader(self.fogShader)
  lg.draw(floor)
  lg.setShader()

  lg.push()
  translate3D({ x = 0, y = 10, z = 0 })
  lg.draw(ceiling)
  lg.pop()

  lg.push()
  translate3D(self.rubikPosition)
  for _, p in ipairs(self.pieces) do
    lg.push()
    if (self.isRotating or self.tweeningRotation) and p[self.rotatingAxisLetter] == self.rotatingSlice[self.rotatingAxisLetter] then
      translate3D(self.rotatingSlice)
      lg.applyTransform(R3.rotate(R3.aa_to_quat(self.rotatingAxis.x, self.rotatingAxis.y, self.rotatingAxis.z,
        self.visRotatingAngle)))
      translate3D(vecMath.sub(p, self.rotatingSlice))
    else
      translate3D(p)
    end
    lg.draw(p.mesh)
    lg.pop()
  end
  lg.pop()

  lg.pop()

  if self.drawDebug then
    for axis, point in pairs(self.rotationOptions) do
      lg.setColor(debugColors[axis])
      lg.circle("fill", point.x, point.y, 5)
    end
  end
end

return game
