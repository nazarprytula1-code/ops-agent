local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Press F near the football to kick it (see BallKick.server.luau, which
-- picks the actual direction/force and enforces range + cooldown -- this
-- script only asks the server to kick, it does not move the ball itself).

local KICK_KEY = Enum.KeyCode.F

local kickEvent = ReplicatedStorage:WaitForChild("KickBall") :: RemoteEvent

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == KICK_KEY then
		kickEvent:FireServer()
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
