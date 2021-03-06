local vector = require "../vector"
local laser = require "laser"

function love.load()
  love.window.setMode(1024, 768, { fullscreen = true })
  love.mouse.setVisible(false)

  isPressingUp = false
  isPressingLeft = false
  isPressingDown = false
  isPressingRight = false

  aimWithMouse = false
  mousePos = vector(0, 0)

  playerPos = vector(love.graphics.getWidth()/2, love.graphics.getHeight()/2)
  playerVel = vector(0, 0)
  playerAcc = vector(0, 0)

  gunAngle = 0
  gunVel = 0
  gunAcc = 0

  firingLaser = false

  world = {}
end

function love.update(dt)
  mousePos = vector(love.mouse.getX(), love.mouse.getY())

  if isPressingUp then playerAcc.y = -0.1
  elseif isPressingDown then playerAcc.y = 0.1
  else playerAcc.y = 0
  end

  if isPressingLeft then playerAcc.x = -0.1
  elseif isPressingRight then playerAcc.x = 0.1
  else playerAcc.x = 0
  end

  if isPressingAimLeft then gunAcc = 0.001
  elseif isPressingAimRight then gunAcc = -0.001
  else gunAcc = 0
  end

  playerVel = playerVel + playerAcc
  playerPos = playerPos + playerVel

  playerAcc = playerAcc / 1.1
  playerVel = playerVel / 1.01

  gunVel = gunVel + gunAcc
  gunAngle = gunAngle + gunVel

  gunAcc = gunAcc / 1.1
  gunVel = gunVel / 1.01

  if aimWithMouse then
    gunDir = (mousePos - playerPos):normalized()
    gunAngle = math.atan2(gunDir.y, gunDir.x)
  else
    gunDir = vector(math.cos(gunAngle), math.sin(gunAngle))
  end

  gunPos = playerPos + gunDir*19

  local last_point = nil
  for i, point in ipairs(world) do
    -- collisions with points
    local normalToPlayer = (playerPos - point):normalized()
    if normalToPlayer * playerVel < 0 and playerPos:dist(point) <= 20 then
      playerPos = playerPos - playerVel
      playerVel = laser.reflect(playerPos, playerPos + playerVel, normalToPlayer) * playerVel:len() / 1.1
      playerAcc = vector(0, 0)
      break
    end

    -- collisions with walls
    if last_point then
      local wallNormal = laser.normalOfLine(point, last_point)
      local dirToPlayer = playerPos - point
      if wallNormal * dirToPlayer < 0 then
        wallNormal = -wallNormal
      end
      if wallNormal * playerVel < 0 then
        local hitIdx, hitPoint, hitNormal = laser.raycast({ last_point, point }, playerPos, -wallNormal)
        if hitPoint and playerPos:dist(hitPoint) <= 20 then
          playerPos = playerPos - playerVel
          playerVel = laser.reflect(playerPos, playerPos + playerVel, hitNormal) * playerVel:len() / 1.5
          playerAcc = vector(0, 0)
          break
        end
      end
    end
    last_point = point
  end

  laserSegments = {}
  if firingLaser then
    table.insert(laserSegments, gunPos + gunDir*6)

    local laserStart = playerPos + gunDir
    local laserDir = gunDir

    while #laserSegments < 100 do
      local hitIdx, hitPoint, hitNormal = laser.raycast(world, laserStart, laserDir)

      if not hitPoint then break end

      laserDir = laser.reflect(laserStart, hitPoint, hitNormal)
      laserStart = hitPoint

      table.insert(laserSegments, laserStart)
    end

    table.insert(laserSegments, laserStart + laserDir*love.graphics.getWidth()*3)
  end
end

function love.draw()
  love.graphics.setColor(0, 0, 0)
  love.graphics.rectangle('fill', 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  love.graphics.setLineWidth(3)
  local last_point = nil
  for i, point in ipairs(world) do
    love.graphics.setColor(.9, .7, .5)
    love.graphics.circle('fill', point.x, point.y, 3)
    if last_point then
      love.graphics.setColor(.7, .5, .3)
      love.graphics.line(last_point.x, last_point.y, point.x, point.y)
    end
    last_point = point
  end

  love.graphics.setColor(.4, .5, .9)
  love.graphics.circle('fill', playerPos.x, playerPos.y, 20)

  love.graphics.setColor(.37, .37, .37)
  love.graphics.circle('fill', gunPos.x, gunPos.y, 7)

  love.graphics.setColor(1, 1, 1)
  love.graphics.setLineWidth(1)
  love.graphics.line(mousePos.x, mousePos.y - 5, mousePos.x, mousePos.y + 5)
  love.graphics.line(mousePos.x - 5, mousePos.y, mousePos.x + 5, mousePos.y)

  local last_point = nil
  for i, point in ipairs(laserSegments) do
    if last_point then
      local f = math.max(0, (41 - i) / 40)
      love.graphics.setColor(1*f, 0, 0)
      love.graphics.setLineWidth(3)
      love.graphics.line(last_point.x, last_point.y, point.x, point.y)

      love.graphics.setColor(1*f, .5*f, 0)
      love.graphics.setLineWidth(2)
      love.graphics.line(last_point.x, last_point.y, point.x, point.y)

      love.graphics.setColor(1*f, 0, 0)
      love.graphics.setLineWidth(1)
      love.graphics.line(last_point.x, last_point.y, point.x, point.y)
    end
    last_point = point
  end
end

function love.mousepressed(x, y, button)
  table.insert(world, vector(x, y))
end

function love.mousemoved()
  aimWithMouse = true
  gunAcc = 0
  gunVel = 0
end

function love.keypressed(key, scancode)
  if key == "escape" or key == "q" then
    love.event.quit()
  elseif key == "w" then
    isPressingUp = true
  elseif key == "a" then
    isPressingLeft = true
  elseif key == "s" then
    isPressingDown = true
  elseif key == "d" then
    isPressingRight = true
  elseif key == "left" then
    isPressingAimLeft = true
    aimWithMouse = false
  elseif key == "right" then
    isPressingAimRight = true
    aimWithMouse = false
  elseif key == "space" then
    firingLaser = true
  elseif key == "r" then
    world = {}
  elseif key == "u" then
    table.remove(world)
  end
end

function love.keyreleased(key, scancode)
  if key == "w" then
    isPressingUp = false
  elseif key == "a" then
    isPressingLeft = false
  elseif key == "s" then
    isPressingDown = false
  elseif key == "d" then
    isPressingRight = false
  elseif key == "left" then
    isPressingAimLeft = false
  elseif key == "right" then
    isPressingAimRight = false
  elseif key == "space" then
    firingLaser = false
  end
end
