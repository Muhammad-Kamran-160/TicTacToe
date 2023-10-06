--[[
	FetchAssets
	Author: Kamran / portodemesso
]]

--Implementation of assets saving and adding them to git control using remodel. DO NOT delete karta.rbxl.
local game = remodel.readPlaceFile("karta.rbxl")

-- If the directory does not exist yet, we'll create it.
remodel.createDirAll("Assets")
remodel.createDirAll("Assets/Workspace")
remodel.createDirAll("Assets/StarterGui")
remodel.createDirAll("Assets/Lighting")
remodel.createDirAll("src/ReplicatedStorage/Sounds")

local workspaceAssets = game.Workspace

for _,asset in pairs(workspaceAssets:GetChildren()) do
    remodel.writeModelFile("Assets/Workspace/" .. asset.Name .. ".rbxmx", asset)
end

local starterGui = game.StarterGui

for _,ui in pairs(starterGui:GetChildren()) do
    remodel.writeModelFile("Assets/StarterGui/" .. ui.Name .. ".rbxmx", ui)
end

local lighting = game.Lighting

for _,light in pairs(lighting:GetChildren()) do
    remodel.writeModelFile("Assets/Lighting/" .. light.Name .. ".rbxmx", light)
end

local sounds = game.ReplicatedStorage.Sounds

for _,sound in pairs(sounds:GetChildren()) do
    remodel.writeModelFile("src/ReplicatedStorage/Sounds/" .. sound.Name .. ".rbxmx", sound)
end