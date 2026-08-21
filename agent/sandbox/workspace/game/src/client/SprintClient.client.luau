local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

-- Sprint (hold Shift), per Slack request ("добав режим пришвидшення, як
-- правило кнопка шіфт... зроби за стандартами роблокс, щоби гравці на
-- телефоні могли теж прискорюватися"). ContextActionService's
-- `createTouchButton` argument is the standard cross-platform Roblox
-- pattern: it binds Shift for keyboard players AND automatically adds an
-- on-screen button for touch (mobile) players, both calling the exact same
-- handler.
--
-- This script only tells the server whether the local player wants to
-- sprint right now -- PlayerBootstrap.server.luau is the one that decides
-- the resulting Humanoid.WalkSpeed from GameConfig, instead of trusting a
-- client-chosen speed value.

local SPRINT_ACTION = "Sprint"

local setSprintingEvent = ReplicatedStorage:WaitForChild("SetSprinting") :: RemoteEvent

local function onSprintAction(_actionName: string, inputState: Enum.UserInputState)
	if inputState == Enum.UserInputState.Begin then
		setSprintingEvent:FireServer(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setSprintingEvent:FireServer(false)
	end
end

ContextActionService:BindAction(SPRINT_ACTION, onSprintAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift)
ContextActionService:SetTitle(SPRINT_ACTION, "Sprint")
