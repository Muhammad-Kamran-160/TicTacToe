--[[
	DataHandler
	Author: Kamran / portodemesso
]]
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- Constants
local Packages = ReplicatedStorage:WaitForChild("Packages")

local ProfileService = require(ServerScriptService.ProfileService)
local Promise = require(Packages:WaitForChild("Promise"))

-- Variables
local Handler = {
    _getCache = {};
}
Handler.__index = Handler

-- Constructor
Handler.new = function(Templates)
    local self = setmetatable({}, Handler)

    self.Templates = Templates
    self.Profiles = {}
    self.Callbacks = {}

    return self
end

-- Functions
Handler.setup = function(self)
    local function load(player)
        task.spawn(function()
            self:loadPlayerProfiles(player)
        end)
    end

    for _, player in Players:GetPlayers() do
        load(player)
    end
    Players.PlayerAdded:Connect(load)

    Players.PlayerRemoving:Connect(function(player)
        local profiles = self.Profiles[player]

        if profiles then
            print("Releasing profiles: PLAYER_REMOVING",player.Name)
            if self.Callbacks[player] then
                for _, callback in self.Callbacks[player] do
                    callback(profiles)
                end
            end

            for _, profile in profiles do
                profile:Release()
            end
        end

        self.Profiles[player] = nil
    end)

    task.spawn(function()
        while task.wait(2.5) do
            self:resolveCache()
        end
    end)
end

Handler.loadPlayerProfiles = function(self, player)
    print("Attempting to load data for " .. player.Name)

    local playerProfiles = {}

    for Name, Template in self.Templates do
        local profileStore = ProfileService.GetProfileStore(Name, Template)
        local profile = profileStore:LoadProfileAsync("player_" .. tostring(player.UserId))

        if profile == nil then
            return player:Kick("Error loading data")
        end

        profile:AddUserId(player.UserId)
        profile:Reconcile()
        profile:ListenToRelease(function()
            self.Profiles[player] = nil
            player:Kick("Data was released")
        end)

        if player:IsDescendantOf(Players) then
            playerProfiles[Name] = profile
        else
            print("Profile was released: DESCENDANT_INVALID",player:GetFullName())
            return profile:Release()
        end
    end

    if player:IsDescendantOf(Players) then
        self.Profiles[player] = playerProfiles
    end

    self:resolveCache()
end

Handler.resolveCache = function(self)
    for index, record in Handler._getCache do
        local profile = self.Profiles[record.player]

        if profile ~= nil then
            record.resolve(profile)
            table.remove(self._getCache, index)
        end
    end
end

Handler.getProfile = function(self, player)
    return Promise.new(function(resolve, reject)
        if not player:IsDescendantOf(Players) then
            return reject("invalid player")
        end

        local profile = self.Profiles[player]

        if profile then
            resolve(profile)
        else
            table.insert(Handler._getCache, {
                player = player;
                resolve = resolve;
            })
        end
    end)
end

Handler.isProfileLoaded = function(self, player)
    return self.Profiles[player] and true or false
end

Handler.addSaveCallback = function(self, player, callback)
    if not self.Callbacks[player] then
        self.Callbacks[player] = {}
    end

    table.insert(self.Callbacks[player], callback)
end

return Handler
