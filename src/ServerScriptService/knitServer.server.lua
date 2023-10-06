--[[
	KnitServer
	Author: Kamran / portodemesso
]]
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

Knit.AddServices(game:GetService("ServerScriptService").services)

Knit.Start():andThen(function()
    print("Knit Started on Server")
end)