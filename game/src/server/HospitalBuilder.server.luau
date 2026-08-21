local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Builds one hospital building out of parts near spawn on server start.
-- Mirrors HouseBuilder.server.luau's approach (axis-aligned boxes only, no
-- rotation math) but bigger, white/red colored, with a red cross sign on
-- the facade so it reads as a hospital at a glance.
--
-- Placement: Spawn is at world (0,0,0), the starter house sits at (24,0,0)
-- and the city grid sits around (0,0,260) (see CityBuilder.server.luau).
--
-- v2: moved from (-50, 0, 0) to (-90, 0, -60) (southwest of Spawn) per an
-- earlier Slack request.
--
-- v3: moved again per Slack request -- the southwest spot from v2 landed on
-- a football field that exists in the live Studio place but is not part of
-- this Rojo source tree (no script/position for it anywhere under game/),
-- so it can't be avoided by reading the code alone. This puts the hospital
-- on the opposite side instead: due east, past the starter house, at
-- (150, 0, -40). Footprint (half width 18, half depth 14) keeps it clear of
-- Spawn's pad (X in [-6,6], Z in [-6,6]), the starter house (X in [12,36],
-- Z in [-12,12]) and the city grid (Z >= 74), while staying on the
-- Baseplate (X spans [-256,256], Z spans [-256,474] per
-- default.project.json). The entrance now faces -X (the WestWall), i.e.
-- back toward Spawn/the house, since the building is east of Spawn now.
-- If this still overlaps the football field, tell us roughly where the
-- field is (or its Studio Position/Size) and we'll move it precisely.
--
-- v4: added interior furnishings per Slack request ("поставь щось в
-- лікарні" -- "put something in the hospital"): a reception desk just
-- inside the entrance and a hospital bed against the far (north) wall
-- (see buildHospital below). The building was an empty shell before this.

local HOSPITAL_POSITION = Vector3.new(150, 0, -40)
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

-- Cross sign centered above the entrance, on the WestWall face.
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

	-- North, South and East walls are solid.
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
		"EastWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X + halfWidth, wallY, basePosition.Z),
		WALL_COLOR,
		hospital
	)

	-- West wall faces back toward Spawn/the starter house (the building is
	-- now east of both). It has the doorway: two side segments plus a
	-- lintel above the gap, plus a real openable door.
	local westX = basePosition.X - halfWidth
	local sideSegmentDepth = (DEPTH - DOOR_WIDTH) / 2
	newPart(
		"WestWallNear",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(westX, wallY, basePosition.Z - halfDepth + sideSegmentDepth / 2),
		WALL_COLOR,
		hospital
	)
	newPart(
		"WestWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(westX, wallY, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		WALL_COLOR,
		hospital
	)
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"WestWallLintel",
		Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
		Vector3.new(westX, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, basePosition.Z),
		WALL_COLOR,
		hospital
	)

	-- The door itself: closed, it fills the gap; ProximityPrompt (E) swings
	-- it open on a hinge at the near edge of the doorway.
	local doorY = floorY + 0.5 + DOOR_HEIGHT / 2
	local door = newPart(
		"Door",
		Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
		Vector3.new(westX, doorY, basePosition.Z),
		DOOR_COLOR,
		hospital
	)
	door.Material = Enum.Material.Glass
	door.CanCollide = true

	local hingeZ = basePosition.Z - DOOR_WIDTH / 2
	setupSwingingDoor(door, westX, hingeZ)

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
	-- WestWall face (a hair in front of the lintel so it doesn't z-fight).
	local crossZ = basePosition.Z
	local crossY = wallTop - CROSS_ARM_LENGTH / 2 - 1
	local crossX = westX - WALL_THICKNESS / 2 - CROSS_THICKNESS / 2
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

	-- Interior furnishings, per Slack request ("поставь щось в лікарні" --
	-- "put something in the hospital"): a reception desk just inside the
	-- entrance and a hospital bed against the far (north) wall, so the
	-- building isn't an empty shell. All positions are derived from the
	-- existing wall/floor variables above so they stay clear of the walls
	-- regardless of WIDTH/DEPTH/WALL_THICKNESS tuning.
	local interiorFloorY = floorY + 0.5

	local deskWidth = 3
	local deskLength = 10
	local deskHeight = 3
	local deskX = westX + WALL_THICKNESS / 2 + deskWidth / 2 + 1
	newPart(
		"ReceptionDesk",
		Vector3.new(deskWidth, deskHeight, deskLength),
		Vector3.new(deskX, interiorFloorY + deskHeight / 2, basePosition.Z),
		Color3.fromRGB(230, 230, 230),
		hospital
	)
	newPart(
		"DeskSign",
		Vector3.new(0.3, 1.2, 1.2),
		Vector3.new(deskX + deskWidth / 2 + 0.15, interiorFloorY + deskHeight - 1, basePosition.Z),
		TRIM_COLOR,
		hospital
	)

	local bedWidth = 4
	local bedLength = 7
	local bedFrameHeight = 1.6
	local northWallInnerZ = basePosition.Z - halfDepth + WALL_THICKNESS / 2
	local bedZ = northWallInnerZ + bedLength / 2 + 0.5
	local bedX = basePosition.X + halfWidth / 2
	newPart(
		"BedFrame",
		Vector3.new(bedWidth, bedFrameHeight, bedLength),
		Vector3.new(bedX, interiorFloorY + bedFrameHeight / 2, bedZ),
		Color3.fromRGB(180, 180, 180),
		hospital
	)
	newPart(
		"BedMattress",
		Vector3.new(bedWidth - 0.6, 0.8, bedLength - 0.4),
		Vector3.new(bedX, interiorFloorY + bedFrameHeight + 0.4, bedZ),
		Color3.fromRGB(255, 255, 255),
		hospital
	)
	newPart(
		"BedPillow",
		Vector3.new(1.6, 0.6, bedLength - 0.4),
		Vector3.new(bedX - bedWidth / 2 + 1.2, interiorFloorY + bedFrameHeight + 0.9, bedZ),
		Color3.fromRGB(255, 255, 255),
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
