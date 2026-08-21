local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)
local BallDribble = require(ReplicatedStorage.Shared.BallDribble)

-- Lets players interact with the ball built by BallBuilder.server.luau via
-- two key presses (see BallKickClient.client.luau for both bindings):
--
--   * F kicks the ball, per Slack request ("...надай можливість гравцям
--     копати м'яч"). If the ball is currently being dribbled by anyone
--     (including the kicker), the kick also ends that dribble first, per
--     the later Slack request ("інші гравці ударом F зможуть вибити цей
--     м'яч з режиму ведення").
--
--   * G grabs the ball into "dribble" mode if it's roughly in front of the
--     player and within range, per Slack request ("зроби режим ведення
--     м'яча (на якусь клавішу можна захопити м'яч, який є спереду і м'яч
--     буде котитися спереду всюди куди біжить гравець)"): while dribbling,
--     the ball is anchored and every frame repositioned a fixed distance in
--     front of the dribbling player's HumanoidRootPart, so it follows
--     wherever they run. Pressing G again as the current dribbler releases
--     it without a kick.
--
-- Both remotes only ever *request* an action -- this script alone decides
-- whether it's allowed (range, facing, cooldown, current dribble owner) and
-- what actually happens to the ball, so a modified/replayed client request
-- can't fling the ball around or steal a dribble from out of range.

local KICK_RANGE = 7 -- studs (XZ only) the player's root part must be within
local KICK_SPEED = 55 -- studs/second added along the kick direction
local KICK_UPWARD_SPEED = 8 -- small lift so the ball arcs off the ground like a real kick
local KICK_COOLDOWN = 0.4 -- seconds per player, avoids machine-gunning the ball

local DRIBBLE_CAPTURE_RANGE = 8 -- studs (XZ only) the ball must be within to grab it
local DRIBBLE_MIN_FRONT_DOT = 0.3 -- ball must be roughly in front of the player (within ~70 degrees either side) to grab it
local DRIBBLE_FOLLOW_DISTANCE = 4 -- studs in front of the dribbling player the ball tries to stay
local DRIBBLE_FOLLOW_RESPONSIVENESS = 8 -- how quickly the ball catches up to that spot each second (higher = snappier)

local kickEvent = Instance.new("RemoteEvent")
kickEvent.Name = "KickBall"
kickEvent.Parent = ReplicatedStorage

local dribbleEvent = Instance.new("RemoteEvent")
dribbleEvent.Name = "DribbleBall"
dribbleEvent.Parent = ReplicatedStorage

local lastKickAt: { [Player]: number } = {}

local function getField(): Instance?
	return Workspace:FindFirstChild(FootballConfig.FOLDER_NAME)
end

local function getBall(): BasePart?
	local field = getField()
	if not field then
		return nil
	end
	local ball = field:FindFirstChild(FootballConfig.BALL_NAME)
	if ball and ball:IsA("BasePart") then
		return ball
	end
	return nil
end

local function getRootPart(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end
	return nil
end

local function startDribble(player: Player, ball: BasePart)
	ball.Anchored = true
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		local field = getField()
		local rootPart = getRootPart(player)
		if not field or not rootPart then
			BallDribble.stop(getBall())
			return
		end

		local flatLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
		if flatLook.Magnitude < 0.01 then
			return -- looking straight up/down; keep the ball where it last was
		end
		flatLook = flatLook.Unit

		local targetX = rootPart.Position.X + flatLook.X * DRIBBLE_FOLLOW_DISTANCE
		local targetZ = rootPart.Position.Z + flatLook.Z * DRIBBLE_FOLLOW_DISTANCE
		local groundY = GroundUtils.findGroundY(targetX, targetZ, field)
		local targetPosition = Vector3.new(
			targetX,
			groundY + FootballConfig.BALL_DIAMETER / 2 + FootballConfig.BALL_GROUND_CLEARANCE,
			targetZ
		)

		local alpha = math.clamp(deltaTime * DRIBBLE_FOLLOW_RESPONSIVENESS, 0, 1)
		ball.Position = ball.Position:Lerp(targetPosition, alpha)
	end)

	BallDribble.start(player, connection)
end

local function onDribbleRequest(player: Player)
	if BallDribble.player == player then
		BallDribble.stop(getBall())
		return
	end
	if BallDribble.isDribbling() then
		return -- someone else already has it; only a kick (see onKick) can knock it loose
	end

	local rootPart = getRootPart(player)
	if not rootPart then
		return
	end

	local ball = getBall()
	if not ball or not ball.CanCollide then
		return -- CanCollide is false while the ball is hidden after a goal, see GoalScoring.server.luau
	end

	local delta = ball.Position - rootPart.Position
	local toBall = Vector3.new(delta.X, 0, delta.Z)
	if toBall.Magnitude > DRIBBLE_CAPTURE_RANGE or toBall.Magnitude < 0.01 then
		return
	end

	local flatLook = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if flatLook.Magnitude < 0.01 then
		return
	end

	if flatLook.Unit:Dot(toBall.Unit) < DRIBBLE_MIN_FRONT_DOT then
		return -- ball isn't in front of the player
	end

	startDribble(player, ball)
end

local function onKick(player: Player)
	local now = os.clock()
	local last = lastKickAt[player]
	if last and now - last < KICK_COOLDOWN then
		return
	end

	local rootPart = getRootPart(player)
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

	-- A kick always breaks the ball out of dribble mode, whether it's this
	-- same player releasing it to shoot or a defender knocking it away from
	-- whoever was dribbling it.
	if BallDribble.isDribbling() then
		BallDribble.stop(ball)
	end

	local direction = if toBall.Magnitude > 0.01 then toBall.Unit else rootPart.CFrame.LookVector
	ball.AssemblyLinearVelocity = direction * KICK_SPEED + Vector3.new(0, KICK_UPWARD_SPEED, 0)
end

kickEvent.OnServerEvent:Connect(onKick)
dribbleEvent.OnServerEvent:Connect(onDribbleRequest)

Players.PlayerRemoving:Connect(function(player: Player)
	lastKickAt[player] = nil
	if BallDribble.player == player then
		BallDribble.stop(getBall())
	end
end)
