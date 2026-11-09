-- Protótipo para Delta. Pegue o ovo manualmente e ative durante a luta.
local player = assert(game:GetService("Players").LocalPlayer, "Execute no cliente.")
local guiParent = assert(player:WaitForChild("PlayerGui", 8), "PlayerGui indisponível.")
for _, name in ipairs({ "EsquivaFaixas", "EsquivaOvo" }) do
    local old = guiParent:FindFirstChild(name)
    if old then old:Destroy() end
end

local function make(class, parent, props)
    local object = Instance.new(class)
    for name, value in pairs(props) do object[name] = value end
    object.Parent = parent
    return object
end

local gui = make("ScreenGui", guiParent, {
    Name = "EsquivaFaixas", ResetOnSpawn = false, DisplayOrder = 45,
})
local function round(object, radius)
    make("UICorner", object, { CornerRadius = UDim.new(0, radius) })
end
local panel = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.new(0.49, 0, 0, 220),
    BackgroundColor3 = Color3.fromRGB(30, 10, 13), BorderSizePixel = 0,
})
make("UISizeConstraint", panel, { MaxSize = Vector2.new(345, 220) })
make("UICorner", panel, { CornerRadius = UDim.new(0, 10) })

local function control(class, text, y, height)
    return make(class, panel, {
        Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, height),
        Text = text, TextSize = 14, TextWrapped = true, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 235, 233),
        BackgroundTransparency = class == "TextLabel" and 1 or 0,
        BackgroundColor3 = Color3.fromRGB(157, 31, 40), BorderSizePixel = 0,
    })
end
local title = control("TextLabel", "ESQUIVA DO BOSS · V59", 5, 30)
title.Size = UDim2.new(1, -49, 0, 30)
title.TextXAlignment = Enum.TextXAlignment.Left
local minimize = control("TextButton", "−", 6, 28)
minimize.Position, minimize.Size = UDim2.new(1, -36, 0, 6), UDim2.fromOffset(29, 28)
round(minimize, 6)
local status = control("TextLabel", "Desligada", 38, 49)
local toggle = control("TextButton", "Ligar esquiva", 92, 29)
local eggsToggle = control("TextButton", "Lista de ovos", 124, 21)
round(toggle, 7)
round(eggsToggle, 6)
local LINGER = 0.35
local LOOKAHEAD = { 0.06, 0.12, 0.18, 0.24, 0.30, 0.36, 0.44, 0.52 }
local TRIGGER_MARGIN, EXIT_MARGIN = 1.3, 8
local MAX_RUN_DISTANCE, JUMP_INTERVAL = 24, 0.12
local directions = {}
for index = 0, 23 do
    local angle = index * math.pi / 12
    directions[index + 1] = Vector3.new(math.cos(angle), 0, math.sin(angle))
end

local active
local enabled = false
local speedTarget = 80
local speedLabel = control("TextLabel", "", 128, 27)

local function updateSpeedLabel(session)
    local actual = session and string.format(" · atual %.1f", session.humanoid.WalkSpeed) or ""
    if session and session.slowed then
        speedLabel.Text = session.slowArea .. " · lentidão do boss" .. actual
        return
    elseif session and session.speedBoost then
        speedLabel.Text = string.format("%s · alvo %.0f%s", session.speedBoost, session.appliedSpeed or session.humanoid.WalkSpeed, actual)
        return
    end
    local target = speedTarget == 0 and "Padrão do jogo" or string.format("%d studs/s", speedTarget)
    speedLabel.Text = target .. actual
end

local function restoreSpeed(session)
    local humanoid = session.humanoid
    if session.appliedSpeed and humanoid.Parent and humanoid.WalkSpeed == session.appliedSpeed then
        humanoid.WalkSpeed = session.originalSpeed
    end
    session.appliedSpeed = nil
end

local function applySpeed(session)
    local humanoid = session.humanoid
    if session.slowArea and humanoid.WalkSpeed <= 5 then
        if not session.slowed then
            session.slowed = true
            print("[Esquiva V59] " .. session.slowArea .. " · lentidão detectada")
        end
        return
    end
    local recovered = session.slowed
    session.slowed = false
    if speedTarget == 0 and not session.speedBoost then
        restoreSpeed(session)
    elseif humanoid.Parent then
        if humanoid.WalkSpeed ~= session.appliedSpeed then
            session.originalSpeed = humanoid.WalkSpeed
        end
        local desired = speedTarget == 0 and session.originalSpeed or speedTarget
        if speedTarget == 0 and session.speedBoost then desired = math.min(80, desired * 2) end
        humanoid.WalkSpeed = desired
        session.appliedSpeed = desired
        if recovered then
            print(string.format("[Esquiva V59] %s · velocidade retomada %.1f -> %.1f", session.slowArea, session.originalSpeed, desired))
        end
    end
    if session.walking then
        local remaining = session.runGoal - session.root.Position
        local distance = Vector3.new(remaining.X, 0, remaining.Z).Magnitude
        session.runUntil = os.clock() + math.clamp(distance / math.max(1, humanoid.WalkSpeed) + 0.55, 0.7, 3.5)
    end
end
local function finish(session, message)
    if active ~= session then return end
    active = nil
    session.hpConnection:Disconnect()
    restoreSpeed(session)
    updateSpeedLabel(nil)
    if (session.walking or session.passage or session.reefTarget or session.reefHolding) and session.humanoid.Parent and session.root.Parent then
        session.humanoid:MoveTo(session.root.Position)
    end
    toggle.Text = enabled and "Desligar esquiva" or "Ligar esquiva"
    status.Text = string.format("%s · %d esquivas\n%d quedas · %.2f HP perdido",
        message, session.moves, session.hits, session.damage)
    print(string.format("[Esquiva V59] %s | última rota a pé %.1f studs",
        status.Text, session.lastDistance))
end

local function desertShape(part)
    local size = part.Size
    if size.X <= 1 and math.abs(size.Y - 28) <= 1 and math.abs(size.Z - 28) <= 1
        and math.abs(part.CFrame.RightVector.Y) >= 0.98 then
        return "circle"
    end
    if size.Y <= 1 and math.abs(size.X - 25) <= 1 and math.abs(size.Z - 22) <= 1
        and math.abs(part.CFrame.UpVector.Y) >= 0.98 then
        return "rectangle"
    end
end

local function isWarning(part, position)
    local color, size = part.Color, part.Size
    local thin = math.min(size.X, size.Y, size.Z)
    local span = math.max(size.X, size.Y, size.Z)
    return color.R >= 0.55 and color.R > color.G * 1.45 and color.R > color.B * 1.45
        and part.Transparency < 0.98 and thin <= 2 and span >= 5
        and math.abs(part.Position.Y - position.Y) <= 14
        and Vector3.new(part.Position.X-position.X, 0, part.Position.Z-position.Z).Magnitude <= 150 + span / 2
end

local function updateWarning(previous, part, now)
    local frame, size = part.CFrame, part.Size
    local warning = {
        frame = frame, size = size, seen = now,
        static = part.Transparency >= 0.60 or math.max(size.X, size.Y, size.Z) >= 18,
        movingUntil = previous and previous.movingUntil or 0,
        velocity = Vector3.zero, growth = Vector3.zero,
    }
    if previous then
        local elapsed = now - previous.seen
        if elapsed > 0 and elapsed < 0.25 then
            local shift = frame.Position - previous.frame.Position
            local sizeChange = size - previous.size
            warning.velocity = Vector3.new(shift.X, 0, shift.Z) / elapsed
            if warning.velocity.Magnitude > 180 then warning.velocity = warning.velocity.Unit * 180 end
            warning.growth = Vector3.new(
                math.clamp(sizeChange.X / elapsed, 0, 160),
                math.clamp(sizeChange.Y / elapsed, 0, 160),
                math.clamp(sizeChange.Z / elapsed, 0, 160)
            )
            if warning.velocity.Magnitude > 2 or warning.growth.Magnitude > 3 then
                warning.movingUntil = now + 0.25
            end
        end
    end
    return warning
end

local function projectWarnings(tracked, now)
    local areas, waves = {}, 0
    for part, warning in pairs(tracked) do
        if now - warning.seen > LINGER then
            tracked[part] = nil
        elseif warning.static or warning.movingUntil >= now then
            table.insert(areas, warning)
            if warning.movingUntil >= now then
                waves = waves + 1
                if warning.seen == now then
                    local previousTime = 0
                    for _, seconds in ipairs(LOOKAHEAD) do
                        local shift = warning.frame:VectorToObjectSpace(warning.velocity * (seconds - previousTime))
                        local sweep = Vector3.new(math.abs(shift.X), math.abs(shift.Y), math.abs(shift.Z))
                        table.insert(areas, {
                            frame = warning.frame + warning.velocity * ((seconds + previousTime) / 2),
                            size = warning.size + warning.growth * seconds + sweep,
                            projected = true,
                            swampWall = warning.swampWall,
                            portal = warning.swampWall,
                        })
                        previousTime = seconds
                    end
                end
            end
        end
    end
    return areas, waves
end

local function inside(position, warning, margin)
    local center = warning.frame.Position
    local localPoint = warning.frame:PointToObjectSpace(Vector3.new(position.X, center.Y, position.Z))
    local size = warning.size
    if warning.shape == "circle" then
        local radius = math.max(size.Y, size.Z) / 2 + margin
        return localPoint.Y^2 + localPoint.Z^2 <= radius^2
    end
    return math.abs(localPoint.X) <= size.X / 2 + margin
        and math.abs(localPoint.Y) <= size.Y / 2 + margin
        and math.abs(localPoint.Z) <= size.Z / 2 + margin
end

local function threatened(position, warnings, margin, currentOnly)
    for _, warning in pairs(warnings) do
        if (not currentOnly or not warning.projected) and inside(position, warning, margin) then return true end
    end
    return false
end

local function horizontalDistance(a, b)
    local delta = a - b
    return Vector3.new(delta.X, 0, delta.Z).Magnitude
end

-- As paredes de CarryWalls podem ter CanQuery=false. Use a geometria delas.
local function cageBounds(origin)
    local cage = workspace:FindFirstChild("CarryWalls")
    if not cage then return end
    local xWalls, zWalls = {}, {}
    for _, part in ipairs(cage:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name == "Field" or part.Name == "Force")
            and part.Size.Y >= 12 and part.Size.Z <= 1 and part.Size.X >= 8
            and math.abs(origin.Y - part.Position.Y) <= part.Size.Y / 2 + 2 then
            local x, z = part.Position.X, part.Position.Z
            local right = part.CFrame.RightVector
            if math.abs(right.Z) >= 0.99 then
                table.insert(xWalls, { at = x, low = z - part.Size.X / 2, high = z + part.Size.X / 2 })
            elseif math.abs(right.X) >= 0.99 then
                table.insert(zWalls, { at = z, low = x - part.Size.X / 2, high = x + part.Size.X / 2 })
            end
        end
    end

    local function bracket(walls, coordinate, across)
        local low, high
        for _, wall in ipairs(walls) do
            if across >= wall.low - 0.1 and across <= wall.high + 0.1 then
                if wall.at < coordinate and (not low or wall.at > low) then low = wall.at end
                if wall.at > coordinate and (not high or wall.at < high) then high = wall.at end
            end
        end
        return low, high
    end
    local function covers(walls, at, low, high)
        local spans = {}
        for _, wall in ipairs(walls) do
            if math.abs(wall.at - at) <= 0.15 then table.insert(spans, wall) end
        end
        table.sort(spans, function(a, b) return a.low < b.low end)
        local covered = low
        for _, span in ipairs(spans) do
            if span.low > covered + 0.2 then break end
            covered = math.max(covered, span.high)
            if covered >= high - 0.2 then return true end
        end
        return false
    end
    local minX, maxX = bracket(xWalls, origin.X, origin.Z)
    local minZ, maxZ = bracket(zWalls, origin.Z, origin.X)
    if minX and maxX and minZ and maxZ
        and covers(xWalls, minX, minZ, maxZ) and covers(xWalls, maxX, minZ, maxZ)
        and covers(zWalls, minZ, minX, maxX) and covers(zWalls, maxZ, minX, maxX) then
        return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ }
    end
end

local function inCage(point, bounds, margin)
    return bounds and point.X >= bounds.minX + margin and point.X <= bounds.maxX - margin
        and point.Z >= bounds.minZ + margin and point.Z <= bounds.maxZ - margin
end

local function crossesPortal(origin, target, warnings, margin)
    for _, warning in ipairs(warnings) do
        if warning.portal and not inside(origin, warning, margin) then
            local frame = warning.frame
            local y = frame.Position.Y
            local start = frame:PointToObjectSpace(Vector3.new(origin.X, y, origin.Z))
            local finish = frame:PointToObjectSpace(Vector3.new(target.X, y, target.Z))
            local delta = finish - start
            local enter, leave = 0, 1
            for _, axis in ipairs({ "X", "Z" }) do
                local half = warning.size[axis] / 2 + margin
                if math.abs(delta[axis]) < 1e-6 then
                    if math.abs(start[axis]) > half then enter, leave = 1, 0 end
                else
                    local low = (-half - start[axis]) / delta[axis]
                    local high = (half - start[axis]) / delta[axis]
                    enter, leave = math.max(enter, math.min(low, high)), math.min(leave, math.max(low, high))
                end
            end
            if enter <= leave then return true end
        end
    end
    return false
end

local function outsideCircleTarget(root, circles, warnings, bounds, ray)
    local best, bestDistance
    for _, circle in ipairs(circles) do
        local center, radius = circle.center, circle.radius
        if horizontalDistance(root.Position, center) <= radius + 5 then
            for _, extra in ipairs({ 6, 10, 15, 20 }) do
                for _, direction in ipairs(directions) do
                    local candidate = Vector3.new(center.X, root.Position.Y, center.Z) + direction * (radius + extra)
                    local outside = inCage(candidate, bounds, 5)
                    for _, other in ipairs(circles) do
                        if horizontalDistance(candidate, other.center) <= other.radius + 5 then outside = false; break end
                    end
                    local distance = horizontalDistance(root.Position, candidate)
                    if outside and (not bestDistance or distance < bestDistance)
                        and not threatened(candidate, warnings, 2) then
                        local ground = workspace:Raycast(candidate + Vector3.new(0, 8, 0), Vector3.new(0, -25, 0), ray)
                        if ground and ground.Normal.Y >= .65 then
                            local point = ground.Position + Vector3.new(0, 3, 0)
                            local overhead = workspace:Raycast(ground.Position + Vector3.new(0, .2, 0),
                                Vector3.new(0, 5, 0), ray)
                            if not overhead then best, bestDistance = point, distance end
                        end
                    end
                end
            end
        end
    end
    return best
end

