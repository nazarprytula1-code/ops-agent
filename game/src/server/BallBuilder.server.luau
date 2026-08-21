local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)
local BallCollision = require(ReplicatedStorage.Shared.BallCollision)

-- Places one kickable ball at the center of the pitch built by
-- FootballFieldBuilder.server.luau, per Slack request ("...і один м'яч").
-- See BallKick.server.luau for how players kick it and
-- GoalScoring.server.luau for how it gets reset to this same spot after a
-- goal.
--
-- Reads the ground independently via the same GroundUtils call and the same
-- FootballConfig.FIELD_POSITION that FootballFieldBuilder uses, instead of
-- depending on the two builder scripts running in a particular order --
-- same reasoning as CarBuilder/TreeBuilder each finding their own ground.
--
-- Unlike the other builders, the ball is NOT anchored: it needs real
-- physics (gravity, rolling, bouncing) to be kickable at all.
--
-- The ball is put in its own collision group (see BallCollision.luau) so
-- BallBoundaryBuilder.server.luau's invisible pitch-edge walls can push
-- this ball around without ever touching a player or anything else.

local BALL_COLOR = Color3.fromRGB(255, 255, 255)

local FIELD = FootballConfig.FIELD_POSITION
local PITCH_THICKNESS = FootballConfig.PITCH_THICKNESS
local BALL_DIAMETER = FootballConfig.BALL_DIAMETER
local BALL_GROUND_CLEARANCE = FootballConfig.BALL_GROUND_CLEARANCE

BallCollision.ensureGroups()

local Field = Workspace:FindFirstChild(FootballConfig.FOLDER_NAME)
if not Field then
	Field = Instance.new("Folder")
	Field.Name = FootballConfig.FOLDER_NAME
	Field.Parent = Workspace
end

local existingBall = Field:FindFirstChild(FootballConfig.BALL_NAME)
if existingBall then
	existingBall:Destroy()
end

local groundY = GroundUtils.findGroundY(FIELD.X, FIELD.Z, Field)
local pitchTopY = groundY + PITCH_THICKNESS
local ballY = pitchTopY + BALL_DIAMETER / 2 + BALL_GROUND_CLEARANCE

local ball = Instance.new("Part")
ball.Name = FootballConfig.BALL_NAME
ball.Shape = Enum.PartType.Ball
ball.Size = Vector3.new(BALL_DIAMETER, BALL_DIAMETER, BALL_DIAMETER)
ball.Position = Vector3.new(FIELD.X, ballY, FIELD.Z)
ball.Anchored = false
ball.CanCollide = true
ball.CollisionGroup = BallCollision.BALL_GROUP
ball.Color = BALL_COLOR
ball.Material = Enum.Material.SmoothPlastic
-- Bouncy and low-friction so it rolls and bounces like a real ball instead
-- of sticking dead wherever it lands.
ball.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.35, 0.55, 1, 1)
ball.Parent = Field
