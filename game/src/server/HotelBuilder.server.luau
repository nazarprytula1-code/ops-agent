local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GroundUtils = require(ReplicatedStorage.Shared:WaitForChild("GroundUtils"))

-- Builds a 3-floor hotel on server start, per Slack request ("3х поверховий
-- готель"). Separate from HouseBuilder/CityBuilder/TreeBuilder/CarBuilder and
-- does not touch any of them.
--
-- Placement: west of Spawn (world X=0), clear of the starter house/car/tree
-- (all near X=24) and clear of the City grid (Z=74..474). Ground Y is found
-- with GroundUtils.findGroundY instead of assumed, so the building always
-- sits flush on whatever the live baseplate/terrain actually is at that spot.
--
-- Scope: this is an exterior shell, like the starter house. The ground floor
-- is a real walk-in room behind an openable door (ProximityPrompt, hold E).
-- Floors 2-3 are massing + windows only (no interior floor slabs or stairs)
-- -- there is currently no way to walk up to them. Adding real interior
-- floors/stairs is a reasonable follow-up if that's wanted.

local HOTEL_XZ = Vector3.new(-70, 0, -40)

local FOOTPRINT_X = 30 -- building depth along X (North/South wall length)
local FOOTPRINT_Z = 46 -- building frontage along Z (East/West wall length)
local FLOORS = 3
local FLOOR_HEIGHT = 14
local WALL_THICKNESS = 2

local GROUND_WALL_COLOR = Color3.fromRGB(150, 60, 50) -- brick base
local UPPER_WALL_COLOR = Color3.fromRGB(226, 220, 205) -- stucco upper floors
local BAND_TRIM_COLOR = Color3.fromRGB(245, 244, 238)
local ROOF_COLOR = Color3.fromRGB(70, 70, 76)
local ROOF_TRIM_COLOR = Color3.fromRGB(245, 244, 238)
local DOOR_COLOR = Color3.fromRGB(63, 38, 22)
local WINDOW_COLOR = Color3.fromRGB(140, 200, 225)
local SIGN_BOARD_COLOR = Color3.fromRGB(40, 40, 44)
local SIGN_TEXT_COLOR = Color3.fromRGB(255, 210, 90)

local DOOR_WIDTH = 10
local DOOR_HEIGHT = 12 -- < FLOOR_HEIGHT, leaves room for a lintel above it
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4

local WINDOW_WIDTH = 3.5
local WINDOW_HEIGHT = 6
local WINDOW_INSET = 0.15 -- how far the window pane sits in front of the wall face, avoids z-fighting
local WINDOW_DOOR_CLEARANCE = 7 -- skip a window if it would land this close to the door center (floor 1 only)
local EAST_WEST_WINDOW_COUNT = 6 -- per floor, spaced along FOOTPRINT_Z
local NORTH_SOUTH_WINDOW_COUNT = 3 -- per floor, spaced along FOOTPRINT_X

local ROOF_OVERHANG = 2
local ROOF_THICKNESS = 1.5
local ROOF_TRIM_HEIGHT = 1.2

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

local function newWindow(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.Position = position
	part.Color = WINDOW_COLOR
	part.Material = Enum.Material.Glass
	part.Transparency = 0.15
	part.Parent = parent
	return part
end

-- Mirrors HouseBuilder.server.luau's swinging door: hinges open around the
-- vertical line at (hingeX, hingeZ), then swings shut on the next trigger.
local function setupSwingingDoor(door: Part, hingeX: number, hingeZ: number)
	local closedCFrame = door.CFrame
	local doorWidth = door.Size.Z
	local openCFrame = CFrame.new(hingeX + doorWidth / 2, door.Position.Y, hingeZ) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Hotel Entrance"
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

-- Adds a row of `count` windows evenly spaced along `spanLength`, centered on
-- `centerCoord`, on the outer face of a wall perpendicular to `axis` ("X" or
-- "Z") at `wallCoord`, on the `sign` (-1/1) side. `skipNearCenter`, if given,
-- omits any window whose offset from centerCoord is within that distance
-- (used to keep floor-1 windows clear of the door).
local function addWindowRow(
	house: Instance,
	axis: string,
	wallCoord: number,
	sign: number,
	centerCoord: number,
	spanLength: number,
	windowY: number,
	count: number,
	skipNearCenter: number?
)
	local outerCoord = wallCoord + sign * (WALL_THICKNESS / 2 + WINDOW_INSET)
	for i = 1, count do
		local t = (i - 0.5) / count - 0.5
		local offset = t * (spanLength - WINDOW_WIDTH * 2)
		if not skipNearCenter or math.abs(offset) >= skipNearCenter then
			local coord = centerCoord + offset
			if axis == "X" then
				-- Wall perpendicular to X: pane thickness along X, width along Z.
				newWindow(
					"Window",
					Vector3.new(WINDOW_INSET * 2, WINDOW_HEIGHT, WINDOW_WIDTH),
					Vector3.new(outerCoord, windowY, coord),
					house
				)
			else
				-- Wall perpendicular to Z: pane thickness along Z, width along X.
				newWindow(
					"Window",
					Vector3.new(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_INSET * 2),
					Vector3.new(coord, windowY, outerCoord),
					house
				)
			end
		end
	end
end

-- groundY is the real top-of-ground surface (from GroundUtils.findGroundY),
-- not a hardcoded Y.
local function buildHotel(center: Vector3, groundY: number): Model
	local hotel = Instance.new("Model")
	hotel.Name = "Hotel"

	local halfX = FOOTPRINT_X / 2
	local halfZ = FOOTPRINT_Z / 2

	local floorSlabY = groundY + 0.5
	newPart(
		"Foundation",
		Vector3.new(FOOTPRINT_X, 1, FOOTPRINT_Z),
		Vector3.new(center.X, floorSlabY, center.Z),
		Color3.fromRGB(96, 96, 100),
		hotel
	)

	local wallBaseY = floorSlabY + 0.5 -- bottom of the walls, flush on the foundation slab
	local eastX = center.X + halfX
	local westX = center.X - halfX
	local northZ = center.Z - halfZ
	local southZ = center.Z + halfZ

	for floor = 1, FLOORS do
		local floorBottomY = wallBaseY + (floor - 1) * FLOOR_HEIGHT
		local wallY = floorBottomY + FLOOR_HEIGHT / 2
		local windowY = floorBottomY + FLOOR_HEIGHT * 0.55
		local wallColor = floor == 1 and GROUND_WALL_COLOR or UPPER_WALL_COLOR

		-- North and South walls (perpendicular to Z), full width, no door.
		newPart(
			"NorthWall" .. floor,
			Vector3.new(FOOTPRINT_X, FLOOR_HEIGHT, WALL_THICKNESS),
			Vector3.new(center.X, wallY, northZ),
			wallColor,
			hotel
		)
		newPart(
			"SouthWall" .. floor,
			Vector3.new(FOOTPRINT_X, FLOOR_HEIGHT, WALL_THICKNESS),
			Vector3.new(center.X, wallY, southZ),
			wallColor,
			hotel
		)
		addWindowRow(hotel, "Z", northZ, -1, center.X, FOOTPRINT_X, windowY, NORTH_SOUTH_WINDOW_COUNT)
		addWindowRow(hotel, "Z", southZ, 1, center.X, FOOTPRINT_X, windowY, NORTH_SOUTH_WINDOW_COUNT)

		-- West wall (back, perpendicular to X), full width, no door.
		newPart(
			"WestWall" .. floor,
			Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT, FOOTPRINT_Z),
			Vector3.new(westX, wallY, center.Z),
			wallColor,
			hotel
		)
		addWindowRow(hotel, "X", westX, -1, center.Z, FOOTPRINT_Z, windowY, EAST_WEST_WINDOW_COUNT)

		-- East wall (front, faces Spawn at world X=0). Floor 1 has the entrance
		-- doorway; floors 2-3 are solid with windows across the full width.
		if floor == 1 then
			local sideSpan = (FOOTPRINT_Z - DOOR_WIDTH) / 2
			newPart(
				"EastWallNear",
				Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT, sideSpan),
				Vector3.new(eastX, wallY, center.Z - halfZ + sideSpan / 2),
				wallColor,
				hotel
			)
			newPart(
				"EastWallFar",
				Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT, sideSpan),
				Vector3.new(eastX, wallY, center.Z + halfZ - sideSpan / 2),
				wallColor,
				hotel
			)
			local lintelHeight = FLOOR_HEIGHT - DOOR_HEIGHT
			newPart(
				"EastWallLintel",
				Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
				Vector3.new(eastX, floorBottomY + DOOR_HEIGHT + lintelHeight / 2, center.Z),
				wallColor,
				hotel
			)

			local doorY = floorBottomY + DOOR_HEIGHT / 2
			local door = newPart(
				"Door",
				Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
				Vector3.new(eastX, doorY, center.Z),
				DOOR_COLOR,
				hotel
			)
			door.Material = Enum.Material.Wood
			door.CanCollide = true
			setupSwingingDoor(door, eastX, center.Z - DOOR_WIDTH / 2)

			addWindowRow(hotel, "X", eastX, 1, center.Z, FOOTPRINT_Z, windowY, EAST_WEST_WINDOW_COUNT, WINDOW_DOOR_CLEARANCE)
		else
			newPart(
				"EastWall" .. floor,
				Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT, FOOTPRINT_Z),
				Vector3.new(eastX, wallY, center.Z),
				wallColor,
				hotel
			)
			addWindowRow(hotel, "X", eastX, 1, center.Z, FOOTPRINT_Z, windowY, EAST_WEST_WINDOW_COUNT)
		end

		-- Thin trim band marking the top of each floor (also hides the seam
		-- between the ground-floor brick and the upper stucco color).
		newPart(
			"FloorBand" .. floor,
			Vector3.new(FOOTPRINT_X + 0.4, 0.6, FOOTPRINT_Z + 0.4),
			Vector3.new(center.X, floorBottomY + FLOOR_HEIGHT, center.Z),
			BAND_TRIM_COLOR,
			hotel
		)
	end

	local wallTop = wallBaseY + FLOORS * FLOOR_HEIGHT

	-- Flat overhanging roof, same axis-aligned two-slab approach as
	-- HouseBuilder/CityBuilder (no rotation math, no risk of a misoriented part).
	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(FOOTPRINT_X + ROOF_OVERHANG * 2, ROOF_THICKNESS, FOOTPRINT_Z + ROOF_OVERHANG * 2),
		Vector3.new(center.X, roofY, center.Z),
		ROOF_COLOR,
		hotel
	)
	newPart(
		"RoofTrim",
		Vector3.new(FOOTPRINT_X + ROOF_OVERHANG, ROOF_TRIM_HEIGHT, FOOTPRINT_Z + ROOF_OVERHANG),
		Vector3.new(center.X, roofY + ROOF_THICKNESS / 2 + ROOF_TRIM_HEIGHT / 2, center.Z),
		ROOF_TRIM_COLOR,
		hotel
	)

	-- "HOTEL" sign above the entrance, facing Spawn (+X).
	local signY = wallBaseY + FLOOR_HEIGHT + 1.5
	local sign = newPart(
		"SignBoard",
		Vector3.new(0.4, 3, DOOR_WIDTH + 6),
		Vector3.new(eastX + 0.4, signY, center.Z),
		SIGN_BOARD_COLOR,
		hotel
	)
	sign.Material = Enum.Material.Metal

	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SignGui"
	signGui.Face = Enum.NormalId.Right -- +X face, toward Spawn
	signGui.LightInfluence = 0
	signGui.Parent = sign

	local signLabel = Instance.new("TextLabel")
	signLabel.Name = "SignLabel"
	signLabel.BackgroundTransparency = 1
	signLabel.Size = UDim2.fromScale(1, 1)
	signLabel.Font = Enum.Font.GothamBold
	signLabel.Text = "HOTEL"
	signLabel.TextColor3 = SIGN_TEXT_COLOR
	signLabel.TextScaled = true
	signLabel.Parent = signGui

	hotel.PrimaryPart = hotel:FindFirstChild("Foundation") :: Part
	return hotel
end

local Hotels = Workspace:FindFirstChild("Hotels")
if not Hotels then
	Hotels = Instance.new("Folder")
	Hotels.Name = "Hotels"
	Hotels.Parent = Workspace
end

local existingHotel = Hotels:FindFirstChild("Hotel")
if existingHotel then
	existingHotel:Destroy()
end

local groundY = GroundUtils.findGroundY(HOTEL_XZ.X, HOTEL_XZ.Z, Hotels)
local hotel = buildHotel(HOTEL_XZ, groundY)
hotel.Parent = Hotels