local function safeStep(root, warnings, ray, bossPosition, bounds, margin, preferFar, heading, gravityCenter, cosmic, maxDistance)
    local origin = root.Position
    local currentFloor = workspace:Raycast(origin, Vector3.new(0, -18, 0), ray)
    if not currentFloor or currentFloor.Normal.Y < 0.65 then return end
    local clearance = origin.Y - currentFloor.Position.Y
    local bossDistance = bossPosition and horizontalDistance(origin, bossPosition)
    local minimumBossDistance = bossDistance and (preferFar and bossDistance + 4 or math.max(0, bossDistance - 2))
    maxDistance = maxDistance or MAX_RUN_DISTANCE
    local first, last, increment = 2, maxDistance, 1
    if preferFar then first, last, increment = maxDistance, 5, -1 end
    local outward
    if gravityCenter then
        local offset = origin - gravityCenter
        outward = Vector3.new(offset.X, 0, offset.Z)
        if outward.Magnitude > .1 then outward = outward.Unit else outward = nil end
        last = 36
    end
    for distance = first, last, increment do
        local best, bestDistance
        for _, direction in ipairs(directions) do
            local candidate = origin + direction * distance
            local distanceFromBoss = bossPosition and horizontalDistance(candidate, bossPosition)
            if inCage(candidate, bounds, 4)
                and (not minimumBossDistance or distanceFromBoss >= minimumBossDistance)
                and (not outward or direction:Dot(outward) >= 0)
                and not threatened(candidate, warnings, margin)
                and (not cosmic or not crossesPortal(origin, candidate, warnings, margin))
                and (not heading or not threatened(origin:Lerp(candidate, .5), warnings, margin)) then
                local floor = workspace:Raycast(candidate + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), ray)
                if floor and floor.Normal.Y >= 0.65
                    and math.abs(floor.Position.Y - currentFloor.Position.Y) <= 2 then
                    local destination = floor.Position + Vector3.new(0, clearance, 0)
                    local travel = destination - origin
                    if not workspace:Raycast(origin, travel, ray)
                        and not workspace:Raycast(origin + Vector3.new(0, 1.5, 0), travel, ray) then
                        if not distanceFromBoss and not heading and not outward then return travel end
                        local score = (distanceFromBoss or 0) + (heading and 12 * direction:Dot(heading) or 0)
                            + (outward and 24 * direction:Dot(outward) or 0)
                        if not bestDistance or score > bestDistance then
                            best, bestDistance = travel, score
                        end
                    end
                end
            end
        end
        if best then return best end
    end
end

local EDGE_INSET = 12
local EDGE_APPROACH = 24
local EDGE_BOSS_RANGE = 65

local function perimeterStep(root, warnings, ray, bossPosition, bounds, heading)
    local origin = root.Position
    local x0, x1 = bounds.minX + EDGE_INSET, bounds.maxX - EDGE_INSET
    local z0, z1 = bounds.minZ + EDGE_INSET, bounds.maxZ - EDGE_INSET
    if x1 <= x0 or z1 <= z0 then return end

    local floor = workspace:Raycast(origin, Vector3.new(0, -18, 0), ray)
    if not floor or floor.Normal.Y < .65 then return end

    local best, bestScore
    local function consider(x, z)
        local target = Vector3.new(x, origin.Y, z)
        local travel = target - origin
        if travel.Magnitude < 10 or crossesPortal(origin, target, warnings, TRIGGER_MARGIN) then return end
        for _, fraction in ipairs({ .25, .5, .75, 1 }) do
            if threatened(origin:Lerp(target, fraction), warnings, TRIGGER_MARGIN) then return end
        end
        local landing = workspace:Raycast(target + Vector3.new(0, 2, 0), Vector3.new(0, -20, 0), ray)
        if not landing or landing.Normal.Y < .65 or math.abs(landing.Position.Y - floor.Position.Y) > 2 then return end
        travel = landing.Position + Vector3.new(0, origin.Y - floor.Position.Y, 0) - origin
        if workspace:Raycast(origin, travel, ray)
            or workspace:Raycast(origin + Vector3.new(0, 1.5, 0), travel, ray) then return end

        local cornerTarget = math.min(x - x0, x1 - x) <= 6 and math.min(z - z0, z1 - z) <= 6
        local score = (bossPosition and horizontalDistance(target, bossPosition) or 0)
            + (heading and 8 * travel.Unit:Dot(heading) or 0) - (cornerTarget and 24 or 0)
        if not bestScore or score > bestScore then
            best, bestScore = travel, score
        end
    end

    local function alongX(x)
        if math.abs(origin.X - x) > EDGE_APPROACH then return end
        consider(x, math.clamp(origin.Z - 32, z0, z1))
        consider(x, math.clamp(origin.Z + 32, z0, z1))
    end
    local function alongZ(z)
        if math.abs(origin.Z - z) > EDGE_APPROACH then return end
        consider(math.clamp(origin.X - 32, x0, x1), z)
        consider(math.clamp(origin.X + 32, x0, x1), z)
    end
    alongX(x0)
    alongX(x1)
    alongZ(z0)
    alongZ(z1)
    return best
end

local function swampPassage(part)
    local c, size = part.Color, part.Size
    return part.Transparency < .98 and math.abs(c.R * 255 - 70) <= 8
        and c.G * 255 >= 245 and math.abs(c.B * 255 - 120) <= 8
        and math.abs(size.Y - .2) <= .15
        and math.abs(math.max(size.X, size.Z) - 15) <= 1
        and math.abs(math.min(size.X, size.Z) - 9) <= 1
        and math.abs(part.CFrame.UpVector.Y) >= .98
end

