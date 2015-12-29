SCEN_EDIT.Include("scen_edit/state/abstract_map_editing_state.lua")
BrushObjectState = AbstractMapEditingState:extends{}

function BrushObjectState:init(editorView, objectDefIDs)
    AbstractMapEditingState.init(self, editorView)

    self.objectDefIDs = objectDefIDs
    self.randomSeed = os.clock()

    self.spread  = self.editorView.fields["spread"].value
    self.noise   = self.editorView.fields["noise"].value
    self.team    = self.editorView.fields["team"].value

    self.applyDelay          = 0.1
    self.initialDelay        = 0
    self.tolerance           = 5
end

function BrushObjectState:GetApplyParams(x, z, button)
	return x, z, button
end

function BrushObjectState:FilterObject(objectID)
    local objectDefID = self.bridge.spGetObjectDefID(objectID)
    local isApproved = false
    for _, approvedObjectDefID in pairs(self.objectDefIDs) do
        if approvedObjectDefID == objectDefID then
            isApproved = true
            break
        end
    end
    return isApproved
end

function sunflower(n, alpha)   --  example: n=500, alpha=2
    local b = math.floor(alpha * math.sqrt(n) + 0.5)      -- number of boundary points 
    local phi = (math.sqrt(5)+1) / 2           -- golden ratio
    local points = {}
    for k = 1, n do
        r = radius(k,n,b);
        theta = 2 * math.pi * k / (phi * phi);
        table.insert(points, {r*math.cos(theta), r*math.sin(theta)})
        --plot(r*cos(theta), r*sin(theta), 'r*');
    end
    return points
end

function radius(k, n, b)
    if k > n - b then
        return 1 -- put on the boundary
    else 
        return math.sqrt(k-1/2)/math.sqrt(n-(b+1)/2)  -- apply square root
    end
end


function BrushObjectState:Apply(bx, bz, button)
    local existing = {}
    local radius = self.size * math.sqrt(2)
    for _, objectID in pairs(self.bridge.spGetObjectsInCylinder(bx, bz, radius)) do
        if button == 3 or self:FilterObject(objectID) then
            table.insert(existing, objectID)
        end
    end
    math.randomseed(self.randomSeed)
    local commands = {}
    if button == 1 then
        if self.objectDefIDs and #self.objectDefIDs > 0 then
            local numPoints = math.ceil(self.size * self.size / self.spread / self.spread)
            local points = sunflower(numPoints, 2)   --  example: n=500, alpha=2
            for i = 1, #points do
                local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]
                local angle = math.random() * math.pi * 2
                local x, z = bx + points[i][1] * radius/2, bz + points[i][2] * radius/2
                x, z = x + math.random() * self.noise - self.noise / 2, z + math.random() * self.noise - self.noise / 2
                local alreadyPlaced = false
                for _, objectID in pairs(self.bridge.spGetObjectsInCylinder(x, z, self.spread - self.tolerance)) do
                    if self:FilterObject(objectID) then
                        alreadyPlaced = true
                        break
                    end
                end
                if not alreadyPlaced then
                    local y = Spring.GetGroundHeight(x, z)
                    local dirX = math.sin(angle)
                    local dirZ = math.cos(angle)
                    local cmd = self.bridge.AddObjectCommand({
                        defName = objectDefID,
                        pos = { x = x, y = y, z = z },
                        dir = { x = dirX, y = 0, z = dirZ },
                        team = self.team,
                    })
                    commands[#commands + 1] = cmd
                end
            end
            self.randomSeed = os.clock()
        end
    elseif button == 3 then
        for i = 1, #existing do
            local cmd = self.bridge.RemoveObjectCommand(existing[i])
            commands[#commands + 1] = cmd
        end
    end

    if #commands > 0 then
        local compoundCommand = CompoundCommand(commands)
        SCEN_EDIT.commandManager:execute(compoundCommand)
    end
    self.randomSeed = self.randomSeed + os.clock()
    return true
end

function BrushObjectState:KeyPress(key, mods, isRepeat, label, unicode)
    -- FIXME: cannot use "super" here in the current version of LCS and the new version is broken
    if AbstractMapEditingState.KeyPress(self, key, mods, isRepeat, label, unicode) then
        return true
    end
--     if key == 49 then -- 1
--         local newState = TerrainShapeModifyState(self.editorView)
--         if self.size then
--             newState.size = self.size
--         end
--         SCEN_EDIT.stateManager:SetState(newState)
--     elseif key == 50 then -- 2
--         local newState = TerrainSmoothState(self.editorView)
--         if self.size then
--             newState.size = self.size
--         end
--         SCEN_EDIT.stateManager:SetState(newState)
--     else
--         return false
--     end
    return false
end

function BrushObjectState:DrawObject(object, bridge)
    gl.PushMatrix()
    local objectDefID         = object.objectDefID
    local objectTeamID        = object.objectTeamID
    local pos                 = object.pos
    bridge.DrawObject({
        color           = { r = 0.4, g = 1, b = 0.4, a = 0.8 },
        objectDefID     = objectDefID,
        objectTeamID    = objectTeamID,
        pos             = pos,
        angle           = { x = 0, y = 0, z = 0 },
    })
    gl.PopMatrix()
end

function BrushObjectState:DrawWorld()
    local x, y = Spring.GetMouseState()
    local result, coords = Spring.TraceScreenRay(x, y, true)
    if result ~= "ground" then
        return
    end
    local baseX, baseY, baseZ = unpack(coords)
    gl.PushMatrix()
    gl.Color(0, 1, 0, 0.3)
    --gl.DepthTest(true)
    gl.Utilities.DrawGroundCircle(baseX, baseZ, self.size)
    gl.PopMatrix()

    if not self.objectDefIDs or #self.objectDefIDs == 0 then
        return
    end
    math.randomseed(self.randomSeed)
    local objectDefID = self.objectDefIDs[1]
    --local objectDefID = self.objectDefIDs[math.random(1, #self.objectDefIDs)]

    gl.PushMatrix()
    local shaderObj = SCEN_EDIT.view.modelShaders:GetShader()
    gl.UseShader(shaderObj.shader)
    gl.Uniform(shaderObj.timeID, os.clock())
    baseY = Spring.GetGroundHeight(baseX, baseZ)
    local object = {
        objectDefID = objectDefID,
        objectTeamID = self.team,
        pos = { x = baseX, y = baseY, z = baseZ },
    }
    self:DrawObject(object, self.bridge)
    gl.UseShader(0)
    gl.PopMatrix()
end

-- Custom unit/feature classes
BrushUnitState = BrushObjectState:extends{}
function BrushUnitState:init(...)
    BrushObjectState.init(self, ...)
    self.bridge = unitBridge
end

BrushFeatureState = BrushObjectState:extends{}
function BrushFeatureState:init(...)
    BrushObjectState.init(self, ...)
    self.bridge = featureBridge
end