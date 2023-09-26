local game = require "game"

local state = setmetatable({}, { __index = game })
state:init()

function love.update(dt)
  state:update(dt)
end

function love.mousemoved(x, y, dx, dy)
  state:mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, b)
  state:mousepressed(x, y, b)
end

function love.mousereleased(x, y, b)
  state:mousereleased(x, y, b)
end

function love.draw()
  state:draw()
end
