local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Procedurally builds a small city: a 4x4 grid of 16 blocks, each block
-- ("quarter") holding 12 simplified houses (3 per side, facing outward)
-- with one tree beside each house, plus roads between blocks and around
-- the outer edge of the whole grid.
--
-- This is intentionally separate from HouseBuilder.server.luau (the single
-- interactive starter house near Spawn) and does not touch it.
-- v2: the city used to sit at CITY_ORIGIN Z=500, past the edge of the
-- 512-stud Baseplate (which only reached Z=256) -- an unwalkable gap/pit
-- of empty space between Spawn and the city. Fixed two ways: moved the
-- city closer (Z=260, still clear of the starter house at (24,0,0)) and
-- extended Baseplate toward +Z in default.project.json so it now reaches
-- Z=474, comfortably past the city's near edge.
--
-- v3: the whole city was built assuming the ground is exactly Y=0 (the
-- Baseplate top per default.project.json). If the live place's actual
-- baseplate/terrain has drifted from that (e.g. edited in Studio outside
-- of Rojo), a hardcoded Y=0 buries most of the city -- that's the "city
-- underground, only ~1 block of tree tops and ~3.5 blocks of wall show"
-- report from Slack. Same fix as TreeBuilder.server.luau: a downward
-- Workspace:Raycast at the city center finds the real ground surface
-- there, and the whole city (road + every block) is built flush on top
-- of that instead of a hardcoded 0. Falls back to Y=0 if the raycast
-- finds nothing.
--
-- v4: after v3, the found ground surface was often literally the extended
-- Baseplate itself (see v2 -- it now reaches under the city's near edge),
-- so RoadBase's top landed exactly coplanar with the Baseplate's top --
-- two overlapping surfaces at the same Y flicker/z-fight (the "road is
-- blinking" report from Slack). GROUND_CLEARANCE lifts the whole city a
-- small, imperceptible amount above the raycast hit so RoadBase is always
-- strictly above whatever it landed on.
--
-- v5: per Slack request, all 192 city house doors are now real, openable
-- doors (ProximityPrompt, hold E) instead of painted panels -- the original
-- "non-interactive for performance" tradeoff from v1 is gone. Reuses the
-- same hinge-swing approach as HouseBuilder.server.luau's starter door, but
-- generalized to work for a door on any of the 4 wall orientations (see
-- setupSwingingDoor below), since city houses need doors facing all 4
-- directions depending on which edge of the block they sit on. To keep 192
-- simultaneous ProximityPrompts cheap, MaxActivationDistance is small (8
-- studs, same as the starter house) so Roblox only activates prompts for
-- doors actually near the local player; it does not scale with door count.
--
-- v6: per Slack request, every one of the 192 city houses now gets one bed
-- (the separate starter house in HouseBuilder.server.luau gets two -- see
-- that file's own buildBed/v6 note). Each bed is pushed flush against the
-- wall opposite that house's door (using the same doorAxis/doorSign the
-- house was built with) so it never blocks the doorway or the door's swing.
--
-- v7: per Slack request, all 192 city houses (walls/door/roof) and their
-- beds are scaled up 1.5x. PITCH, ROW_INSET and TREE_OFFSET are bumped by
-- the same 1.5x so the bigger houses still fit 3-per-row without
-- overlapping each other, the block edge/road, or their own tree -- the
-- bed's position is computed from HOUSE_SIZE/WALL_THICKNESS/BED_LENGTH at
-- runtime (see buildCityHouse), so it scales automatically with no extra
-- change needed.
--
-- v8: v7 only checked that houses stayed apart from their row-neighbors
-- (via PITCH) and the block edge/road (via ROW_INSET) -- it missed that
-- the corner house of one row (e.g. the north row) and the corner house of
-- the perpendicular row (e.g. the west row) sit close to the same block
-- corner, and with the bigger 1.5x houses they overlapped each other there
-- (the "хати перетинаються" report from Slack). BLOCK_SIZE is now bigger
-- (68->94) so each row can sit far enough from the block center (pushing
-- rowPerp up, which separates it from the perpendicular row at the corner)
-- while still keeping a margin from the block edge/road; ROW_INSET is
-- retuned (12->10) to fit both margins for the new house size. Both the
-- corner-corner gap and the edge-to-road gap now have a few studs of
-- clearance -- see the buildBlock geometry below. This also grows the
-- overall city footprint, so Workspace.Baseplate's Z size is extended in
-- default.project.json (730->820) so the city's far edge still lands on
-- solid ground instead of past the baseplate (the same class of bug as the
-- v2 note above, now re-triggered by the city simply being bigger).

--
-- v9: per Slack request, CITY_ORIGIN moved back (Z 260->300, +40 studs) for
-- more clearance from the starter house near Spawn. Workspace.Baseplate's Z
-- size is extended again (820->900) so the city's far edge (now further
-- out) still lands on solid ground.

--
-- v10: per Slack request, trees must not touch their house. With the old
-- TREE_OFFSET=9, the tree's leaves ball (radius 2.6) actually overlapped
-- the house's roof overhang (which sticks out ROOF_OVERHANG=1.5 past the
-- wall, i.e. HOUSE_SIZE/2+1.5=7.5 from center) by ~0.4 studs. Centering the
-- tree in the gap between two houses' roofs at the old PITCH=21 only left
-- ~0.4 studs clearance on each side -- too tight to trust. PITCH is bumped
-- 21->23 (corner-overlap margin from v8 stays positive at 2 studs, see
-- buildBlock) to open up that gap, and TREE_OFFSET is retuned to 11.5, the
-- middle of the new gap, giving ~1.4 studs of clearance from both the
-- tree's own house and the next house's roof.

