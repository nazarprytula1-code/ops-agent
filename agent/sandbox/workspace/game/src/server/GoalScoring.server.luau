local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)

-- Watches the ball built by BallBuilder.server.luau and, per Slack request,
-- counts a goal for the right team as soon as it reaches the net inside
-- either goal frame (built by FootballFieldBuilder.server.luau), updates the
-- big scoreboard (built by ScoreboardBuilder.server.luau), then hides the
-- ball and respawns it at the pitch's center after GOAL_RESPAWN_DELAY.
--
-- Goal detection is a simple position check against each goal's box (from
-- the goal line back to the net, across the goal mouth, from the pitch
-- surface up to the crossbar) polled on Heartbeat, rather than a Touched
-- event on a thin sensor plate: the goal's back net is solid (CanCollide
-- true, see FootballFieldBuilder), so a scoring ball is physically stopped
-- and lingers inside that box for many frames -- a position check can't
-- miss it the way a Touched event on a fast-moving ball sometimes can.
--
-- TEAM_A defends the west goal (scores when the ball reaches the EAST
-- goal's net); TEAM_B defends the east goal (scores when the ball reaches
-- the WEST goal's net) -- see FootballConfig for the naming.

local FIELD = FootballConfig.FIELD_POSITION
local LENGTH = FootballConfig.FIELD_LENGTH
local GOAL_WIDTH = FootballConfig.GOAL_WIDTH
local GOAL_HEIGHT = FootballConfig.GOAL_HEIGHT
local GOAL_DEPTH = FootballConfig.GOAL_DEPTH
local GOAL_NET_GAP = FootballConfig.GOAL_NET_GAP
local PITCH_THICKNESS = FootballConfig.PITCH_THICKNESS
local BALL_DIAMETER = FootballConfig.BALL_DIAMETER
local BALL_GROUND_CLEARANCE = FootballConfig.BALL_GROUND_CLEARANCE
local RESPAWN_DELAY = FootballConfig.GOAL_RESPAWN_DELAY

local Field = Workspace:WaitForChild(FootballConfig.FOLDER_NAME)
local ball = Field:WaitForChild(FootballConfig.BALL_NAME) :: BasePart
local scoreText = Field
	:WaitForChild("Scoreboard")
	:WaitForChild("Crossbar")
	:WaitForChild("ScoreboardGui")
	:WaitForChild("Background")
	:WaitForChild("ScoreText") :: TextLabel

-- Same ground/spawn math as BallBuilder.server.luau, computed once here so
-- a goal reset puts the ball back exactly where it started.
local groundY = GroundUtils.findGroundY(FIELD.X, FIELD.Z, Field)
local pitchTopY = groundY + PITCH_THICKNESS
local spawnPosition = Vector3.new(FIELD.X, pitchTopY + BALL_DIAMETER / 2 + BALL_GROUND_CLEARANCE, FIELD.Z)

local goalMinY = pitchTopY
local goalMaxY = pitchTopY + GOAL_HEIGHT
local goalMinZ = FIELD.Z - GOAL_WIDTH / 2
local goalMaxZ = FIELD.Z + GOAL_WIDTH / 2

local westGoalLineX = FIELD.X - LENGTH / 2
local eastGoalLineX = FIELD.X + LENGTH / 2

-- The goal box runs from the goal line itself back through GOAL_NET_GAP's
-- empty pocket and the net's own footprint (GOAL_DEPTH) -- i.e. everywhere
-- the ball can physically be once it has fully crossed the goal line, up to
-- where the solid net stops it. See FootballFieldBuilder.server.luau for
-- why GOAL_NET_GAP has to exist at all (otherwise the net stops the ball
-- exactly on the goal line and this box would never be reached).
local goalBoxDepth = GOAL_NET_GAP + GOAL_DEPTH

local scoreA = 0
local scoreB = 0
local processingGoal = false

local function updateScoreText()
	scoreText.Text = ("%s   %d  :  %d   %s"):format(FootballConfig.TEAM_A_NAME, scoreA, scoreB, FootballConfig.TEAM_B_NAME)
end

local function isInsideBox(position: Vector3, minX: number, maxX: number): boolean
	return position.X >= minX
		and position.X <= maxX
		and position.Z >= goalMinZ
		and position.Z <= goalMaxZ
		and position.Y >= goalMinY
		and position.Y <= goalMaxY
end

local function resetBall()
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.Position = spawnPosition
	ball.Transparency = 0
	ball.CanCollide = true
	ball.Anchored = false
	processingGoal = false
end

local function onGoal(scoringTeam: "A" | "B")
	processingGoal = true

	if scoringTeam == "A" then
		scoreA += 1
	else
		scoreB += 1
	end
	updateScoreText()

	-- Freeze and hide the ball immediately so it isn't still sitting in the
	-- net (or getting shoved around by it) during the respawn delay.
	ball.AssemblyLinearVelocity = Vector3.zero
	ball.AssemblyAngularVelocity = Vector3.zero
	ball.Anchored = true
	ball.CanCollide = false
	ball.Transparency = 1

	task.delay(RESPAWN_DELAY, resetBall)
end

updateScoreText()

RunService.Heartbeat:Connect(function()
	if processingGoal then
		return
	end

	local position = ball.Position
	if isInsideBox(position, westGoalLineX - goalBoxDepth, westGoalLineX) then
		onGoal("B") -- ball crossed into the WEST goal -> TEAM_B scores
	elseif isInsideBox(position, eastGoalLineX, eastGoalLineX + goalBoxDepth) then
		onGoal("A") -- ball crossed into the EAST goal -> TEAM_A scores
	end
end)
