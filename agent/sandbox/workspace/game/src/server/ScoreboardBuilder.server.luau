local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)

-- Builds one big scoreboard (two poles + a fixed board) just past the
-- pitch's north fence, per Slack request ("зроби лічильник (велике табло)
-- голів"). GoalScoring.server.luau owns the actual score state and updates
-- the board's TextLabel when a goal is scored -- this script only builds
-- the static structure and the initial "0 : 0" display.
--
-- v2: per Slack follow-up ("зроби нерухомим" -- "make it stationary"), the
-- score display is a SurfaceGui on a fixed Board part instead of a
-- BillboardGui: a BillboardGui always turns to face the camera, which reads
-- as the sign "moving"/spinning as a player walks around it. A SurfaceGui
-- has a fixed facing instead, like a real sign. The Board part itself is
-- never rotated -- it's built with zero rotation (axis-aligned, same as
-- every other builder in this game) and the GUI is put on Enum.NormalId.Back
-- (world +Z on an unrotated part) instead, since the board sits north of
-- the pitch (smaller Z) and the pitch/players are south of it (larger Z):
-- Front normally faces -Z, so Back is the +Z face that actually looks
-- toward the pitch. That avoids any CFrame/rotation math entirely.
--
-- Placed straddling the north fence's entrance gap (see FieldFenceBuilder),
-- like an arch over the walk-in point, with SCOREBOARD_POLE_SPACING (16
-- studs) between the poles -- narrower than the 14-stud gap plus each
-- pole's own thickness, so there's still a comfortable walk-through gap
-- between the poles themselves.
--
-- Height is derived from the real ground surface via GroundUtils, not a
-- hardcoded Y, so the scoreboard sits correctly even if the live baseplate/
-- terrain at that spot ever differs from default.project.json.

local POLE_COLOR = Color3.fromRGB(60, 60, 65)
local BOARD_COLOR = Color3.fromRGB(30, 30, 35)
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
local BOARD_WIDTH = FootballConfig.SCOREBOARD_BOARD_WIDTH
local BOARD_HEIGHT = FootballConfig.SCOREBOARD_BOARD_HEIGHT
local BOARD_THICKNESS = FootballConfig.SCOREBOARD_BOARD_THICKNESS

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

-- The board itself: no rotation, sits on top of the poles like a real
-- scoreboard frame. See the file header for why the GUI goes on the Back
-- face instead of rotating this part.
local board = newBoxPart(
	"Board",
	Vector3.new(BOARD_WIDTH, BOARD_HEIGHT, BOARD_THICKNESS),
	Vector3.new(FIELD.X, pitchTopY + POLE_HEIGHT + BOARD_HEIGHT / 2, scoreboardZ),
	BOARD_COLOR,
	Scoreboard
)

local surfaceGui = Instance.new("SurfaceGui")
surfaceGui.Name = "ScoreboardGui"
surfaceGui.Face = Enum.NormalId.Back -- +Z on this unrotated part, i.e. facing the pitch to the south
surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
surfaceGui.PixelsPerStud = 50
surfaceGui.Parent = board

local background = Instance.new("Frame")
background.Name = "Background"
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = BOARD_BACKGROUND_COLOR
background.BorderSizePixel = 0
background.Parent = surfaceGui

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
