local DBL_EPSILON = 2.2204460492503131e-16
local abs = math.abs
local sqrt = math.sqrt
local min = math.min
local max = math.max

local vecMath = {}

function vecMath.add(a, b)
  return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
end

function vecMath.sub(a, b)
  return { x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }
end

function vecMath.mul(a, n)
  return { x = a.x * n, y = a.y * n, z = a.z * n }
end

function vecMath.dot(a, b)
  return a.x * b.x + a.y * b.y + a.z * b.z
end

function vecMath.normalize(a)
  local len = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
  return {
    x = a.x / len,
    y = a.y / len,
    z = a.z / len,
  }
end

function vecMath.mulMatrixVec4(m, b)
  local a = { m:getMatrix() }
  return {
    b[1] * a[1] + b[2] * a[2] + b[3] * a[3] + b[4] * a[4],
    b[1] * a[5] + b[2] * a[6] + b[3] * a[7] + b[4] * a[8],
    b[1] * a[9] + b[2] * a[10] + b[3] * a[11] + b[4] * a[12],
    b[1] * a[13] + b[2] * a[14] + b[3] * a[15] + b[4] * a[16],
  }
end

function vecMath.rayPlaneIntersect(ray, plane)
  local denom = vecMath.dot(plane.normal, ray.direction)

  -- ray does not intersect plane
  if abs(denom) < DBL_EPSILON then
    return false
  end

  -- distance of direction
  local d = vecMath.sub(plane.position, ray.position)
  local t = vecMath.dot(d, plane.normal) / denom

  if t < DBL_EPSILON then
    return false
  end

  -- Return collision point and distance from ray origin
  return vecMath.add(ray.position, vecMath.mul(ray.direction, t)), t
end

function vecMath.rayAABBIntersect(ray, aabb)
  local dx   = 1 / ray.direction.x
  local dy   = 1 / ray.direction.y
  local dz   = 1 / ray.direction.z

  local t1   = (aabb.min.x - ray.position.x) * dx
  local t2   = (aabb.max.x - ray.position.x) * dx
  local t3   = (aabb.min.y - ray.position.y) * dy
  local t4   = (aabb.max.y - ray.position.y) * dy
  local t5   = (aabb.min.z - ray.position.z) * dz
  local t6   = (aabb.max.z - ray.position.z) * dz

  local tmin = max(max(min(t1, t2), min(t3, t4)), min(t5, t6))
  local tmax = min(min(max(t1, t2), max(t3, t4)), max(t5, t6))

  -- ray is intersecting AABB, but whole AABB is behind us
  if tmax < 0 then
    return false
  end

  -- ray does not intersect AABB
  if tmin > tmax then
    return false
  end

  -- Return collision point and distance from ray origin
  return vecMath.add(ray.position, vecMath.mul(ray.direction, tmin)), tmin
end

return vecMath
