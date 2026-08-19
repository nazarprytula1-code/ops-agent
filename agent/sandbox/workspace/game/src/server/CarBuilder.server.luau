local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Builds one simple car out of parts parked beside the main house, per
-- Slack request ("добав машину біля основного будиночка").
--
-- Placement: the house (see HouseBuilder.server.luau) is a 24x24 footprint
-- centered at HOUSE_POSITION with its door on the west wall (facing Spawn
-- at world X=0) and a tree at its southwest exterior corner (see
-- TreeBuilder.server.luau). The car is parked just outside the house's
-- east exterior wall -- clear of the door/walk-up path and the tree.
--
-- The car's length runs along Z and its width along X, so the wheels'
-- circular faces point along world X with zero rotation: Roblox's default
-- Cylinder part shape already has its axis along the part's local X, so
-- this keeps the whole model axis-aligned with no rotation math (same
-- reasoning HouseBuilder/TreeBuilder use to avoid misoriented parts).
--
-- Height is derived from the real ground surface via GroundUtils, not a
-- hardcoded Y, so the car sits correctly even if the live baseplate/terrain
-- at that spot ever differs from default.project.json.

local HOUSE_POSITION = Vector3.new(24, 0, 0)
local HOUSE_HALF_WIDTH = 12 -- WIDTH / 2 from HouseBuilder
local CAR_CLEARANCE = 8 -- studs beyond the house's east exterior wall

local CAR_XZ = Vector3.new(HOUSE_POSITION.X + HOUSE_HALF_WIDTH + CAR_CLEARANCE, 0, HOUSE_POSITION.Z)

local BODY_LENGTH = 16 -- along Z (front-back)
local BODY_WIDTH = 7 -- along X (left-right)
local BODY_HEIGHT = 4.5
local BODY_COLOR = Color3.fromRGB(178, 34, 34)

local CABIN_LENGTH = 8
local CABIN_WIDTH = 5.5
local CABIN_HEIGHT = 3.4
local CABIN_COLOR = Color3.fromRGB(200, 225, 235)
local CABIN_Z_OFFSET = -1 -- shift slightly toward the rear, like a cabin set back from the hood

local WHEEL_DIAMETER = 4
local WHEEL_THICKNESS = 1
local WHEEL_COLOR = Color3.fromRGB(25, 25, 25)
local WHEEL_X_OFFSET = BODY_WIDTH / 2 + 0.2 -- pokes out slightly past the body sides, like a real wheel
local WHEEL_Z_OFFSET = BODY_LENGTH / 2 - WHEEL_DIAMETER / 2 - 1.5 -- front/rear axle position

local RIDE_HEIGHT_RATIO = 0.55 -- fraction of wheel diameter the body's underside sits above wheel center

local function newBoxPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
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

local function newWheel(name: string, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.Size = Vector3.new(WHEEL_THICKNESS, WHEEL_DIAMETER, WHEEL_DIAMETER)
	part.Position = position
	part.Color = WHEEL_COLOR
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

-- groundY is the real top-of-ground surface the wheels rest on.
local function buildCar(x: number, groundY: number, z: number): Model
	local car = Instance.new("Model")
	car.Name = "Car"

	local wheelY = groundY + WHEEL_DIAMETER / 2
	local bodyBottomY = groundY + WHEEL_DIAMETER * RIDE_HEIGHT_RATIO
	local bodyY = bodyBottomY + BODY_HEIGHT / 2
	local cabinY = bodyBottomY + BODY_HEIGHT + CABIN_HEIGHT / 2

	local body = newBoxPart("Body", Vector3.new(BODY_WIDTH, BODY_HEIGHT, BODY_LENGTH), Vector3.new(x, bodyY, z), BODY_COLOR, car)

	newBoxPart(
		"Cabin",
		Vector3.new(CABIN_WIDTH, CABIN_HEIGHT, CABIN_LENGTH),
		Vector3.new(x, cabinY, z + CABIN_Z_OFFSET),
		CABIN_COLOR,
		car
	)

	newWheel("WheelFrontLeft", Vector3.new(x - WHEEL_X_OFFSET, wheelY, z + WHEEL_Z_OFFSET), car)
	newWheel("WheelFrontRight", Vector3.new(x + WHEEL_X_OFFSET, wheelY, z + WHEEL_Z_OFFSET), car)
	newWheel("WheelRearLeft", Vector3.new(x - WHEEL_X_OFFSET, wheelY, z - WHEEL_Z_OFFSET), car)
	newWheel("WheelRearRight", Vector3.new(x + WHEEL_X_OFFSET, wheelY, z - WHEEL_Z_OFFSET), car)

	car.PrimaryPart = body
	return car
end

local Cars = Workspace:FindFirstChild("Cars")
if not Cars then
	Cars = Instance.new("Folder")
	Cars.Name = "Cars"
	Cars.Parent = Workspace
end

local existingCar = Cars:FindFirstChild("Car")
if existingCar then
	existingCar:Destroy()
end

local groundY = GroundUtils.findGroundY(CAR_XZ.X, CAR_XZ.Z, Cars)
local car = buildCar(CAR_XZ.X, groundY, CAR_XZ.Z)
car.Parent = Cars
