local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Builds a police department building near Spawn, per Slack request
-- ("зроби поліцейський відділ").
--
-- Placement: the starter house (HouseBuilder.server.luau) sits at
-- (24, 0, 0) with its door facing Spawn (world X=0). The car
-- (CarBuilder.server.luau) is parked east of that house, and the NPC
-- (NpcChat.server.luau) stands near it too. To stay clear of all of that,
-- the police department sits on the opposite (west) side of Spawn, at
-- (-40, 0, 0), with its own door facing east toward Spawn.
--
-- Follows the same axis-aligned-boxes-only approach as HouseBuilder (no
-- rotation math for the structure itself, so there's no risk of a
-- misoriented part) and grounds itself via GroundUtils.findGroundY instead
-- of assuming the baseplate/terrain sits at a hardcoded Y.

local POLICE_POSITION_XZ = Vector3.new(-40, 0, 0)

local WALL_HEIGHT = 32
local WIDTH = 34 -- along X
local DEPTH = 26 -- along Z
local WALL_THICKNESS = 2
local WALL_COLOR = Color3.fromRGB(232, 232, 232)
local TRIM_COLOR = Color3.fromRGB(18, 40, 92)
local ROOF_COLOR = Color3.fromRGB(45, 45, 50)
local ROOF_TRIM_HEIGHT = 1.2
local ROOF_OVERHANG = 3
local ROOF_THICKNESS = 2
local DOOR_COLOR = Color3.fromRGB(24, 34, 60)
local DOOR_WIDTH = 10
local DOOR_HEIGHT = 24
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4
local TRIM_BAND_HEIGHT = 3

local LIGHT_FLASH_SECONDS = 0.4
local RED_LIGHT_COLOR = Color3.fromRGB(255, 40, 40)
local BLUE_LIGHT_COLOR = Color3.fromRGB(40, 90, 255)
local LIGHT_OFF_COLOR = Color3.fromRGB(40, 40, 45)

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

-- Wires a ProximityPrompt (default key: E) onto `door` that swings it open,
-- then swings it shut. This is the same formula CityBuilder.server.luau's
-- setupSwingingDoor uses for an east-facing door (doorAxis="X", sign=1) --
-- reused verbatim (specialized to this one door) rather than re-derived, so
-- it inherits that already-shipped, visually-checked swing direction instead
-- of risking a new sign error.
local function setupSwingingDoor(door: Part, wallX: number, hingeZ: number)
	local closedCFrame = door.CFrame
	local sign = 1 -- east-facing wall, matches CityBuilder's doorAxis="X", sign=1 case
	local offsetNormal = wallX - sign * DOOR_WIDTH / 2
	local openCFrame = CFrame.new(offsetNormal, door.Position.Y, hingeZ) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Police Department"
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

-- Adds a "POLICE DEPARTMENT" sign above the door and a small alternating
-- red/blue light bar on the roof (classic police-station look), without any
-- rotation math -- the sign is a flat SurfaceGui on an axis-aligned board.
local function addSignAndLights(basePosition: Vector3, floorY: number, eastX: number, roofY: number, parent: Instance)
	local sign = newPart(
		"Sign",
		Vector3.new(0.5, 5, DOOR_WIDTH + 4),
		Vector3.new(eastX + 0.5, floorY + 0.5 + DOOR_HEIGHT + 4, basePosition.Z),
		TRIM_COLOR,
		parent
	)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Right
	gui.LightInfluence = 0
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "POLICE\nDEPARTMENT"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Parent = gui

	-- Light bar: two small parts side by side on the roof ridge, each with a
	-- PointLight, alternating on/off out of phase to read as a flashing
	-- police light bar.
	local barY = roofY + ROOF_THICKNESS / 2 + 1
	local redLight = newPart("RedLight", Vector3.new(2, 1.4, 3), Vector3.new(basePosition.X - 2, barY, basePosition.Z), RED_LIGHT_COLOR, parent)
	local blueLight = newPart("BlueLight", Vector3.new(2, 1.4, 3), Vector3.new(basePosition.X + 2, barY, basePosition.Z), BLUE_LIGHT_COLOR, parent)
	redLight.Material = Enum.Material.Neon
	blueLight.Material = Enum.Material.Neon

	local redPointLight = Instance.new("PointLight")
	redPointLight.Color = RED_LIGHT_COLOR
	redPointLight.Range = 20
	redPointLight.Brightness = 3
	redPointLight.Parent = redLight

	local bluePointLight = Instance.new("PointLight")
	bluePointLight.Color = BLUE_LIGHT_COLOR
	bluePointLight.Range = 20
	bluePointLight.Brightness = 3
	bluePointLight.Parent = blueLight

	task.spawn(function()
		while redLight.Parent and blueLight.Parent do
			redLight.Color = RED_LIGHT_COLOR
			redPointLight.Enabled = true
			blueLight.Color = LIGHT_OFF_COLOR
			bluePointLight.Enabled = false
			task.wait(LIGHT_FLASH_SECONDS)

			redLight.Color = LIGHT_OFF_COLOR
			redPointLight.Enabled = false
			blueLight.Color = BLUE_LIGHT_COLOR
			bluePointLight.Enabled = true
			task.wait(LIGHT_FLASH_SECONDS)
		end
	end)
