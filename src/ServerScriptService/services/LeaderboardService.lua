--[[
	LeaderboardService
	Author: Kamran / portodemesso
]]
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Data = require(script.Parent.Parent.data)

-- Create the service:
local LeaderboardService = Knit.CreateService {
	Name = "LeaderboardService",
    Client = {},
}

LeaderboardService.MaxTimer = 30  -- Update leaderboard interval
-- Add some methods to the service:

--Get leaderboard part and UI
local function getLeaderboard()
	local Board = workspace:WaitForChild("LeaderboardPart")
	local Template = Board:WaitForChild("Template")
	local Containers = {
		Board.Leaderboard.List;
	}
	return Board, Template, Containers
end

-- Looping function to fetch data after max interval and display it
local function update(Store, Containers, Template)
	local page = Store:GetSortedAsync(false, 14):GetCurrentPage()
	local scores = {}

	for k, data in page do
		if data.value > -1 then
			table.insert(scores, {
				userId = data.key;
				name = Players:GetNameFromUserIdAsync(data.key);
				wins = data.value;
			})
		end
	end

	for _, container in Containers do
		for _, v in container:GetChildren() do
			if v:IsA("Frame") then
				v:Destroy()
			end
		end
	end

	for _, data in scores do
		local card = Template:Clone()
		card.User.Text = data.name
		card.Score.Text = data.wins
		card.HeadShot.Image = Players:GetUserThumbnailAsync(data.userId, Enum.ThumbnailType.AvatarBust, Enum.ThumbnailSize.Size420x420)

		card:Clone().Parent = Containers[1]
		card.Parent = Containers[1]
		card.Visible = true
	end
end

-- Init Ordered Datastore and loop update in Heartbeat
function LeaderboardService:KnitInit()
	local Board, Template, Containers = getLeaderboard()

	local Store = DataStoreService:GetOrderedDataStore("wins")

	local function playerAdded(player)
		Data:addSaveCallback(player, function(profiles)
			local data = profiles.Main.Data

			for _ = 1, 3 do
				local success, message = pcall(function()
					Store:SetAsync(player.UserId, data.TotalWins)
				end)

				if success then
					print("success")
					break
				else
					warn("Error saving leaderboard:", message)
				end

				task.wait(3)
			end            
		end)
	end

	for _, v in Players:GetPlayers() do
		playerAdded(v)
	end
	Players.PlayerAdded:Connect(playerAdded)
	update(Store, Containers, Template)
	local counter = 0
	game:GetService("RunService").Heartbeat:Connect(function(delta)
		counter += delta
		if counter >= self.MaxTimer then
			counter = 0
			update(Store, Containers, Template)
		end
	end)
end

return LeaderboardService