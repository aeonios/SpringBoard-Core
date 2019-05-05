ExportCommand = Command:extends{}
ExportCommand.className = "ExportCommand"

function ExportCommand:init(path)
    self.path = path
    --add extension if it doesn't exist
    if Path.GetExt(self.path) ~= SB_FILE_EXT then
        self.path = self.path .. SB_FILE_EXT
    end
end

local function ScriptTxtSave(path, dev)
    local scriptTxt = SaveCommand.GenerateScript(dev)
    local file = assert(io.open(path, "w"))
    file:write(scriptTxt)
    file:close()
end

function ExportCommand:execute()
    if VFS.FileExists(self.path) then
        Log.Notice("File exists, trying to remove...")
        os.remove(self.path)
    end
    assert(not VFS.FileExists(self.path), "File already exists")

    local projectDir = SB.project.path
    ScriptTxtSave(SB.model.scenarioInfo.name .. "-script.txt")
    ScriptTxtSave(SB.model.scenarioInfo.name .. "-script-DEV.txt", true)

    --Log.Notice("compressing folder...")
    --create an archive from the directory
    VFS.CompressFolder(projectDir, "zip", self.path)
end
