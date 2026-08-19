local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Drives the car(s) built by CarBuilder.server.luau.
--
-- Why this script exists: VehicleSeat's built-in "no script" driving only
-- moves a vehicle through motorized HingeConstraint wheel joints (Roblox
-- calls this out via VehicleSeat.AreHingesDetected). CarBuilder welds the
-- wheels rigidly to the body for a simple, stable chassis instead of
-- hinging them, so nothing would turn Throttle/Steer into motion on its
-- own -- that's why the seat showed a speed dial stuck at 0. This script
-- reads the seat's ThrottleFloat/SteerFloat every frame and sets the
-- welded body's AssemblyLinearVelocity/AssemblyAngularVelocity directly,
-- which moves the whole rigid assembly (body + cabin + wheels + seat)
-- regardless of wheel joint geometry.

local TURN_RATE = math.rad(90) -- radians/sec of yaw at full steering lock
local PARKED_DAMPING = 0.85 -- per-frame horizontal velocity decay when nobody is driving

local function driveCar(car: Model)
	local seat = car:FindFirstChild("DriverSeat")
	local body = car.PrimaryPart
	if not (seat and seat:IsA("VehicleSeat") and body) then
		return
	end

	local occupant = seat.Occupant
	if occupant then
		local forward = seat.CFrame.LookVector
		forward = Vector3.new(forward.X, 0, forward.Z)
		if forward.Magnitude > 0 then
			forward = forward.Unit
		end

		local targetSpeed = seat.ThrottleFloat * seat.MaxSpeed
		local currentVelocity = body.AssemblyLinearVelocity
		body.AssemblyLinearVelocity = Vector3.new(forward.X * targetSpeed, currentVelocity.Y, forward.Z * targetSpeed)
		body.AssemblyAngularVelocity = Vector3.new(0, -seat.SteerFloat * TURN_RATE, 0)
	else
		-- Nobody's driving: kill any leftover spin and let horizontal motion
		-- decay instead of coasting forever (wheel friction alone may not
		-- be enough since the chassis is a rigid welded assembly, not
		-- individually-spinning wheels).
		local currentVelocity = body.AssemblyLinearVelocity
		body.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		body.AssemblyLinearVelocity = Vector3.new(currentVelocity.X * PARKED_DAMPING, currentVelocity.Y, currentVelocity.Z * PARKED_DAMPING)
	end
end

RunService.Heartbeat:Connect(function()
	local Cars = Workspace:FindFirstChild("Cars")
	if not Cars then
		return
	end
	for _, car in Cars:GetChildren() do
		if car:IsA("Model") then
			driveCar(car)
		end
	end
end)
