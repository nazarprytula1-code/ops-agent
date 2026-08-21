local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GroundUtils = require(ReplicatedStorage.Shared:WaitForChild("GroundUtils"))

-- Builds a 3-floor hotel on server start, per Slack request ("3х поверховий
-- готель"). Separate from HouseBuilder/CityBuilder/TreeBuilder/CarBuilder and
-- does not touch any of them.
--
-- v2 (per Slack: "постав готель в інше місце і постав сходи в готель"):
--   * Moved from (-70, 0, -40) to HOTEL_XZ below, a different empty patch of
--     baseplate, still clear of the starter house/car/tree (all near X=24)
--     and the City grid (Z=74..474). Because the hotel is now east of Spawn
--     instead of west, the entrance moved from the East wall to the West
--     wall (ENTRANCE_SIGN = -1) so it still faces Spawn at world X=0.
--   * Added real interior floor slabs between floor 1/2 and floor 2/3, each
--     with a stairwell hole, plus solid ascending-block stairs (the same
--     "axis-aligned boxes only" approach as every other builder here -- no
--     rotated ramps/wedges, so there's no risk of a misoriented part) and
--     guard rails around the 3 open edges of each hole (the 4th edge, where
--     the flight arrives, is left open -- that's the landing). Floors 2 and
--     3 are now actually reachable by walking up through the stairwell.
--
-- Ground Y is found with GroundUtils.findGroundY instead of assumed, so the
-- building always sits flush on whatever the live baseplate/terrain actually
-- is at that spot.

local HOTEL_XZ = Vector3.new(90, 0, -100)
local ENTRANCE_SIGN = -1 -- -1 = West wall has the door (faces Spawn from here); 1 = East wall

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
local SLAB_COLOR = Color3.fromRGB(120, 118, 112)
local STAIR_COLOR = Color3.fromRGB(150, 148, 142)
local RAIL_COLOR = Color3.fromRGB(60, 60, 66)

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

-- Interior slab (the floor between two levels) and stairwell.
--
-- v3 (per Slack screenshot: character stuck/crouched at the bottom step,
-- unable to climb): the original 10 steps over FLOOR_HEIGHT gave a 1.4-stud
-- rise per step, too tall for the Humanoid to walk up automatically (it has
-- to be able to step onto each riser without jumping). STAIR_STEP_RISE is
-- now a fixed, known-comfortable 1 stud (the standard value used for
-- walkable Roblox block stairs) and the step count is derived from
-- FLOOR_HEIGHT so it always divides evenly; STAIR_STEP_DEPTH is a fixed
-- comfortable 2-stud tread, and STAIR_RUN follows from that instead of
-- being picked independently.
local SLAB_THICKNESS = 1
local STAIR_WIDTH = 9 -- along X -- wide enough that the 3rd-person camera has room and doesn't clip into nearby walls
local STAIR_STEP_RISE = 1 -- studs per step -- low enough to walk up without jumping
local STAIR_STEP_DEPTH = 2 -- studs per step (tread depth)
local STAIR_STEP_COUNT = FLOOR_HEIGHT / STAIR_STEP_RISE -- FLOOR_HEIGHT must be a multiple of STAIR_STEP_RISE
local STAIR_RUN = STAIR_STEP_COUNT * STAIR_STEP_DEPTH -- along Z
local STAIR_MARGIN_FROM_WALL = 3 -- gap between the North wall's inner face and the first step
local RAIL_HEIGHT = 3.5
local RAIL_THICKNESS = 0.5
local STAIR_LIGHT_COLOR = Color3.fromRGB(255, 244, 214)
local STAIR_LIGHT_RANGE = 26
local STAIR_LIGHT_BRIGHTNESS = 2

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

-- Builds the slab between two floors as a rectangular frame (4 non-
-- overlapping strips) around a rectangular stairwell hole, so the hole is a
-- real gap in the geometry rather than a part hidden behind another part.
-- `slabCenterY` is the vertical center of the (thin) slab; its top is the
-- floor of the level above, its bottom is the ceiling of the level below.
local function buildSlabWithHole(
	house: Instance,
	name: string,
	center: Vector3,
	slabCenterY: number,
	holeXMin: number,
	holeXMax: number,
	holeZMin: number,
	holeZMax: number
)
	local xMin = center.X - FOOTPRINT_X / 2
	local xMax = center.X + FOOTPRINT_X / 2
	local zMin = center.Z - FOOTPRINT_Z / 2
	local zMax = center.Z + FOOTPRINT_Z / 2

	-- West strip: full Z span, X from the wall to the hole's west edge.
	newPart(
		name .. "West",
		Vector3.new(holeXMin - xMin, SLAB_THICKNESS, FOOTPRINT_Z),
		Vector3.new((xMin + holeXMin) / 2, slabCenterY, center.Z),
		SLAB_COLOR,
		house
	)
	-- East strip: full Z span, X from the hole's east edge to the wall.
	newPart(
		name .. "East",
		Vector3.new(xMax - holeXMax, SLAB_THICKNESS, FOOTPRINT_Z),
		Vector3.new((holeXMax + xMax) / 2, slabCenterY, center.Z),
		SLAB_COLOR,
		house
	)
	-- North strip: only the hole's X span, Z from the wall to the hole's north edge.
	newPart(
		name .. "North",
		Vector3.new(holeXMax - holeXMin, SLAB_THICKNESS, holeZMin - zMin),
		Vector3.new((holeXMin + holeXMax) / 2, slabCenterY, (zMin + holeZMin) / 2),
		SLAB_COLOR,
		house
	)
	-- South strip: only the hole's X span, Z from the hole's south edge to the wall.
	newPart(
		name .. "South",
		Vector3.new(holeXMax - holeXMin, SLAB_THICKNESS, zMax - holeZMax),
		Vector3.new((holeXMin + holeXMax) / 2, slabCenterY, (holeZMax + zMax) / 2),
		SLAB_COLOR,
		house
	)
end

-- Solid ascending-block staircase (each step is one box, bottom flush on
-- `fromY`, top flush at the step's height) climbing along +Z from
-- `stairZMin` to `stairZMax`, centered on `stairX`. Axis-aligned only, same
-- approach every other builder in this repo uses for structure.
local function buildStairs(house: Instance, stairX: number, stairZMin: number, stairZMax: number, fromY: number)
	for i = 1, STAIR_STEP_COUNT do
		local stepHeight = i * STAIR_STEP_RISE
		newPart(
			"Step" .. i,
			Vector3.new(STAIR_WIDTH, stepHeight, STAIR_STEP_DEPTH),
			Vector3.new(stairX, fromY + stepHeight / 2, stairZMin + (i - 0.5) * STAIR_STEP_DEPTH),
			STAIR_COLOR,
			house
		)
	end
end

-- Guard rails on the 3 edges of a stairwell hole that are a real fall risk
-- when standing on the floor above (`floorTopY`, i.e. the slab's top face).
-- The 4th edge (holeZMax, where the flight arrives) is left open -- that's
-- the landing.
local function addStairRails(
	house: Instance,
	holeXMin: number,
	holeXMax: number,
	holeZMin: number,
	holeZMax: number,
	floorTopY: number
)
	local railY = floorTopY + RAIL_HEIGHT / 2
	local holeCenterX = (holeXMin + holeXMax) / 2
	local holeCenterZ = (holeZMin + holeZMax) / 2

	newPart(
		"StairRailNorth",
		Vector3.new(holeXMax - holeXMin + RAIL_THICKNESS, RAIL_HEIGHT, RAIL_THICKNESS),
		Vector3.new(holeCenterX, railY, holeZMin),
		RAIL_COLOR,
		house
	)
	newPart(
		"StairRailWest",
		Vector3.new(RAIL_THICKNESS, RAIL_HEIGHT, holeZMax - holeZMin + RAIL_THICKNESS),
		Vector3.new(holeXMin, railY, holeCenterZ),
		RAIL_COLOR,
		house
	)
	newPart(
		"StairRailEast",
		Vector3.new(RAIL_THICKNESS, RAIL_HEIGHT, holeZMax - holeZMin + RAIL_THICKNESS),
		Vector3.new(holeXMax, railY, holeCenterZ),
		RAIL_COLOR,
		house
	)
end

-- A small ceiling-mounted light fixture (Neon cylinder + PointLight) so the
-- stairwell shaft isn't pitch dark -- it has no windows of its own, and the
-- exterior wall windows don't reach the center of the building.
local function addStairLight(house: Instance, x: number, y: number, z: number)
	local fixture = Instance.new("Part")
	fixture.Name = "StairLightFixture"
	fixture.Anchored = true
	fixture.CanCollide = false
	fixture.Shape = Enum.PartType.Cylinder
	fixture.Size = Vector3.new(0.3, 1.4, 1.4)
	fixture.CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
	fixture.Color = STAIR_LIGHT_COLOR
	fixture.Material = Enum.Material.Neon
	fixture.Parent = house

	local light = Instance.new("PointLight")
	light.Color = STAIR_LIGHT_COLOR
	light.Range = STAIR_LIGHT_RANGE
	light.Brightness = STAIR_LIGHT_BRIGHTNESS
	light.Parent = fixture
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
	local northZ = center.Z - halfZ
	local southZ = center.Z + halfZ

	-- Stairwell footprint: a single straight run against the North wall,
	-- centered on X, shared (stacked directly above itself) by both flights.
	local stairXMin = center.X - STAIR_WIDTH / 2
	local stairXMax = center.X + STAIR_WIDTH / 2
	local stairZMin = northZ + WALL_THICKNESS / 2 + STAIR_MARGIN_FROM_WALL
	local stairZMax = stairZMin + STAIR_RUN

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

		-- East and West walls (perpendicular to X). Floor 1 has the entrance
		-- doorway on whichever side faces Spawn (ENTRANCE_SIGN); every other
		-- wall/floor combination is solid with windows across the full width.
		for _, sign in ipairs({ -1, 1 }) do
			local wallX = center.X + sign * halfX
			local wallName = sign < 0 and "WestWall" or "EastWall"

			if floor == 1 and sign == ENTRANCE_SIGN then
				local sideSpan = (FOOTPRINT_Z - DOOR_WIDTH) / 2
				newPart(
					wallName .. "Near",
					Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT, sideSpan),
					Vector3.new(wallX, wallY, center.Z - halfZ + sideSpan / 2),
					wallColor,
					hotel
				)
				newPart(
					wallName .. "Far",
					Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT, sideSpan),
					Vector3.new(wallX, wallY, center.Z + halfZ - sideSpan / 2),
					wallColor,
					hotel
				)
				local lintelHeight = FLOOR_HEIGHT - DOOR_HEIGHT
				newPart(
					wallName .. "Lintel",
					Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
					Vector3.new(wallX, floorBottomY + DOOR_HEIGHT + lintelHeight / 2, center.Z),
					wallColor,
					hotel
				)

				local doorY = floorBottomY + DOOR_HEIGHT / 2
				local door = newPart(
					"Door",
					Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
					Vector3.new(wallX, doorY, center.Z),
					DOOR_COLOR,
					hotel
				)
				door.Material = Enum.Material.Wood
				door.CanCollide = true
				setupSwingingDoor(door, wallX, center.Z - DOOR_WIDTH / 2)

				addWindowRow(hotel, "X", wallX, sign, center.Z, FOOTPRINT_Z, windowY, EAST_WEST_WINDOW_COUNT, WINDOW_DOOR_CLEARANCE)
			else
				newPart(
					wallName .. floor,
					Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT, FOOTPRINT_Z),
					Vector3.new(wallX, wallY, center.Z),
					wallColor,
					hotel
				)
				addWindowRow(hotel, "X", wallX, sign, center.Z, FOOTPRINT_Z, windowY, EAST_WEST_WINDOW_COUNT)
			end
		end

		-- Interior slab + stairwell + stairs + rails between this floor and
		-- the next one (not built above the top floor -- the roof covers it).
		if floor < FLOORS then
			local slabTopY = floorBottomY + FLOOR_HEIGHT
			local slabCenterY = slabTopY - SLAB_THICKNESS / 2
			buildSlabWithHole(hotel, "Slab" .. floor, center, slabCenterY, stairXMin, stairXMax, stairZMin, stairZMax)
			buildStairs(hotel, center.X, stairZMin, stairZMax, floorBottomY)
			addStairRails(hotel, stairXMin, stairXMax, stairZMin, stairZMax, slabTopY)

			local lightY = slabTopY - 1 -- just under the ceiling of this flight
			addStairLight(hotel, center.X, lightY, stairZMin + STAIR_RUN * 0.25)
			addStairLight(hotel, center.X, lightY, stairZMin + STAIR_RUN * 0.75)
		end
	end

	local wallTop = wallBaseY + FLOORS * FLOOR_HEIGHT

	-- Trim band right under the roof (top floor only -- floors 1/2 no longer
	-- need one now that the real interior slabs mark those seams).
	newPart(
		"FloorBand" .. FLOORS,
		Vector3.new(FOOTPRINT_X + 0.4, 0.6, FOOTPRINT_Z + 0.4),
		Vector3.new(center.X, wallTop, center.Z),
		BAND_TRIM_COLOR,
		hotel
	)

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

	-- "HOTEL" sign above the entrance, facing Spawn.
	local entranceX = center.X + ENTRANCE_SIGN * halfX
	local signY = wallBaseY + FLOOR_HEIGHT + 1.5
	local sign = newPart(
		"SignBoard",
		Vector3.new(0.4, 3, DOOR_WIDTH + 6),
		Vector3.new(entranceX + ENTRANCE_SIGN * 0.4, signY, center.Z),
		SIGN_BOARD_COLOR,
		hotel
	)
	sign.Material = Enum.Material.Metal

	local signGui = Instance.new("SurfaceGui")
	signGui.Name = "SignGui"
	signGui.Face = ENTRANCE_SIGN == 1 and Enum.NormalId.Right or Enum.NormalId.Left
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
