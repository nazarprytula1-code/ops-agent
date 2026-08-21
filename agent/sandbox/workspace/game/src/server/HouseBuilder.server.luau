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
-- v5: doubled the whole house (walls, door, roof, wall thickness) 2x per
-- Slack request. All footprint/height/door constants below scale together,
-- so the door keeps its original ~2.2:1 height:width ratio instead of
-- becoming square. basePosition.Y is unchanged (0), and the floor is still
-- sized/positioned so its bottom sits exactly on the baseplate top (Y=0,
-- see default.project.json) -- nothing is built underground.
--
-- v6: per Slack request, this is the "main" house (as opposed to the many
-- city houses in CityBuilder.server.luau) and gets TWO beds -- city houses
-- get one each (see CityBuilder's own buildBed). Both beds are pushed flush
-- against EastWall (the wall opposite the door, which is on WestWall) and
-- spaced apart along Z, so neither blocks the doorway, the door's swing, or
-- each other.

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local WALL_HEIGHT = 28
local WIDTH = 24
local DEPTH = 24
local WALL_THICKNESS = 2
local WALL_COLOR = Color3.fromRGB(194, 178, 128)
local ROOF_COLOR = Color3.fromRGB(120, 60, 40)
local ROOF_TRIM_COLOR = Color3.fromRGB(90, 44, 30)
local DOOR_COLOR = Color3.fromRGB(63, 38, 22)
local DOOR_WIDTH = 10
local DOOR_HEIGHT = 22
local ROOF_OVERHANG = 3 -- extra width/depth the roof extends past the walls
local ROOF_THICKNESS = 2
local ROOF_TRIM_HEIGHT = 1.2
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4

-- Bed (this house gets two -- see v6 note above)
local BED_LENGTH = 6 -- head-to-foot
local BED_WIDTH = 3
local BED_ROW_OFFSET = 6 -- how far each of the two beds sits from center along Z
local BED_FRAME_HEIGHT = 1
local BED_MATTRESS_HEIGHT = 0.6
local BED_PILLOW_HEIGHT = 0.3
local BED_FRAME_COLOR = Color3.fromRGB(92, 64, 40)
local BED_MATTRESS_COLOR = Color3.fromRGB(235, 235, 225)
local BED_PILLOW_COLOR = Color3.fromRGB(250, 250, 250)
local BED_BLANKET_COLOR = Color3.fromRGB(150, 40, 40)

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

-- Builds one simple boxy bed (frame + mattress + pillow + blanket) and
-- parents it under `parent`. `x`/`z` is the bed's footprint center; `axis`
-- is which world axis the bed's head-to-foot length runs along ("X" or
-- "Z"), and `sign` (-1 or 1) is which end along that axis is the head
-- (where the pillow goes -- callers push the head against a wall).
local function buildBed(x: number, z: number, floorY: number, axis: string, sign: number, length: number, width: number, parent: Instance): Model
	local bed = Instance.new("Model")
	bed.Name = "Bed"

	local frameSize = if axis == "Z" then Vector3.new(width, BED_FRAME_HEIGHT, length) else Vector3.new(length, BED_FRAME_HEIGHT, width)
	local frameY = floorY + 0.5 + BED_FRAME_HEIGHT / 2
	newPart("BedFrame", frameSize, Vector3.new(x, frameY, z), BED_FRAME_COLOR, bed)

	local mattressSize = if axis == "Z"
		then Vector3.new(width * 0.88, BED_MATTRESS_HEIGHT, length * 0.96)
		else Vector3.new(length * 0.96, BED_MATTRESS_HEIGHT, width * 0.88)
	local mattressY = frameY + BED_FRAME_HEIGHT / 2 + BED_MATTRESS_HEIGHT / 2
	newPart("Mattress", mattressSize, Vector3.new(x, mattressY, z), BED_MATTRESS_COLOR, bed)

	local pillowLength = math.min(length * 0.22, 1)
	local headOffset = sign * (length / 2 - pillowLength / 2 - 0.1)
	local pillowX = if axis == "Z" then x else x + headOffset
	local pillowZ = if axis == "Z" then z + headOffset else z
	local pillowSize = if axis == "Z" then Vector3.new(width * 0.65, BED_PILLOW_HEIGHT, pillowLength) else Vector3.new(pillowLength, BED_PILLOW_HEIGHT, width * 0.65)
	newPart(
		"Pillow",
		pillowSize,
		Vector3.new(pillowX, mattressY + BED_MATTRESS_HEIGHT / 2 + BED_PILLOW_HEIGHT / 2, pillowZ),
		BED_PILLOW_COLOR,
		bed
	)

	local blanketLength = length * 0.5
	local footOffset = -sign * (length / 2 - blanketLength / 2 - 0.1)
	local blanketX = if axis == "Z" then x else x + footOffset
	local blanketZ = if axis == "Z" then z + footOffset else z
	local blanketSize = if axis == "Z" then Vector3.new(width * 0.9, 0.15, blanketLength) else Vector3.new(blanketLength, 0.15, width * 0.9)
	local blanket = newPart(
		"Blanket",
		blanketSize,
		Vector3.new(blanketX, mattressY + BED_MATTRESS_HEIGHT / 2 + 0.08, blanketZ),
		BED_BLANKET_COLOR,
		bed
	)
	blanket.Material = Enum.Material.Fabric

	bed.Parent = parent
	return bed
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

	-- Two beds (v6): pushed flush against EastWall, the wall opposite the
	-- door, and spaced apart along Z so they don't touch each other, the
	-- North/South walls, or the door's swing.
	local bedX = basePosition.X + (halfWidth - WALL_THICKNESS / 2 - BED_LENGTH / 2)
	buildBed(bedX, basePosition.Z - BED_ROW_OFFSET, floorY, "X", 1, BED_LENGTH, BED_WIDTH, house)
	buildBed(bedX, basePosition.Z + BED_ROW_OFFSET, floorY, "X", 1, BED_LENGTH, BED_WIDTH, house)

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
