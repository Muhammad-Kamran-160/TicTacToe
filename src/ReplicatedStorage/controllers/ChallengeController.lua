--[[
	ChallengeController
	Author: Kamran / portodemesso
]]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local ChallengeController = Knit.CreateController {
    Name = "ChallengeController",
}

ChallengeController.ChallengeUI = nil
ChallengeController.RequestsSent = {}  -- keeping record of all requests sent

--Initializing UI, RemoteSignals etc
function ChallengeController:KnitStart()
    local rootUI = LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("Main")
    self.ChallengeUI = rootUI:FindFirstChild("Invite")
	self.InitUI()
  	self.Mark()
    local ChallengeService = Knit.GetService("ChallengeService")
    ChallengeService.GetRequest:Connect(function(playerId: string, playerName: string)
       if self.ChallengeUI then
			local challenger = self.ChallengeUI:FindFirstChild("Challenger")
			if challenger then
				challenger.Value = playerId
			end
          if challenger.Value ~= 0 then
            local description = self.ChallengeUI:FindFirstChild("Body")
            if description then
                description.Text = string.format("<font color='#BB86FC'>%s</font> has sent you an invite to play Tic-Tac-Toe!", playerName)
            end
            self.ChallengeUI.Visible = true
			self.ChallengeUI.sfx:Play()
            task.delay(8, function()
                self.ChallengeUI.Visible = false
                challenger.Value = 0
            end)
          end
       end
    end)
    ChallengeService.RequestRejected:Connect(function(player: Player)
        local index = table.find(self.RequestsSent, player.UserId)
        if index then
            table.remove(self.RequestsSent, index)
            self.ToggleChallengeButton(player.Name, true)
        end
    end)
    ChallengeService.RequestAccepted:Connect(function(player: Player)
        self.RequestsSent = {}
        self.ToggleChallengeButton(player.Name, true)
	end)
	ChallengeService.RemoveBillboardUI:Connect(function(name: string)
		local root = LocalPlayer:WaitForChild("PlayerGui")
		if root:FindFirstChild(name) then
			root:FindFirstChild(name):Destroy()
		end
	end)
	ChallengeService.ToggleBillboardUI:Connect(function(toggle: boolean)
		local root = LocalPlayer:WaitForChild("PlayerGui")
		for _,ui in pairs(root:GetChildren()) do
			if ui:IsA("BillboardGui") then
				ui.Enabled = toggle
			end
		end
	end)
end

--Enable/Disable Challenge Button on Player's head
function ChallengeController:ToggleChallengeButton(playerName: string, toggle: boolean)
    local root = LocalPlayer:WaitForChild("PlayerGui")
    local targetButton = root:FindFirstChild(playerName)
    if targetButton then
        targetButton.Enabled = toggle
    end
end

-- Adding Challenge Button and it's functionality
local function addUI(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	-- Create the UI
	local ui = Instance.new("BillboardGui")
	ui.Name = player.Name
	ui.Active = true
	ui.Size = UDim2.fromScale(4, 1)
	ui.StudsOffset = Vector3.new(0, 4, 0)
	ui.LightInfluence = 0
	ui.MaxDistance = 25
	ui.Adornee = character:WaitForChild("Head", 20)
	ui.Parent = LocalPlayer:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton")
	button.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	button.Size = UDim2.fromScale(1, 1)
	button.TextScaled = true
	button.Text = "Challenge"
	button.Font = Enum.Font.SourceSansSemibold
	button.Parent = ui

	local sound = game.ReplicatedStorage.Sounds:FindFirstChild("click"):Clone()
	if sound then 
		sound.Name = "sfx"
		sound.Parent = button
	end

	Instance.new("UICorner").Parent = button

	-- Button click
	button.Activated:Connect(function()
		if table.find(ChallengeController.RequestsSent, player.UserId) == nil then
			local ChallengeService = Knit.GetService("ChallengeService")
			if button:FindFirstChild("sfx") then
				button:FindFirstChild("sfx")
			end
			ChallengeService:SendRequest(player):andThen(function(result: boolean)
				if result then
					print("request sent successfully")
					table.insert(ChallengeController.RequestsSent, player.UserId)
					ChallengeController.ToggleChallengeButton(player.Name, false)
					task.delay(8, function()
						local index = table.find(ChallengeController.RequestsSent, player.UserId)
						if index then
							table.remove(ChallengeController.RequestsSent, index)
							ChallengeController.ToggleChallengeButton(player.Name, true)
						end
					end)
				else
					print("request failed")
				end
			end)
		else
			print("request already sent")
		end
	end)
end


local function addPlayer(player: Player)
	if player.Character then
		addUI(player)
	end

	player.CharacterAdded:Connect(function()
		addUI(player)
	end)
end

function ChallengeController:Mark(player: Player)
	-- Mark existing players
	for _, player: Player in ipairs(Players:GetPlayers()) do
		if player == LocalPlayer then continue end
		addPlayer(player)
	end
	-- Mark new players
	Players.PlayerAdded:Connect(addPlayer)
end

--UI initializing for notification and button behaviour
function ChallengeController:InitUI()
    if ChallengeController.ChallengeUI then
        local challenger = ChallengeController.ChallengeUI:FindFirstChild("Challenger")
		local options = ChallengeController.ChallengeUI:FindFirstChild("Options")
		for _, button in pairs(options:GetChildren()) do
			if button:IsA("TextButton") then
				button.Activated:Connect(function()
					if challenger.Value ~= 0 then
						local ChallengeService = Knit.GetService("ChallengeService")
						ChallengeService:ProcessRequest(challenger.Value, button.Name):andThen(function(result)
							if result then
								print("request processed successfully")
								if button.Name == "Accept" then
									ChallengeController.RequestsSent = {}
								end
								challenger.Value = 0
								ChallengeController.ChallengeUI.Visible = false
							else
								print("request processing failed")
							end
						end)
					end
					ChallengeController.ChallengeUI.Visible = false
				end)
			end
		end
        
     end
end

return ChallengeController