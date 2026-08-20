local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)

-- Lets any player kick the ball built by BallBuilder.server.luau by pressing
-- a key near it (see BallKickClient.client.luau for the input binding), per
-- Slack request ("...надай можливість гравцям копати м'яч").
--
-- The client only asks to kick -- this script decides the direction (away
-- from the kicking player, toward wherever the ball is) and enforces range
-- and a cooldown itself, so a modified/replayed client request can't fling
-- the ball around at will or spam it.

local KICK_RANGE = 7 -- studs (XZ only) the player's root part must be within
local KICK_SPEED = 55 -- studs/second added along the kick direction
local KICK_UPWARD_SPEED = 8 -- small lift so the ball arcs off the ground like a real kick
local KICK_COOLDOWN = 0.4 -- seconds per player, avoids machine-gunning the ball

local kickEvent = Instance.new("RemoteEvent")
kickEvent.Name = "KickBall"
kickEvent.Parent = ReplicatedStorage

local lastKickAt: { [Player]: number } = {}

local function getBall(): BasePart?
	local field = Workspace:FindFirstChild(FootballConfig.FOLDER_NAME)
	if not field then
		return nil
	end
	local ball = field:FindFirstChild(FootballConfig.BALL_NAME)
	if ball and ball:IsA("BasePart") then
		return ball
	end
	return nil
end

local function onKick(player: Player)
	local now = os.clock()
	local last = lastKickAt[player]
	if last and now - last < KICK_COOLDOWN then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return
	end

	local ball = getBall()
	if not ball then
		return
	end

	local delta = ball.Position - rootPart.Position
	local toBall = Vector3.new(delta.X, 0, delta.Z) -- range/direction ignore height difference
	if toBall.Magnitude > KICK_RANGE then
		return
	end

	lastKickAt[player] = now

	local direction = if toBall.Magnitude > 0.01 then toBall.Unit else rootPart.CFrame.LookVector
	ball.AssemblyLinearVelocity = direction * KICK_SPEED + Vector3.new(0, KICK_UPWARD_SPEED, 0)
end

kickEvent.OnServerEvent:Connect(onKick)

Players.PlayerRemoving:Connect(function(player: Player)
	lastKickAt[player] = nil
end)
