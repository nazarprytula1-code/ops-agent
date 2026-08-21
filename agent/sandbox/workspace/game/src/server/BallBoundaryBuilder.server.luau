local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)
local BallCollision = require(ReplicatedStorage.Shared.BallCollision)

-- Builds an invisible wall right at the pitch boundary -- the touchlines in
-- full, and the goal lines except for the goal mouth -- that only the ball
-- collides with, per Slack request ("на межі поля (крім воріт) є невидима
-- стіна (діє тільки на м'яч), яка не дає м'ячу викотитися за межу поля").
-- Players, and every other part in this place, pass straight through: see
-- BallCollision.luau, which puts these walls and the ball in their own
-- collision groups and disables collisions between the wall group and
-- Default (everything else).
--
-- This is deliberately separate from FieldFenceBuilder's tall perimeter
-- fence, which sits further out and blocks players too -- this one keeps
-- the ball from rolling off the actual playing surface without fencing
-- players in at the same tight boundary.
--
-- Axis-aligned boxes only, same approach as the other football builders:
-- every wall segment runs straight along world X or world Z.
--
-- Height is derived from the real ground surface via GroundUtils, not a
-- hardcoded Y, so the wall sits correctly even if the live baseplate/
-- terrain at that spot ever differs from default.project.json.

local FIELD = FootballConfig.FIELD_POSITION
local LENGTH = FootballConfig.FIELD_LENGTH
local WIDTH = FootballConfig.FIELD_WIDTH
local GOAL_WIDTH = FootballConfig.GOAL_WIDTH
local PITCH_THICKNESS = FootballConfig.PITCH_THICKNESS
local WALL_HEIGHT = FootballConfig.BALL_BOUNDARY_HEIGHT
local WALL_THICKNESS = FootballConfig.BALL_BOUNDARY_THICKNESS

BallCollision.ensureGroups()

local function newWall(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.Transparency = 1
	part.Size = size
	part.Position = position
	part.CollisionGroup = BallCollision.BOUNDARY_GROUP
	part.Parent = parent
	return part
end

local Field = Workspace:FindFirstChild(FootballConfig.FOLDER_NAME)
if not Field then
	Field = Instance.new("Folder")
	Field.Name = FootballConfig.FOLDER_NAME
	Field.Parent = Workspace
end

local existingBoundary = Field:FindFirstChild("BallBoundary")
if existingBoundary then
	existingBoundary:Destroy()
end

local groundY = GroundUtils.findGroundY(FIELD.X, FIELD.Z, Field)
local pitchTopY = groundY + PITCH_THICKNESS
local wallY = pitchTopY + WALL_HEIGHT / 2

local Boundary = Instance.new("Model")
Boundary.Name = "BallBoundary"

-- Touchlines (north/south), full length, no gap -- there's no goal on
-- either long side.
newWall(
	"TouchlineNorth",
	Vector3.new(LENGTH, WALL_HEIGHT, WALL_THICKNESS),
	Vector3.new(FIELD.X, wallY, FIELD.Z - WIDTH / 2),
	Boundary
)
newWall(
	"TouchlineSouth",
	Vector3.new(LENGTH, WALL_HEIGHT, WALL_THICKNESS),
	Vector3.new(FIELD.X, wallY, FIELD.Z + WIDTH / 2),
	Boundary
)

-- Goal lines (west/east), split around the goal mouth so the ball still
-- rolls into the goal/net instead of bouncing off a wall right in front of
-- it. Each side segment runs from the touchline in to the goal post,
-- exactly matching FootballFieldBuilder's post positions (FIELD.Z ± GOAL_WIDTH / 2).
local sideSpan = (WIDTH - GOAL_WIDTH) / 2
local segmentCenterOffset = GOAL_WIDTH / 2 + sideSpan / 2

for _, xSign in ipairs({ -1, 1 }) do
	local x = FIELD.X + xSign * (LENGTH / 2)
	local endName = if xSign < 0 then "West" else "East"

	newWall(
		endName .. "North",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
		Vector3.new(x, wallY, FIELD.Z - segmentCenterOffset),
		Boundary
	)
	newWall(
		endName .. "South",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
		Vector3.new(x, wallY, FIELD.Z + segmentCenterOffset),
		Boundary
	)
end

Boundary.Parent = Field
