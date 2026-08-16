local Workspace = game:GetService("Workspace")

-- Builds one simple tree next to the house on server start.
-- Follows the same approach as HouseBuilder: anchored, axis-aligned parts
-- only for the trunk (a plain box, so there's no rotation math and no risk
-- of a misoriented part). The foliage uses Ball-shaped parts, which look
-- the same from every angle, so they don't need any rotation either.
--
-- Placement: the house is a 24x24 footprint centered at HOUSE_POSITION with
-- its door on the west wall (facing Spawn at world X=0). The tree sits just
-- outside the house's southwest exterior corner, clear of the door gap and
-- clear of the straight walk-up path from Spawn to the door.
--
-- v2: the trunk was computed assuming the ground/baseplate top is exactly
-- Y=0 (matching default.project.json's Baseplate). If the live place's
-- baseplate/terrain at that spot has since drifted from that assumption
-- (e.g. edited directly in Studio outside of Rojo), a hardcoded Y=0 buries
-- the trunk -- that's the "trunk under ground, only the leaves show" report
-- from Slack. The trunk is now grounded with a downward raycast against
-- whatever is actually there instead of trusting a hardcoded constant, so
-- it self-corrects regardless of what the live baseplate/terrain Y is.

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local HOUSE_HALF_WIDTH = 12 -- WIDTH / 2 from HouseBuilder
local HOUSE_HALF_DEPTH = 12 -- DEPTH / 2 from HouseBuilder
local CORNER_OFFSET = 6 -- studs beyond each exterior wall

local TREE_XZ = Vector3.new(
	HOUSE_POSITION.X - HOUSE_HALF_WIDTH - CORNER_OFFSET,
	0,
	HOUSE_POSITION.Z + HOUSE_HALF_DEPTH + CORNER_OFFSET
)

local FALLBACK_GROUND_Y = 0 -- baseplate top per default.project.json, used only if the raycast finds nothing

local TRUNK_HEIGHT = 10
local TRUNK_WIDTH = 2
local TRUNK_COLOR = Color3.fromRGB(92, 64, 40)

local FOLIAGE_DIAMETER = 14
local FOLIAGE_OVERLAP = 3 -- how far the foliage sinks into the trunk top
local FOLIAGE_COLOR = Color3.fromRGB(48, 110, 46)

local RAYCAST_HEIGHT = 500 -- start well above anything reasonable and cast straight down

-- Finds the actual top-of-ground Y at (x, z) instead of assuming the
-- baseplate is exactly at Y=0, so the tree always sits on top of whatever
-- is really there (baseplate, terrain, or a rebuilt house).
local function findGroundY(x: number, z: number): number
	local origin = Vector3.new(x, RAYCAST_HEIGHT, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local trees = Workspace:FindFirstChild("Trees")
	if trees then
		params.FilterDescendantsInstances = { trees }
	end

	local result = Workspace:Raycast(origin, Vector3.new(0, -(RAYCAST_HEIGHT * 2), 0), params)
	if result then
		return result.Position.Y
	end
	return FALLBACK_GROUND_Y
end

local function newBoxPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Wood
	part.Parent = parent
	return part
end

local function newFoliageBall(name: string, diameter: number, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Grass
	part.Parent = parent
	return part
end

-- groundY is the real top-of-ground surface the trunk's bottom rests on.
local function buildTree(x: number, groundY: number, z: number): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local trunkY = groundY + TRUNK_HEIGHT / 2
	local trunk = newBoxPart(
		"Trunk",
		Vector3.new(TRUNK_WIDTH, TRUNK_HEIGHT, TRUNK_WIDTH),
		Vector3.new(x, trunkY, z),
		TRUNK_COLOR,
		tree
	)

	local foliageY = groundY + TRUNK_HEIGHT - FOLIAGE_OVERLAP + FOLIAGE_DIAMETER / 2
	newFoliageBall("Foliage", FOLIAGE_DIAMETER, Vector3.new(x, foliageY, z), FOLIAGE_COLOR, tree)

	tree.PrimaryPart = trunk
	return tree
end

local Trees = Workspace:FindFirstChild("Trees")
if not Trees then
	Trees = Instance.new("Folder")
	Trees.Name = "Trees"
	Trees.Parent = Workspace
end

local existingTree = Trees:FindFirstChild("Tree")
if existingTree then
	existingTree:Destroy()
end

local groundY = findGroundY(TREE_XZ.X, TREE_XZ.Z)
local tree = buildTree(TREE_XZ.X, groundY, TREE_XZ.Z)
tree.Parent = Trees
