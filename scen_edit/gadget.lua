if (gadgetHandler:IsSyncedCode()) then

-- Unused
-- function WidgetCallback(f, params, msgID)
--     local result = {f(unpack(params))}
--     SendToUnsynced("toWidget", table.show{
--         tag = "msg",
--         data = {
--             result = result,
--             msgID = msgID,
--         },
--     })
-- end

local msgParts = {}
local msgPartsSize = 0
local __populatedTeam = false

function gadget:RecvLuaMsg(msg, playerID)
    if #msg < #SB.messageManager.prefix or msg:sub(1, #SB.messageManager.prefix) ~= SB.messageManager.prefix then
        return
    end

    local msgParams = String.Split(msg, '|')
    local op = msgParams[2]
    local par1 = msgParams[3]

    --TODO: figure proper msg name :)
    if op == 'game' then
        local msgParsed = msg:sub(#(SB.messageManager.prefix .. "|" .. op .. "|") + 1)
        -- The package is eventually packed and then compressed. So we must
        -- first uncompress, and then unpack
        if SB.messageManager.compress then
            msgParsed = SB.ZlibDecompress(msgParsed)
        end
        local success, msgTable
        if SB.messageManager.pack then
            success, msgTable = pcall(function()
                return SB.messageManager.packer.unpack(msgParsed)
            end)
        else
            -- FIXME: not super safe to read lua code like this
            -- Jose Luis Cercos-Pita: Packing and unpacking is an efficient way to
            -- fix that
            success, msgTable = pcall(function()
                return assert(loadstring(msgParsed))()
            end)
        end
        if not success then
            Log.Error("Failed to load command (size: " .. #msgParsed .. "): ")
            Log.Error(msgTable)
            Log.Error(msgParsed)
            return
        end
        local msgObj = Message(msgTable.tag, msgTable.data)
        if msgObj.tag == 'event' then
            local data = msgObj.data
            SB.rtModel:OnEvent(data.eventName, data.params)
        end
    elseif op == 'meta' then
        Log.Notice("Send meta data signal")
    else
        if op == 'sync' then
            local msgParsed = msg:sub(#(SB.messageManager.prefix .. "|" .. op .. "|") + 1)
            if SB.messageManager.compress then
                msgParsed = SB.ZlibDecompress(msgParsed)
            end
            local success, msgTable
            if SB.messageManager.pack then
                success, msgTable = pcall(function()
                    return SB.messageManager.packer.unpack(msgParsed)
                end)
            else
                success, msgTable = pcall(function()
                    return assert(loadstring(msgParsed))()
                end)
            end
            if not success then
                Log.Error("Failed to load command (size: " .. #msgParsed .. "): ")
                Log.Error(msgTable)
                Log.Error(msgParsed)
                return
            end
            local msgObj = Message(msgTable.tag, msgTable.data)
            if msgObj.tag == 'command' then
                if Spring.GetGameRulesParam("sb_gameMode") ~= "play" or SB.project.path ~= nil then
                    SB.commandManager:HandleCommandMessage(msgObj)
                else
                    Log.Warning("Command ignored: ", msgTable.data)
                end
            end
        elseif op == 'startMsgPart' then
            msgPartsSize = tonumber(par1)
        elseif op == "msgPart" then
            local index = tonumber(par1)
            local value = msg:sub(#(SB.messageManager.prefix .. "|" .. op .. "|" .. par1 .. "|") + 1)
            msgParts[index] = value
            if #msgParts == msgPartsSize then
                local fullMessage = ""
                for _, part in pairs(msgParts) do
                    fullMessage = fullMessage .. part
                end
                msgPartsSize = 0
                msgParts = {}

                self:RecvLuaMsg(fullMessage, playerID)
            end
        end
    end
end

function gadget:Initialize()
    --Spring.RevertHeightMap(0, 0, Game.mapSizeX, Game.mapSizeZ, 1)
    VFS.Include("scen_edit/include.lua")

    Project.ParseModOpts()
    SB.project = Project.InitializeFromEnvironment()

    --FIXME: shouldn't be here(?)
    SB.conf = Conf()
    SB.metaModel = MetaModel()

    --TODO: relocate this
    MetaModelLoader.Load()

    SB.model = Model()

    SB.messageManager = MessageManager()
    SB.commandManager = CommandManager()

    SB.rtModel = RuntimeModel()

    SB.displayUtil = DisplayUtil()

    SB.executeDelayed("Initialize")
    --populate the managers now that the listeners are set
    SB.loadFrame = Spring.GetGameFrame() + 1
end

function Load()
    if SB.__populated then
        return
    end

    s11n:Populate()
    SB.__populated = true

    pcall(function()
        local OnStartEditingSynced = SB.model.game.OnStartEditingSynced
        if OnStartEditingSynced then
            OnStartEditingSynced()
        end
    end)
end

function gadget:GamePreload()
    -- We cannot load it in GamePreload because LuaUI won't get modelIDs right apparently
    -- Load()
end

function gadget:GameFrame(frameNum)
    if SB.__populated and not __populatedTeam then
        SB.model.teamManager:populate()
        __populatedTeam = true
    end

    SB.executeDelayed("GameFrame")
    SB.rtModel:GameFrame(frameNum)

    --wait a bit before populating everything (so luaui is loaded)
    if SB.loadFrame == frameNum then
        Load()
    end
end

function gadget:Update()
    --SB.executeDelayed()
end

function gadget:TeamDied(teamID)
    SB.rtModel:TeamDied(teamID)
end

function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
    SB.rtModel:UnitCreated(unitID, unitDefID, teamID, builderID)
    -- FIXME: Remove MCL specific hacks
    if Game.gameShortName == "SE MCL" and (unitDefID == 9 or unitDefID == 49) then
        return
    end
    if not SB.rtModel.hasStarted then
        -- FIXME: hack to prevent units being frozen if startCommand is executed in the same frame
        if Spring.GetGameRulesParam("sb_gameMode") == "play" then
            return
        end
        if not SB_USE_PLAY_PAUSE then
            --Spring.MoveCtrl.Enable(unitID)
            --Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { 0 }, {})
            SB.delay(function()
                Spring.SetUnitHealth(unitID, { paralyze = math.pow(2, 32) })
            end)
        end
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    SB.rtModel:UnitDamaged(unitID)
end

function gadget:UnitDestroyed(unitID, ...)
    SB.rtModel:UnitDestroyed(unitID, ...)
end

function gadget:UnitFinished(unitID, unitDefID, teamID)
    SB.rtModel:UnitFinished(unitID)
end

function gadget:FeatureCreated(featureID, allyTeam)
    SB.rtModel:FeatureCreated(featureID, allyTeam)
end

function gadget:FeatureDamaged(featureID, ...)
    SB.rtModel:FeatureDamaged(featureID, ...)
end

function gadget:FeatureDestroyed(featureID, ...)
    SB.rtModel:FeatureDestroyed(featureID, ...)
end

--[[
function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defaultPriority)
--    return true, 1
--    return false, 1000
end

function gadget:AllowWeaponTargetCheck(attackerID, attackerWeaponNum, attackerWeaponDefID)
--    return true
end
--]]
else --unsynced

local function UnsyncedToWidget(_, data)
    if not Script.LuaUI('RecieveGadgetMessage') then
        Spring.Log("SpringBoard", LOG.ERROR, "Missing RecieveGadgetMessage in LuaUI")
        return
    end
    Script.LuaUI.RecieveGadgetMessage(data)
end

function gadget:Initialize()
    gadgetHandler:AddSyncAction('toWidget', UnsyncedToWidget)
end

end
