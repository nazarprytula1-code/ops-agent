local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Builds a small garage next to the police department, per Slack request
-- ("зроби граж справа біля поліцейського участка").
--
-- Placement: the police department (PoliceBuilder.server.luau) sits at
-- world (-40, 0, -95) with a 34(X) x 26(Z) footprint, so its exterior
-- faces are roughly X -58..-22, Z -109..-81 (half extents 17/13 plus half
-- the 2-stud wall). "Справа" (to the right) follows this thread's established
-- convention for this building: someone standing at its door facing Spawn
-- (facing +X) calls -Z "right" -- the same direction the station itself
-- was repeatedly nudged in earlier. So the garage sits along that same -Z
-- side, sharing the station's X center, with a gap so the two buildings
-- don't touch.
--
-- These station dimensions are duplicated from PoliceBuilder.server.luau
-- as documented constants (same approach TreeBuilder/CarBuilder use to
-- reference HouseBuilder's HOUSE_POSITION) rather than a shared import,
-- since these builder scripts are intentionally standalone.
local STATION_POSITION_XZ = Vector3.new(-40, 0, -95) -- PoliceBuilder's POLICE_POSITION_XZ (Y is unused here; only .X/.Z matter)
local STATION_HALF_DEPTH = 13 -- DEPTH / 2 from PoliceBuilder
local STATION_WALL_THICKNESS = 2 -- WALL_THICKNESS from PoliceBuilder

local GARAGE_GAP = 8 -- clearance between the station's north wall and the garage

local WALL_HEIGHT = 14
local WIDTH = 20 -- along X
local DEPTH = 16 -- along Z
local WALL_THICKNESS = 2
local WALL_COLOR = Color3.fromRGB(210, 210, 212)
local TRIM_COLOR = Color3.fromRGB(18, 40, 92) -- matches the police department's navy trim
local ROOF_COLOR = Color3.fromRGB(45, 45, 50)
local ROOF_OVERHANG = 2
local ROOF_THICKNESS = 2
local ROOF_TRIM_HEIGHT = 1
local TRIM_BAND_HEIGHT = 3

-- Big roll-up-style vehicle door on the East wall (facing Spawn, same side
-- as the police department's entrance).
local DOOR_COLOR = Color3.fromRGB(150, 150, 155)
local DOOR_WIDTH = 12
local DOOR_HEIGHT = 10
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.6

local GARAGE_CENTER_X = STATION_POSITION_XZ.X
local GARAGE_CENTER_Z = STATION_POSITION_XZ.Z - STATION_HALF_DEPTH - STATION_WALL_THICKNESS / 2 - GARAGE_GAP - DEPTH / 2

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
-- like a big vehicle door, then swings it shut. Same generalized formula
-- as PoliceBuilder.server.luau/CityBuilder.server.luau's setupSwingingDoor
-- (doorAxis/sign/hingeWidthCoord/wallCoord/width), ported rather than
-- re-derived so it inherits that already-shipped, visually-checked swing
-- direction instead of risking a new sign error.
local function setupSwingingDoor(
	door: Part,
	doorAxis: string,
	sign: number,
	hingeWidthCoord: number,
	wallCoord: number,
	width: number
)
	local closedCFrame = door.CFrame
	local offsetNormal = wallCoord - sign * width / 2
	local openCFrame
	if doorAxis == "Z" then
		openCFrame = CFrame.new(hingeWidthCoord, door.Position.Y, offsetNormal) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)
	else
		openCFrame = CFrame.new(offsetNormal, door.Position.Y, hingeWidthCoord) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Garage"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
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

local function buildGarage(basePosition: Vector3): Model
	local garage = Instance.new("Model")
	garage.Name = "Garage"

	local floorY = basePosition.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(WIDTH, 1, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(150, 150, 150),
		garage
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2
	local halfWidth = WIDTH / 2
	local halfDepth = DEPTH / 2

	local function solidWallWithTrim(name: string, size: Vector3, position: Vector3)
		newPart(name, size, position, WALL_COLOR, garage)
		newPart(
			name .. "Trim",
			Vector3.new(size.X, TRIM_BAND_HEIGHT, size.Z),
			Vector3.new(position.X, floorY + 0.5 + TRIM_BAND_HEIGHT / 2, position.Z),
			TRIM_COLOR,
			garage
		)
	end

	-- North, South and West walls are solid.
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

	-- East wall faces Spawn, same side as the police department's own
	-- entrance. It has the big vehicle doorway: two side segments plus a
	-- lintel above the gap, plus a real openable door.
	local eastX = basePosition.X + halfWidth
	local sideSegmentDepth = (DEPTH - DOOR_WIDTH) / 2
	newPart(
		"EastWallNear",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, wallY, basePosition.Z - halfDepth + sideSegmentDepth / 2),
		WALL_COLOR,
		garage
	)
	newPart(
		"EastWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, wallY, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		WALL_COLOR,
		garage
	)
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"EastWallLintel",
		Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
		Vector3.new(eastX, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, basePosition.Z),
		WALL_COLOR,
		garage
	)

	-- The big door itself: closed, it fills the gap; ProximityPrompt (E)
	-- swings it open on a hinge, like a side-hinged vehicle door. (Kept as a
	-- single plain part, not a multi-piece "roll-up" look -- any decorative
	-- child parts wouldn't move with it when it's tweened, since only the
	-- door part's own CFrame is animated.)
	local doorY = floorY + 0.5 + DOOR_HEIGHT / 2
	local door = newPart(
		"Door",
		Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
		Vector3.new(eastX, doorY, basePosition.Z),
		DOOR_COLOR,
		garage
	)
	door.Material = Enum.Material.Metal
	door.CanCollide = true

	local hingeZ = basePosition.Z - DOOR_WIDTH / 2
	setupSwingingDoor(door, "X", 1, hingeZ, eastX, DOOR_WIDTH)

	-- Flat overhanging roof: two stacked axis-aligned slabs, no rotation.
	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(WIDTH + ROOF_OVERHANG * 2, ROOF_THICKNESS, DEPTH + ROOF_OVERHANG * 2),
		Vector3.new(basePosition.X, roofY, basePosition.Z),
		ROOF_COLOR,
		garage
	)
	newPart(
		"RoofTrim",
		Vector3.new(WIDTH + ROOF_OVERHANG, ROOF_TRIM_HEIGHT, DEPTH + ROOF_OVERHANG),
		Vector3.new(basePosition.X, roofY + ROOF_THICKNESS / 2 + ROOF_TRIM_HEIGHT / 2, basePosition.Z),
		TRIM_COLOR,
		garage
	)

	-- "GARAGE" sign above the door, same SurfaceGui approach as the police
	-- department's sign.
	local sign = newPart(
		"Sign",
		Vector3.new(0.5, 3, DOOR_WIDTH - 2),
		Vector3.new(eastX + 0.5, floorY + 0.5 + DOOR_HEIGHT + 2, basePosition.Z),
		TRIM_COLOR,
		garage
	)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Right
	gui.LightInfluence = 0
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "GARAGE"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Font = Enum.Font.SourceSansBold
	label.TextScaled = true
	label.Parent = gui

	garage.PrimaryPart = floor
	return garage
end

local Garages = Workspace:FindFirstChild("Garages")
if not Garages then
	Garages = Instance.new("Folder")
	Garages.Name = "Garages"
	Garages.Parent = Workspace
end

local existingGarage = Garages:FindFirstChild("Garage")
if existingGarage then
	existingGarage:Destroy()
end

local groundY = GroundUtils.findGroundY(GARAGE_CENTER_X, GARAGE_CENTER_Z, Garages)
local garage = buildGarage(Vector3.new(GARAGE_CENTER_X, groundY, GARAGE_CENTER_Z))
garage.Parent = Garages
