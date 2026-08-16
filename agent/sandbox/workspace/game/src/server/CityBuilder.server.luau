local Workspace = game:GetService("Workspace")

-- Procedurally builds a small city: a 4x4 grid of 16 blocks, each block
-- ("quarter") holding 12 simplified houses (3 per side, facing outward)
-- with one tree beside each house, plus roads between blocks and around
-- the outer edge of the whole grid.
--
-- This is intentionally separate from HouseBuilder.server.luau (the single
-- interactive starter house near Spawn) and does not touch it. City houses
-- here are simplified -- a painted doorway instead of a real openable
-- ProximityPrompt door -- because there are 192 of them (16 blocks x 12);
-- keeping them non-interactive keeps this script small and cheap to build.
-- v2: the city used to sit at CITY_ORIGIN Z=500, past the edge of the
-- 512-stud Baseplate (which only reached Z=256) -- an unwalkable gap/pit
-- of empty space between Spawn and the city. Fixed two ways: moved the
-- city closer (Z=260, still clear of the starter house at (24,0,0)) and
-- extended Baseplate toward +Z in default.project.json so it now reaches
-- Z=474, comfortably past the city's near edge.
--
-- v3: the whole city was built assuming the ground is exactly Y=0 (the
-- Baseplate top per default.project.json). If the live place's actual
-- baseplate/terrain has drifted from that (e.g. edited in Studio outside
-- of Rojo), a hardcoded Y=0 buries most of the city -- that's the "city
-- underground, only ~1 block of tree tops and ~3.5 blocks of wall show"
-- report from Slack. Same fix as TreeBuilder.server.luau: a downward
-- Workspace:Raycast at the city center finds the real ground surface
-- there, and the whole city (road + every block) is built flush on top
-- of that instead of a hardcoded 0. Falls back to Y=0 if the raycast
-- finds nothing.
--
-- v4: after v3, the found ground surface was often literally the extended
-- Baseplate itself (see v2 -- it now reaches under the city's near edge),
-- so RoadBase's top landed exactly coplanar with the Baseplate's top --
-- two overlapping surfaces at the same Y flicker/z-fight (the "road is
-- blinking" report from Slack). GROUND_CLEARANCE lifts the whole city a
-- small, imperceptible amount above the raycast hit so RoadBase is always
-- strictly above whatever it landed on.

-- Grid / layout
local GRID_SIZE = 4 -- 4x4 = 16 blocks
local BLOCK_SIZE = 68 -- footprint of one quarter, studs
local ROAD_WIDTH = 20 -- road width between quarters and around the outer edge
local ROW_INSET = 8 -- distance from a block's edge to its house row centerline
local PITCH = 14 -- spacing between the 3 house centers along one row
local TREE_OFFSET = 6 -- how far the tree sits from its house, along the row
local CITY_ORIGIN = Vector3.new(0, 0, 260) -- close enough to walk to from Spawn (0,0,0); still clear of the starter house (24,0,0)

local CITY_SIZE = GRID_SIZE * BLOCK_SIZE + (GRID_SIZE + 1) * ROAD_WIDTH

local FALLBACK_GROUND_Y = 0 -- baseplate top per default.project.json, used only if the raycast finds nothing
local RAYCAST_HEIGHT = 500 -- start well above anything reasonable and cast straight down
local GROUND_CLEARANCE = 0.2 -- lift the city this far above the raycast hit so RoadBase never sits exactly
-- coplanar with Workspace.Baseplate (which now extends under part of the city, see v2 note above);
-- two same-Y surfaces flicker/z-fight, this guarantees the road always wins the depth test.

-- Finds the actual top-of-ground Y at (x, z) instead of assuming the
-- baseplate is exactly at Y=0, so the whole city always sits on top of
-- whatever is really there (baseplate, terrain, etc). Mirrors
-- TreeBuilder.server.luau's findGroundY.
local function findGroundY(x: number, z: number): number
	local origin = Vector3.new(x, RAYCAST_HEIGHT, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local city = Workspace:FindFirstChild("City")
	if city then
		params.FilterDescendantsInstances = { city }
	end

	local result = Workspace:Raycast(origin, Vector3.new(0, -(RAYCAST_HEIGHT * 2), 0), params)
	if result then
		return result.Position.Y
	end
	return FALLBACK_GROUND_Y
end

-- Ground
local PLATE_THICKNESS = 0.4
local PLATE_COLOR = Color3.fromRGB(90, 140, 60)
local ROAD_COLOR = Color3.fromRGB(58, 58, 58)

-- House
local HOUSE_SIZE = 8 -- square footprint, width == depth
local WALL_HEIGHT = 10
local WALL_THICKNESS = 1
local WALL_COLOR = Color3.fromRGB(194, 178, 128)
local ROOF_COLOR = Color3.fromRGB(120, 60, 40)
local ROOF_TRIM_COLOR = Color3.fromRGB(90, 44, 30)
local DOOR_COLOR = Color3.fromRGB(63, 38, 22)
local DOOR_WIDTH = 3.4
local DOOR_HEIGHT = 6.5
local ROOF_OVERHANG = 1
local ROOF_THICKNESS = 0.8
local ROOF_TRIM_HEIGHT = 0.5

-- Tree
local TREE_TRUNK_HEIGHT = 4
local TREE_TRUNK_RADIUS = 0.6
local TREE_LEAVES_RADIUS = 2.6
local TREE_TRUNK_COLOR = Color3.fromRGB(92, 64, 40)
local TREE_LEAVES_COLOR = Color3.fromRGB(58, 110, 48)

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

-- A simple two-part tree: a vertical trunk and a ball of leaves on top.
local function buildTree(position: Vector3): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Anchored = true
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(TREE_TRUNK_HEIGHT, TREE_TRUNK_RADIUS * 2, TREE_TRUNK_RADIUS * 2)
	-- A Cylinder part's height runs along its local X axis, so rotate it
	-- 90 degrees around Z to stand it upright.
	trunk.CFrame = CFrame.new(position.X, position.Y + TREE_TRUNK_HEIGHT / 2, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = TREE_TRUNK_COLOR
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Anchored = true
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(TREE_LEAVES_RADIUS * 2, TREE_LEAVES_RADIUS * 2, TREE_LEAVES_RADIUS * 2)
	leaves.Position = Vector3.new(position.X, position.Y + TREE_TRUNK_HEIGHT + TREE_LEAVES_RADIUS * 0.7, position.Z)
	leaves.Color = TREE_LEAVES_COLOR
	leaves.Material = Enum.Material.Grass
	leaves.Parent = tree

	tree.PrimaryPart = trunk
	return tree
end

-- Builds one simplified house. `doorAxis` ("X" or "Z") and `doorSign` (-1 or 1)
-- pick which of the 4 walls gets the doorway, e.g. doorAxis="Z", doorSign=-1
-- puts the doorway on the wall facing -Z. The doorway here is a painted
-- panel, not an interactive door (see file header for why).
local function buildCityHouse(center: Vector3, doorAxis: string, doorSign: number): Model
	local house = Instance.new("Model")
	house.Name = "House"

	local half = HOUSE_SIZE / 2
	local floorY = center.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(HOUSE_SIZE, 1, HOUSE_SIZE),
		Vector3.new(center.X, floorY, center.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT

	local function isDoorWall(axis: string, sign: number): boolean
		return axis == doorAxis and sign == doorSign
	end

	-- Walls perpendicular to Z (the "north"/"south" faces).
	for _, sign in ipairs({ -1, 1 }) do
		local wallZ = center.Z + sign * half
		if isDoorWall("Z", sign) then
			local sideSpan = (HOUSE_SIZE - DOOR_WIDTH) / 2
			newPart(
				"DoorWallNear",
				Vector3.new(sideSpan, WALL_HEIGHT, WALL_THICKNESS),
				Vector3.new(center.X - half + sideSpan / 2, wallY, wallZ),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorWallFar",
				Vector3.new(sideSpan, WALL_HEIGHT, WALL_THICKNESS),
				Vector3.new(center.X + half - sideSpan / 2, wallY, wallZ),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorLintel",
				Vector3.new(DOOR_WIDTH, lintelHeight, WALL_THICKNESS),
				Vector3.new(center.X, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, wallZ),
				WALL_COLOR,
				house
			)
			newPart(
				"Door",
				Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, WALL_THICKNESS),
				Vector3.new(center.X, floorY + 0.5 + DOOR_HEIGHT / 2, wallZ),
				DOOR_COLOR,
				house
			)
		else
			newPart(
				sign < 0 and "NorthWall" or "SouthWall",
				Vector3.new(HOUSE_SIZE, WALL_HEIGHT, WALL_THICKNESS),
				Vector3.new(center.X, wallY, wallZ),
				WALL_COLOR,
				house
			)
		end
	end

	-- Walls perpendicular to X (the "west"/"east" faces).
	for _, sign in ipairs({ -1, 1 }) do
		local wallX = center.X + sign * half
		if isDoorWall("X", sign) then
			local sideSpan = (HOUSE_SIZE - DOOR_WIDTH) / 2
			newPart(
				"DoorWallNear",
				Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
				Vector3.new(wallX, wallY, center.Z - half + sideSpan / 2),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorWallFar",
				Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
				Vector3.new(wallX, wallY, center.Z + half - sideSpan / 2),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorLintel",
				Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
				Vector3.new(wallX, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, center.Z),
				WALL_COLOR,
				house
			)
			newPart(
				"Door",
				Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
				Vector3.new(wallX, floorY + 0.5 + DOOR_HEIGHT / 2, center.Z),
				DOOR_COLOR,
				house
			)
		else
			newPart(
				sign < 0 and "WestWall" or "EastWall",
				Vector3.new(WALL_THICKNESS, WALL_HEIGHT, HOUSE_SIZE),
				Vector3.new(wallX, wallY, center.Z),
				WALL_COLOR,
				house
			)
		end
	end

	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(HOUSE_SIZE + ROOF_OVERHANG * 2, ROOF_THICKNESS, HOUSE_SIZE + ROOF_OVERHANG * 2),
		Vector3.new(center.X, roofY, center.Z),
		ROOF_COLOR,
		house
	)
	newPart(
		"RoofTrim",
		Vector3.new(HOUSE_SIZE + ROOF_OVERHANG, ROOF_TRIM_HEIGHT, HOUSE_SIZE + ROOF_OVERHANG),
		Vector3.new(center.X, roofY + ROOF_THICKNESS / 2 + ROOF_TRIM_HEIGHT / 2, center.Z),
		ROOF_TRIM_COLOR,
		house
	)

	house.PrimaryPart = floor
	return house
end

-- Builds one quarter: a grass plate plus 12 houses+trees, 3 per side, each
-- house's door (and its tree) facing outward, away from the block center.
-- baseGroundY is the real ground surface Y found by findGroundY, not a
-- hardcoded assumption.
local function buildBlock(blockCenter: Vector3, container: Instance, baseGroundY: number)
	local block = Instance.new("Model")
	block.Name = "Block"

	local plateY = baseGroundY -- road/plate sits flush on the real ground, not a hardcoded Y=0
	local plate = newPart(
		"Plate",
		Vector3.new(BLOCK_SIZE, PLATE_THICKNESS, BLOCK_SIZE),
		Vector3.new(blockCenter.X, plateY + PLATE_THICKNESS / 2, blockCenter.Z),
		PLATE_COLOR,
		block
	)
	plate.Material = Enum.Material.Grass

	local groundY = plateY + PLATE_THICKNESS
	local rowPerp = BLOCK_SIZE / 2 - ROW_INSET

	local rows = {
		{ axis = "Z", outward = -1 }, -- north edge, doors face -Z
		{ axis = "Z", outward = 1 }, -- south edge, doors face +Z
		{ axis = "X", outward = 1 }, -- east edge, doors face +X
		{ axis = "X", outward = -1 }, -- west edge, doors face -X
	}

	for _, row in ipairs(rows) do
		for _, j in ipairs({ -1, 0, 1 }) do
			if row.axis == "Z" then
				local x = blockCenter.X + j * PITCH
				local z = blockCenter.Z + row.outward * rowPerp
				local house = buildCityHouse(Vector3.new(x, groundY, z), row.axis, row.outward)
				house.Parent = block
				local tree = buildTree(Vector3.new(x + TREE_OFFSET, groundY, z))
				tree.Parent = block
			else
				local z = blockCenter.Z + j * PITCH
				local x = blockCenter.X + row.outward * rowPerp
				local house = buildCityHouse(Vector3.new(x, groundY, z), row.axis, row.outward)
				house.Parent = block
				local tree = buildTree(Vector3.new(x, groundY, z + TREE_OFFSET))
				tree.Parent = block
			end
		end
	end

	block.Parent = container
end

local existingCity = Workspace:FindFirstChild("City")
if existingCity then
	existingCity:Destroy()
end

local City = Instance.new("Folder")
City.Name = "City"
City.Parent = Workspace

-- One raycast at the city's center grounds the whole city (road + every
-- block); the old City folder is already gone (destroyed above), so this
-- hits whatever real baseplate/terrain is actually there.
local cityGroundY = findGroundY(CITY_ORIGIN.X, CITY_ORIGIN.Z) + GROUND_CLEARANCE

local road = newPart(
	"RoadBase",
	Vector3.new(CITY_SIZE, 1, CITY_SIZE),
	Vector3.new(CITY_ORIGIN.X, cityGroundY - 0.5, CITY_ORIGIN.Z),
	ROAD_COLOR,
	City
)
road.Material = Enum.Material.Asphalt

for i = 0, GRID_SIZE - 1 do
	for k = 0, GRID_SIZE - 1 do
		local offsetX = ROAD_WIDTH + BLOCK_SIZE / 2 + i * (BLOCK_SIZE + ROAD_WIDTH) - CITY_SIZE / 2
		local offsetZ = ROAD_WIDTH + BLOCK_SIZE / 2 + k * (BLOCK_SIZE + ROAD_WIDTH) - CITY_SIZE / 2
		local blockCenter = Vector3.new(CITY_ORIGIN.X + offsetX, CITY_ORIGIN.Y, CITY_ORIGIN.Z + offsetZ)
		buildBlock(blockCenter, City, cityGroundY)
	end
end
