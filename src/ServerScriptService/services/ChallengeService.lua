--[[
	ChallengeService
	Author: Kamran / portodemesso
]]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Create the service:
local ChallengeService = Knit.CreateService {
    Name = "ChallengeService",
    Client = {
        GetRequest = Knit.CreateSignal(),
        RequestRejected = Knit.CreateSignal(),
		RequestAccepted = Knit.CreateSignal(),
		RemoveBillboardUI = Knit.CreateSignal(),
        ToggleBillboardUI = Knit.CreateSignal(),
    },
}

ChallengeService.requests = {}  -- Store information about all ongoing requests


-- Add some methods to the service:
function ChallengeService.Client:SendRequest(player: Player, tplayer: Player)
   local MatchService = Knit.GetService("MatchService")
   if MatchService:IsPlayerInMatch(tplayer) then
        return false
   end
   if player and tplayer then
        local found = false
        for _, request in pairs(ChallengeService.requests) do
            if (request.sender == tplayer.UserId and request.receiver == player.UserId) or (request.sender == player.UserId and request.receiver == tplayer.UserId) then
                found = true
                break
            end
        end
        if not found then
            table.insert(ChallengeService.requests, {
                sender = player.UserId;
                receiver = tplayer.UserId;
                status = "pending";
            })
			ChallengeService.Client.GetRequest:Fire(tplayer, player.userId, player.Name)
			task.delay(8, function()
				local index = nil
				for _, request in pairs(ChallengeService.requests) do
					if (request.sender == player.UserId and request.receiver == tplayer.UserId) then
						index = _
						break
					end
				end
				if index then
					table.remove(ChallengeService.requests, index)
				end
			end)
            return true
        end
   end
   return false
end

function ChallengeService.Client:ProcessRequest(player: Player, challengerId: number, action: string)
	local tplayer = game.Players:GetPlayerByUserId(challengerId)
	if player and tplayer then
         local index = nil
         for _, request in pairs(ChallengeService.requests) do
            if request.sender == challengerId and request.receiver == player.UserId then
                index = _
                break
            end
         end
         if index then 
            if action == "Reject" then
                ChallengeService.Client.RequestRejected:Fire(tplayer, player)
                table.remove(ChallengeService.requests, index)
            else
                ChallengeService.Client.RequestAccepted:Fire(tplayer, player)
                ChallengeService.requests[index].status = "accepted"
				local MatchService = Knit.GetService("MatchService")
				local gameId = MatchService:StartGame(player, tplayer)
				if gameId then
					print(gameId.." match has started b/w "..player.Name.." "..tplayer.Name)
                    ChallengeService.Client.ToggleBillboardUI:Fire(player, false)
                    ChallengeService.Client.ToggleBillboardUI:Fire(tplayer, false)
				else
					ChallengeService.RemoveRequestUponCompletion(player.UserId, tplayer.UserId)
				end
            end
         end
    end
 end

 -- Completed requests cleanup after match ending
 function ChallengeService:RemoveRequestUponCompletion(playerId: number, tplayerId: number)
    local index = nil
    for _, request in pairs(ChallengeService.requests) do
       if (request.sender == playerId and request.receiver == tplayerId and request.status == "accepted") or ((request.sender == tplayerId and request.receiver == playerId and request.status == "accepted")) then
           index = _
           break
       end
    end
    if index then 
        table.remove(ChallengeService.requests, index)
    end
end

-- Cleanup requests if player leaves
function ChallengeService:RemoveRequestUponExit(playerId: number)
	local indexes = {}
	for _, request in pairs(ChallengeService.requests) do
		if request.sender == playerId or request.receiver == playerId then
			table.insert(indexes, _)
		end
	end
	for _,index in pairs(indexes) do
		table.remove(ChallengeService.requests, index)
	end
end

--Remove Challenge Button if player leaves
function ChallengeService:RemoveBillboard(name: string)
	ChallengeService.Client.RemoveBillboardUI:FireAll(name)
end

function ChallengeService:ToggleBillboard(player: Player, toggle: boolean)
	ChallengeService.Client.ToggleBillboardUI:Fire(player, toggle)
end



return ChallengeService