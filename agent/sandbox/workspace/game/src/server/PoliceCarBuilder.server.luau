local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Builds one police car parked in front of the garage, per Slack request
-- ("тепер спереді гаража зроби поліцейську машину").
--
-- Placement: the garage (see GarageBuilder.server.luau) is a 20(X) x 16(Z)
-- footprint centered at (GARAGE_CENTER_X, GARAGE_CENTER_Z), with its big
-- vehicle door on the East wall (facing Spawn). "Спереду" (in front) means
-- just outside that same East wall -- these garage numbers are duplicated
-- here as documented constants (same approach GarageBuilder uses to
-- reference PoliceBuilder's position) rather than a shared import.
--
-- Body/cabin/wheel shape and axis-aligned-boxes-only approach are copied
-- from CarBuilder.server.luau (the plain car parked by the starter house)
-- rather than re-derived, recolored into a black-and-white police livery
-- with a red/blue roof light bar (same flashing-light technique
-- PoliceBuilder.server.luau's addSignAndLights uses for the station roof).
local GARAGE_CENTER_X = -40 -- GARAGE_CENTER_X from GarageBuilder.server.luau
local GARAGE_CENTER_Z = -125 -- GARAGE_CENTER_Z from GarageBuilder.server.luau
local GARAGE_HALF_WIDTH = 10 -- WIDTH / 2 from GarageBuilder
local CAR_CLEARANCE = 8 -- studs beyond the garage's east exterior wall, same clearance CarBuilder uses

local CAR_XZ = Vector3.new(GARAGE_CENTER_X + GARAGE_HALF_WIDTH + CAR_CLEARANCE, 0, GARAGE_CENTER_Z)

local BODY_LENGTH = 16 -- along Z (front-back)
local BODY_WIDTH = 7 -- along X (left-right)
local BODY_HEIGHT = 4.5
local BODY_COLOR = Color3.fromRGB(245, 245, 245) -- white police livery

local DOOR_STRIPE_COLOR = Color3.fromRGB(20, 20, 25) -- black side stripe
local DOOR_STRIPE_HEIGHT = 1.4

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

-- Roof light bar: same alternating red/blue flashing-light approach as
-- PoliceBuilder.server.luau's addSignAndLights.
local LIGHT_FLASH_SECONDS = 0.4
local RED_LIGHT_COLOR = Color3.fromRGB(255, 40, 40)
local BLUE_LIGHT_COLOR = Color3.fromRGB(40, 90, 255)
local LIGHT_OFF_COLOR = Color3.fromRGB(40, 40, 45)

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

local function addRoofLights(x: number, roofY: number, z: number, parent: Instance)
	local redLight = newBoxPart("RoofLightRed", Vector3.new(BODY_WIDTH * 0.4, 0.6, 1.6), Vector3.new(x - 1, roofY, z), RED_LIGHT_COLOR, parent)
	local blueLight =
		newBoxPart("RoofLightBlue", Vector3.new(BODY_WIDTH * 0.4, 0.6, 1.6), Vector3.new(x + 1, roofY, z), BLUE_LIGHT_COLOR, parent)
	redLight.Material = Enum.Material.Neon
	blueLight.Material = Enum.Material.Neon

	local redPointLight = Instance.new("PointLight")
	redPointLight.Color = RED_LIGHT_COLOR
	redPointLight.Range = 16
	redPointLight.Brightness = 3
	redPointLight.Parent = redLight

	local bluePointLight = Instance.new("PointLight")
	bluePointLight.Color = BLUE_LIGHT_COLOR
	bluePointLight.Range = 16
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

-- groundY is the real top-of-ground surface the wheels rest on.
local function buildPoliceCar(x: number, groundY: number, z: number): Model
	local car = Instance.new("Model")
	car.Name = "PoliceCar"

	local wheelY = groundY + WHEEL_DIAMETER / 2
	local bodyBottomY = groundY + WHEEL_DIAMETER * RIDE_HEIGHT_RATIO
	local bodyY = bodyBottomY + BODY_HEIGHT / 2
	local cabinY = bodyBottomY + BODY_HEIGHT + CABIN_HEIGHT / 2

	local body =
		newBoxPart("Body", Vector3.new(BODY_WIDTH, BODY_HEIGHT, BODY_LENGTH), Vector3.new(x, bodyY, z), BODY_COLOR, car)

	-- Black door stripe running down both sides, like a real police livery.
	newBoxPart(
		"StripeLeft",
		Vector3.new(0.2, DOOR_STRIPE_HEIGHT, BODY_LENGTH),
		Vector3.new(x - BODY_WIDTH / 2 - 0.1, bodyY, z),
		DOOR_STRIPE_COLOR,
		car
	)
	newBoxPart(
		"StripeRight",
		Vector3.new(0.2, DOOR_STRIPE_HEIGHT, BODY_LENGTH),
		Vector3.new(x + BODY_WIDTH / 2 + 0.1, bodyY, z),
		DOOR_STRIPE_COLOR,
		car
	)

	local cabin = newBoxPart(
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

	addRoofLights(x, cabinY + CABIN_HEIGHT / 2 + 0.3, z + CABIN_Z_OFFSET, car)

	car.PrimaryPart = body
	return car
end

local PoliceCars = Workspace:FindFirstChild("PoliceCars")
if not PoliceCars then
	PoliceCars = Instance.new("Folder")
	PoliceCars.Name = "PoliceCars"
	PoliceCars.Parent = Workspace
end

local existingPoliceCar = PoliceCars:FindFirstChild("PoliceCar")
if existingPoliceCar then
	existingPoliceCar:Destroy()
end

local groundY = GroundUtils.findGroundY(CAR_XZ.X, CAR_XZ.Z, PoliceCars)
local policeCar = buildPoliceCar(CAR_XZ.X, groundY, CAR_XZ.Z)
policeCar.Parent = PoliceCars
