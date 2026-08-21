local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

-- Kick and grab/dribble the football, per Slack request ("зроби за
-- стандартами роблокс, щоби гравці на телефоні могли теж... захоплювати і
-- бити м'яч"). ContextActionService's `createTouchButton` argument is the
-- standard cross-platform Roblox pattern: it binds the given keyboard
-- key(s) for keyboard/mouse players AND automatically adds an on-screen
-- button for touch (mobile) players, both calling the exact same handler --
-- this replaces the old keyboard-only UserInputService.InputBegan check,
-- which mobile players (no physical keys) could never trigger at all.
--
-- See BallKick.server.luau, which picks the actual direction/force/range/
-- facing checks and enforces cooldowns; this script only asks the server
-- to kick or grab, it never moves the ball itself.

local KICK_ACTION = "KickBall"
local GRAB_ACTION = "GrabBall"

local kickEvent = ReplicatedStorage:WaitForChild("KickBall") :: RemoteEvent
local dribbleEvent = ReplicatedStorage:WaitForChild("DribbleBall") :: RemoteEvent

local function onKickAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		kickEvent:FireServer()
	end
end

local function onGrabAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		dribbleEvent:FireServer()
	end
end

ContextActionService:BindAction(KICK_ACTION, onKickAction, true, Enum.KeyCode.F)
ContextActionService:SetTitle(KICK_ACTION, "Kick")

ContextActionService:BindAction(GRAB_ACTION, onGrabAction, true, Enum.KeyCode.G)
ContextActionService:SetTitle(GRAB_ACTION, "Grab")
