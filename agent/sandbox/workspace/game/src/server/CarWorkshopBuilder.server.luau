local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Builds a small car workshop/garage, per Slack request ("зроби майстерню
-- машин" -- "make a car workshop"). Follows the same axis-aligned-boxes
-- approach as HouseBuilder/TreeBuilder/CarBuilder: no rotation math, so
-- there's no risk of a misoriented part.
--
-- Placement: mirrors CarBuilder's own math to line up with the parked car
-- (see CarBuilder.server.luau) -- the house (HouseBuilder.server.luau) is a
-- 24x24 footprint centered at HOUSE_POSITION, and the car is parked just
-- outside the house's east exterior wall. The workshop sits further south
-- of that car, clear of both the house and the car, with its overhead door
-- facing north so walking south from the car/house leads straight to the
-- entrance.
--
-- Height is derived from the real ground surface via GroundUtils (not a
-- hardcoded Y), same reasoning as every other builder script here -- the
-- live baseplate/terrain can differ from what default.project.json defines.

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local HOUSE_HALF_WIDTH = 12 -- WIDTH / 2 from HouseBuilder
local CAR_CLEARANCE = 8 -- studs beyond the house's east exterior wall, from CarBuilder
local CAR_BODY_LENGTH = 16 -- BODY_LENGTH from CarBuilder, along Z

local CAR_XZ = Vector3.new(HOUSE_POSITION.X + HOUSE_HALF_WIDTH + CAR_CLEARANCE, 0, HOUSE_POSITION.Z)
local CAR_REAR_Z = CAR_XZ.Z + CAR_BODY_LENGTH / 2

local WORKSHOP_GAP_FROM_CAR = 6 -- studs between the car's rear bumper and the workshop's entrance wall
local WORKSHOP_WIDTH = 22 -- along X
local WORKSHOP_DEPTH = 24 -- along Z
local WALL_HEIGHT = 16 -- clears the car's body + cabin height with room to spare
local WALL_THICKNESS = 1.5
local WALL_COLOR = Color3.fromRGB(150, 150, 158)
local ROOF_COLOR = Color3.fromRGB(90, 90, 98)
local ROOF_OVERHANG = 2
local ROOF_THICKNESS = 1.2

local DOOR_WIDTH = 12
local DOOR_HEIGHT = 12
local DOOR_COLOR = Color3.fromRGB(200, 160, 40)
local DOOR_TWEEN_SECONDS = 0.6

local WORKBENCH_COLOR = Color3.fromRGB(120, 84, 48)
local TOOLBOX_COLOR = Color3.fromRGB(200, 30, 30)

local WORKSHOP_NORTH_WALL_Z = CAR_REAR_Z + WORKSHOP_GAP_FROM_CAR
local WORKSHOP_POSITION = Vector3.new(CAR_XZ.X, 0, WORKSHOP_NORTH_WALL_Z + WORKSHOP_DEPTH / 2)

local function newPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = Enum.Material.Metal
	part.Parent = parent
	return part
end

-- Wires a ProximityPrompt (default key: E) onto an overhead garage `door`
-- that slides straight up into the header when opened, then back down when
-- closed -- unlike HouseBuilder/CityBuilder's hinge-swing doors, an overhead
-- garage door just translates along Y, so no rotation math is needed here
-- either.
local function setupGarageDoor(door: Part, openOffsetY: number)
	local closedCFrame = door.CFrame
	local openCFrame = closedCFrame + Vector3.new(0, openOffsetY, 0)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPrompt"
	prompt.ActionText = "Open"
	prompt.ObjectText = "Garage Door"
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

-- groundY is the real top-of-ground surface the floor rests on.
local function buildWorkshop(center: Vector3, groundY: number): Model
	local workshop = Instance.new("Model")
	workshop.Name = "CarWorkshop"

	local halfWidth = WORKSHOP_WIDTH / 2
	local halfDepth = WORKSHOP_DEPTH / 2

	local floorY = groundY + 0.5
	local floor = newPart(
		"Floor",
		Vector3.new(WORKSHOP_WIDTH, 1, WORKSHOP_DEPTH),
		Vector3.new(center.X, floorY, center.Z),
		Color3.fromRGB(110, 110, 110),
		workshop
	)
	floor.Material = Enum.Material.Concrete

	local wallTop = floorY + 0.5 + WALL_HEIGHT
	local wallY = floorY + 0.5 + WALL_HEIGHT / 2

	-- South, East and West walls are solid.
	newPart(
		"SouthWall",
		Vector3.new(WORKSHOP_WIDTH, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(center.X, wallY, center.Z + halfDepth),
		WALL_COLOR,
		workshop
	)
	newPart(
		"EastWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, WORKSHOP_DEPTH),
		Vector3.new(center.X + halfWidth, wallY, center.Z),
		WALL_COLOR,
		workshop
	)
	newPart(
		"WestWall",
		Vector3.new(WALL_THICKNESS, WALL_HEIGHT, WORKSHOP_DEPTH),
		Vector3.new(center.X - halfWidth, wallY, center.Z),
		WALL_COLOR,
		workshop
	)

	-- North wall faces the car/house (see file header). It has the overhead
	-- garage doorway: two side segments plus a header above the gap, plus
	-- the sliding door itself.
	local northZ = center.Z - halfDepth
	local sideSegmentWidth = (WORKSHOP_WIDTH - DOOR_WIDTH) / 2
	newPart(
		"NorthWallLeft",
		Vector3.new(sideSegmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(center.X - halfWidth + sideSegmentWidth / 2, wallY, northZ),
		WALL_COLOR,
		workshop
	)
	newPart(
		"NorthWallRight",
		Vector3.new(sideSegmentWidth, WALL_HEIGHT, WALL_THICKNESS),
		Vector3.new(center.X + halfWidth - sideSegmentWidth / 2, wallY, northZ),
		WALL_COLOR,
		workshop
	)
	local headerHeight = WALL_HEIGHT - DOOR_HEIGHT
	newPart(
		"NorthWallHeader",
		Vector3.new(DOOR_WIDTH, headerHeight, WALL_THICKNESS),
		Vector3.new(center.X, floorY + 0.5 + DOOR_HEIGHT + headerHeight / 2, northZ),
		WALL_COLOR,
		workshop
	)

	local door = newPart(
		"GarageDoor",
		Vector3.new(DOOR_WIDTH, DOOR_HEIGHT, WALL_THICKNESS),
		Vector3.new(center.X, floorY + 0.5 + DOOR_HEIGHT / 2, northZ),
		DOOR_COLOR,
		workshop
	)
	door.Material = Enum.Material.Metal
	door.CanCollide = true
	-- Slides up by exactly the door's own height, which tucks it fully
	-- inside the header above (headerHeight >= 0 as long as WALL_HEIGHT >=
	-- DOOR_HEIGHT).
	setupGarageDoor(door, DOOR_HEIGHT)

	-- Flat roof, same overhang approach as HouseBuilder/CityBuilder.
	local roofY = wallTop + ROOF_THICKNESS / 2
	newPart(
		"RoofSlab",
		Vector3.new(WORKSHOP_WIDTH + ROOF_OVERHANG * 2, ROOF_THICKNESS, WORKSHOP_DEPTH + ROOF_OVERHANG * 2),
		Vector3.new(center.X, roofY, center.Z),
		ROOF_COLOR,
		workshop
	)

	-- A workbench and toolbox against the back (south) wall, opposite the
	-- garage door, just for flavor -- clear of the door swing/slide and the
	-- car's parking spot in the middle of the floor.
	local benchY = floorY + 0.5 + 1.5
	newPart(
		"Workbench",
		Vector3.new(6, 3, 1.5),
		Vector3.new(center.X - 5, benchY, center.Z + halfDepth - 1.5),
		WORKBENCH_COLOR,
		workshop
	).Material = Enum.Material.WoodPlanks

	local toolbox = newPart(
		"Toolbox",
		Vector3.new(2, 1.6, 1.2),
		Vector3.new(center.X - 5, floorY + 0.5 + 0.8, center.Z + halfDepth - 3.2),
		TOOLBOX_COLOR,
		workshop
	)
	toolbox.Material = Enum.Material.SmoothPlastic

	workshop.PrimaryPart = floor
	return workshop
end

local Workshops = Workspace:FindFirstChild("Workshops")
if not Workshops then
	Workshops = Instance.new("Folder")
	Workshops.Name = "Workshops"
	Workshops.Parent = Workspace
end

local existingWorkshop = Workshops:FindFirstChild("CarWorkshop")
if existingWorkshop then
	existingWorkshop:Destroy()
end

-- Excludes the Cars folder from the raycast: the workshop sits well south
-- of the parked car so this shouldn't matter in practice, but it keeps this
-- script consistent with CarBuilder's own reasoning (never let a raycast
-- hit a parked car's body instead of the real ground).
local Cars = Workspace:FindFirstChild("Cars")
local groundY = GroundUtils.findGroundY(WORKSHOP_POSITION.X, WORKSHOP_POSITION.Z, Cars)
local workshop = buildWorkshop(WORKSHOP_POSITION, groundY)
workshop.Parent = Workshops
