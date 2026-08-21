local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Builds a small fire department station near Spawn on server start.
--
-- Placement: per Slack request, FIRE_STATION_POSITION was moved 150 studs
-- right (+X) from its original spot west of Spawn, to X=108 -- east of
-- Spawn (X=0) and the starter house (HouseBuilder.server.luau, at X=24),
-- still clear of the procedural city (CityBuilder.server.luau, whose grid
-- starts at Z=74). Ground Y is found via
-- GroundUtils.findGroundY instead of assumed, per the "never hardcode
-- ground Y" rule other builders in this repo already follow (TreeBuilder /
-- CityBuilder): the live baseplate/terrain can differ from a hardcoded 0.
--
-- Features:
--  * Red/white station building with a rooftop sign ("FIRE DEPARTMENT" /
--    "ПОЖЕЖНИЙ ВІДДІЛ") and a blinking rooftop beacon light.
--  * A large roll-up garage bay door on the wall facing Spawn (the west
--    wall, since the station now sits east of Spawn).
--    ProximityPrompt (hold E) slides it straight up and disables its
--    collision, instead of swinging like the other doors in this repo.
--  * A normal pedestrian entrance door on the south wall, reusing the same
--    hinge-swing pattern as HouseBuilder.server.luau / CityBuilder.server.luau.

local FIRE_STATION_POSITION = Vector3.new(108, 0, 6)

local WIDTH = 34 -- X footprint
local DEPTH = 26 -- Z footprint
local WALL_HEIGHT = 22
local WALL_THICKNESS = 2

local STATION_RED = Color3.fromRGB(150, 26, 26)
local TRIM_WHITE = Color3.fromRGB(235, 235, 235)
local ROOF_COLOR = Color3.fromRGB(55, 55, 55)
local DOOR_COLOR = Color3.fromRGB(60, 40, 30)
local BEACON_COLOR = Color3.fromRGB(255, 30, 30)

local GARAGE_DOOR_WIDTH = 14
local GARAGE_DOOR_HEIGHT = 16
local GARAGE_TWEEN_SECONDS = 1.1
local GARAGE_MAX_ACTIVATION_DISTANCE = 10

local SIDE_DOOR_WIDTH = 4.4
local SIDE_DOOR_HEIGHT = 8
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4
local DOOR_MAX_ACTIVATION_DISTANCE = 8

local ROOF_OVERHANG = 2
local ROOF_THICKNESS = 1.2
local ROOF_TRIM_HEIGHT = 1

local BEACON_BLINK_SECONDS = 0.5

local function newPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Concrete
	part.Parent = parent
	return part
end

-- Slides a garage bay door straight up into its header on ProximityPrompt
-- (hold E), disabling collision while open, then lowers and re-enables
-- collision when triggered again. Unlike setupSwingingDoor below, this
-- moves along Y instead of rotating around a hinge, matching how a real
-- roll-up garage door works.
local function setupGarageDoor(door: Part, riseDistance: number)
	local closedCFrame = door.CFrame
	local openCFrame = closedCFrame + Vector3.new(0, riseDistance, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "GaragePrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Garage Door"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GARAGE_MAX_ACTIVATION_DISTANCE
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
			local tween = TweenService:Create(door, TweenInfo.new(GARAGE_TWEEN_SECONDS, Enum.EasingStyle.Sine), { CFrame = openCFrame })
			tween:Play()
			tween.Completed:Wait()
			isOpen = true
		else
			prompt.ActionText = "Open"
			local tween = TweenService:Create(door, TweenInfo.new(GARAGE_TWEEN_SECONDS, Enum.EasingStyle.Sine), { CFrame = closedCFrame })
			tween:Play()
			tween.Completed:Wait()
			door.CanCollide = true
			isOpen = false
		end

		tweening = false
	end)
end

