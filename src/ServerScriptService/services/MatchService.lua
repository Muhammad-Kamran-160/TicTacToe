--[[
	MatchService
	Author: Kamran / portodemesso
]]
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Data = require(script.Parent.Parent.data)

-- Create the service:
local MatchService = Knit.CreateService {
    Name = "MatchService",
    Client = {
        NotifyPlayer = Knit.CreateSignal(),
        UpdateBoard = Knit.CreateSignal(),
        GiveTurn = Knit.CreateSignal(),
    },
}

MatchService.games = {}  -- Store information about all ongoing games

-- Add some methods to the service:

--Leaderstats function
local function createStats(name: string, value: number, leaderstats: Instance)
	local stat = Instance.new("IntValue")
	stat.Name = name
	stat.Value = value
	stat.Parent = leaderstats
end

--Update leaderstats upon change in profile data
local function updateStats(player: Player, statName: string, amount: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local stat = leaderstats:FindFirstChild(statName)
		if stat then
			stat.Value = amount
		end
	end
end

--Init leaderstats, remote signals and player leaving edge case handling
function MatchService:KnitInit()
	local function onPlayerAdded(player: Player)
		-- Add player's leaderstats
		local leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player

		-- Add wins value
		Data:getProfile(player):andThen(function(profiles)
			local data = profiles.Main.Data
			local level = data.Level
			local xp = data.Xp
			local totalWins = data.TotalWins
			createStats("Wins", totalWins, leaderstats)
			createStats("XP", xp, leaderstats)
			createStats("Level", level, leaderstats)
		end)
	end

	game.Players.PlayerAdded:Connect(onPlayerAdded)
	
	game.Players.PlayerRemoving:Connect(function(player)
		local matchLeft = nil
		local gameId = nil
		local ChallengeService = Knit.GetService("ChallengeService")
		for _, match in pairs(MatchService.games) do
			if table.find(match.players, player) then
				matchLeft = match
				gameId = _
			end
		end
		if matchLeft and gameId then
			for _,eachPlayer in pairs(matchLeft.players) do
				if eachPlayer ~= player then
					Data:getProfile(eachPlayer):andThen(function(profiles)
						local data = profiles.Main.Data
						local level = data.Level
						local xp = data.Xp
						local totalWins = data.TotalWins
						totalWins += 1
						data.TotalWins = totalWins
						xp += 50
						if xp >= 100 then
							xp -= 100
							level += 1
							data.Level = level
						end
						data.Xp = xp 
						updateStats(eachPlayer,"XP", xp)
						updateStats(eachPlayer,"Level", level)
						updateStats(eachPlayer,"Wins", totalWins)
					end)
					MatchService.Client.NotifyPlayer:Fire(eachPlayer, "win")
					break
				end
			end
		end
		ChallengeService:RemoveBillboard(player.Name)
		ChallengeService:ToggleBillboard(player, true)
		ChallengeService:RemoveRequestUponExit(player.UserId)
	end)
end

--Utility function to check if player is in a game
function MatchService:IsPlayerInMatch(player: Player)
	for _, match in pairs(MatchService.games) do
		if table.find(match.players, player) then
			return true
		end
	end
	return false
end

--Start game upon accepting the challenge invitation
function MatchService:StartGame(player: Player, tplayer: Player)
    -- Check if the player is already in a game
    if player and tplayer then
        for _, match in pairs(MatchService.games) do
			if table.find(match.players, player) or table.find(match.players, tplayer) then
                return  -- Player is already in a game
            end
        end

        local turn = false

        local availableGame = #MatchService.games + 1  -- Create a new game
        turn = true
        MatchService.games[availableGame] = { players = {}, board = {}, turns = {}, winner = nil }

        table.insert(MatchService.games[availableGame].players, player)
        table.insert(MatchService.games[availableGame].players, tplayer)
		MatchService.games[availableGame].board = {0,0,0,0,0,0,0,0,0}
		MatchService.games[availableGame].turns[tplayer] = 1
		MatchService.games[availableGame].turns[player] = -1
		MatchService.Client.GiveTurn:Fire(tplayer, turn, availableGame)
		MatchService.Client.GiveTurn:Fire(player, false, availableGame)

        return availableGame  -- Return the game ID to the client
        
    end
end

--Make a move on board and check for match verdict
function MatchService.Client:MakeMove(player: Player, gameId: number, position: number)
    local match = MatchService.games[gameId]
	if not match then
		return false
	end
	if table.find(match.players, player) == nil then
		return false
	end
	if #match.players ~= 2  then
		return false
	end
	
	if  match.winner then
		return false
	end
	local turn = match.turns[player]
	if match.board[position] == 1 or match.board[position] == -1 then
		return false
	end
	
    local otherPlayer = nil
    for _, tplayer in pairs(match.players) do
        if tplayer ~= player then
            otherPlayer = tplayer
        end
    end

	if not otherPlayer then
        match.winner = player
        MatchService:EndGame(gameId, "win", player)
        return true
    end
	
	match.board[position] = turn
	local verdict = MatchService:CheckResult(match.board, turn)
	if  verdict == "win" then
        match.winner = player
        MatchService:EndGame(gameId, "win", player)
	elseif verdict == "draw" then
        MatchService:EndGame(gameId, "draw")
	else
        MatchService.Client.GiveTurn:Fire(player, false)
        if otherPlayer then
            MatchService.Client.GiveTurn:Fire(otherPlayer, true)
            MatchService.Client.UpdateBoard:Fire(otherPlayer, position)
        end
    end

    return true
end

--Utility function for client to fetch opponent
function MatchService.Client:GetOpponent(player: Player, gameId: number)
    local match = MatchService.games[gameId]

    for _, tplayer in pairs(match.players) do
        if tplayer ~= player and game.Players[tplayer.Name] then
            return tplayer
        end
    end
end

--Win, lose, draw logic
function MatchService:CheckResult(board, turn: number)
	local winningCombinations = {
		{1, 2, 3}, {4, 5, 6}, {7, 8, 9},  -- Rows
		{1, 4, 7}, {2, 5, 8}, {3, 6, 9},  -- Columns
		{1, 5, 9}, {3, 5, 7}             -- Diagonals
	}

	for _, combination in ipairs(winningCombinations) do
		local a, b, c = combination[1], combination[2], combination[3]
		if board[a] == 1 and board[b] == 1 and board[c] == 1 then
			if turn == 1 or turn == -1 then
				return "win"
			else
				return "continue"
			end
		elseif board[a] == -1 and board[b] == -1 and board[c] == -1 then
			if turn == 1 or turn == -1 then
				return "win"
			else
				return "continue"
			end
		end
	end

	for _, value in ipairs(board) do
		if value == 0 then
			return "continue"
		end
	end

	return "draw"
end

--Match ending logic and handling edge cases related to it
function MatchService:EndGame(gameId: number, outcome: string, winner: Player)
    local match = MatchService.games[gameId]
    local otherPlayer = nil
    local originPlayer = nil
	local ChallengeService = Knit.GetService("ChallengeService")

	if match then
		for _, player in pairs(match.players) do
			if winner then
				if player ~= winner then
					Data:getProfile(player):andThen(function(profiles)
						local data = profiles.Main.Data
						local level = data.Level
						local xp = data.Xp
						xp += 10
						if xp >= 100 then
							xp -= 100
							level += 1
							data.Level = level
						end
						data.Xp = xp 
						updateStats(player,"XP", xp)
						updateStats(player,"Level", level)
					end)
					otherPlayer = player
					MatchService.Client.NotifyPlayer:Fire(player, "lost", winner)
					ChallengeService:ToggleBillboard(player, true)
				else
					Data:getProfile(player):andThen(function(profiles)
						local data = profiles.Main.Data
						local level = data.Level
						local xp = data.Xp
						local totalWins = data.TotalWins
						totalWins += 1
						data.TotalWins = totalWins
						xp += 50
						if xp >= 100 then
							xp -= 100
							level += 1
							data.Level = level
						end
						data.Xp = xp 
						updateStats(player,"XP", xp)
						updateStats(player,"Level", level)
						updateStats(player,"Wins", totalWins)
					end)
					originPlayer = player
					MatchService.Client.NotifyPlayer:Fire(player, outcome, winner)
					ChallengeService:ToggleBillboard(player, true)
				end
			else
				Data:getProfile(player):andThen(function(profiles)
					local data = profiles.Main.Data
					local level = data.Level
					local xp = data.Xp
					xp += 10
					if xp >= 100 then
						xp -= 100
						level += 1
						data.Level = level
					end
					data.Xp = xp 
					updateStats(player,"XP", xp)
					updateStats(player,"Level", level)
				end)
				otherPlayer = player
				MatchService.Client.NotifyPlayer:Fire(player, outcome, winner)
				ChallengeService:ToggleBillboard(player, true)
			end
		end
	end

    MatchService.games[gameId] = nil  -- Remove the game instance
	if originPlayer and otherPlayer then
		ChallengeService:RemoveRequestUponCompletion(originPlayer.UserId, otherPlayer.UserId)
	end
end

return MatchService