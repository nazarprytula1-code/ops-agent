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
--
-- v7: per Slack request, every solid wall (North, South, East -- WestWall
-- already has the door) now gets a real see-through window: each wall is
-- split into left/right segments plus a sill below and a lintel above (same
-- idea as the door's Near/Far/Lintel segments), with a Glass part filling
-- the resulting hole so you can actually see through it, not just a painted
-- square. See buildWindowedWall.
--
-- v8: per Slack request, this house now has a second floor. Floor2 sits
-- directly on top of the first floor's walls (its bottom = the first
-- floor's wallTop) and is a windowed box just like the first floor (all 4
-- sides this time, since there's no need for a second front door -- you
-- reach it via the Stairs). The roof moves up to sit on the SECOND floor's
-- walls instead of the first floor's. A blocky staircase (StairN parts,
-- each one step taller than the last -- no ramps/rotation, matching this
-- file's existing no-rotation style) climbs the gap between the two
-- floors, tucked against NorthWall and centered in X so it stays clear of
-- both the door (WestWall) and the beds (against EastWall).
--
-- v9: Floor2 used to be one solid slab covering the entire footprint,
-- including directly above the staircase, so climbing players hit their
-- head on it and got stuck a few steps from the top (the "поремонтуй"
-- report from Slack, screenshot showed a player wedged looking up at the
-- Floor2 ceiling). Floor2 is now built from 4 strips that leave a
-- stairwell-shaped hole with headroom the whole way up. See the v9 note by
-- the Floor2 construction in buildHouse for the exact geometry.
--
-- v10: per Slack request, the second floor now has a bed too -- reuses the
-- same bedX as the ground floor's two beds (flush against EastWall2),
-- centered along Z. EastWall2's whole strip of Floor2 is west of the
-- stairwell hole, so there's no overlap to worry about.
--
-- v11: per Slack request, all 3 beds in this house (the 2 on the ground
-- floor, the 1 on Floor2) are bigger -- BED_LENGTH 6->6.5, BED_WIDTH 3->4.5.
-- All 3 beds' placement formulas are relative to these constants, so they
-- stay correctly positioned automatically. Checked clearances: the Floor2
-- bed still has 1.5 studs of clearance from the stairwell hole (was 2 at
-- the old size), and the ground floor beds still have 2.75 studs from the
-- North/South walls and 7.5 studs between each other.

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
local BED_LENGTH = 6.5 -- head-to-foot
local BED_WIDTH = 4.5
local BED_ROW_OFFSET = 6 -- how far each of the two beds sits from center along Z
local BED_FRAME_HEIGHT = 1
local BED_MATTRESS_HEIGHT = 0.6
local BED_PILLOW_HEIGHT = 0.3
local BED_FRAME_COLOR = Color3.fromRGB(92, 64, 40)
local BED_MATTRESS_COLOR = Color3.fromRGB(235, 235, 225)
local BED_PILLOW_COLOR = Color3.fromRGB(250, 250, 250)
local BED_BLANKET_COLOR = Color3.fromRGB(150, 40, 40)

-- Window (one per solid wall -- North, South, East -- see v7 note above)
local WINDOW_WIDTH = 6
local WINDOW_HEIGHT = 8
local WINDOW_SILL_HEIGHT = 10 -- floor-to-sill; lintel above is WALL_HEIGHT - this - WINDOW_HEIGHT
local WINDOW_COLOR = Color3.fromRGB(190, 230, 255)
local WINDOW_TRANSPARENCY = 0.55

-- Floor slabs + staircase (v8 note above)
local FLOOR_THICKNESS = 1
local STAIR_STEP_COUNT = 15 -- how many blocky steps climb from floor 1 to floor 2
local STAIR_STEP_DEPTH = 1.2 -- how far each step advances along Z
local STAIR_WIDTH = 4
local STAIR_COLOR = Color3.fromRGB(130, 95, 60)

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