-- Wires a ProximityPrompt (default key: E) onto `door` that swings it open
-- around the vertical hinge line at `hingeX`/`hingeZ`. Mirrors
-- HouseBuilder.server.luau's setupSwingingDoor.
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
	prompt.MaxActivationDistance = DOOR_MAX_ACTIVATION_DISTANCE
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
			local tween = TweenService:Create(door, TweenInfo.new(DOOR_TWEEN_SECONDS, Enum.EasingStyle.Quad), { CFrame = openCFrame })
			tween:Play()
			tween.Completed:Wait()
			isOpen = true
		else
			prompt.ActionText = "Open"
			local tween = TweenService:Create(door, TweenInfo.new(DOOR_TWEEN_SECONDS, Enum.EasingStyle.Quad), { CFrame = closedCFrame })
			tween:Play()
			tween.Completed:Wait()
			door.CanCollide = true
			isOpen = false
		end

		tweening = false
	end)
end

-- Rooftop sign facing -X (toward Spawn), bilingual per the Slack request.
local function buildSign(center: Vector3, parent: Instance)
	local board = newPart("SignBoard", Vector3.new(0.4, 4, GARAGE_DOOR_WIDTH), center, TRIM_WHITE, parent)
	board.Material = Enum.Material.SmoothPlastic

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Left
	gui.LightInfluence = 0
	gui.PixelsPerStud = 36
	gui.Parent = board

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = gui

	local english = Instance.new("TextLabel")
	english.Size = UDim2.new(1, 0, 0.5, 0)
	english.BackgroundTransparency = 1
	english.Text = "FIRE DEPARTMENT"
	english.TextColor3 = STATION_RED
	english.Font = Enum.Font.SourceSansBold
	english.TextScaled = true
	english.Parent = gui

	local ukrainian = Instance.new("TextLabel")
	ukrainian.Size = UDim2.new(1, 0, 0.5, 0)
	ukrainian.BackgroundTransparency = 1
	ukrainian.Text = "ПОЖЕЖНИЙ ВІДДІЛ"
	ukrainian.TextColor3 = STATION_RED
	ukrainian.Font = Enum.Font.SourceSansBold
	ukrainian.TextScaled = true
	ukrainian.Parent = gui
end

-- A small rooftop beacon that blinks red forever, like a station light.
local function buildBeacon(position: Vector3, parent: Instance)
	local beacon = Instance.new("Part")
	beacon.Name = "Beacon"
	beacon.Anchored = true
	beacon.Shape = Enum.PartType.Ball
	beacon.Size = Vector3.new(1.6, 1.6, 1.6)
	beacon.Position = position
	beacon.Color = BEACON_COLOR
	beacon.Material = Enum.Material.Neon
	beacon.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = BEACON_COLOR
	light.Range = 24
	light.Brightness = 3
	light.Parent = beacon

	task.spawn(function()
		while beacon.Parent do
			beacon.Transparency = 0
			light.Enabled = true
			task.wait(BEACON_BLINK_SECONDS)
			if not beacon.Parent then
				break
			end
			beacon.Transparency = 0.85
			light.Enabled = false
			task.wait(BEACON_BLINK_SECONDS)
		end
	end)
end

