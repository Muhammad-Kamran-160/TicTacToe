--[[
	DataWrapper
	Author: Kamran / portodemesso
]]
-- Services

-- Constants
local Profiles = require(script.profiles)
local Handler = require(script.handler)

-- Variables
local data = Handler.new(Profiles)
data.setup(data)


-- Main
return data