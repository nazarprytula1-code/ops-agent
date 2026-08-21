local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- Per Slack request ("добав режим пришвидшення, як правило кнопка
-- шіфт..."), players can sprint: SprintClient.client.luau asks (via the
-- SetSprinting RemoteEvent) whenever the local player starts/stops holding
-- Shift (or the mobile touch button ContextActionService creates for the
-- same binding, per "за стандартами роблокс"), and this script is the one
-- that actually decides the resulting Humanoid.WalkSpeed from GameConfig,
-- rather than trusting a client-chosen speed value.

local setSprintingEvent = Instance.new("RemoteEvent")
setSprintingEvent.Name = "SetSprinting"
setSprintingEvent.Parent = ReplicatedStorage

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.WalkSpeed = GameConfig.WalkSpeed
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

-- wantsSprint arrives as an arbitrary client payload (RemoteEvent args
-- aren't typed) -- comparing with `== true` coerces anything else to false
-- instead of trusting it outright.
local function onSetSprinting(player: Player, wantsSprint: any)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	humanoid.WalkSpeed = if wantsSprint == true then GameConfig.SprintSpeed else GameConfig.WalkSpeed
end

setSprintingEvent.OnServerEvent:Connect(onSetSprinting)

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