local function passageGoal(root, passages, walls, warnings, bounds, ray, session)
    if #passages == 0 then return end
    local origin = root.Position
    local floor = workspace:Raycast(origin, Vector3.new(0, -18, 0), ray)
    if not floor or floor.Normal.Y < .65 then return end

    -- The green marker refines the predicted wall area. Keep live warning checks.
    local liveRoute = {}
    for _, warning in ipairs(warnings) do
        if not (warning.projected and warning.swampWall) then
            liveRoute[#liveRoute + 1] = warning
        end
    end
    local bestPart, bestTarget, bestDirection, bestWall, bestCost
    for _, part in ipairs(passages) do
        local center = part.Position
        local distance = horizontalDistance(origin, center)
        local cost = distance - (part == session.passage and 8 or 0)
        if not session.crossedPassages[part] and distance <= 65 and (not bestCost or cost < bestCost)
            and inCage(center, bounds, 4) and math.abs(center.Y - floor.Position.Y) <= 2 then
            local target = Vector3.new(center.X, origin.Y, center.Z)
            local direction = part == session.passage and session.passageDirection or nil
            local crossingWall = part == session.passage and session.passageWall or nil
            if not direction then
                local closest
                for _, wall in ipairs(walls) do
                    local axis = wall.CFrame.RightVector
                    local normal = Vector3.new(axis.X, 0, axis.Z)
                    local offset = target - wall.Position
                    local planeDistance = math.abs(offset:Dot(normal))
                    local along = math.abs(offset:Dot(wall.CFrame.LookVector))
                    local rootOffset = origin - target
                    if normal.Magnitude >= .98 and planeDistance <= 2 and along <= 26
                        and math.abs(rootOffset:Dot(wall.CFrame.LookVector)) <= 2.5
                        and (not closest or along < closest) then
                        closest = along
                        crossingWall = wall
                        direction = rootOffset:Dot(normal) >= 0 and -normal.Unit or normal.Unit
                    end
                end
            end

            -- Continue through the marker and finish beyond its far edge.
            if direction then
                local localDirection = part.CFrame:VectorToObjectSpace(direction)
                local exitDistance = math.min(
                    part.Size.X / (2 * math.max(math.abs(localDirection.X), .0001)),
                    part.Size.Z / (2 * math.max(math.abs(localDirection.Z), .0001)))
                target = target + direction * (exitDistance + 5)
            end
            local travel = target - origin
            if inCage(target, bounds, 4)
                and not threatened(target, liveRoute, TRIGGER_MARGIN)
                and not threatened(origin:Lerp(target, .5), liveRoute, TRIGGER_MARGIN)
                and not crossesPortal(origin, target, liveRoute, TRIGGER_MARGIN)
                and (travel.Magnitude <= 1 or not workspace:Raycast(origin, travel, ray)) then
                local landing = workspace:Raycast(target + Vector3.new(0, 4, 0), Vector3.new(0, -22, 0), ray)
                if landing and landing.Normal.Y >= .65 and math.abs(landing.Position.Y - floor.Position.Y) <= 2 then
                    bestPart, bestTarget, bestDirection, bestWall, bestCost = part, target, direction, crossingWall, cost
                end
            end
        end
    end
    return bestPart, bestTarget, bestDirection, bestWall
end

local function cosmicShape(part)
    local size = part.Size
    if size.X <= 1 and math.abs(size.Y - 44) <= 1 and math.abs(size.Z - 44) <= 1
        and math.abs(part.CFrame.RightVector.Y) >= .98 then
        return "circle"
    end
    if size.Y <= 1 and math.abs(size.X - 31) <= 1 and math.abs(size.Z - 25) <= 1
        and math.abs(part.CFrame.UpVector.Y) >= .98 then
        return "rectangle"
    end
end

local function reefPlatform(part)
    local size = part.Size
    local axis = part.CFrame.RightVector
    if not part.CanCollide or part.Transparency >= .98 or math.abs(axis.Y) < .9
        or math.abs(size.X - 3.2) > .6 or math.abs(size.Y - 9.5) > 1
        or math.abs(size.Z - 9.5) > 1 then return end
    return part.Position.Y + size.X * math.abs(axis.Y) / 2
end

local function reefRefuge(root, humanoid, platforms, bounds, ray, session, now)
    local origin = root.Position
    local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
    local support = grounded and workspace:Raycast(origin, Vector3.new(0, -5.5, 0), ray)
    if support and support.Normal.Y >= .65 and support.Material == Enum.Material.Rock
        and support.Position.Y >= 5.5 then
        if not session.reefHolding then humanoid:MoveTo(origin) end
        session.reefHolding = true
        session.reefTarget = nil
        return "Recife · aguardando no topo"
    end
    session.reefHolding = false

    local best, score
    for _, part in ipairs(platforms) do
        local distance = horizontalDistance(origin, part.Position)
        local cost = distance - (part == session.reefTarget and 4 or 0)
        if distance <= 65 and inCage(part.Position, bounds, 5) and (not score or cost < score) then
            best, score = part, cost
        end
    end
    if not best then return end
    local top = reefPlatform(best)
    local target = Vector3.new(best.Position.X, top, best.Position.Z)
    local distance = horizontalDistance(origin, target)
    local groundY = support and support.Position.Y or 0
    local velocity = humanoid.UseJumpPower and humanoid.JumpPower
        or math.sqrt(2 * workspace.Gravity * humanoid.JumpHeight)
    local rise = math.max(0, top - groundY)
    local discriminant = velocity^2 - 2 * workspace.Gravity * rise
    local jumpDistance = discriminant > 0
        and humanoid.WalkSpeed * (velocity + math.sqrt(discriminant)) / workspace.Gravity or 0
    local changed = session.reefTarget ~= best
    session.reefTarget = best
    if changed or now >= (session.reefRefresh or 0) then
        humanoid:MoveTo(target)
        session.reefRefresh = now + .35
    end
    if grounded and rise >= 1 and rise <= 8 and jumpDistance > 0
        and distance <= math.clamp(jumpDistance + 2, 3, 11)
        and now >= (session.reefJumpAt or 0) then
        humanoid.Jump = true
        session.reefJumpAt = now + .45
    end
    return "Recife · subindo para a plataforma"
end

local mappedBounds = {
    [2] = { minX = -120, maxX = 120, minZ = -800, maxZ = -400 },
    [3] = { minX = -120, maxX = 120, minZ = -1200, maxZ = -800 },
    [5] = { minX = -120, maxX = 120, minZ = -2000, maxZ = -1600 },
    [10] = { minX = -120, maxX = 120, minZ = -2800, maxZ = -2400 },
    [11] = { minX = -120, maxX = 120, minZ = -3200, maxZ = -2800 },
}

local function hasEgg(value)
    return value == true or (tonumber(value) or 0) > 0
end

local function startFight()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local hp = player:GetAttribute("BossHP")
    local carrying = player:GetAttribute("Carrying")
    if not hasEgg(carrying) or not root or not humanoid or humanoid.Health <= 0 or type(hp) ~= "number" or hp < 0 then
        status.Text = "Ligada · aguardando ovo na mão"
        return
    end

    local zoneNumber = tonumber(carrying)
    local desert, ice = zoneNumber == 2, zoneNumber == 3
    local cosmic = zoneNumber == 5
    local swamp, reef = zoneNumber == 10, zoneNumber == 11
    local fallbackBounds = mappedBounds[zoneNumber]
    local session = { slowArea = swamp and "Pântano" or (reef and "Recife"), crossedPassages = setmetatable({}, { __mode = "k" }), speedBoost = cosmic and "Área 5" or (swamp and "Pântano"), moves = 0, hits = 0, damage = 0, interrupted = false, warnings = {}, lastDistance = 0, humanoid = humanoid, root = root }
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.RespectCanCollide = true
    active = session
    toggle.Text = "Desligar esquiva"
    session.hpConnection = player:GetAttributeChangedSignal("BossHP"):Connect(function()
        local value = player:GetAttribute("BossHP")
        if type(value) ~= "number" or value < 0 then
            session.interrupted = true
        elseif value < hp then
            session.hits = session.hits + 1
            session.damage = session.damage + hp - value
            print(string.format("[Esquiva] BossHP %.2f -> %.2f", hp, value))
        end
        if type(value) == "number" and value >= 0 then hp = value end
    end)

    task.spawn(function()
        local lastScan, lastJump = -math.huge, -math.huge
        local bounds, checkedAt = nil, -math.huge
        local ok, err = pcall(function()
            if active ~= session then return end
            applySpeed(session)
            while gui.Parent and active == session do
                updateSpeedLabel(session)
                local now = os.clock()
                local carryingNow = player:GetAttribute("Carrying")
                if not hasEgg(carryingNow) or session.interrupted or player.Character ~= character or not root.Parent or humanoid.Health <= 0 then
                    finish(session, "Luta encerrada")
                    return
                end
                if session.slowArea and (session.slowed or (session.appliedSpeed and humanoid.WalkSpeed ~= session.appliedSpeed)) then
                    applySpeed(session)
                end
                if now - checkedAt >= 0.25 then
                    bounds, checkedAt = cageBounds(root.Position), now
                    if not bounds and fallbackBounds and inCage(root.Position, fallbackBounds, 0.1) then
                        bounds = fallbackBounds
                    end
                end
                local insideArena = inCage(root.Position, bounds, 0.1)
                if not insideArena and session.walking then
                    humanoid:MoveTo(root.Position)
                    session.walking = false
                end
                local folder = workspace:FindFirstChild("BossFX")
                if now - (session.effectsAt or -math.huge) >= 0.06 then
                    session.effectsAt = now
                    session.fxParts = {}
                    session.bosses = {}
                    local known = {
                        ["Touro Gigante"] = true, ["Escaravelho Rei"] = true, ["Yeti Ancião"] = true,
                        ["Golem de Magma"] = true, ["Titã Cósmico"] = true,
                    }
                    local function scan(container)
                        for _, object in ipairs(container:GetDescendants()) do
                            if object:IsA("BasePart") then
                                table.insert(session.fxParts, object)
                            elseif object:IsA("Model") and (known[object.Name] or object:GetAttribute("BossId") ~= nil
                                or object:GetAttribute("IsBoss") == true or object:FindFirstChildOfClass("Humanoid")
                                or object.Name:lower():find("boss", 1, true)) then
                                table.insert(session.bosses, object)
                            end
                        end
                    end
                    if folder then scan(folder) end
                    for _, child in ipairs(workspace:GetChildren()) do
                        local name = child.Name:lower()
                        if child ~= folder and (name == "effects" or name == "vfx" or name == "bosses"
                            or name:find("bossfx", 1, true)) then
                            scan(child)
                        elseif child:IsA("BasePart") then
                            table.insert(session.fxParts, child)
                        elseif child:IsA("Model") and (known[child.Name] or child:GetAttribute("IsBoss") == true) then
                            table.insert(session.bosses, child)
                        end
                    end
                end
                local circles, passages, swampWalls, reefPlatforms = {}, {}, {}, {}
                for _, part in ipairs(session.fxParts) do
                    if part.Parent then
                        local bossFX = folder and part:IsDescendantOf(folder)
                        local size = part.Size
                        local color = part.Color
                        if reef then
                            local top = reefPlatform(part)
                            if top and top >= .4 and top <= 8.5 then
                                reefPlatforms[#reefPlatforms + 1] = part
                            end
                        end
                        if swamp and swampPassage(part) then
                            passages[#passages + 1] = part
                        end
                        if swamp and part.Transparency < .98 and math.abs(size.X - .5) <= .25
                            and math.abs(size.Y - 2.1) <= .4 and math.abs(size.Z - 29.6) <= 1
                            and math.abs(part.CFrame.UpVector.Y) >= .98
                            and horizontalDistance(part.Position, root.Position) <= 100 then
                            swampWalls[#swampWalls + 1] = part
                        end
                        local smallGround = bossFX and part.Transparency < .98
                            and color.R > .45 and color.R > color.G * 1.35 and color.R > color.B * 1.35
                            and math.abs(part.Position.Y-root.Position.Y) <= 16
                            and horizontalDistance(part.Position, root.Position) <= 150
                            and (part:IsA("WedgePart") or (size.Y <= .6 and size.X >= 2.8 and size.Z >= 2.8))
                        local desertFX = desert and bossFX
                        local shape = desertFX and part.Transparency >= 0.60
                            and part.Transparency < 0.98 and desertShape(part)
                        local cosmicWarning = cosmic and bossFX and part.Transparency >= .60
                            and part.Transparency < .98 and cosmicShape(part)
                        local pink = cosmic and bossFX and part.Transparency < .98
                            and color.R > .45 and color.B > .35 and color.G < math.min(color.R, color.B) * .8
                        local span = math.max(size.X, size.Y, size.Z)
                        local disk = cosmic and (bossFX or part.Transparency >= .2) and part.Transparency < .995
                            and math.abs(part.Position.Y-root.Position.Y) <= 16
                            and not pink and color.R >= .4 and color.R > color.G * 1.2 and color.R > color.B * 1.2
                            and span >= 12
                            and ((size.X <= 2 and math.abs(size.Y-size.Z) <= span * .2
                                and math.abs(part.CFrame.RightVector.Y) >= .9)
                                or (size.Y <= 2 and math.abs(size.X-size.Z) <= span * .2
                                    and math.abs(part.CFrame.UpVector.Y) >= .9)
                                or (size.Z <= 2 and math.abs(size.X-size.Y) <= span * .2
                                    and math.abs(part.CFrame.LookVector.Y) >= .9))
                        if disk then table.insert(circles, { center = part.Position, radius = span / 2 }) end
                        local beam = bossFX and cosmic and math.abs(span - 70) <= 2
                            and size.Y <= .65 and math.min(size.X, size.Z) <= 1
                            and math.abs(part.Position.Y - root.Position.Y) <= 8
                        local swampWarning = ((swamp and bossFX) or reef) and part.Transparency < .98
                            and size.Y <= 1 and math.abs(size.X - 33) <= 1 and math.abs(size.Z - 26) <= 1
                            and math.abs(part.CFrame.UpVector.Y) >= .98
                            and math.abs(part.Position.Y - root.Position.Y) <= 16
                        local swampWall = swamp and bossFX and part.Transparency < .98
                            and size.Y <= 1 and math.abs(span - 30) <= 1.5
                            and math.min(size.X, size.Z) >= 2 and math.min(size.X, size.Z) <= 18
                            and math.abs(part.CFrame.UpVector.Y) >= .98
                            and math.abs(part.Position.Y - root.Position.Y) <= 16
                            and color.R > .45 and color.R > color.G * 1.35 and color.R > color.B * 1.35
                        local reefDisk = reef and part.Transparency < .98 and color.R > .8
                            and color.G < .3 and color.B < .3 and math.abs(size.X - .2) <= .15
                            and math.abs(size.Y - 2.5) <= .3 and math.abs(size.Z - 2.5) <= .3
                            and math.abs(part.CFrame.RightVector.Y) >= .9
                            and math.abs(part.Position.Y - root.Position.Y) <= 8
                        shape = shape or cosmicWarning or (swampWarning and "rectangle") or (reefDisk and "circle")
                        if not (pink and cosmicWarning == "circle") and (shape or beam or swampWall or smallGround or isWarning(part, root.Position)) then
                            local warning = updateWarning(session.warnings[part], part, now)
                            warning.shape = shape
                            warning.priority = cosmicWarning == "rectangle" or swampWarning
                            warning.gravity = cosmicWarning == "circle" and not pink
                            warning.portal = beam or swampWall
                            warning.swampWall = swampWall
                            if beam or swampWall then warning.static = true end
                            if smallGround then warning.static = true end
                            if shape then
                                warning.static = true
                                warning.movingUntil = 0
                            end
                            session.warnings[part] = warning
                        end
                    end
                end
                local bossPosition, nearestBoss = nil, math.huge
                for _, boss in ipairs(session.bosses) do
                    if boss.Parent then
                        local position = boss:GetPivot().Position
                        local distance = horizontalDistance(root.Position, position)
                        if math.abs(position.Y - root.Position.Y) <= 30 and distance < nearestBoss then
                            bossPosition, nearestBoss = position, distance
                        end
                    end
                end
                if desert then
                    local map = workspace:FindFirstChild("Map")
                    local zones = map and map:FindFirstChild("Zones")
                    local zone = zones and zones:FindFirstChild("Zone2")
                    local boss = zone and zone:FindFirstChild("Boss")
                    local glow = boss and boss:FindFirstChild("Glow")
                    if glow and glow:IsA("BasePart") and math.abs(glow.Position.Y-root.Position.Y)<=25 then
                        bossPosition = glow.Position
                        nearestBoss = horizontalDistance(root.Position, bossPosition)
                    end
                end
                if swamp or reef then
                    local map = workspace:FindFirstChild("Map")
                    local zones = map and map:FindFirstChild("Zones")
                    local zone = zones and zones:FindFirstChild("Zone" .. zoneNumber)
                    local boss = zone and zone:FindFirstChild("Boss")
                    local position = boss and ((boss:IsA("Model") and boss:GetPivot().Position)
                        or (boss:IsA("BasePart") and boss.Position))
                    if position and inCage(position, fallbackBounds, 0)
                        and math.abs(position.Y - root.Position.Y) <= 30 then
                        bossPosition = position
                    end
                end
                local areas, waves = projectWarnings(session.warnings, now)
                local circleEscaped, circleStatus
                local circleThreat = false
                for _, circle in ipairs(circles) do
                    if horizontalDistance(root.Position, circle.center) <= circle.radius + 5 then
                        circleThreat = true
                        break
                    end
                end
                if circleThreat and not insideArena then circleStatus = "Círculo detectado · aguardando perímetro" end
                if circleThreat and insideArena and now - (session.lastCircleTeleport or -math.huge) >= .45 then
                    ray.FilterDescendantsInstances = folder and { character, folder } or { character }
                    local target = outsideCircleTarget(root, circles, areas, bounds, ray)
                    if target then
                        local distance = horizontalDistance(root.Position, target)
                        humanoid:MoveTo(root.Position)
                        character:PivotTo(character:GetPivot() + (target-root.Position))
                        root.AssemblyLinearVelocity = Vector3.zero
                        session.walking, session.runGoal, session.patrolling = false, nil, false
                        session.lastCircleTeleport = now
                        session.moves = session.moves + 1
                        session.lastDistance = distance
                        session.urgent = nil
                        circleEscaped = true
                        session.circleCheck = { at = now + .18, from = root.Position, distance = distance }
                    else
                        circleStatus = "Círculo detectado · sem destino livre"
                    end
                end
                local danger = threatened(root.Position, areas, reef and 4 or TRIGGER_MARGIN)
                local message = not insideArena and "Aguardando perímetro fechado" or "Dentro da arena"
                local goal = session.runGoal
                local goalDistance = goal and horizontalDistance(root.Position, goal) or math.huge
                local urgent, gravityPart, gravityCenter
                if cosmic or swamp then
                    for part, warning in pairs(session.warnings) do
                        if warning.gravity and now - warning.seen <= LINGER
                            and inside(root.Position, warning, 5) then
                            gravityPart, gravityCenter = part, warning.frame.Position
                        end
                        if warning.priority and now - warning.seen <= LINGER
                            and inside(root.Position, warning, TRIGGER_MARGIN) then
                            urgent = part
                        end
                    end
                end
                urgent = gravityPart or urgent
                if gravityCenter then danger = true end
                if session.passage and session.passageDirection and session.passageTarget
                    and horizontalDistance(root.Position, session.passageTarget) <= 2 then
                    session.crossedPassages[session.passage] = true
                    local wall = session.passageWall
                    if wall and wall.Parent then
                        for _, marker in ipairs(passages) do
                            local relative = wall.CFrame:PointToObjectSpace(marker.Position)
                            if math.abs(relative.X) <= 2 and math.abs(relative.Z) <= 45 then
                                session.crossedPassages[marker] = true
                            end
                        end
                    end
                    session.crossedWalls = (session.crossedWalls or 0) + 1
                    print(string.format("[Esquiva V59] Travessia pelo vão concluída (%d)", session.crossedWalls))
                    session.passage, session.passageTarget, session.passageDirection, session.passageWall = nil, nil, nil, nil
                end
                local passage, passageTarget, passageDirection, passageWall
                if swamp and insideArena and not urgent and #passages > 0 then
                    ray.FilterDescendantsInstances = folder and { character, folder } or { character }
                    passage, passageTarget, passageDirection, passageWall = passageGoal(root, passages, swampWalls, areas, bounds, ray, session)
                end
                local refuge
                if reef and insideArena and #reefPlatforms > 0 then
                    ray.FilterDescendantsInstances = { character }
                    refuge = reefRefuge(root, humanoid, reefPlatforms, bounds, ray, session, now)
                end
                if refuge then
                    session.walking, session.runGoal = false, nil
                    message = refuge
                elseif passage then
                    local oldTarget = session.passageTarget
                    if session.passage ~= passage or not oldTarget or horizontalDistance(oldTarget, passageTarget) > 1
                        or now >= (session.passageRefresh or 0) then
                        humanoid:MoveTo(passageTarget)
                        session.passageTarget = passageTarget
                        session.passageRefresh = now + .5
                    end
                    session.passage, session.passageDirection, session.passageWall = passage, passageDirection, passageWall
                    session.walking, session.runGoal = false, nil
                    message = passageDirection and "Atravessando pelo vão verde"
                        or (horizontalDistance(root.Position, passageTarget) <= 2
                            and "Alinhado ao vão verde" or "Alinhando ao vão verde")
                else
                    if session.reefTarget or session.reefHolding then
                        session.reefTarget, session.reefHolding = nil, false
                        humanoid:MoveTo(root.Position)
                    end
                    if session.passage then
                        session.passage, session.passageTarget, session.passageDirection, session.passageWall = nil, nil, nil, nil
                        humanoid:MoveTo(root.Position)
                    end
                    local followEdge = false
                    if insideArena and not danger and not urgent then
                        local position = root.Position
                        local edgeX = math.min(position.X - bounds.minX, bounds.maxX - position.X)
                        local edgeZ = math.min(position.Z - bounds.minZ, bounds.maxZ - position.Z)
                        local nearCorner = edgeX <= EDGE_APPROACH and edgeZ <= EDGE_APPROACH
                        local bossNear = bossPosition and horizontalDistance(position, bossPosition) <= EDGE_BOSS_RANGE
                        followEdge = nearCorner or (bossNear and math.min(edgeX, edgeZ) <= EDGE_APPROACH)
                    end
                    local switchToDodge = (danger and session.patrolling) or (urgent and urgent ~= session.urgent)
                    session.urgent = urgent
                    if session.walking and (not insideArena or not goal or not inCage(goal, bounds, 4)
                        or threatened(goal, areas, TRIGGER_MARGIN) or now >= session.runUntil
                        or (session.followingEdge and (threatened(root.Position:Lerp(goal, .5), areas, TRIGGER_MARGIN)
                            or crossesPortal(root.Position, goal, areas, TRIGGER_MARGIN)))
                        or (followEdge and session.patrolling and not session.edgeChecked)
                        or switchToDodge or ((cosmic or swamp) and crossesPortal(root.Position, goal, areas, TRIGGER_MARGIN)) or goalDistance <= 5) then
                        if not insideArena then humanoid:MoveTo(root.Position) end
                        session.walking, session.runGoal = false, nil
                    end
                    if session.walking then message = session.patrolling and (session.followingEdge and "Correndo pela lateral" or "Patrulhando a arena")
                                or "Correndo para fora do ataque" end
    
                    if insideArena and not session.walking and now - lastScan >= 0.04 then
                        lastScan = now
                        ray.FilterDescendantsInstances = folder and { character, folder } or { character }
                        local delta, edgeDelta
                        if gravityCenter then
                            delta = safeStep(root, areas, ray, nil, bounds, 5, false, nil, gravityCenter, true)
                        elseif reef and danger then
                            delta = safeStep(root, areas, ray, bossPosition, bounds, 12, true, nil, nil, true, 40)
                                or safeStep(root, areas, ray, nil, bounds, 8, true, nil, nil, true, 32)
                        elseif (desert or ice or cosmic or swamp) and danger then
                            delta = safeStep(root, areas, ray, nil, bounds, 1.75, false, nil, nil, cosmic or swamp)
                        elseif not danger then
                            local heading = session.heading or Vector3.new(1, 0, 0)
                            if followEdge then
                                edgeDelta = perimeterStep(root, areas, ray, bossPosition, bounds, heading)
                                delta = edgeDelta
                            end
                            if (swamp or reef) and not delta then
                                local innerBounds = {
                                    minX = bounds.minX + 8, maxX = bounds.maxX - 8,
                                    minZ = bounds.minZ + 8, maxZ = bounds.maxZ - 8,
                                }
                                if bossPosition then
                                    delta = safeStep(root, areas, ray, bossPosition, innerBounds, EXIT_MARGIN, true, nil, nil, true)
                                        or safeStep(root, areas, ray, bossPosition, bounds, EXIT_MARGIN, true, nil, nil, true)
                                end
                                delta = delta or safeStep(root, areas, ray, nil, innerBounds, EXIT_MARGIN, true, heading, nil, true)
                            end
                            delta = delta or safeStep(root, areas, ray, bossPosition, bounds, EXIT_MARGIN, true, heading, nil, cosmic or swamp)
                                or safeStep(root, areas, ray, nil, bounds, EXIT_MARGIN, true, heading, nil, cosmic or swamp)
                        elseif danger then
                            delta = safeStep(root, areas, ray, bossPosition, bounds, EXIT_MARGIN, false)
                        end
                        if not delta and danger and not gravityCenter then
                            delta = safeStep(root, areas, ray, nil, bounds, 2.5, false, nil, nil, cosmic or swamp)
                        end
                        if not delta and cosmic then
                            delta = safeStep(root, areas, ray, nil, bounds, .75, false, nil, gravityCenter, true)
                        end
                        if delta then
                            local distance = horizontalDistance(Vector3.zero, delta)
                            session.runGoal = root.Position + delta
                            session.runUntil = now + math.clamp(distance / math.max(1, humanoid.WalkSpeed) + 0.55, 0.7, 3.5)
                            session.walking = true
                            session.patrolling = not danger
                            session.edgeChecked = followEdge
                            session.followingEdge = edgeDelta ~= nil
                            session.heading = Vector3.new(delta.X, 0, delta.Z).Unit
                            humanoid:MoveTo(session.runGoal)
                            if not session.patrolling then session.moves = session.moves + 1 end
                            session.lastDistance = distance
                            message = session.patrolling and (session.followingEdge and "Correndo pela lateral" or "Patrulhando a arena")
                                or "Correndo para fora do ataque"
                        else
                            humanoid:MoveTo(root.Position)
                            message = reef and not danger and "Recife · posição livre" or "Sem saída interna livre a pé"
                        end
                    end
                end
                if not refuge and not reef and not passage and (cosmic or (not desert and not ice)) and inCage(root.Position, bounds, 4) and now - lastJump >= JUMP_INTERVAL and humanoid.FloorMaterial ~= Enum.Material.Air then
                    humanoid.Jump = true
                    lastJump = now
                end
                if gravityCenter and session.walking then message = "Buraco Negro · fuga radial" end
                if session.circleCheck and now >= session.circleCheck.at then
                    if horizontalDistance(root.Position, session.circleCheck.from) > math.max(8, session.circleCheck.distance * .65)
                        and circleThreat then
                        circleStatus = "Círculo · personagem voltou à área"
                    end
                    session.circleCheck = nil
                end
                if circleEscaped then circleStatus = "Círculo · teleporte solicitado" end
                if circleStatus then
                    message = circleStatus
                    if circleStatus ~= session.circleStatus then print("[Círculo V59] " .. circleStatus) end
                end
                session.circleStatus = circleStatus
                status.Text = string.format("HP %.2f · Ondas %d · Quedas %d\n%s · %.0f studs",
                    hp, waves, session.hits, message, session.lastDistance)
                task.wait(0.04)
            end
        end)
        if not ok then
            enabled = false
            warn("[Esquiva] " .. tostring(err))
            finish(session, "Erro · veja o console")
        end
    end)
end

toggle.Activated:Connect(function()
    enabled = not enabled
    toggle.Text = enabled and "Desligar esquiva" or "Ligar esquiva"
    if not enabled then
        if active then finish(active, "Desligada") else status.Text = "Desligada" end
    end
end)

task.spawn(function()
    while gui.Parent do
        if enabled and not active then startFight() end
        task.wait(0.25)
    end
end)

gui.Destroying:Connect(function()
    if active then
        finish(active, "Painel fechado")
    end
end)

local eggsPanel = make("Frame", gui, {
    AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 12),
    Size = UDim2.new(0.40, 0, 0.76, 0), BackgroundColor3 = Color3.fromRGB(30, 10, 13),
    BorderSizePixel = 0,
})
round(eggsPanel, 10)
make("UISizeConstraint", eggsPanel, { MaxSize = Vector2.new(260, 540) })
local eggsTitle = make("TextLabel", eggsPanel, {
    Text = "OVOS · ÁREA 1", Position = UDim2.fromOffset(9, 4), Size = UDim2.new(1, -46, 0, 31),
    TextColor3 = Color3.fromRGB(232, 243, 255), Font = Enum.Font.GothamBold, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1,
})
local hideEggs = make("TextButton", eggsPanel, {
    Text = "×", Position = UDim2.new(1, -33, 0, 5), Size = UDim2.fromOffset(27, 27),
    BackgroundColor3 = Color3.fromRGB(89, 23, 31), TextColor3 = Color3.new(1, 1, 1),
})
round(hideEggs, 6)
hideEggs.Activated:Connect(function() eggsPanel.Visible = false end)
eggsToggle.Activated:Connect(function() eggsPanel.Visible = not eggsPanel.Visible end)

local list = make("ScrollingFrame", eggsPanel, {
    Position = UDim2.fromOffset(6, 73), Size = UDim2.new(1, -12, 1, -157),
    CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 4, BackgroundTransparency = 1, BorderSizePixel = 0,
})
make("UIListLayout", list, { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

local collectionStatus = make("TextLabel", eggsPanel, {
    Position = UDim2.new(0, 7, 1, -47), Size = UDim2.new(1, -14, 0, 42),
    BackgroundColor3 = Color3.fromRGB(59, 19, 24), TextColor3 = Color3.fromRGB(229, 240, 255),
    Text = "Escolha um ovo e toque em Coletar.", TextSize = 12, TextWrapped = true,
    Font = Enum.Font.Gotham,
})
round(collectionStatus, 6)

local auto, rareHunt = false, false
local releasedEggs = {}
local autoDeposit, autoHatch = false, false
local depositing, hatching = false, false
local selectedZone = 1
local autoButton = make("TextButton", eggsPanel, {
    Position = UDim2.new(0, 7, 1, -81), Size = UDim2.new(1, -14, 0, 29),
    BackgroundColor3 = Color3.fromRGB(157, 31, 40), TextColor3 = Color3.fromRGB(255, 237, 234),
    Font = Enum.Font.GothamBold, Text = "Auto Coletar · OFF", TextSize = 13,
})
round(autoButton, 6)
local function setAuto(value)
    auto = value
    autoButton.Text = value and "Auto Coletar · ON" or "Auto Coletar · OFF"
    autoButton.BackgroundColor3 = value and Color3.fromRGB(31, 123, 99) or Color3.fromRGB(66, 77, 165)
end

local inputService = game:GetService("UserInputService")
local function stylePanel(frame, handle, flat)
    make("UIStroke", frame, { Color = Color3.fromRGB(232, 68, 52), Thickness = 1.5, Transparency = 0.15 })
    if not flat then
        make("UIGradient", frame, { Rotation = 90, Color = ColorSequence.new(
            Color3.fromRGB(255, 157, 143), Color3.fromRGB(162, 96, 104)) })
    end
    handle.Active = true
    local touch, origin, original
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            touch, origin, original = input, input.Position, frame.Position
        end
    end)
    local move = inputService.InputChanged:Connect(function(input)
        if not touch then return end
        if touch.UserInputType == Enum.UserInputType.Touch then
            if input ~= touch then return end
        elseif input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        local change = input.Position - origin
        local camera = workspace.CurrentCamera
        if not camera then return end
        local view = camera.ViewportSize
        local x = original.X.Scale * view.X + original.X.Offset + change.X
        local y = original.Y.Scale * view.Y + original.Y.Offset + change.Y
        local left = frame.AbsoluteSize.X * frame.AnchorPoint.X
        x = math.clamp(x, left, math.max(left, view.X - frame.AbsoluteSize.X + left))
        y = math.clamp(y, 0, math.max(0, view.Y - 80))
        frame.Position = UDim2.fromOffset(x, y)
    end)
    local ended = inputService.InputEnded:Connect(function(input)
        if input == touch then touch = nil end
    end)
    gui.Destroying:Connect(function() move:Disconnect(); ended:Disconnect() end)
end

local function carryingEgg()
    local value = player:GetAttribute("Carrying")
    return hasEgg(value)
end

local collecting = false
local function promptPosition(prompt)
    local host = prompt.Parent
    if host:IsA("Attachment") then return host.WorldPosition end
    if host:IsA("BasePart") then return host.Position end
    if host:IsA("Model") then return host:GetPivot().Position end
end

local function approach(character, root, egg, target, reach, allowed)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.WalkSpeed <= 0 then return false end
    local origin = root.Position
    local ray = RaycastParams.new()
    ray.FilterType = Enum.RaycastFilterType.Exclude
    ray.RespectCanCollide = true
    ray.FilterDescendantsInstances = { character, egg }
    local floor = workspace:Raycast(origin, Vector3.new(0, -12, 0), ray)
    local clearance = floor and origin.Y - floor.Position.Y or 3
    local radius = math.min(3, reach / 2)
    local direct, fallback, directDistance, fallbackDistance
    for _, direction in ipairs(directions) do
        local point = target + direction * radius
        local ground = workspace:Raycast(point + Vector3.new(0, 7, 0), Vector3.new(0, -17, 0), ray)
        if ground and ground.Normal.Y >= 0.65 then
            local destination = ground.Position + Vector3.new(0, clearance, 0)
            local delta = destination - origin
            local distance = delta.Magnitude
            if (destination - target).Magnitude <= reach then
                if not fallbackDistance or distance < fallbackDistance then
                    fallback, fallbackDistance = destination, distance
                end
                if (not directDistance or distance < directDistance) and not workspace:Raycast(origin, delta, ray) then
                    direct, directDistance = destination, distance
                end
            end
        end
    end

    local function canMove()
        return allowed() and player.Character == character and root.Parent == character
            and egg.Parent and not carryingEgg()
    end
    local function inRange()
        return (root.Position - target).Magnitude <= math.max(reach - .5, reach * .9)
    end
    local function walkTo(point)
        if not canMove() then return false end
        local distance = horizontalDistance(root.Position, point)
        if distance <= 1.25 then return true end
        humanoid:MoveTo(point)
        local deadline = os.clock() + math.clamp(distance / math.max(1, humanoid.WalkSpeed) + 1, 1, 8)
        while canMove() and os.clock() < deadline do
            if inRange() or horizontalDistance(root.Position, point) <= 1.25 then return true end
            task.wait(.05)
        end
        return false
    end

    if direct then walkTo(direct) end
    if fallback and canMove() and not inRange() then
        local path = game:GetService("PathfindingService"):CreatePath({ AgentCanJump = false })
        local computed = pcall(function() path:ComputeAsync(root.Position, fallback) end)
        local waypoints = computed and path.Status == Enum.PathStatus.Success and path:GetWaypoints()
        path:Destroy()
        if waypoints then
            for _, waypoint in ipairs(waypoints) do
                if inRange() or not walkTo(waypoint.Position) then break end
            end
        end
    end
    if root.Parent == character then humanoid:MoveTo(root.Position) end
    return canMove() and (root.Position - target).Magnitude <= reach
end

local function visibleControl(object)
    local node = object
    while node and node ~= guiParent do
        if node:IsA("GuiObject") and not node.Visible then return false end
        if node:IsA("ScreenGui") and not node.Enabled then return false end
        node = node.Parent
    end
    return node == guiParent
end

local function hasLabel(object, expected)
    expected = expected:lower():match("^%s*(.-)%s*$")
    local function matches(node)
        return (node:IsA("TextLabel") or node:IsA("TextButton")) and visibleControl(node)
            and node.Text:lower():match("^%s*(.-)%s*$") == expected
    end
    if matches(object) then return true end
    for _, child in ipairs(object:GetDescendants()) do
        if matches(child) then return true end
    end
    return false
end

local function findFace(scope, text, zoneNumber)
    if not scope then return end
    local cardName = zoneNumber == 10 and "pantano" or (zoneNumber == 11 and "recife")
    local found, named, ambiguous, namedAmbiguous
    for _, object in ipairs(scope:GetDescendants()) do
        if object.Name == "Face" and object:IsA("GuiButton") and visibleControl(object)
            and hasLabel(object, text) then
            local card = object.Parent and object.Parent.Parent
            if cardName and card then
                for _, label in ipairs(card:GetDescendants()) do
                    if label:IsA("TextLabel") and visibleControl(label)
                        and label.Text:gsub("Â", "â"):lower():gsub("â", "a"):find(cardName, 1, true) then
                        if named and named ~= object then namedAmbiguous = true end
                        named = object
                        break
                    end
                end
            end
            if not zoneNumber or (card and hasLabel(card, tostring(zoneNumber))) then
                if found then ambiguous = true end
                found = object
            end
        end
    end
    if cardName then return named and not namedAmbiguous and named or nil end
    return not ambiguous and found or nil
end

local function waitFor(root, timeout, check, interval)
    local deadline = os.clock() + timeout
    repeat
        if not gui.Parent or not root.Parent then return end
        local result = check()
        if result then return result end
        task.wait(interval or 0.08)
    until os.clock() >= deadline
end

local function signalFace(face, input, clicks)
    if type(firesignal) ~= "function" then return false, "firesignal indisponível" end
    local ok, err = pcall(firesignal, face.Activated, input, clicks or 1)
    return ok, ok and nil or tostring(err)
end

local function eggZone(egg, prompt)
    local id = tonumber(egg:GetAttribute("Zone"))
    if id then return id end
    prompt = prompt or egg:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt then return end
    local name = prompt.ObjectText:gsub("Â", "a"):gsub("â", "a"):lower()
    local point = promptPosition(prompt)
    if name:find("ovo do pantano", 1, true) and point and inCage(point, mappedBounds[10], 0) then
        return 10
    end
end

local function nearestEggZone(position)
    local folder = workspace:FindFirstChild("Eggs")
    local nearest, distance
    for _, egg in ipairs(folder and folder:GetChildren() or {}) do
        local zoneNumber = eggZone(egg)
        local point = egg:IsA("BasePart") and egg.Position or (egg:IsA("Model") and egg:GetPivot().Position)
        if zoneNumber and point then
            local gap = horizontalDistance(position, point)
            if not distance or gap < distance then nearest, distance = zoneNumber, gap end
        end
    end
    return nearest, distance
end

local function inEggZone(position, zoneNumber)
    if (zoneNumber == 10 or zoneNumber == 11) and inCage(position, mappedBounds[zoneNumber], 0) then return true end
    local nearby, distance = nearestEggZone(position)
    return nearby == zoneNumber and distance and distance <= 230
end

local function launchZone(character, root, input, clicks, allowed, zoneNumber)
    local function currentHUD() return guiParent:FindFirstChild("HUD") end
    local map = workspace:FindFirstChild("Map")
    local base = map and map:FindFirstChild("Base")
    local zone = base and base:FindFirstChild("ThrowZone")
    local function inThrowZone()
        if not zone or not zone:IsA("BasePart") then return false end
        local point = zone.CFrame:PointToObjectSpace(root.Position)
        return math.abs(point.X) <= zone.Size.X/2 + 1 and math.abs(point.Z) <= zone.Size.Z/2 + 1
            and math.abs(point.Y) < 12
    end
    local function control(scopeName, label, area)
        local hud = currentHUD()
        if not hud then return end
        return findFace(hud:FindFirstChild(scopeName, true), label, area)
            or findFace(hud, label, area)
    end
    local function menuOpen()
        local hud = currentHUD()
        return hud and (control("Panel", "IR!", zoneNumber) or hasLabel(hud, "Para onde vai a Pérola?"))
    end
    local function cancelled()
        return (allowed and not allowed()) or player.Character ~= character
    end
    local function awaitUI(seconds, check)
        local result = waitFor(root, seconds, function() return cancelled() or check() end)
        return not cancelled() and result or nil
    end

    local function pressWhenReady(scopeName, label, area)
        task.wait(.25)
        if cancelled() or root.Parent ~= character then return false, "Lançamento interrompido." end
        local face = control(scopeName, label, area)
        if not face then return false, label .. ": o botão mudou antes do toque." end
        return signalFace(face, input, clicks)
    end

    if not menuOpen() then
        local throw = inThrowZone() and awaitUI(1.2, function()
            return control("Actions", "ARREMESSAR")
        end)
        if cancelled() then return false, "Lançamento interrompido." end
        if not throw and not menuOpen() then
            collectionStatus.Text = "Indo para a plataforma de lançamento..."
            local launch = awaitUI(4, function() return control("TopNav", "Lançar") end)
            if not launch then return false, "Botão Lançar não encontrado no HUD." end
            local ok, reason = pressWhenReady("TopNav", "Lançar")
            if not ok then return false, "Lançar: " .. reason end
            throw = awaitUI(7, function()
                if menuOpen() then return true end
                return control("Actions", "ARREMESSAR")
            end)
        end
        if cancelled() then return false, "Lançamento interrompido." end
        if not menuOpen() then
            if not throw then return false, "A plataforma não mostrou o botão Arremessar no HUD." end
            collectionStatus.Text = "Abrindo o seletor de áreas..."
            local ok, reason = pressWhenReady("Actions", "ARREMESSAR")
            if not ok then return false, "Arremessar: " .. reason end
        end
    end

    local destination = zoneNumber == 11 and "Recife" or ("Área " .. zoneNumber)
    collectionStatus.Text = "Buscando " .. destination .. " no seletor..."
    local face = awaitUI(6, function() return control("Panel", "IR!", zoneNumber) end)
    if cancelled() then return false, "Lançamento interrompido." end
    if not face then
        return false, menuOpen() and ("Menu aberto, mas o botão IR! de " .. destination .. " não foi encontrado.")
            or "Arremessar foi acionado, mas o seletor de áreas não abriu."
    end
    local before = root.Position
    local ok, reason = pressWhenReady("Panel", "IR!", zoneNumber)
    if not ok then return false, "IR!: " .. reason end

    collectionStatus.Text = "Aguardando chegada à Área " .. zoneNumber .. "..."
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local landedAt
    local arrived = waitFor(root, 10, function()
        if (allowed and not allowed()) or player.Character ~= character then return true end
        local current = root.Position
        if horizontalDistance(before, current) >= 55 and inEggZone(current, zoneNumber)
            and humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
            landedAt = landedAt or os.clock()
            return os.clock() - landedAt >= .45
        end
        landedAt = nil
    end)
    if not arrived then return false, "IR!: chegada à Área " .. zoneNumber .. " não confirmada." end
    if (allowed and not allowed()) or player.Character ~= character then return false, "Lançamento interrompido." end
    local invite = guiParent:FindFirstChild("FightUI")
    invite = invite and invite:FindFirstChild("FightInvite")
    local skip = invite and invite:FindFirstChild("FightSkip")
    local face = skip and skip:FindFirstChild("Face")
    if face and face:IsA("GuiButton") and visibleControl(face) then
        local dismissed = signalFace(face, input, clicks)
        if not dismissed or not waitFor(root, 2, function() return not visibleControl(face) end) then
            return false, "Feche o convite de luta e toque em Coletar novamente."
        end
    end
    return true
end

local function eggRarity(egg, prompt)
    local rank = tonumber(egg:GetAttribute("EggRarity")) or tonumber(egg:GetAttribute("Rarity"))
    if rank then return rank end
    local name = prompt.ObjectText:lower()
    if name:find("mítico", 1, true) or name:find("mythic", 1, true) then return 5 end
    if name:find("lendário", 1, true) or name:find("legendary", 1, true) then return 4 end
    if name:find("épico", 1, true) or name:find("epic", 1, true) then return 3 end
    if name:find("raro", 1, true) or name:find("rare", 1, true) then return 2 end
    return 0
end

local function matchesReleasedEgg(egg, zoneNumber, rank, point, now)
    if rank >= 3 then return false end
    for _, released in ipairs(releasedEggs) do
        if now < released.untilTime and released.zone == zoneNumber
            and (egg == released.egg or (rank == released.rank
                and (horizontalDistance(point, released.drop) <= 8
                    or horizontalDistance(point, released.spawn) <= 5))) then
            return true
        end
    end
    return false
end

local function bestEgg(root, zoneNumber, retryAfter, minimumRank, nearbyOnly, visited)
    local folder = workspace:FindFirstChild("Eggs")
    local selected, rank, distance
    local now = os.clock()
    for i = #releasedEggs, 1, -1 do
        if releasedEggs[i].untilTime <= now then table.remove(releasedEggs, i) end
    end
    for _, egg in ipairs(folder and folder:GetChildren() or {}) do
        local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt and prompt.Enabled and prompt.ActionText:lower():find("pegar ovo", 1, true)
            and eggZone(egg, prompt) == zoneNumber and (not visited or not visited[egg])
            and (not retryAfter or (retryAfter[egg] or 0) <= now) then
            local point = promptPosition(prompt)
            local rarity = eggRarity(egg, prompt)
            local gap = point and (point - root.Position).Magnitude
            local reach = nearbyOnly and math.min(18, prompt.MaxActivationDistance + 6) or math.huge
            if gap and gap <= reach and (not minimumRank or rarity > minimumRank)
                and not matchesReleasedEgg(egg, zoneNumber, rarity, point, now)
                and (not rank or rarity > rank or (rarity == rank and gap < distance)) then
                selected, rank, distance = egg, rarity, gap
            end
        end
    end
    return selected
end

local function releaseCarriedEgg(root, input, clicks, allowed, buttonTimeout)
    local drop = waitFor(root, buttonTimeout, function()
        if not allowed() or not carryingEgg() then return end
        local hud = guiParent:FindFirstChild("HUD")
        return findFace(hud, "LARGAR OVO") or findFace(hud, "SOLTAR OVO")
            or findFace(hud, "Largar ovo") or findFace(hud, "Soltar ovo")
    end)
    if not drop or not allowed() or not carryingEgg() then return false end
    local dropPosition = root.Position
    if not signalFace(drop, input, clicks) then return false end
    local released = waitFor(root, 1.5, function() return not carryingEgg() end) == true
    return released, dropPosition
end

local function collectEgg(egg, input, clicks, fromAuto, retryAfter)
    if hatching or depositing or collecting or (auto and not fromAuto) then return end
    if carryingEgg() then collectionStatus.Text = "Você já está carregando um ovo."; return end
    collecting = true
    local function allowed() return gui.Parent ~= nil and (not fromAuto or auto) end
    local heldPrompt
    local ok, message, finished, eggName, upgrade, stop = pcall(function()
        local eggs = workspace:FindFirstChild("Eggs")
        local zoneNumber = eggZone(egg)
        if not eggs or egg.Parent ~= eggs or not zoneNumber or zoneNumber < 1 or zoneNumber > 12 then
            return "Ovo indisponível. Escolha outro."
        end
        local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
        if not prompt or not prompt.Enabled or not prompt.ActionText:lower():find("pegar ovo", 1, true) then
            return "A coleta desse ovo está indisponível."
        end
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local target = promptPosition(prompt)
        if not root or not target then return "Personagem ou ovo indisponível." end
        if (root.Position.Z > -50 or not inEggZone(root.Position, zoneNumber))
            and (root.Position - target).Magnitude > prompt.MaxActivationDistance then
            local launched, reason = launchZone(character, root, input, clicks, allowed, zoneNumber)
            if not launched then return reason end
            if not allowed() or player.Character ~= character or not root.Parent
                or not prompt:IsDescendantOf(egg) or not prompt.Enabled then
                return "Ovo indisponível após o lançamento. Escolha outro."
            end
            target = promptPosition(prompt)
            if not target then return "Ovo indisponível após o lançamento." end
        end
        collectionStatus.Text = "Indo até o ovo..."
        if (root.Position - target).Magnitude > prompt.MaxActivationDistance * .9 then
            if not approach(character, root, egg, target, prompt.MaxActivationDistance, function()
                return allowed() and prompt.Enabled and prompt:IsDescendantOf(egg)
            end) then
                return "Sem trajeto livre. Aproxime-se e tente de novo."
            end
            task.wait(0.10)
        end
        if not allowed() or player.Character ~= character or not root.Parent then return "Coleta cancelada." end
        if carryingEgg() then return "Você já está carregando um ovo." end
        if not prompt:IsDescendantOf(egg) or not prompt.Enabled then return "Ovo indisponível." end
        target = promptPosition(prompt)
        if not target or (root.Position - target).Magnitude > prompt.MaxActivationDistance then
            return "O jogo não manteve o personagem perto do ovo."
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local settledAt
        local settled = waitFor(root, 2.5, function()
            if not allowed() or not prompt:IsDescendantOf(egg) or not prompt.Enabled then return end
            local point = promptPosition(prompt)
            if humanoid and point and (root.Position - point).Magnitude <= prompt.MaxActivationDistance
                and humanoid.FloorMaterial ~= Enum.Material.Air
                and horizontalDistance(root.AssemblyLinearVelocity, Vector3.zero) <= 3 then
                settledAt = settledAt or os.clock()
                return os.clock() - settledAt >= .32
            end
            settledAt = nil
        end, .04)
        if not settled or not allowed() or player.Character ~= character then
            return "Personagem sem posição estável para coletar."
        end
        local name = prompt.ObjectText
        local heldRank = eggRarity(egg, prompt)
        local recycling = fromAuto and rareHunt and heldRank < 3
        if recycling then
            local better = bestEgg(root, zoneNumber, retryAfter, 2)
            if better then return "Épico ou superior apareceu.", false, nil, better end
        end
        collectionStatus.Text = "Segurando a interação de coleta..."
        heldPrompt = prompt
        local holdDuration = math.max(0, prompt.HoldDuration)
        prompt:InputHoldBegin()
        local releaseAt = os.clock() + holdDuration + .08
        while os.clock() < releaseAt and not carryingEgg() and allowed() and player.Character == character
            and prompt:IsDescendantOf(egg) and prompt.Enabled do
            local point = promptPosition(prompt)
            if not point or (root.Position - point).Magnitude > prompt.MaxActivationDistance then break end
            task.wait(math.min(0.04, math.max(0, releaseAt - os.clock())))
        end
        pcall(function() prompt:InputHoldEnd() end)
        heldPrompt = nil
        local confirmationEnd = os.clock() + 2.5
        while not carryingEgg() and allowed() and player.Character == character and os.clock() < confirmationEnd do
            task.wait(0.04)
        end
        if not allowed() or player.Character ~= character then return "Coleta cancelada." end
        if not carryingEgg() then return "O jogo não confirmou a coleta." end

        enabled = true
        toggle.Text = "Desligar esquiva"
        if recycling then
            collectionStatus.Text = "Soltando ovo comum ou raro..."
            local released, dropPosition = releaseCarriedEgg(root, input, clicks, allowed, 2.5)
            if released then
                releasedEggs[#releasedEggs + 1] = {
                    egg = egg, zone = zoneNumber, rank = heldRank,
                    spawn = target, drop = dropPosition, untilTime = os.clock() + 32,
                }
                return "Ovo solto · buscando outro enquanto este expira.", false
            end
            return "Ciclo pausado: o jogo não confirmou soltar o ovo.", false, nil, nil, true
        end
        collectionStatus.Text = "Ovo na mão · esquiva ligada."
        local pickedAt = os.clock()
        local deadline = pickedAt + 65
        local nextUpgradeCheck = 0
        local dropAttempted = false
        while allowed() and carryingEgg() and player.Character == character and os.clock() < deadline do
            local now = os.clock()
            if fromAuto and heldRank > 0 and not dropAttempted and now >= nextUpgradeCheck
                and inEggZone(root.Position, zoneNumber) and humanoid
                and humanoid.FloorMaterial ~= Enum.Material.Air then
                nextUpgradeCheck = now + .35
                local better = bestEgg(root, zoneNumber, nil, heldRank, true)
                if better then
                    dropAttempted = true
                    if releaseCarriedEgg(root, input, clicks, allowed, .35) then
                        return "Ovo solto para tentar raridade maior.", false, nil, better
                    end
                end
            end
            task.wait(.2)
        end
        if not allowed() then return "Coleta interrompida." end
        if carryingEgg() then return "Ovo ainda em transporte." end
        if fromAuto then
            if os.clock() - pickedAt < 27 then return "Transporte terminou cedo. Confira o ovo." end
            local returned = waitFor(root, 8, function()
                return not allowed() or root.Position.Z > -50
            end)
            if not returned or not allowed() then return "Retorno à base não confirmado." end
        end
        return "Transporte terminou. Confira o ovo na base.", true, name
    end)
    if heldPrompt then pcall(function() heldPrompt:InputHoldEnd() end) end
    collecting = false
    if not ok then warn("[Coleta Área 1] " .. tostring(message)) end
    if gui.Parent then collectionStatus.Text = ok and message or "Erro na coleta. Veja o console." end
    return ok and finished == true, eggName, ok and upgrade or nil, ok and stop
end

local order = { common = 1, comum = 1, uncommon = 2, incomum = 2, rare = 3, raro = 3,
    epic = 4, epico = 4, ["épico"] = 4, legendary = 5, lendario = 5, ["lendário"] = 5,
    mythic = 6, mythical = 6, mitico = 6, ["mítico"] = 6, divine = 7, secret = 8 }
local colors = { Color3.fromRGB(197, 210, 230), Color3.fromRGB(104, 220, 144),
    Color3.fromRGB(107, 174, 255), Color3.fromRGB(195, 135, 255), Color3.fromRGB(255, 192, 83),
    Color3.fromRGB(255, 116, 150), Color3.fromRGB(129, 245, 240), Color3.fromRGB(252, 227, 125) }

local function field(object, names)
    for _, key in ipairs(names) do
        local value = object:GetAttribute(key)
        if value ~= nil then return value end
        local child = object:FindFirstChild(key)
        if child and (child:IsA("StringValue") or child:IsA("IntValue")) then return child.Value end
    end
end

local function previewEgg(icon, object)
    local view = make("ViewportFrame", icon, {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Ambient = Color3.fromRGB(170, 170, 170),
    })
    local model = make("Model", view, {})
    local parts = object:GetDescendants()
    if object:IsA("BasePart") then table.insert(parts, 1, object) end
    local count = 0
    for _, part in ipairs(parts) do
        if part:IsA("BasePart") and part.Archivable and part.Transparency < 0.99 then
            local clone = part:Clone()
            if clone then
                for _, child in ipairs(clone:GetChildren()) do
                    if not (child:IsA("SpecialMesh") or child:IsA("Decal") or child:IsA("Texture")
                        or child:IsA("SurfaceAppearance")) then child:Destroy() end
                end
                clone.Anchored = true
                clone.Parent = model
                count = count + 1
                if count >= 70 then break end
            end
        end
    end
    if count == 0 then view:Destroy(); return end
    local center, size = model:GetBoundingBox()
    local distance = math.max(size.X, size.Y, size.Z) * 2.4
    local camera = make("Camera", view, {
        FieldOfView = 32,
        CFrame = CFrame.lookAt(center.Position + Vector3.new(0.48, 0.25, 1).Unit * distance, center.Position),
    })
    view.CurrentCamera = camera
    icon.Text = ""
end

local function pantanoEggs()
    local folder = workspace:FindFirstChild("Eggs")
    local rows = {}
    for _, egg in ipairs(folder and folder:GetChildren() or {}) do
        local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
        if eggZone(egg, prompt) == 10 then
            local position = egg:IsA("BasePart") and egg.Position
                or (egg:IsA("Model") and egg:GetPivot().Position)
            local rarity = tonumber(egg:GetAttribute("EggRarity") or egg:GetAttribute("Rarity")) or 0
            rows[#rows + 1] = {
                object = egg, position = position, rank = rarity,
                name = prompt and prompt.ObjectText ~= "" and prompt.ObjectText or "Ovo do Pântano",
                active = prompt and prompt.Enabled,
                collectible = prompt and prompt.Enabled and prompt.ActionText:lower():find("pegar ovo", 1, true) ~= nil,
            }
        end
    end
    return rows
end

local lastSignature, lastEggObjects = nil, {}
local function refreshEggs()
    local rows, loaded = {}, 0
    local zoneNumber = selectedZone
    local eggs = workspace:FindFirstChild("Eggs")
    local rarityNames = { [1] = "Comum", [2] = "Raro", [3] = "Épico", [4] = "Lendário" }
    if zoneNumber == 10 then
        local scanned = pantanoEggs()
        loaded = #scanned
        for _, egg in ipairs(scanned) do
            if egg.active then
                rows[#rows + 1] = {
                    object = egg.object, name = egg.name, rank = egg.rank,
                    rarity = rarityNames[egg.rank] or ("Raridade " .. egg.rank),
                    location = tostring(egg.position or ""), image = "",
                }
            end
        end
    else
        for _, object in ipairs(eggs and eggs:GetChildren() or {}) do
            local prompt = object:FindFirstChildWhichIsA("ProximityPrompt", true)
            local matches = eggZone(object, prompt) == zoneNumber
            if matches then loaded = loaded + 1 end
            if matches and prompt and prompt.Enabled then
                local value = field(object, { "EggRarity", "Rarity" })
                local numeric = tonumber(value)
                local rarity = numeric and (rarityNames[numeric] or ("Raridade " .. numeric))
                    or tostring(value or "Sem raridade")
                local image = field(object, { "Image", "Icon", "ImageId", "IconId", "Thumbnail" })
                if type(image) == "number" or (type(image) == "string" and image:match("^%d+$")) then
                    image = "rbxassetid://" .. tostring(image)
                end
                local rank = order[rarity:lower()] or 0
                local location = object:IsA("BasePart") and object.Position
                    or (object:IsA("Model") and object:GetPivot().Position)
                local label = prompt.ObjectText ~= "" and prompt.ObjectText or object.Name
                table.insert(rows, { name = label, rarity = rarity, rank = rank,
                    image = type(image) == "string" and image or "",
                    location = location and tostring(location) or "", object = object })
            end
        end
    end
    table.sort(rows, function(a, b)
        if a.rank ~= b.rank then return a.rank > b.rank end
        if a.name ~= b.name then return a.name < b.name end
        if a.rarity ~= b.rarity then return a.rarity < b.rarity end
        return a.location < b.location
    end)
    local keys, eggObjects, changed = {}, {}, false
    for index = 1, math.min(#rows, 60) do
        local row = rows[index]
        eggObjects[index] = row.object
        if row.object ~= lastEggObjects[index] then changed = true end
        keys[index] = row.name .. "|" .. row.rarity .. "|" .. row.image .. "|" .. row.location
    end
    local signature = zoneNumber .. ":" .. loaded .. ":" .. #rows .. ":" .. table.concat(keys, "\n")
    if lastSignature == signature and not changed then return end
    lastSignature, lastEggObjects = signature, eggObjects
    for _, item in ipairs(list:GetChildren()) do
        if not item:IsA("UIListLayout") then item:Destroy() end
    end
    local areaName = zoneNumber == 10 and "PÂNTANO" or (zoneNumber == 11 and "RECIFE" or ("ÁREA " .. zoneNumber))
    eggsTitle.Text = "OVOS · " .. areaName .. (zoneNumber == 10
        and string.format(" (%d/%d ativos)", #rows, loaded) or (" (" .. #rows .. ")"))
    if #rows == 0 then
        make("TextLabel", list, {
            Text = zoneNumber == 10 and (loaded > 0 and "Ovos do Pântano carregados, mas sem interação ativa."
                or "Nenhum ovo do Pântano carregado. Vá até a área para atualizar a lista.")
                or "Nenhum ovo desta área carregado.", Size = UDim2.new(1, -4, 0, 62),
            BackgroundTransparency = 1, TextWrapped = true, TextSize = 12,
            TextColor3 = Color3.fromRGB(198, 211, 231), Font = Enum.Font.Gotham,
        })
    end
    for index = 1, math.min(#rows, 60) do
        local row = rows[index]
        local item = make("Frame", list, {
            LayoutOrder = index, Size = UDim2.new(1, -5, 0, 82),
            BackgroundColor3 = Color3.fromRGB(59, 19, 24), BorderSizePixel = 0,
        })
        round(item, 6)
        local icon = make("TextLabel", item, {
            Text = "🥚", Position = UDim2.fromOffset(4, 7), Size = UDim2.fromOffset(35, 36),
            TextSize = 24, BackgroundTransparency = 1,
        })
        if row.image ~= "" then
            make("ImageLabel", icon, {
                Image = row.image, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
                ScaleType = Enum.ScaleType.Fit,
            })
        elseif zoneNumber ~= 10 and index <= 12 then
            pcall(previewEgg, icon, row.object)
        end
        make("TextLabel", item, {
            Text = row.name .. "\n" .. row.rarity, Position = UDim2.fromOffset(44, 4),
            Size = UDim2.new(1, -48, 0, 44), BackgroundTransparency = 1, TextSize = 12,
            TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBold,
            TextColor3 = colors[row.rank] or Color3.fromRGB(211, 221, 238),
        })
        local collect = make("TextButton", item, {
            Text = "Coletar", Position = UDim2.fromOffset(5, 51), Size = UDim2.new(1, -10, 0, 26),
            BackgroundColor3 = Color3.fromRGB(157, 31, 40), BorderSizePixel = 0,
            TextColor3 = Color3.new(1, 1, 1), TextSize = 13, Font = Enum.Font.GothamBold,
        })
        round(collect, 5)
        collect.Activated:Connect(function(input, clicks) collectEgg(row.object, input, clicks) end)
    end
end

task.spawn(function()
    while gui.Parent do
        if eggsPanel.Visible then refreshEggs() end
        task.wait(selectedZone == 10 and 1 or 3)
    end
end)

local function ownPen()
    local map = workspace:FindFirstChild("Map")
    local base = map and map:FindFirstChild("Base")
    local plots = base and base:FindFirstChild("Plots")
    for _, plot in ipairs(plots and plots:GetChildren() or {}) do
        if tonumber(plot:GetAttribute("OwnerId")) == player.UserId then
            return plot:FindFirstChild("PenEggs")
        end
    end
end

local function eggNameKey(value)
    if type(value) ~= "string" then return "" end
    return value:gsub("^%s*🥚%s*", ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
end

local function findEggTool(character, name, previousTools)
    local expected = eggNameKey(name)
    if expected == "" then return end
    local function match(container)
        local found
        for _, object in ipairs(container and container:GetChildren() or {}) do
            if object:IsA("Tool") and not previousTools[object] and (eggNameKey(object.Name) == expected or eggNameKey(object:GetAttribute("EggName")) == expected) then
                if found then return nil, true end
                found = object
            end
        end
        return found
    end
    local equipped, ambiguous = match(character)
    if equipped or ambiguous then return equipped end
    return match(player:FindFirstChildOfClass("Backpack"))
end

local function hotbarSnapshot()
    local inventory = guiParent:FindFirstChild("Inventory")
    local bar = inventory and inventory:FindFirstChild("Hotbar")
    local slots = {}
    for _, slot in ipairs(bar and bar:GetDescendants() or {}) do
        if slot.Name == "BarSlot" and slot:IsA("GuiObject") then table.insert(slots, slot) end
    end
    table.sort(slots, function(a, b)
        if a.LayoutOrder ~= b.LayoutOrder then return a.LayoutOrder < b.LayoutOrder end
        return a.AbsolutePosition.X < b.AbsolutePosition.X
    end)
    local result = {}
    for index, slot in ipairs(slots) do
        local evidence, labels = {}, {}
        local nodes = slot:GetDescendants()
        table.insert(nodes, 1, slot)
        for _, node in ipairs(nodes) do
            for key, value in pairs(node:GetAttributes()) do
                local lower = key:lower()
                if lower:find("item", 1, true) or lower:find("egg", 1, true)
                    or lower == "count" or lower == "amount" then
                    table.insert(evidence, node.Name .. ":" .. key .. "=" .. tostring(value))
                end
            end
            if node:IsA("TextLabel") or node:IsA("TextButton") then
                if node.Text ~= "" and node.Visible then
                    table.insert(labels, node.Text)
                    table.insert(evidence, node.Name .. ":text=" .. node.Text)
                end
            elseif (node:IsA("ImageLabel") or node:IsA("ImageButton")) and node.Visible and node.Image ~= "" then
                table.insert(evidence, node.Name .. ":image=" .. node.Image)
            elseif node:IsA("ObjectValue") and node.Value then
                table.insert(evidence, node.Name .. ":value=" .. node.Value:GetFullName())
            end
        end
        table.sort(evidence)
        local button = slot:IsA("GuiButton") and slot or slot:FindFirstChild("Face", true)
        if button and not button:IsA("GuiButton") then button = nil end
        result[index] = { button = button, fingerprint = table.concat(evidence, "|"), labels = labels }
    end
    return result
end

local function newEggSlot(previous, name)
    local matched, changes = {}, {}
    for index, row in ipairs(hotbarSnapshot()) do
        local before = previous[index]
        if row.button and visibleControl(row.button) and row.fingerprint ~= "" then
            local expected = eggNameKey(name)
            for _, label in ipairs(row.labels) do
                if expected ~= "" and eggNameKey(label) == expected then
                    table.insert(matched, row.button)
                    break
                end
            end
            if not before or before.fingerprint ~= row.fingerprint then
                table.insert(changes, row.button)
            end
        end
    end
    if #matched == 1 then return matched[1] end
    if #changes == 1 then return changes[1] end
end

local function worldPoint()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local size = camera.ViewportSize
    for _, y in ipairs({ .68, .55, .41, .77, .30 }) do
        for _, x in ipairs({ .50, .43, .57, .67, .33, .76, .24, .84, .16 }) do
            local point = Vector2.new(size.X * x, size.Y * y)
            local blocked = false
            for _, item in ipairs(guiParent:GetGuiObjectsAtPosition(point.X, point.Y)) do
                if visibleControl(item) and (item:IsA("GuiButton") or item.Active or item:IsDescendantOf(gui)) then
                    blocked = true
                    break
                end
            end
            if not blocked then return point end
        end
    end
end

local function penTimes()
    local raw = player:GetAttribute("PenEggTimes")
    if type(raw) ~= "string" then return end
    local ok, times = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
    if not ok or type(times) ~= "table" then return end
    local counts = {}
    for _, timestamp in ipairs(times) do
        if type(timestamp) == "number" then counts[timestamp] = (counts[timestamp] or 0) + 1 end
    end
    return counts
end

local placementPoints = setmetatable({}, { __mode = "k" })

local function performPlacement(character, root, pen, name, previousTools, previousSlots, input, clicks, placed, item)
    local nearest, distance
    for _, item in ipairs(pen:GetChildren()) do
        local point = item:IsA("BasePart") and item.Position or (item:IsA("Model") and item:GetPivot().Position)
        if point then
            local delta = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
            if not distance or delta.Magnitude < distance then nearest, distance = delta, delta.Magnitude end
        end
    end
    -- Cercado vazio: procure um piso pertencente ao lote, na direção da entrada.
    if not nearest and pen.Parent then
        local plot = pen.Parent
        local forward = root.CFrame.LookVector
        forward = Vector3.new(forward.X, 0, forward.Z)
        local ray = RaycastParams.new()
        ray.FilterType = Enum.RaycastFilterType.Exclude
        ray.FilterDescendantsInstances = { character }
        ray.RespectCanCollide = true
        if forward.Magnitude > 0.1 then
            for _, step in ipairs({ 12, 9, 6 }) do
                local delta = forward.Unit * step
                local point = root.Position + delta
                local floor = workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -12, 0), ray)
                if floor and floor.Instance:IsDescendantOf(plot) and floor.Normal.Y >= 0.65
                    and not workspace:Raycast(root.Position, delta, ray) then
                    nearest, distance = delta, step
                    break
                end
            end
        end
    end
    local marked = not depositing and placementPoints[pen]
    if marked then
        local delta = marked - root.Position
        nearest, distance = Vector3.new(delta.X, 0, delta.Z), horizontalDistance(root.Position, marked)
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local pending = "Interior do cercado não confirmado"
    local function eligible()
        return gui.Parent and (depositing or (auto and autoDeposit)) and root.Parent and player.Character == character
            and ownPen() == pen and not carryingEgg()
    end
    local function confirm(seconds)
        waitFor(root, seconds, function() return placed() or not eligible() end, .03)
        return placed()
    end
    local function tapToPlace()
        local point = eligible() and worldPoint()
        if not point then
            pending = "Nenhuma área livre da tela para tocar"
            return false
        end
        if type(firesignal) ~= "function" then
            pending = "Toque indisponível no executor"
            return false
        end
        pending = "O jogo não confirmou a colocação pelo toque"
        collectionStatus.Text = "Ovo selecionado · tocando para colocar..."
        pcall(function() firesignal(inputService.TouchTapInWorld, point, false) end)
        if confirm(1.25) then return true end
        if eligible() then
            pcall(function() firesignal(inputService.TouchTap, { point }, false) end)
            return confirm(1.25)
        end
        return false
    end
    if humanoid and nearest and distance <= (marked and 120 or 30) and eligible() then
        collectionStatus.Text = marked and "Indo ao ponto salvo no celeiro..." or "Entrando no seu cercado..."
        local target = marked or (root.Position + nearest)
        local function walkTo(point, seconds, tolerance)
            if not eligible() then return false end
            if horizontalDistance(root.Position, point) <= tolerance then return true end
            humanoid:MoveTo(point)
            waitFor(root, seconds, function()
                return not eligible() or horizontalDistance(root.Position, point) <= tolerance
            end)
            return eligible() and horizontalDistance(root.Position, point) <= tolerance
        end
        local arrivalTolerance = 1.5
        local alreadyThere = horizontalDistance(root.Position, target) <= arrivalTolerance
        local arrived = walkTo(target, 4, arrivalTolerance)
        if not arrived and marked and eligible() then
            local path = game:GetService("PathfindingService"):CreatePath({ AgentCanJump = false })
            local computed = pcall(function() path:ComputeAsync(root.Position, target) end)
            if computed and path.Status == Enum.PathStatus.Success then
                local deadline = os.clock() + 8
                for _, waypoint in ipairs(path:GetWaypoints()) do
                    local remaining = deadline - os.clock()
                    if remaining <= 0 or not walkTo(waypoint.Position, math.min(remaining, 2), 1.5) then break end
                end
                arrived = walkTo(target, 1, arrivalTolerance)
            end
            path:Destroy()
        end
        if root.Parent and not arrived then humanoid:MoveTo(root.Position) end
        if arrived and eligible() then
            if not alreadyThere then task.wait(.15) end
            local tool = item and item.tool or (name and name ~= "" and findEggTool(character, name, previousTools))
            if tool and eligible() then
                if tool.Parent ~= character then
                    humanoid:EquipTool(tool)
                    waitFor(root, .35, function() return tool.Parent == character or not eligible() end, .03)
                end
                if eligible() and tool.Parent == character then
                    if tapToPlace() then return true end
                    if eligible() then
                        tool:Activate()
                        if confirm(1.5) then return true end
                    end
                end
            end

            if eligible() and (not item or item.slot) then
                pending = "Ovo não identificado na barra"
                collectionStatus.Text = "Procurando o ovo na barra..."
                local slot = waitFor(root, 3, function()
                    if not eligible() then return end
                    if item then return item.slot end
                    return newEggSlot(previousSlots, name)
                end)
                if slot and eligible() then
                    pending = "A barra não aceitou a seleção"
                    collectionStatus.Text = "Selecionando o ovo na barra..."
                    if signalFace(slot, input, clicks) then
                        if confirm(.12) then return true end
                        if tapToPlace() then return true end
                        local equipped = findEggTool(character, name, previousTools)
                        if equipped and equipped.Parent == character and eligible() then
                            equipped:Activate()
                            if confirm(1.5) then return true end
                        end
                    end
                end
            end
        else
            warn(string.format("[Colocação V59] Alvo a %.2f studs após caminhar", horizontalDistance(root.Position, target)))
        end
    end

    if not eligible() then return false, "Ciclo interrompido." end
    collectionStatus.Text = pending .. " · confirmando..."
    if confirm(3) then return true end
    return false, pending .. ". Colocação não confirmada."
end

local function placeInPen(character, root, pen, name, previousTools, previousSlots, input, clicks, item)
    local before = tonumber(player:GetAttribute("PenEggs"))
    if not before then return false, "Contador do cercado indisponível." end
    local original = penTimes()
    local confirmed = false
    local function placed()
        if confirmed then return true end
        if ownPen() ~= pen then return false end
        if (tonumber(player:GetAttribute("PenEggs")) or before) > before then
            confirmed = true
        elseif original then
            for timestamp, count in pairs(penTimes() or {}) do
                if count > (original[timestamp] or 0) then
                    confirmed = true
                    break
                end
            end
        end
        if confirmed and depositing and root.Parent == character then
            placementPoints[pen] = root.Position
        end
        return confirmed
    end
    local countChanged = player:GetAttributeChangedSignal("PenEggs"):Connect(placed)
    local timesChanged = player:GetAttributeChangedSignal("PenEggTimes"):Connect(placed)
    local ok, result, reason = pcall(performPlacement, character, root, pen, name,
        previousTools, previousSlots, input, clicks, placed, item)
    countChanged:Disconnect()
    timesChanged:Disconnect()
    if not ok then error(result) end
    return result, reason
end

local function inventoryEgg(character, expectedName, previousTools)
    local expected = eggNameKey(expectedName)
    for _, container in ipairs({ character, player:FindFirstChildOfClass("Backpack") }) do
        for _, tool in ipairs(container:GetChildren()) do
            if tool:IsA("Tool") then
                local eggName = tool:GetAttribute("EggName")
                local matches = expected == "" or eggNameKey(eggName) == expected or eggNameKey(tool.Name) == expected
                if matches and not (previousTools and previousTools[tool])
                    and (eggNameKey(eggName) ~= "" or eggNameKey(tool.Name):match("^ovo ")) then
                    return { tool = tool, name = eggNameKey(eggName) ~= "" and eggName or tool.Name }
                end
            end
        end
    end
    for _, row in ipairs(hotbarSnapshot()) do
        if row.button and visibleControl(row.button) then
            for _, label in ipairs(row.labels) do
                local key = eggNameKey(label)
                if key:match("^ovo ") and (expected == "" or key == expected) then
                    return { slot = row.button, name = label }
                end
            end
        end
    end
end

local function depositInventory(character, root, pen, input, clicks)
    local placed = 0
    while gui.Parent and (depositing or (auto and autoDeposit)) and root.Parent
        and player.Character == character and ownPen() == pen and not carryingEgg() do
        local item = inventoryEgg(character)
        if not item then return placed end
        local started = os.clock()
        local ok, reason = placeInPen(character, root, pen, item.name, {}, {}, input, clicks, item)
        if not ok then return placed, reason end
        placed = placed + 1
        local remaining = .25 - (os.clock() - started)
        if remaining > 0 then task.wait(remaining) end
    end
    return placed
end

local function hatchReady(root, pen, input, clicks, standaloneAuto)
    local hatched = 0
    local function allowed()
        return gui.Parent and (hatching and (not standaloneAuto or autoHatch) or (auto and autoHatch))
            and root.Parent == player.Character and ownPen() == pen and not carryingEgg()
    end
    while allowed() do
        local candidate, nearest
        for _, prompt in ipairs(pen:GetDescendants()) do
            if prompt:IsA("ProximityPrompt") and prompt.Name == "HatchPrompt" and prompt.Enabled then
                local point = promptPosition(prompt)
                local distance = point and (point - root.Position).Magnitude
                if distance and distance <= prompt.MaxActivationDistance and (not nearest or distance < nearest) then
                    candidate, nearest = prompt, distance
                end
            end
        end
        local function hatchFace()
            local hatch = guiParent:FindFirstChild("HatchButton")
            local face = hatch and hatch:FindFirstChild("Face", true)
            return face and face:IsA("GuiButton") and visibleControl(face) and face
        end
        local face = hatchFace()
        if not candidate and not face then return true, nil, hatched end
        print(string.format("[Eclosão V59] %s | prompt=%s | botão=%s | ovos=%s",
            standaloneAuto and "auto independente" or (auto and "ciclo" or "manual"),
            candidate and string.format("%.1f studs", nearest) or "indisponível",
            face and "visível" or "oculto", tostring(player:GetAttribute("PenEggs"))))
        local before = tonumber(player:GetAttribute("PenEggs"))
        local original = penTimes()
        local function confirmed()
            local current = tonumber(player:GetAttribute("PenEggs"))
            if before and current and current < before then return true end
            local times = original and penTimes()
            if times then
                for timestamp, count in pairs(original) do
                    if (times[timestamp] or 0) < count then return true end
                end
            end
        end
        local function waitConfirmation(seconds)
            waitFor(root, seconds, function() return confirmed() or not allowed() end)
            return confirmed()
        end
        collectionStatus.Text = "Chocando ovo pronto..."
        local success
        if candidate and pcall(function() candidate:InputHoldBegin() end) then
            local deadline = os.clock() + math.max(.05, candidate.HoldDuration)
            while allowed() and candidate.Parent and os.clock() < deadline do task.wait(.04) end
            pcall(function() candidate:InputHoldEnd() end)
            success = waitConfirmation(1.5)
            print("[Eclosão V59] Prompt confirmado=" .. tostring(success == true))
        end
        if not success and allowed() then
            local face = hatchFace()
            if face then
                local sent, problem = signalFace(face, input, clicks)
                if sent then success = waitConfirmation(2) end
                print("[Eclosão V59] Botão confirmado=" .. tostring(success == true)
                    .. (problem and " | " .. problem or ""))
            end
        end
        if not success then return false, "Eclosão não confirmada.", hatched end
        hatched = hatched + 1
        task.wait(.35)
    end
    return false, "Eclosão interrompida.", hatched
end

local looping = false
local pendingDeposit
autoButton.Activated:Connect(function(input, clicks)
    if auto then setAuto(false); collectionStatus.Text = "Desligando ciclo..."; return end
    if hatching or depositing or looping or collecting or carryingEgg() then return end
    local zoneNumber = selectedZone
    setAuto(true)
    looping = true
    task.spawn(function()
        local failures = 0
        local retryAfter = setmetatable({}, { __mode = "k" })
        local visited = setmetatable({}, { __mode = "k" })
        local preferredEgg
        local finalStatus
        local function finishDeposit(character, root)
            local pen = ownPen()
            if pendingDeposit and autoDeposit then
                if not pen then return false, "Seu cercado não foi encontrado" end
                local ready = waitFor(root, 2, function() return not auto or (not active and not carryingEgg()) end)
                if not ready or not auto then return false, "Aguardando fim da esquiva" end
                local item = pendingDeposit
                local selected = inventoryEgg(character, item.name, item.previousTools)
                local deposited, problem = placeInPen(character, root, pen, item.name,
                    item.previousTools, item.previousSlots, input, clicks, selected)
                if not deposited then
                    warn("[Colocação V59] " .. tostring(problem) .. " · próxima coleta bloqueada")
                    return false, problem
                end
            end
            pendingDeposit = nil
            if auto and autoHatch and pen then
                local ran, hatched, problem = pcall(hatchReady, root, pen, input, clicks)
                if not ran or not hatched then warn("[Eclosão] " .. tostring(ran and problem or hatched)) end
            end
            if auto and autoDeposit and pen then
                local _, problem = depositInventory(character, root, pen, input, clicks)
                if problem then warn("[Inventário V59] " .. problem) end
            end
            return true, autoDeposit and "Ovo colocado · próxima rodada" or "Depósito desligado · próxima rodada"
        end
        local function runRound()
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            if not root then return false, "Aguardando personagem" end
            if carryingEgg() then return false, "Aguardando fim do transporte" end
            if pendingDeposit then return finishDeposit(character, root) end
            if root.Position.Z > -50 or not inEggZone(root.Position, zoneNumber) then
                local launched, problem = launchZone(character, root, input, clicks,
                    function() return auto and gui.Parent end, zoneNumber)
                if not launched then return false, problem end
            end
            if not gui.Parent or not auto then return false, "Ciclo desligado" end
            if active then
                local ready = waitFor(root, 2, function() return not active end)
                if not ready then return false, "Aguardando fim da esquiva" end
            end
            if zoneNumber == 10 then collectionStatus.Text = "Pântano · aguardando ovos do ID 10..." end
            local egg = waitFor(root, zoneNumber == 10 and 18 or 8, function()
                local folder = workspace:FindFirstChild("Eggs")
                if not auto then return true end
                if preferredEgg and folder and preferredEgg.Parent == folder then return preferredEgg end
                if rareHunt then
                    local candidate = bestEgg(root, zoneNumber, retryAfter, 2)
                        or bestEgg(root, zoneNumber, retryAfter, nil, false, visited)
                    if candidate then return candidate end
                    local nextRotation = bestEgg(root, zoneNumber, retryAfter)
                    if nextRotation then table.clear(visited) end
                    return nextRotation
                end
                return bestEgg(root, zoneNumber, retryAfter)
            end)
            if not auto then return false, "Ciclo desligado" end
            if not egg then
                local waitingForExpiry = false
                if rareHunt then
                    for _, released in ipairs(releasedEggs) do
                        if released.zone == zoneNumber and released.untilTime > os.clock() then
                            waitingForExpiry = true
                            break
                        end
                    end
                end
                if waitingForExpiry then return false, "Aguardando aparecer outro ovo", true end
                return false, "Aguardando ovos da Área " .. zoneNumber
            end
            local previousSlots = hotbarSnapshot()
            local previousTools = {}
            for _, container in ipairs({ character, player:FindFirstChildOfClass("Backpack") }) do
                for _, tool in ipairs(container:GetChildren()) do
                    if tool:IsA("Tool") then previousTools[tool] = true end
                end
            end
            preferredEgg = nil
            local collected, name, upgrade, stop = collectEgg(egg, input, clicks, true, retryAfter)
            if stop then return false, collectionStatus.Text, false, true end
            if not collected then
                retryAfter[egg] = os.clock() + 20
                if rareHunt then visited[egg] = true end
                preferredEgg = upgrade
                return false, collectionStatus.Text, true
            end
            table.clear(retryAfter)
            pendingDeposit = { name = name, previousTools = previousTools, previousSlots = previousSlots }
            if not auto then return false, "Ciclo desligado" end
            local returnedCharacter = player.Character
            local returnedRoot = returnedCharacter and returnedCharacter:FindFirstChild("HumanoidRootPart")
            if not returnedRoot then return false, "Aguardando personagem na base" end
            return finishDeposit(returnedCharacter, returnedRoot)
        end
        while gui.Parent and auto do
            local ok, success, reason, retryEgg, stop = pcall(runRound)
            if ok and stop then
                finalStatus = reason
                break
            end
            if not gui.Parent or not auto then break end
            if ok and success then
                failures = 0
                collectionStatus.Text = reason
            else
                failures = failures + 1
                local detail = ok and reason or tostring(success)
                collectionStatus.Text = tostring(detail) .. " · tentando novamente"
                if not ok then warn("[Auto Coletar V59] " .. detail) end
            end
            autoButton.Text = pendingDeposit and autoDeposit and "Auto ON · depósito pendente" or "Auto ON"
            local delay = retryEgg and .35 or (failures == 0 and 2 or math.min(25, 2 + failures * 3))
            local untilTime = os.clock() + delay
            while gui.Parent and auto and os.clock() < untilTime do task.wait(0.2) end
        end
        looping = false
        if gui.Parent then
            setAuto(false)
            collectionStatus.Text = finalStatus or "Ciclo desligado."
        end
    end)
end)


local function arcadeButton(parent, caption, position, size)
    local button = make("TextButton", parent, {
        Position = position, Size = size, Text = caption, TextSize = 12,
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(242, 250, 255),
        BackgroundColor3 = Color3.fromRGB(157, 31, 40), BorderSizePixel = 0,
        TextWrapped = true,
    })
    round(button, 6)
    return button
end

do
    local function heading(parent, caption, y, size, bold)
        return make("TextLabel", parent, {
            Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, size + 10),
            BackgroundTransparency = 1, Text = caption, TextSize = size,
            Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextColor3 = Color3.fromRGB(225, 232, 250), TextXAlignment = Enum.TextXAlignment.Left,
        })
    end
    heading(eggsPanel, "OPERAÇÕES  /  COLETA", 8, 10, true)
    heading(eggsPanel, "Central de coleta", 24, 23, true)
    local controls = make("Frame", eggsPanel, {
        Name = "CollectionSurface", Position = UDim2.fromOffset(8, 66),
        Size = UDim2.new(.39, -12, 1, -74), BorderSizePixel = 0,
    })
    local catalog = make("Frame", eggsPanel, {
        Name = "CollectionSurface", Position = UDim2.new(.39, 4, 0, 66),
        Size = UDim2.new(.61, -12, 1, -74), BorderSizePixel = 0,
    })
    round(controls, 10)
    round(catalog, 10)
    heading(controls, "AUTOMAÇÃO", 10, 10, true)
    heading(controls, "Controles do ciclo", 29, 16, true)
    heading(controls, "STATUS DO CICLO", 156, 10, true)
    autoButton.Parent = controls
    autoButton.Size = UDim2.new(1, -28, 0, 38)
    autoButton.Position = UDim2.fromOffset(14, 67)
    collectionStatus.Parent = controls
    collectionStatus.Position = UDim2.fromOffset(14, 178)
    collectionStatus.Size = UDim2.new(1, -28, 0, 68)
    local hunt = arcadeButton(controls, "Épico+ · OFF", UDim2.fromOffset(14, 113),
        UDim2.new(1, -28, 0, 34))
    hunt.Activated:Connect(function()
        if auto or looping or collecting then
            collectionStatus.Text = "Pare o ciclo para mudar o modo."
            return
        end
        rareHunt = not rareHunt
        hunt.Text = rareHunt and "Épico+ · ON" or "Épico+ · OFF"
        collectionStatus.Text = rareHunt and "Épico+ · alterna ovos comuns e raros até achar um épico ou superior."
            or "Coleta normal · prioriza a maior raridade."
    end)
    eggsTitle.Parent = catalog
    eggsTitle.Position = UDim2.fromOffset(14, 6)
    eggsTitle.Size = UDim2.new(1, -28, 0, 31)
    list.Parent = catalog
    list.Position = UDim2.fromOffset(12, 75)
    list.Size = UDim2.new(1, -24, 1, -85)
end

local previousArea = arcadeButton(eggsTitle.Parent, "‹", UDim2.fromOffset(7, 39), UDim2.fromOffset(29, 27))
local nextArea = arcadeButton(eggsTitle.Parent, "›", UDim2.new(1, -36, 0, 39), UDim2.fromOffset(29, 27))
local areaLabel = arcadeButton(eggsTitle.Parent, "ID 01 · toque: Pântano",
    UDim2.fromOffset(38, 39), UDim2.new(1, -76, 0, 27))
local function chooseArea(zoneNumber)
    if auto or collecting then
        collectionStatus.Text = "Desligue o ciclo antes de trocar de área."
        return
    end
    selectedZone = zoneNumber
    areaLabel.Text = selectedZone == 10 and "ÁREA 7 · PÂNTANO"
        or (selectedZone == 11 and "ÁREA 8 · RECIFE") or string.format("ID %02d · toque: Pântano", selectedZone)
    list.CanvasPosition = Vector2.zero
    refreshEggs()
end
areaLabel.Activated:Connect(function() chooseArea(10) end)
previousArea.Activated:Connect(function() chooseArea((selectedZone - 2) % 12 + 1) end)
nextArea.Activated:Connect(function() chooseArea(selectedZone % 12 + 1) end)

local palettes = {
    { "Índigo", Color3.fromRGB(15, 20, 34), Color3.fromRGB(24, 31, 48), Color3.fromRGB(66, 77, 165), Color3.fromRGB(171, 183, 255) },
    { "Crimson", Color3.fromRGB(29, 12, 18), Color3.fromRGB(56, 22, 35), Color3.fromRGB(149, 40, 63), Color3.fromRGB(255, 118, 108) },
    { "Menta", Color3.fromRGB(12, 27, 25), Color3.fromRGB(25, 57, 49), Color3.fromRGB(28, 113, 93), Color3.fromRGB(101, 245, 194) },
    { "Âmbar", Color3.fromRGB(33, 22, 13), Color3.fromRGB(63, 43, 28), Color3.fromRGB(141, 82, 26), Color3.fromRGB(255, 204, 107) },
}
local shell = make("Frame", gui, {
    Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(820, 465),
    BackgroundColor3 = Color3.fromRGB(15, 15, 31), BorderSizePixel = 0, ClipsDescendants = true,
})
round(shell, 12)
local header = make("TextLabel", shell, {
    Position = UDim2.fromOffset(16, 4), Size = UDim2.new(1, -155, 0, 40),
    Text = "Central de Ovos  /  V59", TextColor3 = Color3.fromRGB(124, 232, 255),
    Font = Enum.Font.GothamBold, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    BackgroundTransparency = 1,
})
local shrink = arcadeButton(shell, "−", UDim2.new(1, -40, 0, 9), UDim2.fromOffset(30, 28))
local zoomOut = arcadeButton(shell, "A−", UDim2.new(1, -108, 0, 9), UDim2.fromOffset(30, 28))
local zoomIn = arcadeButton(shell, "A+", UDim2.new(1, -74, 0, 9), UDim2.fromOffset(30, 28))
local nav = make("Frame", shell, {
    Position = UDim2.fromOffset(10, 50), Size = UDim2.new(0, 150, 1, -60),
    BackgroundColor3 = Color3.fromRGB(35, 31, 65), BorderSizePixel = 0,
})
round(nav, 8)
make("TextLabel", nav, {
    Position = UDim2.fromOffset(13, 9), Size = UDim2.new(1, -26, 0, 25),
    BackgroundTransparency = 1, Text = "ÁREA DE TRABALHO", TextSize = 10,
    Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(165, 180, 208),
    TextXAlignment = Enum.TextXAlignment.Left,
})
local content = make("Frame", shell, {
    Position = UDim2.fromOffset(170, 50), Size = UDim2.new(1, -180, 1, -60),
    BackgroundTransparency = 1,
})
local function asPage(page)
    local limit = page:FindFirstChildOfClass("UISizeConstraint")
    if limit then limit:Destroy() end
    page.AnchorPoint = Vector2.zero
    page.Position = UDim2.fromOffset(0, 0)
    page.Size = UDim2.fromScale(1, 1)
    page.Parent = content
end
asPage(panel)
asPage(eggsPanel)
minimize:Destroy()
eggsToggle:Destroy()
hideEggs:Destroy()
title.Text = "Esquiva"
do
    for index, label in ipairs({ "− 2", "Padrão", "+ 2" }) do
        local button = arcadeButton(panel, label, UDim2.new((index - 1) / 3, 8, 0, 160),
            UDim2.new(1 / 3, -16, 0, 32))
        button.Activated:Connect(function()
            local humanoid = active and active.humanoid
            if index == 2 then
                speedTarget = 0
            else
                local base = speedTarget > 0 and speedTarget or (active and active.speedBoost and active.originalSpeed) or (humanoid and humanoid.WalkSpeed or 16)
                speedTarget = math.clamp(math.floor(base + 0.5) + (index == 1 and -2 or 2), 8, 80)
            end
            if active then applySpeed(active) end
            updateSpeedLabel(active)
        end)
    end
    updateSpeedLabel(nil)
end
eggsTitle.Text = "Coleta e ovos"

local function settingsPage(heading, description)
    local page = make("Frame", content, {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 15, 31), BorderSizePixel = 0,
    })
    round(page, 8)
    make("TextLabel", page, {
        Position = UDim2.fromOffset(12, 7), Size = UDim2.new(1, -24, 0, 28),
        Text = heading, BackgroundTransparency = 1, TextColor3 = Color3.fromRGB(224, 241, 255),
        TextSize = 16, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
    })
    if description then
        make("TextLabel", page, {
            Position = UDim2.fromOffset(12, 45), Size = UDim2.new(1, -24, 0, 56),
            Text = description, TextWrapped = true, BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(219, 231, 249), TextSize = 13,
            Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left,
        })
    end
    return page
end

local penPage = settingsPage("Colocação", "Marque um ponto dentro do celeiro. A coleta aguarda o depósito antes de sair novamente.")
local hatchPage = settingsPage("Eclosão", "Entre rodadas, tenta chocar os ovos prontos que estiverem ao alcance no seu cercado.")
local looksPage = settingsPage("Aparência", "Arraste pelo título para mover a central.")
local penToggle = arcadeButton(penPage, "Auto Colocar · OFF", UDim2.fromOffset(12, 111), UDim2.new(1, -24, 0, 32))
local hatchToggle = arcadeButton(hatchPage, "Auto Chocar · OFF", UDim2.fromOffset(12, 111), UDim2.new(1, -24, 0, 32))
penToggle.Activated:Connect(function()
    autoDeposit = not autoDeposit
    penToggle.Text = autoDeposit and "Auto Colocar · ON" or "Auto Colocar · OFF"
end)
local depositNow = arcadeButton(penPage, "Colocar ovos do inventário", UDim2.fromOffset(12, 151), UDim2.new(1, -24, 0, 36))
local markPen = arcadeButton(penPage, "Marcar ponto dentro do celeiro", UDim2.fromOffset(12, 193), UDim2.new(1, -24, 0, 36))
markPen.Activated:Connect(function()
    if looping or depositing or hatching or collecting then
        markPen.Text = "Pare o ciclo para marcar o ponto"
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local pen = ownPen()
    if not root or not pen or carryingEgg() then
        markPen.Text = "Entre no seu celeiro para marcar"
        return
    end
    placementPoints[pen] = root.Position
    markPen.Text = "Ponto salvo · marcar novamente"
end)
depositNow.Activated:Connect(function(input, clicks)
    if depositing or hatching then return end
    if looping or collecting then
        depositNow.Text = "Depósito gerenciado pela coleta"
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local pen = ownPen()
    if not root or not pen or carryingEgg() then
        depositNow.Text = "Volte ao seu cercado para colocar"
        return
    end
    depositing = true
    depositNow.Text = "Colocando ovos..."
    local ok, count, reason = pcall(depositInventory, character, root, pen, input, clicks)
    depositing = false
    if not gui.Parent then return end
    if not ok or reason then
        warn("[Inventário V59] " .. tostring(reason or count))
        depositNow.Text = "Colocação não confirmada · veja console"
    elseif count == 0 then
        depositNow.Text = "Nenhum ovo identificado · tentar novamente"
    else
        depositNow.Text = string.format("%d colocado(s) · ponto salvo", count)
    end
end)
local hatchNow = arcadeButton(hatchPage, "Chocar ovos prontos", UDim2.fromOffset(12, 151), UDim2.new(1, -24, 0, 36))
hatchNow.Activated:Connect(function(input, clicks)
    if hatching then return end
    if looping or collecting or depositing then
        hatchNow.Text = "Aguarde a ação atual terminar"
        return
    end
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local pen = ownPen()
    if not root or not pen or carryingEgg() then
        hatchNow.Text = "Volte ao seu cercado para chocar"
        return
    end
    hatching = true
    hatchNow.Text = "Chocando..."
    local ran, ok, reason, count = pcall(hatchReady, root, pen, input, clicks)
    hatching = false
    if not gui.Parent then return end
    if not ran or not ok then
        warn("[Eclosão V59] " .. tostring(ran and reason or ok))
        hatchNow.Text = "Eclosão não confirmada · veja console"
    elseif count == 0 then
        hatchNow.Text = "Nenhum ovo pronto ao alcance"
    else
        hatchNow.Text = string.format("%d chocado(s) · verificar novamente", count)
    end
end)
local hatchInput, hatchClicks
hatchToggle.Activated:Connect(function(input, clicks)
    hatchInput, hatchClicks = input, clicks
    autoHatch = not autoHatch
    hatchToggle.Text = autoHatch and "Auto Chocar · ON" or "Auto Chocar · OFF"
end)

task.spawn(function()
    local lastState
    while gui.Parent do
        local delay = 1.5
        if autoHatch and not auto and not looping and not collecting and not depositing and not hatching then
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local pen = ownPen()
            if root and pen and not carryingEgg() then
                hatching = true
                local ran, ok, reason, count = pcall(hatchReady, root, pen, hatchInput, hatchClicks, true)
                hatching = false
                local state = ran and ok and (count > 0 and "confirmado" or "sem interação pronta ao alcance")
                    or tostring(ran and reason or ok)
                if state ~= lastState then print("[Eclosão V59] Auto independente: " .. state) end
                lastState = state
                if not ran or not ok then delay = 6 end
            end
        end
        task.wait(delay)
    end
end)

local themeIndex = 1
local theme = arcadeButton(looksPage, "Tema · Índigo", UDim2.fromOffset(12, 105), UDim2.new(1, -24, 0, 29))
local scale = make("UIScale", shell, { Scale = 1 })
local smaller = arcadeButton(looksPage, "Tamanho −", UDim2.fromOffset(12, 144), UDim2.new(.5, -16, 0, 29))
local larger = arcadeButton(looksPage, "Tamanho +", UDim2.new(.5, 4, 0, 144), UDim2.new(.5, -16, 0, 29))
local compact, zoom = false, 1
local function layoutShell()
    local width, height = 820, 465
    if compact then width, height = 182, 322 end
    shell.Size = UDim2.fromOffset(width, height)
    local view = gui.AbsoluteSize
    if view.X > 24 and view.Y > 24 then
        local limit = math.min((view.X - 24) / width, (view.Y - 24) / height)
        local fit = math.min(limit * .88, 1)
        scale.Scale = math.min(fit * zoom, limit)
        shell.Position = UDim2.fromOffset(
            math.clamp(shell.Position.X.Offset, 0, math.max(0, view.X - width * scale.Scale)),
            math.clamp(shell.Position.Y.Offset, 0, math.max(0, view.Y - height * scale.Scale)))
    end
    header.Text = compact and "Central de Ovos" or "Central de Ovos  /  V59"
    header.Size = UDim2.new(1, compact and -52 or -155, 0, 40)
    content.Visible = not compact
    zoomIn.Visible, zoomOut.Visible = not compact, not compact
    shrink.Text = compact and "+" or "−"
    larger.Text = string.format("Tamanho + · %d%%", math.floor(zoom * 100 + .5))
end
local function resize(amount)
    zoom = math.clamp(zoom + amount, .65, 1.3)
    layoutShell()
end
smaller.Activated:Connect(function() resize(-.1) end)
larger.Activated:Connect(function() resize(.1) end)
zoomOut.Activated:Connect(function() resize(-.1) end)
zoomIn.Activated:Connect(function() resize(.1) end)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutShell)

local pages = {
    { "Coleta de ovos", eggsPanel }, { "Depósito", penPage }, { "Eclosão", hatchPage },
    { "Esquiva do boss", panel }, { "Aparência", looksPage },
}
local selectedPage = 1
local function showPage(index)
    selectedPage = index
    compact = false
    layoutShell()
    local palette = palettes[themeIndex]
    for i, entry in ipairs(pages) do
        entry[2].Visible = i == index
        entry[3].Text = (i == index and "  ▸  " or "      ") .. entry[1]
        entry[3].BackgroundColor3 = i == index and palette[4] or palette[3]
    end
    if index == 1 then refreshEggs() end
end
for index, entry in ipairs(pages) do
    local button = arcadeButton(nav, entry[1], UDim2.fromOffset(7, 39 + (index - 1) * 41),
        UDim2.new(1, -14, 0, 36))
    button.TextXAlignment = Enum.TextXAlignment.Left
    entry[3] = button
    button.Activated:Connect(function() showPage(index) end)
end
shrink.Activated:Connect(function()
    compact = not compact
    layoutShell()
end)
stylePanel(shell, header, true)

local function paint(object)
    local palette = palettes[themeIndex]
    if object == shell or object == panel or object == eggsPanel or object == penPage
        or object == hatchPage or object == looksPage then
        object.BackgroundColor3 = palette[2]
    elseif object:IsA("UIStroke") then
        object.Color = palette[5]
    elseif object:IsA("UIGradient") then
        object.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(201, 201, 223))
    elseif object:IsA("TextButton") then
        object.BackgroundColor3 = palette[4]
    elseif object == nav or (object:IsA("Frame") and object.Name == "CollectionSurface") then
        object.BackgroundColor3 = palette[3]
    elseif object == collectionStatus or (object:IsA("Frame") and object.Parent == list) then
        object.BackgroundColor3 = palette[2]
    elseif object == header or object == title or object == eggsTitle or object == areaLabel then
        object.TextColor3 = palette[5]
    end
end
local function repaint()
    theme.Text = "Tema · " .. palettes[themeIndex][1]
    for _, object in ipairs(gui:GetDescendants()) do paint(object) end
    local palette = palettes[themeIndex]
    for index, entry in ipairs(pages) do
        entry[3].BackgroundColor3 = index == selectedPage and palette[4] or palette[3]
    end
end
theme.Activated:Connect(function()
    themeIndex = themeIndex % #palettes + 1
    repaint()
end)
gui.DescendantAdded:Connect(paint)
showPage(1)
repaint()

-- Se o jogador chegar por conta própria, abra a lista do destino detectado.
task.spawn(function()
    local wasInPantano = false
    while gui.Parent do
        local character = player.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")
        local inside = root and inCage(root.Position, mappedBounds[10], 0)
        if not inside then
            wasInPantano = false
        elseif not wasInPantano and not auto and not collecting then
            wasInPantano = true
            if selectedZone ~= 10 then chooseArea(10) end
        end
        task.wait(1)
    end
end)
