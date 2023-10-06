--[[
	KnitClient
	Author: Kamran / portodemesso
]]
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

Knit.AddControllers(game:GetService("ReplicatedStorage").controllers)

Knit.Start():andThen(function()
    print("Knit Started on Client")
end)