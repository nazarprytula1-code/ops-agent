local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Press F near the football to kick it, or G (while it's roughly in front
-- of you) to grab it into dribble mode -- see BallKick.server.luau, which
-- picks the actual direction/force/range/facing checks and enforces
-- cooldowns; this script only asks the server to kick or grab, it never
-- moves the ball itself.

local KICK_KEY = Enum.KeyCode.F
local DRIBBLE_KEY = Enum.KeyCode.G

local kickEvent = ReplicatedStorage:WaitForChild("KickBall") :: RemoteEvent
local dribbleEvent = ReplicatedStorage:WaitForChild("DribbleBall") :: RemoteEvent

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end
	if input.KeyCode == KICK_KEY then
		kickEvent:FireServer()
	elseif input.KeyCode == DRIBBLE_KEY then
		dribbleEvent:FireServer()
	end
end

UserInputService.InputBegan:Connect(onInputBegan)
