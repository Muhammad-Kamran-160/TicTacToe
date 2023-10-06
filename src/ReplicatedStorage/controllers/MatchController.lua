--[[
	MatchController
	Author: Kamran / portodemesso
]]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local MatchController = Knit.CreateController {
    Name = "MatchController",
}

local gameSigns = {"×", "O"}

MatchController.BoardUI = nil
MatchController.WinUI = nil
MatchController.LostUI = nil
MatchController.DrawUI = nil
MatchController.GameId = nil
MatchController.Turn = false


--Initializing all related UIs and RemoteSignals
function MatchController:KnitInit()
    local rootUI = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main")
	self.BoardUI = rootUI:FindFirstChild("Game")
    self.WinUI = rootUI:FindFirstChild("Win")
    self.LostUI = rootUI:FindFirstChild("Lose")
    self.DrawUI = rootUI:FindFirstChild("Draw")
	self.InitBoard()
	self.ResetBoardUI()
    local MatchService = Knit.GetService("MatchService")
    MatchService.NotifyPlayer:Connect(function(outcome: string, winner: Player)
        local resultantUI = nil
        if outcome == "lost" then
            resultantUI = self.LostUI
        elseif outcome == "win" then
            resultantUI = self.WinUI
        else
            resultantUI = self.DrawUI
        end
        if resultantUI then
            self.BoardUI.Visible = false
            resultantUI.Visible = true
            resultantUI.sfx:Play()
            task.delay(6, function()
                resultantUI.Visible = false
            end)
		end
		self.ResetBoardUI()
    end)
    MatchService.GiveTurn:Connect(function(turn: boolean, gameId: number)
        if self.GameId == nil then
            self.GameId = gameId
            self.LoadBoard()
        end
        self.Turn = turn
        local opponent = self.BoardUI:FindFirstChild("Opponent")
        opponent.Warning.Visible = self.Turn
    end)
    MatchService.UpdateBoard:Connect(function(position: number)
        if self.BoardUI then
            local buttons = self.BoardUI:FindFirstChild("Board")
            local buttonToUpdate = buttons:FindFirstChild(tostring(position))
            if buttonToUpdate then
                buttonToUpdate.Text = gameSigns[2]
            end
        end
    end)
end

--Simple function to get player thumbnail
local function GetAvatarIcon(userId: number)
    local thumbType = Enum.ThumbnailType.HeadShot
	local thumbSize = Enum.ThumbnailSize.Size420x420
    local content, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)
    if isReady then
        return content
    end
end

--Displaying the board, resetting it and adding button functionality
function MatchController:LoadBoard()
	if MatchController.BoardUI then
		local buttons = MatchController.BoardUI:FindFirstChild("Board")
		local opponent = MatchController.BoardUI:FindFirstChild("Opponent")
		for _,button in pairs(buttons:GetChildren()) do
			if button:IsA("TextButton") then
				button.Text = ""
			end
		end
        local MatchService = Knit.GetService("MatchService")
		MatchService:GetOpponent(MatchController.GameId):andThen(function(player: Player)
            if player then
                if game.Players[player.Name] then
					local userId = player.UserId
					local opponent = MatchController.BoardUI:FindFirstChild("Opponent")
					local localPlayer = MatchController.BoardUI:FindFirstChild("LocalPlayer")
					local opponentAvatar = GetAvatarIcon(userId)
                    local localAvatar = GetAvatarIcon(LocalPlayer.UserId)
                    if opponentAvatar then
                        opponent.HeadShot.Image = opponentAvatar
                    end
                    opponent.User.Text = player.Name
                    if localAvatar then
                        localPlayer.HeadShot.Image = localAvatar
                    end
                    localPlayer.User.Text = game.Players.LocalPlayer.Name
					MatchController.BoardUI.Visible = true
                end
            end
        end)
    end
end

--Resetting board again after match completion
function MatchController:ResetBoardUI()
	if MatchController.BoardUI then
		local buttons = MatchController.BoardUI:FindFirstChild("Board")
		local opponent = MatchController.BoardUI:FindFirstChild("Opponent")
        for _,button in pairs(buttons:GetChildren()) do
            if button:IsA("TextButton") then
                button.Text = ""
            end
        end
        opponent.User.Text = ""
        opponent.HeadShot.Image = ""
        opponent.Warning.Visible = false
		MatchController.GameId = nil
		MatchController.Turn = false
    end
end

--Game logic implementation
function MatchController:InitBoard()
    if MatchController.BoardUI then
		local buttons = MatchController.BoardUI:FindFirstChild("Board")
        for _,button in pairs(buttons:GetChildren()) do
            if button:IsA("TextButton") then
                button.Activated:Connect(function()
					if button.Text == "" and MatchController.Turn then
						local MatchService = Knit.GetService("MatchService")
						local number = tonumber(button.Name)
                        button.sfx:Play()
						MatchService:MakeMove(MatchController.GameId, number):andThen(function(result)
                            if result then
								button.Text = gameSigns[1]
							else
								print("move failed")
                            end
                        end)
                    end
                end)
            end
        end
    end
end

return MatchController