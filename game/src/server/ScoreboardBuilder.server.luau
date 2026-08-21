local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)

-- Builds one big scoreboard (two poles + a crossbar carrying a BillboardGui)
-- just past the pitch's north fence, per Slack request ("зроби лічильник
-- (велике табло) голів"). GoalScoring.server.luau owns the actual score
-- state and updates the BillboardGui's TextLabel when a goal is scored --
-- this script only builds the static structure and the initial "0 : 0"
-- display.
--
-- A BillboardGui (always faces the camera) is used instead of a flat
-- SurfaceGui panel so the score is readable from anywhere on the pitch
-- without any rotation/facing math -- same reasoning the other builders use
-- to avoid misoriented parts, just applied to a GUI instead of a part.
--
-- Placed straddling the north fence's entrance gap (see FieldFenceBuilder),
-- like an arch over the walk-in point, with SCOREBOARD_POLE_SPACING (10
-- studs) between the poles -- comfortably narrower than the 14-stud gap, so
-- it doesn't block players walking through.
--
-- Height is derived from the real ground surface via GroundUtils, not a
-- hardcoded Y, so the scoreboard sits correctly even if the live baseplate/
-- terrain at that spot ever differs from default.project.json.

local POLE_COLOR = Color3.fromRGB(60, 60, 65)
local BOARD_BACKGROUND_COLOR = Color3.fromRGB(15, 15, 20)
local TEXT_COLOR = Color3.fromRGB(255, 214, 0)

local FIELD = FootballConfig.FIELD_POSITION
local WIDTH = FootballConfig.FIELD_WIDTH
local PITCH_THICKNESS = FootballConfig.PITCH_THICKNESS
local FENCE_SIDE_MARGIN = FootballConfig.FENCE_SIDE_MARGIN
local OFFSET_BEYOND_FENCE = FootballConfig.SCOREBOARD_OFFSET_BEYOND_FENCE
local POLE_HEIGHT = FootballConfig.SCOREBOARD_POLE_HEIGHT
local POLE_SPACING = FootballConfig.SCOREBOARD_POLE_SPACING
local POLE_THICKNESS = FootballConfig.SCOREBOARD_POLE_THICKNESS
local CROSSBAR_THICKNESS = FootballConfig.SCOREBOARD_CROSSBAR_THICKNESS

local function newBoxPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Parent = parent
	return part
end

local Field = Workspace:FindFirstChild(FootballConfig.FOLDER_NAME)
if not Field then
	Field = Instance.new("Folder")
	Field.Name = FootballConfig.FOLDER_NAME
	Field.Parent = Workspace
end

local existingScoreboard = Field:FindFirstChild("Scoreboard")
if existingScoreboard then
	existingScoreboard:Destroy()
end

local groundY = GroundUtils.findGroundY(FIELD.X, FIELD.Z, Field)
local pitchTopY = groundY + PITCH_THICKNESS

local outerHalfWidth = WIDTH / 2 + FENCE_SIDE_MARGIN -- matches FieldFenceBuilder's north fence line
local scoreboardZ = FIELD.Z - outerHalfWidth - OFFSET_BEYOND_FENCE

local Scoreboard = Instance.new("Model")
Scoreboard.Name = "Scoreboard"

local poleY = pitchTopY + POLE_HEIGHT / 2
local leftPole = newBoxPart(
	"PoleWest",
	Vector3.new(POLE_THICKNESS, POLE_HEIGHT, POLE_THICKNESS),
	Vector3.new(FIELD.X - POLE_SPACING / 2, poleY, scoreboardZ),
	POLE_COLOR,
	Scoreboard
)
newBoxPart(
	"PoleEast",
	Vector3.new(POLE_THICKNESS, POLE_HEIGHT, POLE_THICKNESS),
	Vector3.new(FIELD.X + POLE_SPACING / 2, poleY, scoreboardZ),
	POLE_COLOR,
	Scoreboard
)

local crossbar = newBoxPart(
	"Crossbar",
	Vector3.new(POLE_SPACING + POLE_THICKNESS, CROSSBAR_THICKNESS, POLE_THICKNESS),
	Vector3.new(FIELD.X, pitchTopY + POLE_HEIGHT, scoreboardZ),
	POLE_COLOR,
	Scoreboard
)

local billboard = Instance.new("BillboardGui")
billboard.Name = "ScoreboardGui"
billboard.Size = UDim2.fromOffset(500, 150)
billboard.StudsOffset = Vector3.new(0, 4, 0)
billboard.AlwaysOnTop = true
billboard.MaxDistance = 500
billboard.Adornee = crossbar
billboard.Parent = crossbar

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = BOARD_BACKGROUND_COLOR
background.BorderSizePixel = 0
background.Parent = billboard

local scoreText = Instance.new("TextLabel")
scoreText.Name = "ScoreText"
scoreText.Size = UDim2.fromScale(1, 1)
scoreText.BackgroundTransparency = 1
scoreText.Font = Enum.Font.GothamBold
scoreText.TextColor3 = TEXT_COLOR
scoreText.TextScaled = true
scoreText.Text = ("%s   0  :  0   %s"):format(FootballConfig.TEAM_A_NAME, FootballConfig.TEAM_B_NAME)
scoreText.Parent = background

Scoreboard.PrimaryPart = leftPole
Scoreboard.Parent = Field
