local Workspace = game:GetService("Workspace")

-- Builds one small house out of parts near spawn on server start.
-- Position/size chosen to sit on the baseplate next to Spawn (see default.project.json).
--
-- v2: replaced the misrotated gable-wedge roof (which rendered as a giant
-- floating X) with a simple flat overhanging roof slab. Axis-aligned boxes
-- only -- no rotation math, so there is no risk of a misoriented part.

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local WALL_HEIGHT = 14
local WIDTH = 12
local DEPTH = 12
local WALL_THICKNESS = 1
local WALL_COLOR = Color3.fromRGB(194, 178, 128)
local ROOF_COLOR = Color3.fromRGB(120, 60, 40)
local ROOF_TRIM_COLOR = Color3.fromRGB(90, 44, 30)
local DOOR_WIDTH = 3.5
local DOOR_HEIGHT = 7.5
local ROOF_OVERHANG = 1.5 -- extra width/depth the roof extends past the walls
local ROOF_THICKNESS = 1
local ROOF_TRIM_HEIGHT = 0.6

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
	local floor = newPart(
		"Floor",
		Vector3.new(WIDTH, 1, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2
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

	-- Flat overhanging roof: two stacked axis-aligned slabs, no rotation.
	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(WIDTH + ROOF_OVERHANG * 2, ROOF_THICKNESS, DEPTH + ROOF_OVERHANG * 2),
		Vector3.new(basePosition.X, roofY, basePosition.Z),
		ROOF_COLOR,
		house
	)
	newPart(
		"RoofTrim",
		Vector3.new(WIDTH + ROOF_OVERHANG, ROOF_TRIM_HEIGHT, DEPTH + ROOF_OVERHANG),
		Vector3.new(basePosition.X, roofY + ROOF_THICKNESS / 2 + ROOF_TRIM_HEIGHT / 2, basePosition.Z),
		ROOF_TRIM_COLOR,
		house
	)

	house.PrimaryPart = floor
	return house
end

local Houses = Workspace:FindFirstChild("Houses")
if not Houses then
	Houses = Instance.new("Folder")
	Houses.Name = "Houses"
	Houses.Parent = Workspace
end

local existingHouse = Houses:FindFirstChild("House")
if existingHouse then
	existingHouse:Destroy()
end

local house = buildHouse(HOUSE_POSITION)
house.Parent = Houses
