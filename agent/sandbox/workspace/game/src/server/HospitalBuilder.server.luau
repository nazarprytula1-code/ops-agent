local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Builds one hospital building out of parts near spawn on server start.
-- Mirrors HouseBuilder.server.luau's approach (axis-aligned boxes only, no
-- rotation math) but bigger, white/red colored, with a red cross sign on
-- the facade so it reads as a hospital at a glance.
--
-- Placement: Spawn is at world (0,0,0), the starter house sits at (24,0,0)
-- and the city grid sits around (0,0,260) (see CityBuilder.server.luau).
-- HOSPITAL_POSITION = (-50, 0, 0) keeps the hospital's footprint (half
-- width 18 -> X in [-68,-32]) clear of Spawn's pad (X in [-6,6]), the
-- starter house (X in [12,36]) and the city, while staying on the
-- Baseplate (X spans [-256,256], Z spans [-256,474] per default.project.json).
-- The entrance faces +X (the EastWall), i.e. toward Spawn.

local HOSPITAL_POSITION = Vector3.new(-50, 0, 0)
local WALL_HEIGHT = 36
local WIDTH = 36
local DEPTH = 28
local WALL_THICKNESS = 2
local WALL_COLOR = Color3.fromRGB(235, 235, 235)
local TRIM_COLOR = Color3.fromRGB(200, 30, 30)
local ROOF_COLOR = Color3.fromRGB(210, 210, 210)
local DOOR_COLOR = Color3.fromRGB(120, 170, 200)
local DOOR_WIDTH = 12
local DOOR_HEIGHT = 24
local ROOF_OVERHANG = 3
local ROOF_THICKNESS = 2
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4

-- Cross sign centered above the entrance, on the EastWall face.
local CROSS_ARM_LENGTH = 8
local CROSS_ARM_WIDTH = 2.4
local CROSS_THICKNESS = 0.6

local function newPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- Wires a ProximityPrompt (default key: E) onto `door` that swings it open
-- around the vertical hinge line at `hingeX`/`hingeZ`, then swings it shut.
-- Same approach as HouseBuilder.server.luau's setupSwingingDoor.
local function setupSwingingDoor(door: Part, hingeX: number, hingeZ: number)
	local closedCFrame = door.CFrame
	local doorWidth = door.Size.Z
	local openCFrame = CFrame.new(hingeX, door.Position.Y, hingeZ - doorWidth / 2) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Hospital Door"
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

local function buildHospital(basePosition: Vector3): Model
	local hospital = Instance.new("Model")
	hospital.Name = "Hospital"

	local floorY = basePosition.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(WIDTH, 1, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(200, 200, 200),
		hospital
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2
	local halfWidth = WIDTH / 2
	local halfDepth = DEPTH / 2

	-- North, South and West walls are solid.
	newPart(
		"NorthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z - halfDepth),
		WALL_COLOR,
		hospital
	)
	newPart(
		"SouthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z + halfDepth),
		WALL_COLOR,
		hospital
	)
	newPart(
		"WestWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X - halfWidth, wallY, basePosition.Z),
		WALL_COLOR,
		hospital
	)

	-- East wall faces Spawn (Spawn is at world X=0, this building is at
	-- X=-50, so walking straight from Spawn reaches the +X wall first).
	-- It has the doorway: two side segments plus a lintel above the gap,
	-- plus a real openable door.
	local eastX = basePosition.X + halfWidth
	local sideSegmentDepth = (DEPTH - DOOR_WIDTH) / 2
	newPart(
		"EastWallNear",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, wallY, basePosition.Z - halfDepth + sideSegmentDepth / 2),
		WALL_COLOR,
		hospital
	)
	newPart(
		"EastWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, wallY, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		WALL_COLOR,
		hospital
	)
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"EastWallLintel",
		Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
		Vector3.new(eastX, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, basePosition.Z),
		WALL_COLOR,
		hospital
	)

	-- The door itself: closed, it fills the gap; ProximityPrompt (E) swings
	-- it open on a hinge at the near edge of the doorway.
	local doorY = floorY + 0.5 + DOOR_HEIGHT / 2
	local door = newPart(
		"Door",
		Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
		Vector3.new(eastX, doorY, basePosition.Z),
		DOOR_COLOR,
		hospital
	)
	door.Material = Enum.Material.Glass
	door.CanCollide = true

	local hingeZ = basePosition.Z - DOOR_WIDTH / 2
	setupSwingingDoor(door, eastX, hingeZ)

	-- Flat overhanging roof, plus a red trim band -- same two-slab,
	-- axis-aligned approach as HouseBuilder.server.luau (no rotation math).
	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(WIDTH + ROOF_OVERHANG * 2, ROOF_THICKNESS, DEPTH + ROOF_OVERHANG * 2),
		Vector3.new(basePosition.X, roofY, basePosition.Z),
		ROOF_COLOR,
		hospital
	)
	newPart(
		"RoofTrim",
		Vector3.new(WIDTH + ROOF_OVERHANG, 1, DEPTH + ROOF_OVERHANG),
		Vector3.new(basePosition.X, roofY + ROOF_THICKNESS / 2 + 0.5, basePosition.Z),
		TRIM_COLOR,
		hospital
	)

	-- Red cross sign centered above the entrance, mounted flush on the
	-- EastWall face (a hair in front of the lintel so it doesn't z-fight).
	local crossZ = basePosition.Z
	local crossY = wallTop - CROSS_ARM_LENGTH / 2 - 1
	local crossX = eastX + WALL_THICKNESS / 2 + CROSS_THICKNESS / 2
	newPart(
		"CrossVertical",
		Vector3.new(CROSS_THICKNESS, CROSS_ARM_LENGTH, CROSS_ARM_WIDTH),
		Vector3.new(crossX, crossY, crossZ),
		TRIM_COLOR,
		hospital
	)
	newPart(
		"CrossHorizontal",
		Vector3.new(CROSS_THICKNESS, CROSS_ARM_WIDTH, CROSS_ARM_LENGTH),
		Vector3.new(crossX, crossY, crossZ),
		TRIM_COLOR,
		hospital
	)

	hospital.PrimaryPart = floor
	return hospital
end

local Hospitals = Workspace:FindFirstChild("Hospitals")
if not Hospitals then
	Hospitals = Instance.new("Folder")
	Hospitals.Name = "Hospitals"
	Hospitals.Parent = Workspace
end

local existingHospital = Hospitals:FindFirstChild("Hospital")
if existingHospital then
	existingHospital:Destroy()
end

local hospital = buildHospital(HOSPITAL_POSITION)
hospital.Parent = Hospitals
