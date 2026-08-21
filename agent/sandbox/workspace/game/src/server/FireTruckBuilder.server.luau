local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Builds one fire truck parked directly in front of the fire station's
-- garage bay, per Slack request ("зроби спереди пожежного відділа пожежну
-- машину" -- put a fire truck in front of the fire department).
--
-- Placement: the fire station (see FireStationBuilder.server.luau) is a
-- 34x26 footprint centered at FIRE_STATION_POSITION (X=108, Z=6), with its
-- garage bay on the west wall (facing Spawn at world X=0 -- see that file's
-- v2 note about the station moving east of Spawn). The truck sits west of
-- that wall, centered on the same Z as the garage door, so it looks parked
-- ready to pull straight out.
--
-- Same axis-aligned, no-rotation approach as CarBuilder.server.luau: length
-- runs along Z, width along X, wheels are Cylinder parts (default local-X
-- axis) so nothing needs to be rotated. Ground Y comes from
-- GroundUtils.findGroundY, not a hardcoded constant.

local FIRE_STATION_POSITION = Vector3.new(108, 0, 6)
local FIRE_STATION_HALF_WIDTH = 17 -- WIDTH / 2 from FireStationBuilder
local TRUCK_CLEARANCE = 10 -- studs beyond the station's west (garage) wall

local BODY_LENGTH = 22 -- along Z (front-back)
local BODY_WIDTH = 9 -- along X (left-right)
local BODY_HEIGHT = 6
local BODY_COLOR = Color3.fromRGB(196, 24, 24)
local STRIPE_COLOR = Color3.fromRGB(240, 240, 240)
local STRIPE_HEIGHT = 0.8

local CABIN_LENGTH = 8
local CABIN_WIDTH = 8.4
local CABIN_HEIGHT = 4.2
local CABIN_COLOR = Color3.fromRGB(210, 30, 30)
local CABIN_Z_OFFSET = 6 -- pushed toward the front (nose), like a real fire truck's cab

local WINDSHIELD_COLOR = Color3.fromRGB(190, 220, 230)

local HOSEBED_LENGTH = 10
local HOSEBED_WIDTH = 8.6
local HOSEBED_HEIGHT = 1.6
local HOSEBED_COLOR = Color3.fromRGB(60, 60, 60)
local HOSEBED_Z_OFFSET = -7 -- toward the rear

local LADDER_LENGTH = 20
local LADDER_WIDTH = 1.4
local LADDER_HEIGHT = 0.8
local LADDER_COLOR = Color3.fromRGB(200, 200, 200)

local WHEEL_DIAMETER = 4.6
local WHEEL_THICKNESS = 1.2
local WHEEL_COLOR = Color3.fromRGB(25, 25, 25)
local WHEEL_X_OFFSET = BODY_WIDTH / 2 + 0.2
local WHEEL_Z_OFFSET = BODY_LENGTH / 2 - WHEEL_DIAMETER / 2 - 1.8

local RIDE_HEIGHT_RATIO = 0.55 -- fraction of wheel diameter the body's underside sits above wheel center

local BEACON_SIZE = 1.2
local BEACON_RED = Color3.fromRGB(255, 20, 20)
local BEACON_BLUE = Color3.fromRGB(40, 90, 255)
local BEACON_BLINK_SECONDS = 0.35

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

-- A small beacon that blinks forever, alternating red/blue like real
-- emergency lights. Mirrors FireStationBuilder.server.luau's rooftop beacon.
local function buildBeacon(name: string, position: Vector3, color: Color3, parent: Instance)
	local beacon = Instance.new("Part")
	beacon.Name = name
	beacon.Anchored = true
	beacon.Shape = Enum.PartType.Ball
	beacon.Size = Vector3.new(BEACON_SIZE, BEACON_SIZE, BEACON_SIZE)
	beacon.Position = position
	beacon.Color = color
	beacon.Material = Enum.Material.Neon
	beacon.Parent = parent

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
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

-- groundY is the real top-of-ground surface the wheels rest on.
local function buildFireTruck(x: number, groundY: number, z: number): Model
	local truck = Instance.new("Model")
	truck.Name = "FireTruck"

	local wheelY = groundY + WHEEL_DIAMETER / 2
	local bodyBottomY = groundY + WHEEL_DIAMETER * RIDE_HEIGHT_RATIO
	local bodyY = bodyBottomY + BODY_HEIGHT / 2
	local cabinY = bodyBottomY + BODY_HEIGHT + CABIN_HEIGHT / 2
	local stripeY = bodyBottomY + BODY_HEIGHT * 0.55

	local body =
		newBoxPart("Body", Vector3.new(BODY_WIDTH, BODY_HEIGHT, BODY_LENGTH), Vector3.new(x, bodyY, z), BODY_COLOR, truck)

	newBoxPart(
		"Stripe",
		Vector3.new(BODY_WIDTH + 0.2, STRIPE_HEIGHT, BODY_LENGTH + 0.2),
		Vector3.new(x, stripeY, z),
		STRIPE_COLOR,
		truck
	)

	newBoxPart(
		"Cabin",
		Vector3.new(CABIN_WIDTH, CABIN_HEIGHT, CABIN_LENGTH),
		Vector3.new(x, cabinY, z + CABIN_Z_OFFSET),
		CABIN_COLOR,
		truck
	)

	newBoxPart(
		"Windshield",
		Vector3.new(CABIN_WIDTH - 0.6, CABIN_HEIGHT * 0.5, 0.4),
		Vector3.new(x, cabinY + CABIN_HEIGHT * 0.15, z + CABIN_Z_OFFSET + CABIN_LENGTH / 2),
		WINDSHIELD_COLOR,
		truck
	)

	local hosebedY = bodyBottomY + BODY_HEIGHT + HOSEBED_HEIGHT / 2
	newBoxPart(
		"HoseBed",
		Vector3.new(HOSEBED_WIDTH, HOSEBED_HEIGHT, HOSEBED_LENGTH),
		Vector3.new(x, hosebedY, z + HOSEBED_Z_OFFSET),
		HOSEBED_COLOR,
		truck
	)

	local ladderY = bodyBottomY + BODY_HEIGHT + HOSEBED_HEIGHT + LADDER_HEIGHT / 2 + 0.3
	newBoxPart(
		"Ladder",
		Vector3.new(LADDER_WIDTH, LADDER_HEIGHT, LADDER_LENGTH),
		Vector3.new(x, ladderY, z + HOSEBED_Z_OFFSET),
		LADDER_COLOR,
		truck
	)

	newWheel("WheelFrontLeft", Vector3.new(x - WHEEL_X_OFFSET, wheelY, z + WHEEL_Z_OFFSET), truck)
	newWheel("WheelFrontRight", Vector3.new(x + WHEEL_X_OFFSET, wheelY, z + WHEEL_Z_OFFSET), truck)
	newWheel("WheelRearLeft", Vector3.new(x - WHEEL_X_OFFSET, wheelY, z - WHEEL_Z_OFFSET), truck)
	newWheel("WheelRearRight", Vector3.new(x + WHEEL_X_OFFSET, wheelY, z - WHEEL_Z_OFFSET), truck)

	buildBeacon(
		"BeaconRed",
		Vector3.new(x - CABIN_WIDTH / 4, cabinY + CABIN_HEIGHT / 2 + BEACON_SIZE / 2, z + CABIN_Z_OFFSET),
		BEACON_RED,
		truck
	)
	buildBeacon(
		"BeaconBlue",
		Vector3.new(x + CABIN_WIDTH / 4, cabinY + CABIN_HEIGHT / 2 + BEACON_SIZE / 2, z + CABIN_Z_OFFSET),
		BEACON_BLUE,
		truck
	)

	truck.PrimaryPart = body
	return truck
end

local FireTrucks = Workspace:FindFirstChild("FireTrucks")
if not FireTrucks then
	FireTrucks = Instance.new("Folder")
	FireTrucks.Name = "FireTrucks"
	FireTrucks.Parent = Workspace
end

local existingTruck = FireTrucks:FindFirstChild("FireTruck")
if existingTruck then
	existingTruck:Destroy()
end

local garageWallX = FIRE_STATION_POSITION.X - FIRE_STATION_HALF_WIDTH
local truckX = garageWallX - TRUCK_CLEARANCE - BODY_WIDTH / 2
local truckZ = FIRE_STATION_POSITION.Z

local groundY = GroundUtils.findGroundY(truckX, truckZ, FireTrucks)
local truck = buildFireTruck(truckX, groundY, truckZ)
truck.Parent = FireTrucks
