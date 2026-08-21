local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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
--
-- v2: per Slack request ("зроби щоб на машині можна було їхати"), the car
-- is now actually drivable. All parts are built anchored (so the initial
-- placement via GroundUtils is exact and doesn't jitter on spawn), then
-- unanchored and rigidly welded to Body once positioned. A VehicleSeat is
-- welded in too -- Roblox seats already auto-seat a touching player with
-- no extra script, and expose Throttle/Steer once occupied. Since there's
-- no separate wheel/hinge drivetrain (the wheels are just decorative
-- cylinders, like CarBuilder's), a small Heartbeat loop (wireDriving)
-- turns Throttle/Steer into actual movement by setting the welded
-- assembly's AssemblyLinearVelocity/AssemblyAngularVelocity directly --
-- the common lightweight "no suspension" arcade-vehicle approach.
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

local SEAT_WIDTH = CABIN_WIDTH - 1
local SEAT_LENGTH = CABIN_LENGTH - 3
local SEAT_HEIGHT = 1

-- Driving feel: no real suspension/drivetrain, so movement is applied
-- directly as assembly velocity every Heartbeat while a player is seated.
local MAX_SPEED = 45 -- studs/second at full throttle
local TURN_RATE = 2.2 -- radians/second at full steer

-- Roof light bar: same alternating red/blue flashing-light approach as
-- PoliceBuilder.server.luau's addSignAndLights.
local LIGHT_FLASH_SECONDS = 0.4
local RED_LIGHT_COLOR = Color3.fromRGB(255, 40, 40)
local BLUE_LIGHT_COLOR = Color3.fromRGB(40, 90, 255)
local LIGHT_OFF_COLOR = Color3.fromRGB(40, 40, 45)

local function newBoxPart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true -- unanchored + welded once the whole car is positioned; see unanchorAndWeld
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

-- Unanchors every BasePart under `car` except `body`, and rigidly welds
-- each of them to `body` with a WeldConstraint, then unanchors `body`
-- itself last (so nothing falls/shifts while the welds are still being
-- set up). The whole car then moves and falls as one physics assembly.
local function unanchorAndWeld(car: Model, body: BasePart)
	for _, descendant in ipairs(car:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant ~= body then
			descendant.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	body.Anchored = false
end

-- Turns a seated player's Throttle/Steer into actual movement, since this
-- car has no wheel/hinge drivetrain. `forward` is the world-space unit
-- vector the car's hood points toward (see buildPoliceCar).
local function wireDriving(seat: VehicleSeat, body: BasePart, forward: Vector3)
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not seat.Parent then
			connection:Disconnect()
			return
		end

		if seat.Occupant then
			local moveDirection = (body.CFrame:VectorToWorldSpace(forward)) * seat.Throttle * MAX_SPEED
			body.AssemblyLinearVelocity = Vector3.new(moveDirection.X, body.AssemblyLinearVelocity.Y, moveDirection.Z)
			body.AssemblyAngularVelocity = Vector3.new(0, -seat.Steer * TURN_RATE, 0)
		else
			body.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
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

	-- CanCollide = false: the seat below sits inside this same footprint,
	-- and this box is a solid stand-in for the whole greenhouse (roof +
	-- windows), not a hollow shell -- without this, a player could never
	-- physically touch (and so never sit in) the DriverSeat underneath it.
	local cabin = newBoxPart(
		"Cabin",
		Vector3.new(CABIN_WIDTH, CABIN_HEIGHT, CABIN_LENGTH),
		Vector3.new(x, cabinY, z + CABIN_Z_OFFSET),
		CABIN_COLOR,
		car
	)
	cabin.CanCollide = false

	newWheel("WheelFrontLeft", Vector3.new(x - WHEEL_X_OFFSET, wheelY, z + WHEEL_Z_OFFSET), car)
	newWheel("WheelFrontRight", Vector3.new(x + WHEEL_X_OFFSET, wheelY, z + WHEEL_Z_OFFSET), car)
	newWheel("WheelRearLeft", Vector3.new(x - WHEEL_X_OFFSET, wheelY, z - WHEEL_Z_OFFSET), car)
	newWheel("WheelRearRight", Vector3.new(x + WHEEL_X_OFFSET, wheelY, z - WHEEL_Z_OFFSET), car)

	addRoofLights(x, cabinY + CABIN_HEIGHT / 2 + 0.3, z + CABIN_Z_OFFSET, car)

	-- Driver seat: sits on the cabin floor. Roblox auto-seats a touching
	-- player with no extra script; Throttle/Steer are then read by
	-- wireDriving below.
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Anchored = true
	seat.Size = Vector3.new(SEAT_WIDTH, SEAT_HEIGHT, SEAT_LENGTH)
	seat.Position = Vector3.new(x, bodyBottomY + BODY_HEIGHT + SEAT_HEIGHT / 2, z + CABIN_Z_OFFSET)
	seat.Color = Color3.fromRGB(30, 30, 35)
	seat.Material = Enum.Material.Fabric
	seat.Parent = car

	unanchorAndWeld(car, body)

	-- The hood/front of the car is the +Z end (CABIN_Z_OFFSET shifts the
	-- cabin slightly toward the rear, -Z), so "forward" is world +Z at
	-- spawn; wireDriving re-expresses that through Body's CFrame every
	-- frame so it still means "forward" after the car turns.
	wireDriving(seat, body, Vector3.new(0, 0, 1))

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