-- tree's own house and the next house's roof.
--
-- v11: per Slack request, every solid wall on every city house (the 3 walls
-- that aren't the door wall) now gets a real see-through window -- same
-- approach as HouseBuilder.server.luau's buildWindowedWall: split the solid
-- wall into left/right (or near/far) segments plus a sill below and a
-- lintel above, with a Glass part filling the resulting hole.

-- Grid / layout
local GRID_SIZE = 4 -- 4x4 = 16 blocks
local BLOCK_SIZE = 94 -- footprint of one quarter, studs
local ROAD_WIDTH = 20 -- road width between quarters and around the outer edge
local ROW_INSET = 10 -- distance from a block's edge to its house row centerline
local PITCH = 23 -- spacing between the 3 house centers along one row
local TREE_OFFSET = 11.5 -- how far the tree sits from its house, along the row
local CITY_ORIGIN = Vector3.new(0, 0, 300) -- still walkable from Spawn (0,0,0); pushed back from 260 per Slack (v9) for more clearance from the starter house (24,0,0)

local CITY_SIZE = GRID_SIZE * BLOCK_SIZE + (GRID_SIZE + 1) * ROAD_WIDTH

local FALLBACK_GROUND_Y = 0 -- baseplate top per default.project.json, used only if the raycast finds nothing
local RAYCAST_HEIGHT = 500 -- start well above anything reasonable and cast straight down
local GROUND_CLEARANCE = 0.2 -- lift the city this far above the raycast hit so RoadBase never sits exactly
-- coplanar with Workspace.Baseplate (which now extends under part of the city, see v2 note above);
-- two same-Y surfaces flicker/z-fight, this guarantees the road always wins the depth test.

-- Finds the actual top-of-ground Y at (x, z) instead of assuming the
-- baseplate is exactly at Y=0, so the whole city always sits on top of
-- whatever is really there (baseplate, terrain, etc). Mirrors
-- TreeBuilder.server.luau's findGroundY.
local function findGroundY(x: number, z: number): number
	local origin = Vector3.new(x, RAYCAST_HEIGHT, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local city = Workspace:FindFirstChild("City")
	if city then
		params.FilterDescendantsInstances = { city }
	end

	local result = Workspace:Raycast(origin, Vector3.new(0, -(RAYCAST_HEIGHT * 2), 0), params)
	if result then
		return result.Position.Y
	end
	return FALLBACK_GROUND_Y
end

-- Ground
local PLATE_THICKNESS = 0.4
local PLATE_COLOR = Color3.fromRGB(90, 140, 60)
local ROAD_COLOR = Color3.fromRGB(58, 58, 58)

-- House
local HOUSE_SIZE = 12 -- square footprint, width == depth
local WALL_HEIGHT = 15
local WALL_THICKNESS = 1.5
local WALL_COLOR = Color3.fromRGB(194, 178, 128)
local ROOF_COLOR = Color3.fromRGB(120, 60, 40)
local ROOF_TRIM_COLOR = Color3.fromRGB(90, 44, 30)
local DOOR_COLOR = Color3.fromRGB(63, 38, 22)
local DOOR_WIDTH = 5.1
local DOOR_HEIGHT = 9.75
local DOOR_OPEN_ANGLE = math.rad(90)
local DOOR_TWEEN_SECONDS = 0.4
local DOOR_MAX_ACTIVATION_DISTANCE = 8 -- keeps 192 simultaneous prompts cheap; only doors near the player activate
local ROOF_OVERHANG = 1.5
local ROOF_THICKNESS = 1.2
local ROOF_TRIM_HEIGHT = 0.75

-- Bed (one per city house, per v6 note above)
local BED_LENGTH = 4.5 -- head-to-foot
local BED_WIDTH = 3
local BED_FRAME_HEIGHT = 1.05
local BED_MATTRESS_HEIGHT = 0.6
local BED_PILLOW_HEIGHT = 0.3
local BED_FRAME_COLOR = Color3.fromRGB(92, 64, 40)
local BED_MATTRESS_COLOR = Color3.fromRGB(235, 235, 225)
local BED_PILLOW_COLOR = Color3.fromRGB(250, 250, 250)
local BED_BLANKET_COLOR = Color3.fromRGB(150, 40, 40)

-- Window (one per solid wall per house -- see v11 note above)
local WINDOW_WIDTH = 4
local WINDOW_HEIGHT = 4
local WINDOW_SILL_HEIGHT = 5 -- floor-to-sill; lintel above is WALL_HEIGHT - this - WINDOW_HEIGHT
local WINDOW_COLOR = Color3.fromRGB(190, 230, 255)
local WINDOW_TRANSPARENCY = 0.55

-- Tree
local TREE_TRUNK_HEIGHT = 4
local TREE_TRUNK_RADIUS = 0.6
local TREE_LEAVES_RADIUS = 2.6
local TREE_TRUNK_COLOR = Color3.fromRGB(92, 64, 40)
local TREE_LEAVES_COLOR = Color3.fromRGB(58, 110, 48)

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

-- Wires a ProximityPrompt (default key: E) onto a city house `door` that
-- swings it open around a vertical hinge line, then swings it shut. Mirrors
-- HouseBuilder.server.luau's setupSwingingDoor, generalized for a door on
-- any of the 4 wall orientations: `doorAxis` ("X" or "Z") is the wall's
-- normal axis (same meaning as buildCityHouse's doorAxis/doorSign), `sign`
-- is which side of that axis the wall is on, `hingeWidthCoord` is the fixed
-- coordinate along the door's width axis where the hinge sits (the "Near"
-- edge, matching DoorWallNear), and `wallCoord` is the wall's fixed
-- coordinate along its normal axis.
local function setupSwingingDoor(door: Part, doorAxis: string, sign: number, hingeWidthCoord: number, wallCoord: number)
	local closedCFrame = door.CFrame
	-- Shifting the door's center this far off the wall plane, toward the
	-- room's interior (-sign direction), then rotating 90 degrees swaps the
	-- door's width/thickness axes, which keeps the edge at hingeWidthCoord
	-- fixed on the wall plane -- i.e. it hinges open instead of teleporting.
	local offsetNormal = wallCoord - sign * DOOR_WIDTH / 2
	local openCFrame
	if doorAxis == "Z" then
		openCFrame = CFrame.new(hingeWidthCoord, door.Position.Y, offsetNormal) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)
	else
		openCFrame = CFrame.new(offsetNormal, door.Position.Y, hingeWidthCoord) * CFrame.Angles(0, DOOR_OPEN_ANGLE, 0)
	end

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
-- segments work, just with a Sill added and no ProximityPrompt). Mirrors
-- HouseBuilder.server.luau's buildWindowedWall. `axis` is which world axis
-- the wall's *length* runs along ("X" for North/South walls, "Z" for
-- West/East walls); `normalCoord` is the wall's fixed coordinate on the
-- other axis; `alongCenter` is the wall's center and `wallLength` its
-- length along `axis`.
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

