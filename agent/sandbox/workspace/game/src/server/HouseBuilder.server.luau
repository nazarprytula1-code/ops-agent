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
-- v6: added a sittable toilet on the first floor (bowl + tank + a real
-- `Seat`) per Slack request.
--
-- v7: added a second floor and windows per Slack request ("ЧОМУ НЕМА
-- ДРУГОГО ПОВЕРХА І ДЕ ВІКНА"). North, South and East walls on both floors
-- now have a centered cut-out window (sill + lintel + a Glass pane) instead
-- of being solid boxes; the West wall keeps the ground-floor door and gets
-- a matching window upstairs. A second floor slab sits on top of the first
-- floor's walls with a rectangular stairwell hole, reached by a block
-- staircase built in the SouthWall/EastWall corner (opposite the toilet,
-- which stays in the NorthWall/EastWall corner). The roof now sits on top
-- of the second floor instead of the first.

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local WALL_HEIGHT = 28 -- first floor wall height
local SECOND_WALL_HEIGHT = 20 -- second floor wall height
local FLOOR2_THICKNESS = 1
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

-- Windows: a centered cut-out (side segments + sill + lintel) with a Glass
-- pane filling the gap, used on every wall except the ground-floor door wall.
local WINDOW_WIDTH = 8
local WINDOW_HEIGHT = 8
local WINDOW_SILL_HEIGHT = 8 -- distance from the floor to the bottom of the window
local GLASS_COLOR = Color3.fromRGB(170, 210, 230)

-- Toilet (bowl + tank + sittable seat), tucked in the NorthWall/EastWall
-- corner, away from the door path and the stairs.
local TOILET_MARGIN = 3 -- gap from the two walls it's tucked into
local TOILET_BOWL_WIDTH = 4
local TOILET_BOWL_DEPTH = 5
local TOILET_BOWL_HEIGHT = 3
local TOILET_SEAT_HEIGHT = 0.6
local TOILET_TANK_WIDTH = 4
local TOILET_TANK_DEPTH = 1.2
local TOILET_TANK_HEIGHT = 4
local TOILET_COLOR = Color3.fromRGB(250, 250, 250)

-- Stairs up to the second floor: a block staircase in the SouthWall/EastWall
-- corner, going up as it runs from the EastWall toward the middle of the house.
local STAIR_MARGIN = 3 -- gap from the SouthWall and EastWall
local STAIR_WIDTH = 6
local STAIR_RUN = 16 -- total horizontal distance covered while climbing
local STAIR_STEPS = 16
local STAIR_COLOR = Color3.fromRGB(120, 120, 120)

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

-- Builds a wall that runs along the X axis (North/South walls) with a
-- centered window cut into it: two side segments, a sill, a lintel, and a
-- glass pane filling the gap.
local function buildWallAlongX(
	namePrefix: string,
	centerX: number,
	wallY: number,
	wallHeight: number,
	wallLength: number,
	thickness: number,
	z: number,
	color: Color3,
	floorTopY: number,
	parent: Instance
)
	local halfLen = wallLength / 2
	local sideLen = (wallLength - WINDOW_WIDTH) / 2
	newPart(
		namePrefix .. "Left",
		Vector3.new(sideLen, wallHeight, thickness),
		Vector3.new(centerX - halfLen + sideLen / 2, wallY, z),
		color,
		parent
	)
	newPart(
		namePrefix .. "Right",
		Vector3.new(sideLen, wallHeight, thickness),
		Vector3.new(centerX + halfLen - sideLen / 2, wallY, z),
		color,
		parent
	)

	local topHeight = wallHeight - WINDOW_SILL_HEIGHT - WINDOW_HEIGHT
	local sillY = floorTopY + WINDOW_SILL_HEIGHT / 2
	newPart(namePrefix .. "Sill", Vector3.new(WINDOW_WIDTH, WINDOW_SILL_HEIGHT, thickness), Vector3.new(centerX, sillY, z), color, parent)

	local lintelY = floorTopY + WINDOW_SILL_HEIGHT + WINDOW_HEIGHT + topHeight / 2
	newPart(namePrefix .. "Lintel", Vector3.new(WINDOW_WIDTH, topHeight, thickness), Vector3.new(centerX, lintelY, z), color, parent)

	local glassY = floorTopY + WINDOW_SILL_HEIGHT + WINDOW_HEIGHT / 2
	local glass = newPart(
		namePrefix .. "Glass",
		Vector3.new(WINDOW_WIDTH - 0.6, WINDOW_HEIGHT - 0.6, 0.4),
		Vector3.new(centerX, glassY, z),
		GLASS_COLOR,
		parent
	)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.4
	glass.CanCollide = false
end

-- Same as buildWallAlongX but for a wall that runs along the Z axis
-- (East/West walls).
local function buildWallAlongZ(
	namePrefix: string,
	centerZ: number,
	wallY: number,
	wallHeight: number,
	wallLength: number,
	thickness: number,
	x: number,
	color: Color3,
	floorTopY: number,
	parent: Instance
)
	local halfLen = wallLength / 2
	local sideLen = (wallLength - WINDOW_WIDTH) / 2
	newPart(
		namePrefix .. "Near",
		Vector3.new(thickness, wallHeight, sideLen),
		Vector3.new(x, wallY, centerZ - halfLen + sideLen / 2),
		color,
		parent
	)
	newPart(
		namePrefix .. "Far",
		Vector3.new(thickness, wallHeight, sideLen),
		Vector3.new(x, wallY, centerZ + halfLen - sideLen / 2),
		color,
		parent
	)

	local topHeight = wallHeight - WINDOW_SILL_HEIGHT - WINDOW_HEIGHT
	local sillY = floorTopY + WINDOW_SILL_HEIGHT / 2
	newPart(namePrefix .. "Sill", Vector3.new(thickness, WINDOW_SILL_HEIGHT, WINDOW_WIDTH), Vector3.new(x, sillY, centerZ), color, parent)

	local lintelY = floorTopY + WINDOW_SILL_HEIGHT + WINDOW_HEIGHT + topHeight / 2
	newPart(namePrefix .. "Lintel", Vector3.new(thickness, topHeight, WINDOW_WIDTH), Vector3.new(x, lintelY, centerZ), color, parent)

	local glassY = floorTopY + WINDOW_SILL_HEIGHT + WINDOW_HEIGHT / 2
	local glass = newPart(
		namePrefix .. "Glass",
		Vector3.new(0.4, WINDOW_HEIGHT - 0.6, WINDOW_WIDTH - 0.6),
		Vector3.new(x, glassY, centerZ),
		GLASS_COLOR,
		parent
	)
	glass.Material = Enum.Material.Glass
	glass.Transparency = 0.4
	glass.CanCollide = false
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

-- Builds a small sittable toilet (bowl + tank + Seat) whose bowl bottom
-- sits on `floorTopY`, tucked into the NorthWall/EastWall corner.
local function buildToilet(basePosition: Vector3, floorTopY: number, halfWidth: number, halfDepth: number, parent: Instance)
	local toiletX = basePosition.X + halfWidth - TOILET_MARGIN - TOILET_BOWL_WIDTH / 2
	local toiletZ = basePosition.Z - halfDepth + TOILET_MARGIN + TOILET_BOWL_DEPTH / 2

	local bowlY = floorTopY + TOILET_BOWL_HEIGHT / 2
	local bowl = newPart(
		"ToiletBowl",
		Vector3.new(TOILET_BOWL_WIDTH, TOILET_BOWL_HEIGHT, TOILET_BOWL_DEPTH),
		Vector3.new(toiletX, bowlY, toiletZ),
		TOILET_COLOR,
		parent
	)
	bowl.Material = Enum.Material.SmoothPlastic

	-- Tank sits against the NorthWall, behind the bowl.
	local tankY = floorTopY + TOILET_TANK_HEIGHT / 2
	local tankZ = toiletZ - TOILET_BOWL_DEPTH / 2 + TOILET_TANK_DEPTH / 2
	local tank = newPart(
		"ToiletTank",
		Vector3.new(TOILET_TANK_WIDTH, TOILET_TANK_HEIGHT, TOILET_TANK_DEPTH),
		Vector3.new(toiletX, tankY, tankZ),
		TOILET_COLOR,
		parent
	)
	tank.Material = Enum.Material.SmoothPlastic

	-- Real Seat instance on top of the bowl so players can sit on it
	-- (click the seat prompt, same as any other Roblox seat).
	local seat = Instance.new("Seat")
	seat.Name = "ToiletSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(TOILET_BOWL_WIDTH - 0.5, TOILET_SEAT_HEIGHT, TOILET_BOWL_DEPTH - 1)
	seat.Position = Vector3.new(toiletX, bowlY + TOILET_BOWL_HEIGHT / 2 + TOILET_SEAT_HEIGHT / 2, toiletZ - 0.3)
	seat.Color = TOILET_COLOR
	seat.Material = Enum.Material.SmoothPlastic
	seat.Parent = parent
end

-- Builds a rectangular slab at height `y` covering [minX,maxX] x [minZ,maxZ]
-- but with a rectangular hole cut out at [holeMinX,holeMaxX] x
-- [holeMinZ,holeMaxZ], using 4 boxes (north/south bands plus west/east
-- infill for the middle band) so nothing is placed over the hole.
local function buildFloorWithHole(
	y: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	holeMinX: number,
	holeMaxX: number,
	holeMinZ: number,
	holeMaxZ: number,
	thickness: number,
	color: Color3,
	parent: Instance,
	namePrefix: string
)
	local function box(name: string, x0: number, x1: number, z0: number, z1: number)
		local sizeX = x1 - x0
		local sizeZ = z1 - z0
		if sizeX <= 0 or sizeZ <= 0 then
			return
		end
		newPart(name, Vector3.new(sizeX, thickness, sizeZ), Vector3.new((x0 + x1) / 2, y, (z0 + z1) / 2), color, parent)
	end

	box(namePrefix .. "North", minX, maxX, minZ, holeMinZ)
	box(namePrefix .. "South", minX, maxX, holeMaxZ, maxZ)
	box(namePrefix .. "West", minX, holeMinX, holeMinZ, holeMaxZ)
	box(namePrefix .. "East", holeMaxX, maxX, holeMinZ, holeMaxZ)
end

-- Builds a block staircase: solid stacked steps rising from `floor1TopY` to
-- `floor1TopY + totalRise`, running from `baseX` in the -X direction at
-- constant Z (`z`), centered under `STAIR_WIDTH`.
local function buildStairs(baseX: number, z: number, floor1TopY: number, totalRise: number, parent: Instance)
	local stepRun = STAIR_RUN / STAIR_STEPS
	local stepRise = totalRise / STAIR_STEPS
	for i = 1, STAIR_STEPS do
		local stepHeight = i * stepRise
		local centerX = baseX - (i - 0.5) * stepRun
		local centerY = floor1TopY + stepHeight / 2
		newPart("Step" .. i, Vector3.new(stepRun, stepHeight, STAIR_WIDTH), Vector3.new(centerX, centerY, z), STAIR_COLOR, parent)
	end
end

local function buildHouse(basePosition: Vector3): Model
	local house = Instance.new("Model")
	house.Name = "House"

	local halfWidth = WIDTH / 2
	local halfDepth = DEPTH / 2

	-- Ground (first) floor.
	local floorY = basePosition.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(WIDTH, 1, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)
	local floor1Top = floorY + 0.5

	local wall1Top = floor1Top + WALL_HEIGHT
	local wallY1 = floor1Top + WALL_HEIGHT / 2

	-- North and South walls (first floor) each get a centered window.
	buildWallAlongX(
		"NorthWall",
		basePosition.X,
		wallY1,
		WALL_HEIGHT,
		WIDTH,
		WALL_THICKNESS,
		basePosition.Z - halfDepth,
		WALL_COLOR,
		floor1Top,
		house
	)
	buildWallAlongX(
		"SouthWall",
		basePosition.X,
		wallY1,
		WALL_HEIGHT,
		WIDTH,
		WALL_THICKNESS,
		basePosition.Z + halfDepth,
		WALL_COLOR,
		floor1Top,
		house
	)

	-- East wall (first floor) also gets a centered window.
	buildWallAlongZ(
		"EastWall",
		basePosition.Z,
		wallY1,
		WALL_HEIGHT,
		DEPTH,
		WALL_THICKNESS,
		basePosition.X + halfWidth,
		WALL_COLOR,
		floor1Top,
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
		Vector3.new(westX, wallY1, basePosition.Z - halfDepth + sideSegmentDepth / 2),
		WALL_COLOR,
		house
	)
	newPart(
		"WestWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(westX, wallY1, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		WALL_COLOR,
		house
	)
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"WestWallLintel",
		Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
		Vector3.new(westX, floor1Top + DOOR_HEIGHT + lintelHeight / 2, basePosition.Z),
		WALL_COLOR,
		house
	)

	-- The door itself: closed, it fills the gap; ProximityPrompt (E) swings
	-- it open on a hinge at the near edge of the doorway.
	local doorY = floor1Top + DOOR_HEIGHT / 2
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

	-- Toilet on the first floor, tucked in the NorthWall/EastWall corner.
	buildToilet(basePosition, floor1Top, halfWidth, halfDepth, house)

	-- Stairs up to the second floor, tucked in the SouthWall/EastWall corner
	-- (opposite the toilet), climbing from the EastWall toward the middle.
	local stairBaseX = basePosition.X + halfWidth - STAIR_MARGIN
	local stairZ = basePosition.Z + halfDepth - STAIR_MARGIN - STAIR_WIDTH / 2

	-- Second floor: a slab on top of the first floor's walls, with a
	-- rectangular hole where the stairs come up.
	local floor2Y = wall1Top + FLOOR2_THICKNESS / 2
	local floor2Top = floor2Y + FLOOR2_THICKNESS / 2
	local holeMinX = stairBaseX - STAIR_RUN
	local holeMaxX = stairBaseX
	local holeMinZ = stairZ - STAIR_WIDTH / 2
	local holeMaxZ = stairZ + STAIR_WIDTH / 2
	buildFloorWithHole(
		floor2Y,
		basePosition.X - halfWidth,
		basePosition.X + halfWidth,
		basePosition.Z - halfDepth,
		basePosition.Z + halfDepth,
		holeMinX,
		holeMaxX,
		holeMinZ,
		holeMaxZ,
		FLOOR2_THICKNESS,
		Color3.fromRGB(96, 72, 48),
		house,
		"Floor2"
	)

	buildStairs(stairBaseX, stairZ, floor1Top, floor2Top - floor1Top, house)

	-- Second floor walls: all four get a centered window (no door needed --
	-- access is via the interior stairs).
	local wall2Top = floor2Top + SECOND_WALL_HEIGHT
	local wallY2 = floor2Top + SECOND_WALL_HEIGHT / 2
	buildWallAlongX(
		"NorthWall2",
		basePosition.X,
		wallY2,
		SECOND_WALL_HEIGHT,
		WIDTH,
		WALL_THICKNESS,
		basePosition.Z - halfDepth,
		WALL_COLOR,
		floor2Top,
		house
	)
	buildWallAlongX(
		"SouthWall2",
		basePosition.X,
		wallY2,
		SECOND_WALL_HEIGHT,
		WIDTH,
		WALL_THICKNESS,
		basePosition.Z + halfDepth,
		WALL_COLOR,
		floor2Top,
		house
	)
	buildWallAlongZ(
		"EastWall2",
		basePosition.Z,
		wallY2,
		SECOND_WALL_HEIGHT,
		DEPTH,
		WALL_THICKNESS,
		basePosition.X + halfWidth,
		WALL_COLOR,
		floor2Top,
		house
	)
	buildWallAlongZ(
		"WestWall2",
		basePosition.Z,
		wallY2,
		SECOND_WALL_HEIGHT,
		DEPTH,
		WALL_THICKNESS,
		basePosition.X - halfWidth,
		WALL_COLOR,
		floor2Top,
		house
	)

	-- Flat overhanging roof on top of the second floor: two stacked
	-- axis-aligned slabs, no rotation.
	local roofY = wall2Top + ROOF_THICKNESS / 2
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
