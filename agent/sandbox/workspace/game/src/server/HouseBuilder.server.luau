local Workspace = game:GetService("Workspace")

-- Builds one small house out of parts near spawn on server start.
-- Position/size chosen to sit on the baseplate next to Spawn (see default.project.json).

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local WALL_HEIGHT = 8
local WIDTH = 12
local DEPTH = 12
local WALL_THICKNESS = 1
local WALL_COLOR = Color3.fromRGB(194, 178, 128)
local ROOF_COLOR = Color3.fromRGB(120, 60, 40)
local DOOR_WIDTH = 3.5
local DOOR_HEIGHT = 5.5

local function newPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.WoodPlanks
	part.Parent = parent
	return part
end

local function buildHouse(basePosition: Vector3): Model
	local house = Instance.new("Model")
	house.Name = "House"

	local floorY = basePosition.Y + 0.5
	newPart(
		"Floor",
		Vector3.new(WIDTH, 1, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)

	local wallY = floorY + WALL_HEIGHT / 2 + 0.5
	local halfWidth = WIDTH / 2
	local halfDepth = DEPTH / 2

	-- Back and side walls are solid.
	newPart(
		"BackWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z - halfDepth),
		WALL_COLOR,
		house
	)
	newPart(
		"LeftWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X - halfWidth, wallY, basePosition.Z),
		WALL_COLOR,
		house
	)
	newPart(
		"RightWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X + halfWidth, wallY, basePosition.Z),
		WALL_COLOR,
		house
	)

	-- Front wall has a doorway: two side segments plus a lintel above the gap.
	local sideSegmentWidth = (WIDTH - DOOR_WIDTH) / 2
	newPart(
		"FrontWallLeft",
		Vector3.new(sideSegmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X - DOOR_WIDTH / 2 - sideSegmentWidth / 2, wallY, basePosition.Z + halfDepth),
		WALL_COLOR,
		house
	)
	newPart(
		"FrontWallRight",
		Vector3.new(sideSegmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X + DOOR_WIDTH / 2 + sideSegmentWidth / 2, wallY, basePosition.Z + halfDepth),
		WALL_COLOR,
		house
	)
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"FrontWallLintel",
		Vector3.new(DOOR_WIDTH, lintelHeight, WALL_THICKNESS),
		Vector3.new(basePosition.X, floorY + DOOR_HEIGHT + lintelHeight / 2, basePosition.Z + halfDepth),
		WALL_COLOR,
		house
	)

	-- Simple gable roof made from two angled wedges.
	local roofY = floorY + WALL_HEIGHT + 1
	local roofSlope = math.rad(35)
	local roofLength = math.sqrt((halfDepth) ^ 2 + 2 ^ 2) -- approximate slope run
	local leftRoof = Instance.new("WedgePart")
	leftRoof.Name = "RoofLeft"
	leftRoof.Anchored = true
	leftRoof.Size = Vector3.new(WIDTH + 1, 2, roofLength)
	leftRoof.Color = ROOF_COLOR
	leftRoof.Material = Enum.Material.Slate
	leftRoof.CFrame = CFrame.new(basePosition.X, roofY, basePosition.Z - halfDepth / 2)
		* CFrame.Angles(-roofSlope, math.rad(90), 0)
	leftRoof.Parent = house

	local rightRoof = leftRoof:Clone()
	rightRoof.Name = "RoofRight"
	rightRoof.CFrame = CFrame.new(basePosition.X, roofY, basePosition.Z + halfDepth / 2)
		* CFrame.Angles(roofSlope, math.rad(90), 0)
	rightRoof.Parent = house

	house.PrimaryPart = house.Floor
	return house
end

local Houses = Workspace:FindFirstChild("Houses")
if not Houses then
	Houses = Instance.new("Folder")
	Houses.Name = "Houses"
	Houses.Parent = Workspace
end

if not Houses:FindFirstChild("House") then
	local house = buildHouse(HOUSE_POSITION)
	house.Parent = Houses
end