-- A simple two-part tree: a vertical trunk and a ball of leaves on top.
local function buildTree(position: Vector3): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Anchored = true
	trunk.Shape = Enum.PartType.Cylinder
	trunk.Size = Vector3.new(TREE_TRUNK_HEIGHT, TREE_TRUNK_RADIUS * 2, TREE_TRUNK_RADIUS * 2)
	-- A Cylinder part's height runs along its local X axis, so rotate it
	-- 90 degrees around Z to stand it upright.
	trunk.CFrame = CFrame.new(position.X, position.Y + TREE_TRUNK_HEIGHT / 2, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	trunk.Color = TREE_TRUNK_COLOR
	trunk.Material = Enum.Material.Wood
	trunk.Parent = tree

	local leaves = Instance.new("Part")
	leaves.Name = "Leaves"
	leaves.Anchored = true
	leaves.Shape = Enum.PartType.Ball
	leaves.Size = Vector3.new(TREE_LEAVES_RADIUS * 2, TREE_LEAVES_RADIUS * 2, TREE_LEAVES_RADIUS * 2)
	leaves.Position = Vector3.new(position.X, position.Y + TREE_TRUNK_HEIGHT + TREE_LEAVES_RADIUS * 0.7, position.Z)
	leaves.Color = TREE_LEAVES_COLOR
	leaves.Material = Enum.Material.Grass
	leaves.Parent = tree

	tree.PrimaryPart = trunk
	return tree
end

-- Builds one house. `doorAxis` ("X" or "Z") and `doorSign` (-1 or 1)
-- pick which of the 4 walls gets the doorway, e.g. doorAxis="Z", doorSign=-1
-- puts the doorway on the wall facing -Z. The door is a real openable
-- ProximityPrompt door (see setupSwingingDoor / v5 file header note).
local function buildCityHouse(center: Vector3, doorAxis: string, doorSign: number): Model
	local house = Instance.new("Model")
	house.Name = "House"

	local half = HOUSE_SIZE / 2
	local floorY = center.Y + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(HOUSE_SIZE, 1, HOUSE_SIZE),
		Vector3.new(center.X, floorY, center.Z),
		Color3.fromRGB(96, 72, 48),
		house
	)

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2
	local lintelHeight = WALL_HEIGHT - DOOR_HEIGHT

	local function isDoorWall(axis: string, sign: number): boolean
		return axis == doorAxis and sign == doorSign
	end

	-- Walls perpendicular to Z (the "north"/"south" faces).
	for _, sign in ipairs({ -1, 1 }) do
		local wallZ = center.Z + sign * half
		if isDoorWall("Z", sign) then
			local sideSpan = (HOUSE_SIZE - DOOR_WIDTH) / 2
			newPart(
				"DoorWallNear",
				Vector3.new(sideSpan, WALL_HEIGHT, WALL_THICKNESS),
				Vector3.new(center.X - half + sideSpan / 2, wallY, wallZ),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorWallFar",
				Vector3.new(sideSpan, WALL_HEIGHT, WALL_THICKNESS),
				Vector3.new(center.X + half - sideSpan / 2, wallY, wallZ),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorLintel",
				Vector3.new(DOOR_WIDTH, lintelHeight, WALL_THICKNESS),
				Vector3.new(center.X, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, wallZ),
				WALL_COLOR,
				house
			)
			local door = newPart(
				"Door",
				Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, WALL_THICKNESS),
				Vector3.new(center.X, floorY + 0.5 + DOOR_HEIGHT / 2, wallZ),
				DOOR_COLOR,
				house
			)
			door.Material = Enum.Material.Wood
			door.CanCollide = true
			setupSwingingDoor(door, "Z", sign, center.X - DOOR_WIDTH / 2, wallZ)
		else
			buildWindowedWall(sign < 0 and "NorthWall" or "SouthWall", "X", wallZ, center.X, HOUSE_SIZE, wallY, floorY, house)
		end
	end

	-- Walls perpendicular to X (the "west"/"east" faces).
	for _, sign in ipairs({ -1, 1 }) do
		local wallX = center.X + sign * half
		if isDoorWall("X", sign) then
			local sideSpan = (HOUSE_SIZE - DOOR_WIDTH) / 2
			newPart(
				"DoorWallNear",
				Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
				Vector3.new(wallX, wallY, center.Z - half + sideSpan / 2),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorWallFar",
				Vector3.new(WALL_THICKNESS, WALL_HEIGHT, sideSpan),
				Vector3.new(wallX, wallY, center.Z + half - sideSpan / 2),
				WALL_COLOR,
				house
			)
			newPart(
				"DoorLintel",
				Vector3.new(WALL_THICKNESS, lintelHeight, DOOR_WIDTH),
				Vector3.new(wallX, floorY + 0.5 + DOOR_HEIGHT + lintelHeight / 2, center.Z),
				WALL_COLOR,
				house
			)
			local door = newPart(
				"Door",
				Vector3.new(WALL_THICKNESS, DOOR_HEIGHT, DOOR_WIDTH),
				Vector3.new(wallX, floorY + 0.5 + DOOR_HEIGHT / 2, center.Z),
				DOOR_COLOR,
				house
			)
			door.Material = Enum.Material.Wood
			door.CanCollide = true
			setupSwingingDoor(door, "X", sign, center.Z - DOOR_WIDTH / 2, wallX)
		else
			buildWindowedWall(sign < 0 and "WestWall" or "EastWall", "Z", wallX, center.Z, HOUSE_SIZE, wallY, floorY, house)
		end
	end

	-- One bed (v6): pushed flush against the wall opposite the door (using
	-- the same doorAxis/doorSign this house's door was built with), so it
	-- never blocks the doorway or the door's swing.
	local bedSign = -doorSign
	local bedOffset = bedSign * (half - WALL_THICKNESS / 2 - BED_LENGTH / 2)
	local bedX = center.X + (doorAxis == "X" and bedOffset or 0)
	local bedZ = center.Z + (doorAxis == "Z" and bedOffset or 0)
	buildBed(bedX, bedZ, floorY, doorAxis, bedSign, BED_LENGTH, BED_WIDTH, house)

	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(HOUSE_SIZE + ROOF_OVERHANG * 2, ROOF_THICKNESS, HOUSE_SIZE + ROOF_OVERHANG * 2),
		Vector3.new(center.X, roofY, center.Z),
		ROOF_COLOR,
		house
	)
	newPart(
		"RoofTrim",
		Vector3.new(HOUSE_SIZE + ROOF_OVERHANG, ROOF_TRIM_HEIGHT, HOUSE_SIZE + ROOF_OVERHANG),
		Vector3.new(center.X, roofY + ROOF_THICKNESS / 2 + ROOF_TRIM_HEIGHT / 2, center.Z),
		ROOF_TRIM_COLOR,
		house
	)

	house.PrimaryPart = floor
	return house