local function buildFireStation(basePosition: Vector3): Model
	local station = Instance.new("Model")
	station.Name = "FireStation"

	local half = WIDTH / 2
	local halfDepth = DEPTH / 2

	local floorY = basePosition.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(WIDTH, 1, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(90, 90, 90),
		station
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2

	-- North wall (-Z side) is solid.
	newPart(
		"NorthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z - halfDepth),
		STATION_RED,
		station
	)

	-- South wall (+Z side) has the pedestrian entrance.
	local southZ = basePosition.Z + halfDepth
	local sideSegmentWidth = (WIDTH - SIDE_DOOR_WIDTH) / 2
	newPart(
		"SouthWallNear",
		Vector3.new(sideSegmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X - half + sideSegmentWidth / 2, wallY, southZ),
		STATION_RED,
		station
	)
	newPart(
		"SouthWallFar",
		Vector3.new(sideSegmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X + half - sideSegmentWidth / 2, wallY, southZ),
		STATION_RED,
		station
	)
	local sideLintelHeight = WALL_HEIGHT - SIDE_DOOR_HEIGHT
	newPart(
		"SouthWallLintel",
		Vector3.new(SIDE_DOOR_WIDTH, sideLintelHeight, WALL_THICKNESS),
		Vector3.new(basePosition.X, floorY + 0.5 + SIDE_DOOR_HEIGHT + sideLintelHeight / 2, southZ),
		STATION_RED,
		station
	)
	local sideDoor = newPart(
		"SideDoor",
		Vector3.new(SIDE_DOOR_WIDTH, SIDE_DOOR_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, floorY + 0.5 + SIDE_DOOR_HEIGHT / 2, southZ),
		DOOR_COLOR,
		station
	)
	sideDoor.Material = Enum.Material.Wood
	sideDoor.CanCollide = true
	setupSwingingDoor(sideDoor, basePosition.X - SIDE_DOOR_WIDTH / 2, southZ)

	-- East wall (+X side) is solid.
	newPart(
		"EastWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X + half, wallY, basePosition.Z),
		STATION_RED,
		station
	)

	-- West wall (-X side, facing Spawn now that the station sits east of it)
	-- has the garage bay.
	local westX = basePosition.X - half
	local garageSideDepth = (DEPTH - GARAGE_DOOR_WIDTH) / 2
	newPart(
		"WestWallNear",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, garageSideDepth),
		Vector3.new(westX, wallY, basePosition.Z - halfDepth + garageSideDepth / 2),
		STATION_RED,
		station
	)
	newPart(
		"WestWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, garageSideDepth),
		Vector3.new(westX, wallY, basePosition.Z + halfDepth - garageSideDepth / 2),
		STATION_RED,
		station
	)
	local garageLintelHeight = WALL_HEIGHT - GARAGE_DOOR_HEIGHT
	newPart(
		"WestWallLintel",
		Vector3.new(WALL_THICKNESS, garageLintelHeight, GARAGE_DOOR_WIDTH),
		Vector3.new(westX, floorY + 0.5 + GARAGE_DOOR_HEIGHT + garageLintelHeight / 2, basePosition.Z),
		TRIM_WHITE,
		station
	)
	local garageDoor = newPart(
		"GarageDoor",
		Vector3.new(WALL_THICKNESS, GARAGE_DOOR_HEIGHT, GARAGE_DOOR_WIDTH),
		Vector3.new(westX, floorY + 0.5 + GARAGE_DOOR_HEIGHT / 2, basePosition.Z),
		TRIM_WHITE,
		station
	)
	garageDoor.Material = Enum.Material.Metal
	garageDoor.CanCollide = true
	setupGarageDoor(garageDoor, GARAGE_DOOR_HEIGHT)

	buildSign(
		Vector3.new(westX - 0.3, floorY + 0.5 + GARAGE_DOOR_HEIGHT + garageLintelHeight / 2, basePosition.Z),
		station
	)

	-- Flat overhanging roof, same two-slab pattern as HouseBuilder/CityBuilder.
	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(WIDTH + ROOF_OVERHANG * 2, ROOF_THICKNESS, DEPTH + ROOF_OVERHANG * 2),
		Vector3.new(basePosition.X, roofY, basePosition.Z),
		ROOF_COLOR,
		station
	)
	newPart(
		"RoofTrim",
		Vector3.new(WIDTH + ROOF_OVERHANG, ROOF_TRIM_HEIGHT, DEPTH + ROOF_OVERHANG),
		Vector3.new(basePosition.X, roofY + ROOF_THICKNESS / 2 + ROOF_TRIM_HEIGHT / 2, basePosition.Z),
		TRIM_WHITE,
		station
	)

	buildBeacon(Vector3.new(basePosition.X, roofY + ROOF_THICKNESS / 2 + ROOF_TRIM_HEIGHT + 1, basePosition.Z), station)

	station.PrimaryPart = floor
	return station
end

local FireStationFolder = Workspace:FindFirstChild("FireStation")
if FireStationFolder then
	FireStationFolder:Destroy()
end

FireStationFolder = Instance.new("Folder")
FireStationFolder.Name = "FireStation"
FireStationFolder.Parent = Workspace

local groundY = GroundUtils.findGroundY(FIRE_STATION_POSITION.X, FIRE_STATION_POSITION.Z, FireStationFolder)

local station = buildFireStation(Vector3.new(FIRE_STATION_POSITION.X, groundY, FIRE_STATION_POSITION.Z))
station.Parent = FireStationFolder
