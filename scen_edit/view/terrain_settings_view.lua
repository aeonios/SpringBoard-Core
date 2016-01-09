SCEN_EDIT.Include(SCEN_EDIT_VIEW_DIR .. "editor_view.lua")
TerrainSettingsView = EditorView:extends{}

function TerrainSettingsView:init()
    self:super("init")

    self.images = ImageListView:New {
        padding = {0, 0, 0, 0},
        dir = SCEN_EDIT_IMG_DIR .. "resources/skyboxes",
        width = "100%",
        height = "100%",
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.images.OnSelectItem = {
        function(obj, itemIdx, selected)
			if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
				SCEN_EDIT.delayGL(function()
					local item = self.images.items[itemIdx]
-- 					Spring.Echo(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_2D)
-- 					
-- 					local tex = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
-- -- 						target = 0x8513,
-- 						min_filter = GL.LINEAR,
-- 						mag_filter = GL.LINEAR,
-- 						fbo = true,
-- 					})
-- -- 					gl.Texture(item)
-- 					Spring.Echo(texInfo.xsize, texInfo.ysize, item)
-- 					SCEN_EDIT.model.textureManager:Blit(item, tex)
					local texInfo = gl.TextureInfo(item)
					Spring.SetSkyBoxTexture(item)
				end)
			end

        end
    }
	
	
    self.images2 = ImageListView:New {
        padding = {0, 0, 0, 0},
        dir = SCEN_EDIT_IMG_DIR .. "resources/brush_patterns/detail",
        width = "100%",
        height = "100%",
    }
    -- FIXME: implement a button for entering the mode instead of image selection
    self.images2.OnSelectItem = {
        function(obj, itemIdx, selected)
			if selected and itemIdx > 0 and itemIdx > obj._dirsNum + 1 then
				SCEN_EDIT.delayGL(function()
					local item = self.images2.items[itemIdx]
-- 					Spring.Echo(GL.TEXTURE_CUBE_MAP, GL.TEXTURE_2D)
-- 					
-- 					local tex = gl.CreateTexture(texInfo.xsize, texInfo.ysize, {
-- -- 						target = 0x8513,
-- 						min_filter = GL.LINEAR,
-- 						mag_filter = GL.LINEAR,
-- 						fbo = true,
-- 					})
-- -- 					gl.Texture(item)
-- 					Spring.Echo(texInfo.xsize, texInfo.ysize, item)
-- 					SCEN_EDIT.model.textureManager:Blit(item, tex)
					local texInfo = gl.TextureInfo(item)
					gl.DeleteTexture(item)
					gl.Texture(item)
					Spring.SetMapShadingTexture("$detail", item)
				end)
			end

        end
    }

    self:AddControl("sun-sep", {
        Label:New {
            caption = "Sun",
        },
        Line:New {
            x = 50,
            width = self.VALUE_POS,
        }
    })
    self.initializing = true
    self:AddField(GroupField({
        NumericField({
            name = "sunDirX",
            title = "Dir X:",
            tooltip = "X dir",
            value = 0,
            step = 0.002,
            width = 100,
        }),
        NumericField({
            name = "sunDirY",
            title = "Dir Y:",
            tooltip = "Y dir",
            value = 0,
            step = 0.002,
            width = 100,
        }),
        NumericField({
            name = "sunDirZ",
            title = "Dir Z:",
            tooltip = "Z dir",
            value = 0,
            step = 0.002,
            width = 100,
        }),
    }))
    self:AddControl("sun-ground-sep", {
        Label:New {
            caption = "Sun ground color",
        },
        Line:New {
            x = 150,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        ColorField({
            name = "groundSunColor",
            title = "Diffuse:",
            tooltip = "Ground diffuse color",
            width = 150,
        }),
        ColorField({
            name = "groundAmbientColor",
            title = "Ambient:",
            tooltip = "Ground ambient color",
            width = 150,
        }),
        ColorField({
            name = "groundSpecularColor",
            title = "Specular:",
            tooltip = "Ground specular color",
            width = 150,
        }),
    }))
	self:AddControl("sun-unit-sep", {
        Label:New {
            caption = "Sun unit color",
        },
        Line:New {
            x = 150,
            width = self.VALUE_POS,
        }
    })
    self:AddField(GroupField({
        ColorField({
            name = "unitSunColor",
            title = "Diffuse:",
            tooltip = "Unit diffuse color",
            width = 150,
        }),
        ColorField({
            name = "unitAmbientColor",
            title = "Ambient:",
            tooltip = "Unit ambient color",
            width = 150,
        }),
        ColorField({
            name = "unitSpecularColor",
            title = "Specular:",
            tooltip = "Unit specular color",
            width = 150,
        }),
    }))