end

local function buildPoliceDepartment(basePosition: Vector3): Model
	local station = Instance.new("Model")
	station.Name = "PoliceDepartment"

	local floorY = basePosition.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(WIDTH, 1, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(200, 200, 205),
		station
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2
	local halfWidth = WIDTH / 2
	local halfDepth = DEPTH / 2

	-- North, South and West walls are solid, with a navy trim band near the
	-- base for a "municipal building" look.
	local function solidWallWithTrim(name: string, size: Vector3, position: Vector3)
		newPart(name, size, position, WALL_COLOR, station)
		newPart(
			name .. "Trim",
			Vector3.new(size.X, TRIM_BAND_HEIGHT, size.Z),
			Vector3.new(position.X, floorY + 0.5 + TRIM_BAND_HEIGHT / 2, position.Z),
			TRIM_COLOR,
			station
		)
	end

	solidWallWithTrim(
		"NorthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z - halfDepth)
	)
	solidWallWithTrim(
		"SouthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z + halfDepth)
	)
	solidWallWithTrim(
		"WestWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X - halfWidth, wallY, basePosition.Z)
	)

	-- East wall faces Spawn (Spawn is at world X=0, the station is at
	-- X=-40, so walking straight there reaches the +X wall first). It has
	-- the doorway: two side segments plus a lintel above the gap, plus a
	-- real openable door.
	local eastX = basePosition.X + halfWidth
	local sideSegmentDepth = (DEPTH - DOOR_WIDTH) / 2
	newPart(
		"EastWallNear",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, wallY, basePosition.Z - halfDepth + sideSegmentDepth / 2),
		WALL_COLOR,
		station
	)
	newPart(
		"EastWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, wallY, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		WALL_COLOR,
		station
	)
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"EastWallLintel",
		Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
		Vector3.new(eastX, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, basePosition.Z),
		WALL_COLOR,
		station
	)
	newPart(
		"EastWallTrimNear",
		Vector3.new(WALL_THICKNESS, TRIM_BAND_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, floorY + 0.5 + TRIM_BAND_HEIGHT / 2, basePosition.Z - halfDepth + sideSegmentDepth / 2),
		TRIM_COLOR,
		station
	)
	newPart(
		"EastWallTrimFar",
		Vector3.new(WALL_THICKNESS, TRIM_BAND_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, floorY + 0.5 + TRIM_BAND_HEIGHT / 2, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		TRIM_COLOR,
		station
	)

	-- The door itself: closed, it fills the gap; ProximityPrompt (E) swings
	-- it open on a hinge at the near edge of the doorway.
	local doorY = floorY + 0.5 + DOOR_HEIGHT / 2
	local door = newPart(
		"Door",
		Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
		Vector3.new(eastX, doorY, basePosition.Z),
		DOOR_COLOR,
		station
	)
	door.Material = Enum.Material.Metal
	door.CanCollide = true

	local hingeZ = basePosition.Z - DOOR_WIDTH / 2
	setupSwingingDoor(door, eastX, hingeZ)

	-- Flat overhanging roof: two stacked axis-aligned slabs, no rotation.
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
		TRIM_COLOR,
		station
	)

	addSignAndLights(basePosition, floorY, eastX, roofY, station)

	station.PrimaryPart = floor
	return station
end

local PoliceDepartments = Workspace:FindFirstChild("PoliceDepartments")
if not PoliceDepartments then
	PoliceDepartments = Instance.new("Folder")
	PoliceDepartments.Name = "PoliceDepartments"
	PoliceDepartments.Parent = Workspace
end

local existingStation = PoliceDepartments:FindFirstChild("PoliceDepartment")
if existingStation then
	existingStation:Destroy()
end

local groundY = GroundUtils.findGroundY(POLICE_POSITION_XZ.X, POLICE_POSITION_XZ.Z, PoliceDepartments)
local station = buildPoliceDepartment(Vector3.new(POLICE_POSITION_XZ.X, groundY, POLICE_POSITION_XZ.Z))
station.Parent = PoliceDepartments