end

-- Builds one quarter: a grass plate plus 12 houses+trees, 3 per side, each
-- house's door (and its tree) facing outward, away from the block center.
-- baseGroundY is the real ground surface Y found by findGroundY, not a
-- hardcoded assumption.
local function buildBlock(blockCenter: Vector3, container: Instance, baseGroundY: number)
	local block = Instance.new("Model")
	block.Name = "Block"

	local plateY = baseGroundY -- road/plate sits flush on the real ground, not a hardcoded Y=0
	local plate = newPart(
		"Plate",
		Vector3.new(BLOCK_SIZE, PLATE_THICKNESS, BLOCK_SIZE),
		Vector3.new(blockCenter.X, plateY + PLATE_THICKNESS / 2, blockCenter.Z),
		PLATE_COLOR,
		block
	)
	plate.Material = Enum.Material.Grass

	local groundY = plateY + PLATE_THICKNESS
	local rowPerp = BLOCK_SIZE / 2 - ROW_INSET

	local rows = {
		{ axis = "Z", outward = -1 }, -- north edge, doors face -Z
		{ axis = "Z", outward = 1 }, -- south edge, doors face +Z
		{ axis = "X", outward = 1 }, -- east edge, doors face +X
		{ axis = "X", outward = -1 }, -- west edge, doors face -X
	}

	for _, row in ipairs(rows) do
		for _, j in ipairs({ -1, 0, 1 }) do
			if row.axis == "Z" then
				local x = blockCenter.X + j * PITCH
				local z = blockCenter.Z + row.outward * rowPerp
				local house = buildCityHouse(Vector3.new(x, groundY, z), row.axis, row.outward)
				house.Parent = block
				local tree = buildTree(Vector3.new(x + TREE_OFFSET, groundY, z))
				tree.Parent = block
			else
				local z = blockCenter.Z + j * PITCH
				local x = blockCenter.X + row.outward * rowPerp
				local house = buildCityHouse(Vector3.new(x, groundY, z), row.axis, row.outward)
				house.Parent = block
				local tree = buildTree(Vector3.new(x, groundY, z + TREE_OFFSET))
				tree.Parent = block
			end
		end
	end

	block.Parent = container