-- Builds a solid wall with a real see-through window cut into its middle:
-- two side segments, a sill below the window, a lintel above it, and a
-- Glass part filling the gap (mirrors how the door's Near/Far/Lintel
-- segments work, just with a Sill added and no ProximityPrompt). `axis` is
-- which world axis the wall's *length* runs along ("X" for North/South
-- walls, "Z" for East/West walls); `normalCoord` is the wall's fixed
-- coordinate on the other axis; `alongCenter` is the wall's center and
-- `wallLength` its length along `axis`.
local function buildWindowedWall(name: string, axis: string, normalCoord: number, alongCenter: number, wallLength: number, wallY: number, floorY: number, parent: Instance)
	local sideSpan = (wallLength - WINDOW_WIDTH) / 2
	local lintelHeight = WALL_HEIGHT - WINDOW_SILL_HEIGHT - WINDOW_HEIGHT
	local sillY = floorY + 0.5 + WINDOW_SILL_HEIGHT / 2
	local windowY = floorY + 0.5 + WINDOW_SILL_HEIGHT + WINDOW_HEIGHT / 2
	local lintelY = floorY + 0.5 + WINDOW_SILL_HEIGHT + WINDOW_HEIGHT + lintelHeight / 2

	local glass: Part
	if axis == "X" then
		newPart(
			name .. "Left",
			Vector3.new(sideSpan, WALL_HEIGHT, WALL_THICKNESS),
			Vector3.new(alongCenter - wallLength / 2 + sideSpan / 2, wallY, normalCoord),
			WALL_COLOR,
			parent
		)
		newPart(
			name .. "Right",
			Vector3.new(sideSpan, WALL_HEIGHT, WALL_THICKNESS),
			Vector3.new(alongCenter + wallLength / 2 - sideSpan / 2, wallY, normalCoord),
			WALL_COLOR,
			parent
		)
		newPart(name .. "Sill", Vector3.new(WINDOW_WIDTH, WINDOW_SILL_HEIGHT, WALL_THICKNESS), Vector3.new(alongCenter, sillY, normalCoord), WALL_COLOR, parent)
		newPart(name .. "Lintel", Vector3.new(WINDOW_WIDTH, lintelHeight, WALL_THICKNESS), Vector3.new(alongCenter, lintelY, normalCoord), WALL_COLOR, parent)
		glass = newPart(name .. "Window", Vector3.new(WINDOW_WIDTH, WINDOW_HEIGHT, WALL_THICKNESS), Vector3.new(alongCenter, windowY, normalCoord), WINDOW_COLOR, parent)
	else
		newPart(
			name .. "Near",
			Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
			Vector3.new(normalCoord, wallY, alongCenter - wallLength / 2 + sideSpan / 2),
			WALL_COLOR,
			parent
		)
		newPart(
			name .. "Far",
			Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
			Vector3.new(normalCoord, wallY, alongCenter + wallLength / 2 - sideSpan / 2),
			WALL_COLOR,
			parent
		)
		newPart(name .. "Sill", Vector3.new(WALL_THICKNESS, WINDOW_SILL_HEIGHT, WINDOW_WIDTH), Vector3.new(normalCoord, sillY, alongCenter), WALL_COLOR, parent)
		newPart(name .. "Lintel", Vector3.new(WALL_THICKNESS, lintelHeight, WINDOW_WIDTH), Vector3.new(normalCoord, lintelY, alongCenter), WALL_COLOR, parent)
		glass = newPart(name .. "Window", Vector3.new(WALL_THICKNESS, WINDOW_HEIGHT, WINDOW_WIDTH), Vector3.new(normalCoord, windowY, alongCenter), WINDOW_COLOR, parent)
	end

	glass.Material = Enum.Material.Glass
	glass.Transparency = WINDOW_TRANSPARENCY
end

