local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)

-- Builds one football (soccer) pitch -- grass rectangle, boundary lines,
-- halfway line/spot and two goals -- per Slack request ("намалюй футбольне
-- поле і один м'яч"). See BallBuilder.server.luau for the ball and
-- BallKick.server.luau for the kicking. Placement/clearance reasoning lives
-- in FootballConfig.FIELD_POSITION.
--
-- Axis-aligned boxes only, same approach as HouseBuilder/CarBuilder/
-- TreeBuilder: the pitch's length runs along world X and its width along
-- world Z, so both goals and every line are plain boxes with no rotation
-- math and no risk of a misoriented part.
--
-- Height is derived from the real ground surface via GroundUtils, not a
-- hardcoded Y, so the pitch sits correctly even if the live baseplate/
-- terrain at that spot ever differs from default.project.json.

local PITCH_COLOR = Color3.fromRGB(43, 128, 55)
local LINE_COLOR = Color3.fromRGB(255, 255, 255)
local POST_COLOR = Color3.fromRGB(235, 235, 235)
local NET_COLOR = Color3.fromRGB(245, 245, 245)

local FIELD = FootballConfig.FIELD_POSITION
local LENGTH = FootballConfig.FIELD_LENGTH
local WIDTH = FootballConfig.FIELD_WIDTH
local PITCH_THICKNESS = FootballConfig.PITCH_THICKNESS
local LINE_WIDTH = FootballConfig.LINE_WIDTH
local LINE_THICKNESS = FootballConfig.LINE_THICKNESS
local GOAL_WIDTH = FootballConfig.GOAL_WIDTH
local GOAL_HEIGHT = FootballConfig.GOAL_HEIGHT
local GOAL_DEPTH = FootballConfig.GOAL_DEPTH
local POST_THICKNESS = FootballConfig.POST_THICKNESS

local function newBoxPart(
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	canCollide: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = if canCollide == nil then true else canCollide
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- Builds one goal frame (two posts + a crossbar) plus a back net that
-- catches the ball, at `goalLineX` (the pitch's short edge), opening toward
-- the pitch center.
local function buildGoal(name: string, goalLineX: number, pitchTopY: number, netSign: number, parent: Instance)
	local goal = Instance.new("Model")
	goal.Name = name

	local postHeightCenter = pitchTopY + GOAL_HEIGHT / 2
	local leftZ = FIELD.Z - GOAL_WIDTH / 2
	local rightZ = FIELD.Z + GOAL_WIDTH / 2

	newBoxPart(
		"LeftPost",
		Vector3.new(POST_THICKNESS, GOAL_HEIGHT, POST_THICKNESS),
		Vector3.new(goalLineX, postHeightCenter, leftZ),
		POST_COLOR,
		goal
	)
	newBoxPart(
		"RightPost",
		Vector3.new(POST_THICKNESS, GOAL_HEIGHT, POST_THICKNESS),
		Vector3.new(goalLineX, postHeightCenter, rightZ),
		POST_COLOR,
		goal
	)
	newBoxPart(
		"Crossbar",
		Vector3.new(POST_THICKNESS, POST_THICKNESS, GOAL_WIDTH + POST_THICKNESS),
		Vector3.new(goalLineX, pitchTopY + GOAL_HEIGHT - POST_THICKNESS / 2, FIELD.Z),
		POST_COLOR,
		goal
	)

	-- netSign points away from the pitch center (-1 for the goal at the -X
	-- end, +1 for the goal at the +X end) so the net sits behind the posts
	-- instead of inside the playing field. CanCollide true so a scored ball
	-- stops in the net instead of rolling off into the world.
	local netX = goalLineX + netSign * GOAL_DEPTH / 2
	local net = newBoxPart(
		"Net",
		Vector3.new(GOAL_DEPTH, GOAL_HEIGHT, GOAL_WIDTH + POST_THICKNESS),
		Vector3.new(netX, postHeightCenter, FIELD.Z),
		NET_COLOR,
		goal,
		Enum.Material.Fabric,
		true
	)
	net.Transparency = 0.7

	goal.Parent = parent
end

local Field = Workspace:FindFirstChild(FootballConfig.FOLDER_NAME)
if not Field then
	Field = Instance.new("Folder")
	Field.Name = FootballConfig.FOLDER_NAME
	Field.Parent = Workspace
end

local existingPitch = Field:FindFirstChild("Pitch")
if existingPitch then
	existingPitch:Destroy()
end

local groundY = GroundUtils.findGroundY(FIELD.X, FIELD.Z, Field)
local pitchY = groundY + PITCH_THICKNESS / 2
local pitchTopY = groundY + PITCH_THICKNESS
local lineY = pitchTopY + LINE_THICKNESS / 2

local Pitch = Instance.new("Model")
Pitch.Name = "Pitch"

newBoxPart(
	"Grass",
	Vector3.new(LENGTH, PITCH_THICKNESS, WIDTH),
	Vector3.new(FIELD.X, pitchY, FIELD.Z),
	PITCH_COLOR,
	Pitch,
	Enum.Material.Grass
)

-- Touchlines (long sides, run along X).
newBoxPart(
	"TouchlineNorth",
	Vector3.new(LENGTH, LINE_THICKNESS, LINE_WIDTH),
	Vector3.new(FIELD.X, lineY, FIELD.Z - WIDTH / 2),
	LINE_COLOR,
	Pitch,
	Enum.Material.SmoothPlastic,
	false
)
newBoxPart(
	"TouchlineSouth",
	Vector3.new(LENGTH, LINE_THICKNESS, LINE_WIDTH),
	Vector3.new(FIELD.X, lineY, FIELD.Z + WIDTH / 2),
	LINE_COLOR,
	Pitch,
	Enum.Material.SmoothPlastic,
	false
)

-- Goal lines (short sides, run along Z).
newBoxPart(
	"GoalLineWest",
	Vector3.new(LINE_WIDTH, LINE_THICKNESS, WIDTH),
	Vector3.new(FIELD.X - LENGTH / 2, lineY, FIELD.Z),
	LINE_COLOR,
	Pitch,
	Enum.Material.SmoothPlastic,
	false
)
newBoxPart(
	"GoalLineEast",
	Vector3.new(LINE_WIDTH, LINE_THICKNESS, WIDTH),
	Vector3.new(FIELD.X + LENGTH / 2, lineY, FIELD.Z),
	LINE_COLOR,
	Pitch,
	Enum.Material.SmoothPlastic,
	false
)

-- Halfway line and center spot.
newBoxPart(
	"HalfwayLine",
	Vector3.new(LINE_WIDTH, LINE_THICKNESS, WIDTH),
	Vector3.new(FIELD.X, lineY, FIELD.Z),
	LINE_COLOR,
	Pitch,
	Enum.Material.SmoothPlastic,
	false
)
newBoxPart(
	"CenterSpot",
	Vector3.new(LINE_WIDTH * 1.5, LINE_THICKNESS, LINE_WIDTH * 1.5),
	Vector3.new(FIELD.X, lineY, FIELD.Z),
	LINE_COLOR,
	Pitch,
	Enum.Material.SmoothPlastic,
	false
)

Pitch.PrimaryPart = Pitch:FindFirstChild("Grass") :: Part
Pitch.Parent = Field

local existingGoalWest = Field:FindFirstChild("GoalWest")
if existingGoalWest then
	existingGoalWest:Destroy()
end
local existingGoalEast = Field:FindFirstChild("GoalEast")
if existingGoalEast then
	existingGoalEast:Destroy()
end

buildGoal("GoalWest", FIELD.X - LENGTH / 2, pitchTopY, -1, Field)
buildGoal("GoalEast", FIELD.X + LENGTH / 2, pitchTopY, 1, Field)
