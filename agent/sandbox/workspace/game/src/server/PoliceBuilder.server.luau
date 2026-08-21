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
-- the police department sits on the opposite (west) side of Spawn, along
-- world X=-40, with its own door facing east toward Spawn.
--
-- v2: per Slack follow-up ("поставь в інше місце ... на право трохи 50
-- блоків"), moved from (-40, 0, 0) to (-40, 0, -50) -- 50 studs "to the
-- right" relative to someone standing at the station's door facing Spawn
-- (facing +X, their right hand points toward -Z), while keeping X
-- unchanged so it stays clear of the starter house/car/tree/NPC cluster
-- (all within roughly X 6-52, Z -12..18) and well short of the city (which
-- starts around Z=74).
--
-- v3: per Slack follow-up ("можеш ще трохи в право поліцкейський участок
-- перенести"), moved further the same way -- another 30 studs in -Z --
-- from (-40, 0, -50) to (-40, 0, -80), keeping the same "right" direction
-- as v2 and still well clear of everything else on the baseplate.
--
-- v4: per Slack follow-up ("ще чуть-чуть в право переставь поліцейський
-- участок"), a small further nudge in the same direction -- 15 studs in
-- -Z -- from (-40, 0, -80) to (-40, 0, -95).
--
-- v5: per Slack request ("зроби менші двері в поліцейському участку"),
-- shrunk the door from 10x24 to 6x9 (still comfortably wider/taller than a
-- default character). Every other doorway part (side wall segments, lintel,
-- sign position) is derived from DOOR_WIDTH/DOOR_HEIGHT, so it resizes
-- automatically with no other constants to touch.
--
-- v6: per Slack request ("зроби тепер вікна в поліцейському участку"),
-- added windows: a recessed navy frame plus a semi-transparent glass pane
-- (see addWindow), inset into the North/South/West solid walls (2 each)
-- and both East-wall door-flanking segments (1 each). Each window's frame
-- and glass are sized *thicker* than the wall along the wall's normal axis
-- (WALL_THICKNESS + a small margin) and centered on the same coordinate as
-- the wall itself, so they read as glazing set into the wall without any
-- z-fighting and without needing to cut an actual hole in the wall parts.
--
-- v7: per Slack request ("зроби тепер клітку в поліцейському участку"),
-- added a jail cell inside the building, in the interior northwest corner
-- (clear of every wall, window, and the entrance door's swing path): three
-- fixed sides of vertical bars (see addBarSegment) plus a solid metal gate
-- on a hinge, on the side facing into the room. The main entrance door and
-- the cell gate now share one generalized setupSwingingDoor (ported from
-- CityBuilder.server.luau, extended with a `width` parameter since the two
-- openings aren't the same size) instead of two near-duplicate formulas.
--
-- v8: per Slack request ("зроби висоту клітки до даха в поліцейському
-- участку"), the cell bars/gate now run CELL_BAR_HEIGHT = WALL_HEIGHT
-- (was a fixed 9 studs), i.e. floor to ceiling -- flush with the top of
-- every wall, exactly under the roof slab, with no gap above to climb/see
-- over.
--
-- v9: per Slack request ("зроби грубину клітки щоб вона до лівої стіни
-- була"), the cell's west side is no longer a separate row of bars a few
-- studs in from the West wall -- it now runs flush against that wall's
-- interior face (the West wall doubles as the cell's west side, so the
-- redundant CellWest bar row was removed). Only the cell's east boundary
-- is a fixed offset; the west boundary is computed from
-- halfWidth/WALL_THICKNESS so it always lines up with the real wall.
--
-- Follows the same axis-aligned-boxes-only approach as HouseBuilder (no
-- rotation math for the structure itself, so there's no risk of a
-- misoriented part) and grounds itself via GroundUtils.findGroundY instead
-- of assuming the baseplate/terrain sits at a hardcoded Y.

local POLICE_POSITION_XZ = Vector3.new(-40, 0, -95)

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
local DOOR_WIDTH = 6
local DOOR_HEIGHT = 9
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4
local TRIM_BAND_HEIGHT = 3

local WINDOW_WIDTH = 5
local WINDOW_HEIGHT = 6
local WINDOW_FRAME_BORDER = 0.6 -- how much frame shows around the glass on each side
local WINDOW_NORMAL_MARGIN = 0.6 -- how much thicker than the wall the frame is, along the wall's normal axis
local WINDOW_GLASS_NORMAL_MARGIN = 0.8 -- glass is slightly thicker still, so it renders in front of the frame with no z-fighting
local WINDOW_GLASS_COLOR = Color3.fromRGB(150, 205, 230)
local WINDOW_GLASS_TRANSPARENCY = 0.55

-- Jail cell: a barred enclosure inside the building, in the back-left
-- (northwest) interior corner -- away from the entrance door. Per Slack
-- follow-up ("зроби грубину клітки щоб вона до лівої стіни була"), its
-- west side is no longer a separate row of bars a few studs in from the
-- West wall -- it now runs flush against that wall's interior face (the
-- West wall itself becomes the cell's west side), so there's no gap to
-- squeeze through. Only the east boundary is a fixed offset; the west
-- boundary is computed from halfWidth/WALL_THICKNESS in buildPoliceDepartment
-- so it always lines up with the real wall instead of a hardcoded guess.
local CELL_EAST_X_OFFSET = -3 -- east boundary, from building center along X
local CELL_DEPTH = 8 -- along Z
local CELL_OFFSET_Z = -6 -- center, from building center along Z
local CELL_BAR_HEIGHT = WALL_HEIGHT -- floor to ceiling, per Slack request ("зроби висоту клітки до даха")
local CELL_BAR_RADIUS = 0.15
local CELL_BAR_GAP = 1.3 -- spacing between bar centers along a side
local CELL_RAIL_MARGIN = 0.1 -- how much thicker than 2x bar radius the top/bottom rails are
local CELL_BAR_COLOR = Color3.fromRGB(70, 70, 75)
local GATE_WIDTH = 3

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
-- then swings it shut. This is the same generalized formula
-- CityBuilder.server.luau's setupSwingingDoor uses (doorAxis/sign/
-- hingeWidthCoord/wallCoord), ported verbatim rather than re-derived, so it
-- inherits that already-shipped, visually-checked swing direction instead of
-- risking a new sign error. Extended with an explicit `width` parameter
-- (CityBuilder hardcodes a single DOOR_WIDTH for every door; this building
-- has two different-width openings -- the entrance and the cell gate).
local function setupSwingingDoor(
	door: Part,
	doorAxis: string,
	sign: number,
	hingeWidthCoord: number,
	wallCoord: number,
	width: number,
	objectText: string
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
	prompt.ObjectText = objectText
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

-- Inset window: a navy frame plus a semi-transparent glass pane, centered
-- on the same normal-axis coordinate as the wall it sits in (see v6 note
-- above for why this avoids z-fighting without cutting a hole).
-- `axis` is the wall's normal axis ("Z" for the North/South walls, whose
-- plane is a fixed Z; "X" for the West/East walls, whose plane is a fixed
-- X). `wallCoord` is that fixed coordinate, `alongCoord` is where the
-- window sits along the wall's length, and `y` is its vertical center.
local function addWindow(axis: string, wallCoord: number, alongCoord: number, y: number, parent: Instance, name: string)
	local glassWidth = WINDOW_WIDTH - WINDOW_FRAME_BORDER * 2
	local glassHeight = WINDOW_HEIGHT - WINDOW_FRAME_BORDER * 2

	local frameSize: Vector3
	local glassSize: Vector3
	local position: Vector3
	if axis == "Z" then
		frameSize = Vector3.new(WINDOW_WIDTH, WINDOW_HEIGHT, WALL_THICKNESS + WINDOW_NORMAL_MARGIN)
		glassSize = Vector3.new(glassWidth, glassHeight, WALL_THICKNESS + WINDOW_GLASS_NORMAL_MARGIN)
		position = Vector3.new(alongCoord, y, wallCoord)
	else
		frameSize = Vector3.new(WALL_THICKNESS + WINDOW_NORMAL_MARGIN, WINDOW_HEIGHT, WINDOW_WIDTH)
		glassSize = Vector3.new(WALL_THICKNESS + WINDOW_GLASS_NORMAL_MARGIN, glassHeight, glassWidth)
		position = Vector3.new(wallCoord, y, alongCoord)
	end

	newPart(name .. "Frame", frameSize, position, TRIM_COLOR, parent)
	local glass = newPart(name .. "Glass", glassSize, position, WINDOW_GLASS_COLOR, parent)
	glass.Material = Enum.Material.Glass
	glass.Transparency = WINDOW_GLASS_TRANSPARENCY
	glass.CanCollide = false
end

-- Builds one straight run of vertical jail-cell bars (from `fromAlong` to
-- `toAlong`, along the wall's length axis) plus a top and bottom rail
-- connecting them, on a fixed-coordinate wall whose normal is `axis`
-- ("Z" for the cell's North/South sides, "X" for its East/West sides).
-- Bars are plain Cylinder parts rotated 90 degrees around Z to stand
-- upright (same trick TreeBuilder.server.luau uses for its trunk), so
-- there's no risk of a misoriented part.
local function addBarSegment(
	axis: string,
	wallCoord: number,
	fromAlong: number,
	toAlong: number,
	baseY: number,
	parent: Instance,
	namePrefix: string
)
	local length = toAlong - fromAlong
	local barCount = math.max(2, math.floor(length / CELL_BAR_GAP) + 1)
	local step = length / (barCount - 1)

	for i = 0, barCount - 1 do
		local alongCoord = fromAlong + i * step
		local position
		if axis == "Z" then
			position = Vector3.new(alongCoord, baseY + CELL_BAR_HEIGHT / 2, wallCoord)
		else
			position = Vector3.new(wallCoord, baseY + CELL_BAR_HEIGHT / 2, alongCoord)
		end

		local bar = Instance.new("Part")
		bar.Name = namePrefix .. "Bar" .. i
		bar.Anchored = true
		bar.Shape = Enum.PartType.Cylinder
		bar.Size = Vector3.new(CELL_BAR_HEIGHT, CELL_BAR_RADIUS * 2, CELL_BAR_RADIUS * 2)
		bar.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		bar.Color = CELL_BAR_COLOR
		bar.Material = Enum.Material.Metal
		bar.Parent = parent
	end

	local railThickness = CELL_BAR_RADIUS * 2 + CELL_RAIL_MARGIN
	local midAlong = (fromAlong + toAlong) / 2
	local sizeAlong = length + CELL_BAR_RADIUS * 2
	local railSize: Vector3
	local topPosition: Vector3
	local bottomPosition: Vector3
	if axis == "Z" then
		railSize = Vector3.new(sizeAlong, railThickness, railThickness)
		topPosition = Vector3.new(midAlong, baseY + CELL_BAR_HEIGHT, wallCoord)
		bottomPosition = Vector3.new(midAlong, baseY, wallCoord)
	else
		railSize = Vector3.new(railThickness, railThickness, sizeAlong)
		topPosition = Vector3.new(wallCoord, baseY + CELL_BAR_HEIGHT, midAlong)
		bottomPosition = Vector3.new(wallCoord, baseY, midAlong)
	end

	local topRail = newPart(namePrefix .. "TopRail", railSize, topPosition, CELL_BAR_COLOR, parent)
	topRail.Material = Enum.Material.Metal
	local bottomRail = newPart(namePrefix .. "BottomRail", railSize, bottomPosition, CELL_BAR_COLOR, parent)
	bottomRail.Material = Enum.Material.Metal
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
	-- Above the base trim band, below the roofline -- a natural window band.
	local windowY = floorY + 0.5 + WALL_HEIGHT * 0.62
	local windowAlongOffset = 9 -- how far each North/South window sits from the building's X center

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
	addWindow("Z", basePosition.Z - halfDepth, basePosition.X - windowAlongOffset, windowY, station, "NorthWindowWest")
	addWindow("Z", basePosition.Z - halfDepth, basePosition.X + windowAlongOffset, windowY, station, "NorthWindowEast")

	solidWallWithTrim(
		"SouthWall",
		Vector3.new(WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(basePosition.X, wallY, basePosition.Z + halfDepth)
	)
	addWindow("Z", basePosition.Z + halfDepth, basePosition.X - windowAlongOffset, windowY, station, "SouthWindowWest")
	addWindow("Z", basePosition.Z + halfDepth, basePosition.X + windowAlongOffset, windowY, station, "SouthWindowEast")

	solidWallWithTrim(
		"WestWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, DEPTH),
		Vector3.new(basePosition.X - halfWidth, wallY, basePosition.Z)
	)
	addWindow("X", basePosition.X - halfWidth, basePosition.Z - 7, windowY, station, "WestWindowNorth")
	addWindow("X", basePosition.X - halfWidth, basePosition.Z + 7, windowY, station, "WestWindowSouth")

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
	addWindow("X", eastX, basePosition.Z - halfDepth + sideSegmentDepth / 2, windowY, station, "EastWindowNear")
	newPart(
		"EastWallFar",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSegmentDepth),
		Vector3.new(eastX, wallY, basePosition.Z + halfDepth - sideSegmentDepth / 2),
		WALL_COLOR,
		station
	)
	addWindow("X", eastX, basePosition.Z + halfDepth - sideSegmentDepth / 2, windowY, station, "EastWindowFar")
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
	setupSwingingDoor(door, "X", 1, hingeZ, eastX, DOOR_WIDTH, "Police Department")

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

	-- Jail cell: barred sides plus one solid metal gate on a hinge (per
	-- Slack requests, "зроби клітку" then "зроби грубину клітки щоб вона до
	-- лівої стіни була"). Sits in the interior northwest corner, clear of
	-- the entrance door's swing path. Its west side is the building's own
	-- West wall -- no separate row of bars there -- so the cell now runs
	-- flush from that wall's interior face to its east boundary, with no
	-- gap to squeeze through.
	local cellEastX = basePosition.X + CELL_EAST_X_OFFSET
	local cellWestX = basePosition.X - halfWidth + WALL_THICKNESS / 2 -- flush against the West wall's interior face
	local cellCenterX = (cellWestX + cellEastX) / 2
	local cellCenterZ = basePosition.Z + CELL_OFFSET_Z
	local cellHalfDepth = CELL_DEPTH / 2
	local cellBaseY = floorY + 0.5 -- floor's top surface

	addBarSegment("Z", cellCenterZ - cellHalfDepth, cellWestX, cellEastX, cellBaseY, station, "CellNorth")
	addBarSegment(
		"X",
		cellEastX,
		cellCenterZ - cellHalfDepth,
		cellCenterZ + cellHalfDepth,
		cellBaseY,
		station,
		"CellEast"
	)

	-- South side has the gate: two fixed bar segments flanking the opening.
	local southZ = cellCenterZ + cellHalfDepth
	local cellWidth = cellEastX - cellWestX
	local gateSideSpan = (cellWidth - GATE_WIDTH) / 2
	addBarSegment("Z", southZ, cellWestX, cellWestX + gateSideSpan, cellBaseY, station, "CellSouthWest")
	addBarSegment("Z", southZ, cellEastX - gateSideSpan, cellEastX, cellBaseY, station, "CellSouthEast")

	local gate = newPart(
		"CellGate",
		Vector3.new(GATE_WIDTH, CELL_BAR_HEIGHT, CELL_BAR_RADIUS * 2),
		Vector3.new(cellCenterX, cellBaseY + CELL_BAR_HEIGHT / 2, southZ),
		CELL_BAR_COLOR,
		station
	)
	gate.Material = Enum.Material.Metal
	gate.CanCollide = true

	local gateHingeX = cellCenterX - GATE_WIDTH / 2
	setupSwingingDoor(gate, "Z", 1, gateHingeX, southZ, GATE_WIDTH, "Cell Gate")

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