end

local existingCity = Workspace:FindFirstChild("City")
if existingCity then
	existingCity:Destroy()
end

local City = Instance.new("Folder")
City.Name = "City"
City.Parent = Workspace

-- One raycast at the city's center grounds the whole city (road + every
-- block); the old City folder is already gone (destroyed above), so this
-- hits whatever real baseplate/terrain is actually there.
local cityGroundY = findGroundY(CITY_ORIGIN.X, CITY_ORIGIN.Z) + GROUND_CLEARANCE

local road = newPart(
	"RoadBase",
	Vector3.new(CITY_SIZE, 1, CITY_SIZE),
	Vector3.new(CITY_ORIGIN.X, cityGroundY - 0.5, CITY_ORIGIN.Z),
	ROAD_COLOR,
	City
)
road.Material = Enum.Material.Asphalt

for i = 0, GRID_SIZE - 1 do
	for k = 0, GRID_SIZE - 1 do
		local offsetX = ROAD_WIDTH + BLOCK_SIZE / 2 + i * (BLOCK_SIZE + ROAD_WIDTH) - CITY_SIZE / 2
		local offsetZ = ROAD_WIDTH + BLOCK_SIZE / 2 + k * (BLOCK_SIZE + ROAD_WIDTH) - CITY_SIZE / 2
		local blockCenter = Vector3.new(CITY_ORIGIN.X + offsetX, CITY_ORIGIN.Y, CITY_ORIGIN.Z + offsetZ)
		buildBlock(blockCenter, City, cityGroundY)
	end
end