--     self:AddField(GroupField({
--         NumericField({
--             name = "sunDistance",
--             title = "Sun distance:",
--             tooltip = "Sun distance",
--             value = 0,
--             step = 0.002,
--             width = 150,
--             minValue = -1,
--             maxValue = 1,
--         }),
--         NumericField({
--             name = "sunStartAngle",
--             title = "Start angle:",
--             tooltip = "Sun start angle",
--             value = 0,
--             step = 0.002,
--             width = 150,
--         }),
--         NumericField({
--             name = "sunOrbitTime",
--             title = "Orbit time:",
--             tooltip = "Sun orbit time",
--             value = 0,
--             step = 0.002,
--             width = 100,
--         }),
--     }))
    self:UpdateSun()

    local children = {
		ScrollPanel:New {
			x = 0, 
			right = 0,
			y = 70, 
			height = "15%",
			children = { 
				self.images,
			}
		},
		ScrollPanel:New {
			x = 0, 
			right = 0,
			y = "60%", 
			height = "35%",
			children = { 
				self.images2,
			}
		},
		ScrollPanel:New {
			x = 0,
			y = "25%",
			height = "40%",
			right = 0,
			borderColor = {0,0,0,0},
			horizontalScrollbar = false,
			children = { self.stackPanel },
		},
	}

	self:Finalize(children)
    self.initializing = false
end

function _ColorArrayToChannels(colorArray)
    return {r = colorArray[1], g = colorArray[2], b = colorArray[3], a = colorArray[4]}
end

function TerrainSettingsView:UpdateSun()
    local sunDirX, sunDirY, sunDirZ = gl.GetSun()
--     local sunDirX, sunDirY, sunDirZ, sunDistance, sunStartAngle, sunOrbitTime = gl.GetSun()
    self:Set("sunDirX", sunDirX)
    self:Set("sunDirY", sunDirY)
    self:Set("sunDirZ", sunDirZ)
    local groundDiffuse = {gl.GetSun("diffuse")}
    groundDiffuse[4] = 1
    local groundAmbient = {gl.GetSun("ambient")}
    groundAmbient[4] = 1
    local groundSpecular = {gl.GetSun("specular")}
    groundSpecular[4] = 1
    self:Set("groundSunColor", groundDiffuse)
    self:Set("groundAmbientColor", groundAmbient)
    self:Set("groundSpecularColor", groundSpecular)
    local unitDiffuse = {gl.GetSun("diffuse", "unit")}
    local unitAmbient = {gl.GetSun("ambient", "unit")}
    local unitSpecular = {gl.GetSun("specular", "unit")}
    unitSpecular[4] = 1
    self:Set("unitSunColor", unitDiffuse)
    self:Set("unitAmbientColor", unitAmbient)
    self:Set("unitSpecularColor", unitSpecular)
--     table.echo({groundDiffuse, groundAmbient, groundSpecular})
    self.dynamicSunEnabled = false
--     if sunStartAngle then
--         -- FIXME: distance is wrong, not usable atm
-- --         self.dynamicSunEnabled = true
--         self:Set("sunDistance", sunDistance)
--         self:Set("sunStartAngle", sunStartAngle)
--         self:Set("sunOrbitTime", sunOrbitTime)
--     end
end

function TerrainSettingsView:OnFieldChange(name, value)
    if self.initializing then
        return
    end
    if name == "sunDirX" or name == "sunDirY" or name == "sunDirZ" or name == "sunStartAngle" or name == "sunOrbitTime" or name == "sunDistance" then
        value = { dirX = self.fields["sunDirX"].value,
                  dirY = self.fields["sunDirY"].value,
                  dirZ = self.fields["sunDirZ"].value,
--                   distance = self.fields["sunDistance"].value,
--                   startAngle = self.fields["sunStartAngle"].value,
--                   orbitTime = self.fields["sunOrbitTime"].value,
        }
--         if not self.dynamicSunEnabled then
--             value.distance = nil
--             value.startAngle = nil
--             value.orbitTime = nil
--         end
        local cmd = SetSunParametersCommand(value)
        SCEN_EDIT.commandManager:execute(cmd)
		return
    end
	local t = {}
	if name == "unitAmbientColor" or name == "unitSunColor" then
		value[4] = 1
    else
        value[4] = nil
    end
	t[name] = value
	Spring.SetSunLighting(t)
end