local function buildHouse(basePosition: Vector3): Model
	local house = Instance.new("Model")
	house.Name = "House"

	local floorY = basePosition.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(WIDTH, FLOOR_THICKNESS, DEPTH),
		Vector3.new(basePosition.X, floorY, basePosition.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2
	local halfWidth = WIDTH / 2
	local halfDepth = DEPTH / 2

	-- North, South and East walls are solid, each with a window (v7).
	buildWindowedWall("NorthWall", "X", basePosition.Z - halfDepth, basePosition.X, WIDTH, wallY, floorY, house)
	buildWindowedWall("SouthWall", "X", basePosition.Z + halfDepth, basePosition.X, WIDTH, wallY, floorY, house)
	buildWindowedWall("EastWall", "Z", basePosition.X + halfWidth, basePosition.Z, DEPTH, wallY, floorY, house)

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

	-- Staircase geometry (v8/v9): computed before Floor2 so Floor2 can carve
	-- out a matching stairwell hole (v9) -- see below. Starts flush against
	-- the inside of NorthWall and runs along +Z, centered in X so it stays
	-- clear of the door (WestWall) and the beds (against EastWall).
	local firstFloorSurfaceY = floorY + 0.5
	local climb = FLOOR_THICKNESS + WALL_HEIGHT
	local stepHeight = climb / STAIR_STEP_COUNT
	local stairStartZ = basePosition.Z - halfDepth + WALL_THICKNESS / 2
	local stairRunZ = STAIR_STEP_COUNT * STAIR_STEP_DEPTH

	-- Second floor (v8): a windowed box identical in footprint to the first
	-- floor, sitting directly on top of the first floor's walls. Floor2's
	-- bottom is flush with wallTop (the first floor's wall top), and all 4
	-- sides get a window -- no door needed since you reach it via Stairs.
	--
	-- v9: Floor2 used to be one solid slab covering the WHOLE footprint,
	-- including directly above the staircase -- so climbing players hit a
	-- solid ceiling a few steps from the top and got stuck (the "поремонтуй"
	-- report from Slack: a player wedged under the Floor2 ceiling, looking up
	-- at its underside). Floor2 is now built as 4 strips (left/right of the
	-- stairwell, plus north/south slivers within the stairwell's own X band)
	-- that leave a rectangular hole exactly where the staircase needs
	-- headroom, with STAIRWELL_MARGIN studs of clearance on the open sides so
	-- players don't clip the edges while walking through.
	local floorY2 = wallTop + 0.5
	local STAIRWELL_MARGIN = 1
	local holeXMin = basePosition.X - STAIR_WIDTH / 2 - STAIRWELL_MARGIN
	local holeXMax = basePosition.X + STAIR_WIDTH / 2 + STAIRWELL_MARGIN
	local holeZMin = stairStartZ -- flush with NorthWall's inner face; the wall itself already bounds this side
	local holeZMax = stairStartZ + stairRunZ + STAIRWELL_MARGIN

	local northZ = basePosition.Z - halfDepth
	local southZ = basePosition.Z + halfDepth
	local westXEdge = basePosition.X - halfWidth
	local eastXEdge = basePosition.X + halfWidth

	newPart(
		"Floor2West",
		Vector3.new(holeXMin - westXEdge, FLOOR_THICKNESS, DEPTH),
		Vector3.new((westXEdge + holeXMin) / 2, floorY2, basePosition.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)
	newPart(
		"Floor2East",
		Vector3.new(eastXEdge - holeXMax, FLOOR_THICKNESS, DEPTH),
		Vector3.new((holeXMax + eastXEdge) / 2, floorY2, basePosition.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)
	newPart(
		"Floor2North",
		Vector3.new(holeXMax - holeXMin, FLOOR_THICKNESS, holeZMin - northZ),
		Vector3.new(basePosition.X, floorY2, (northZ + holeZMin) / 2),
		Color3.fromRGB(96, 72, 48),
		house
	)
	newPart(
		"Floor2South",
		Vector3.new(holeXMax - holeXMin, FLOOR_THICKNESS, southZ - holeZMax),
		Vector3.new(basePosition.X, floorY2, (holeZMax + southZ) / 2),
		Color3.fromRGB(96, 72, 48),
		house
	)

	local wallTop2 = floorY2 + 0.5 + WALL_HEIGHT
	local wallY2 = floorY2 + 0.5 + WALL_HEIGHT / 2

	buildWindowedWall("NorthWall2", "X", basePosition.Z - halfDepth, basePosition.X, WIDTH, wallY2, floorY2, house)
	buildWindowedWall("SouthWall2", "X", basePosition.Z + halfDepth, basePosition.X, WIDTH, wallY2, floorY2, house)
	buildWindowedWall("EastWall2", "Z", basePosition.X + halfWidth, basePosition.Z, DEPTH, wallY2, floorY2, house)
	buildWindowedWall("WestWall2", "Z", basePosition.X - halfWidth, basePosition.Z, DEPTH, wallY2, floorY2, house)

	-- One bed on the second floor (v10, per Slack). Reuses the same bedX as
	-- the ground floor's beds (flush against EastWall2), centered along Z --
	-- the stairwell hole is confined to X [holeXMin, holeXMax], well west of
	-- EastWall2, so this whole strip of Floor2 is solid and clear of it.
	buildBed(bedX, basePosition.Z, floorY2, "X", 1, BED_LENGTH, BED_WIDTH, house)

	-- Staircase (v8): STAIR_STEP_COUNT solid blocks, each one step taller
	-- than the last -- a classic blocky staircase, no ramps or rotation.
	-- Together they climb the full gap between the first floor's surface and
	-- the second floor's surface (FLOOR_THICKNESS + WALL_HEIGHT studs), now
	-- with open headroom the whole way up thanks to the v9 Floor2 hole above.
	for i = 1, STAIR_STEP_COUNT do
		local stepFullHeight = i * stepHeight
		local stepZ = stairStartZ + STAIR_STEP_DEPTH * (i - 0.5)
		local step = newPart(
			"Stair" .. i,
			Vector3.new(STAIR_WIDTH, stepFullHeight, STAIR_STEP_DEPTH),
			Vector3.new(basePosition.X, firstFloorSurfaceY + stepFullHeight / 2, stepZ),
			STAIR_COLOR,
			house
		)
		step.Material = Enum.Material.Wood
	end

	-- Flat overhanging roof: two stacked axis-aligned slabs, no rotation.
	-- Now sits on the SECOND floor's walls (wallTop2), not the first
	-- floor's.
	local roofY = wallTop2 + ROOF_THICKNESS / 2
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
