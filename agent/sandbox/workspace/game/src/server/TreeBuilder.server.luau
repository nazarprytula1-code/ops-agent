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

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local HOUSE_HALF_WIDTH = 12 -- WIDTH / 2 from HouseBuilder
local HOUSE_HALF_DEPTH = 12 -- DEPTH / 2 from HouseBuilder
local CORNER_OFFSET = 6 -- studs beyond each exterior wall

local TREE_POSITION = Vector3.new(
	HOUSE_POSITION.X - HOUSE_HALF_WIDTH - CORNER_OFFSET,
	0,
	HOUSE_POSITION.Z + HOUSE_HALF_DEPTH + CORNER_OFFSET
)

local TRUNK_HEIGHT = 10
local TRUNK_WIDTH = 2
local TRUNK_COLOR = Color3.fromRGB(92, 64, 40)

local FOLIAGE_DIAMETER = 14
local FOLIAGE_OVERLAP = 3 -- how far the foliage sinks into the trunk top
local FOLIAGE_COLOR = Color3.fromRGB(48, 110, 46)

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

local function buildTree(basePosition: Vector3): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local trunkY = basePosition.Y + TRUNK_HEIGHT / 2
	local trunk = newBoxPart(
		"Trunk",
		Vector3.new(TRUNK_WIDTH, TRUNK_HEIGHT, TRUNK_WIDTH),
		Vector3.new(basePosition.X, trunkY, basePosition.Z),
		TRUNK_COLOR,
		tree
	)

	local foliageY = basePosition.Y + TRUNK_HEIGHT - FOLIAGE_OVERLAP + FOLIAGE_DIAMETER / 2
	newFoliageBall(
		"Foliage",
		FOLIAGE_DIAMETER,
		Vector3.new(basePosition.X, foliageY, basePosition.Z),
		FOLIAGE_COLOR,
		tree
	)

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

local tree = buildTree(TREE_POSITION)
tree.Parent = Trees
