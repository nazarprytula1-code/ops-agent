local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Builds one small house out of parts near spawn on server start.
-- Position/size chosen to sit on the baseplate next to Spawn (see default.project.json).
--
-- v2: replaced the misrotated gable-wedge roof (which rendered as a giant
-- floating X) with a simple flat overhanging roof slab. Axis-aligned boxes
-- only -- no rotation math for the structure, so there is no risk of a
-- misoriented part.
--
-- v4: the doorway used to be on the +Z wall, which faces *away* from Spawn
-- (Spawn is at world X=0, the house is at X=24, so walking straight there
-- puts you at the -X wall first, which used to be solid -- that's the
-- "wall with no door" from Slack). The door is now on the -X wall (WestWall),
-- facing Spawn, and it is a real openable door (ProximityPrompt, hold E)
-- instead of just an open gap.
--
-- v5: Slack feedback said the door still looked small next to the wall
-- ("4/7 of the wall height" in Play, screenshot showed ~4 plank rows of
-- door vs ~7 total). Bumped DOOR_HEIGHT 11 -> 12.5 (wall is 14, so the
-- door is now ~89% of wall height) and DOOR_WIDTH 5 -> 6. Doorway side
-- segments, lintel, and the door leaf are all computed from these
-- constants, so everything stays consistent automatically.

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local WALL_HEIGHT = 14
local WIDTH = 12
local DEPTH = 12
local WALL_THICKNESS = 1
local WALL_COLOR = Color3.fromRGB(194, 178, 128)
local ROOF_COLOR = Color3.fromRGB(120, 60, 40)
local ROOF_TRIM_COLOR = Color3.fromRGB(90, 44, 30)
local DOOR_COLOR = Color3.fromRGB(63, 38, 22)
local DOOR_WIDTH = 6
local DOOR_HEIGHT = 12.5
local ROOF_OVERHANG = 1.5 -- extra width/depth the roof extends past the walls
local ROOF_THICKNESS = 1
local ROOF_TRIM_HEIGHT = 0.6
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4

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

-- Wires a ProximityPrompt (default key: E) onto `door` that swings it open
-- around the vertical hinge line at `hingeX`/`hingeZ`, then swings it shut.
local function setupSwingingDoor(door: Part, hingeX: number, hingeZ: number)
	local closedCFrame = door.CFrame
	local doorWidth = door.Size.Z
	local openCFrame = CFrame.new(hingeX + doorWidth / 2, door.Position.Y, hingeZ) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Door"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = door

	local isOpen = false
	local tweening = false

	prompt.Triggered:Connect(function()
		if tweening then
			return
		end
		tweening = true

		if not isOpen then
			door.CanCollide = false
			prompt.ActionText = "Close"
			local tween =
				TweenService:Create(door, TweenInfo.new(DOOR_TWEEN_SECONDS, Enum.EasingStyle.Quad), { CFrame = openCFrame })
			tween:Play()
			tween.Completed:Wait()
			isOpen = true
		else
			prompt.ActionText = "Open"
			local tween =
				TweenService:Create(door, TweenInfo.new(DOOR_TWEEN_SECONDS, Enum.EasingStyle.Quad), { CFrame = closedCFrame })
			tween:Play()
			tween.Completed:Wait()
			door.CanCollide = true
			isOpen = false
		end

		tweening = false
	end)
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

	-- North, South and East walls are solid.
	newPart(
		"NorthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z - halfDepth),
		WALL_COLOR,
		house
	)
	newPart(
		"SouthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z + halfDepth),
		WALL_COLOR,
		house
	)
	newPart(
		"EastWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X + halfWidth, wallY, basePosition.Z),
		WALL_COLOR,
		house
	)

	-- West wall faces Spawn (Spawn is at world X=0, this house is at X=24,
	-- so walking straight from Spawn reaches the -X wall first). It has the
	-- doorway: two side segments plus a lintel above the gap, plus a real door.
	local westX = basePosition.X - halfWidth
	local sideSegmentDepth = (DEPTH - DOOR_WIDTH) / 2
	newPart(
		"WestWallNear",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(westX, wallY, basePosition.Z - halfDepth + sideSegmentDepth / 2),
		WALL_COLOR,
		house
	)
	newPart(
		"WestWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(westX, wallY, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		WALL_COLOR,
		house
	)
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"WestWallLintel",
		Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
		Vector3.new(westX, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, basePosition.Z),
		WALL_COLOR,
		house
	)

	-- The door itself: closed, it fills the gap; ProximityPrompt (E) swings
	-- it open on a hinge at the near edge of the doorway.
	local doorY = floorY + 0.5 + DOOR_HEIGHT / 2
	local door = newPart(
		"Door",
		Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
		Vector3.new(westX, doorY, basePosition.Z),
		DOOR_COLOR,
		house
	)
	door.Material = Enum.Material.Wood
	door.CanCollide = true

	local hingeZ = basePosition.Z - DOOR_WIDTH / 2
	setupSwingingDoor(door, westX, hingeZ)

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
