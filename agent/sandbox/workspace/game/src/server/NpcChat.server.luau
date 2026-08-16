local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chat = game:GetService("Chat")

local NPC_NAME = "Guide"
local GREETING = "Привіт! Я NPC і пишу в чат :)"
local TOUCH_MESSAGE = "Гарного дня!"
local TOUCH_COOLDOWN = 5 -- seconds, avoids chat spam when multiple players touch at once
local NPC_X = 6
local NPC_Z = 0

-- TextChannel:DisplaySystemMessage can only be called from the client, so the
-- server broadcasts the message and each client posts it into its own chat window.
local npcChatEvent = Instance.new("RemoteEvent")
npcChatEvent.Name = "NpcChatMessage"
npcChatEvent.Parent = ReplicatedStorage

local function sendToChat(message: string)
	npcChatEvent:FireAllClients(("[%s]: %s"):format(NPC_NAME, message))
end

local function say(part: BasePart, message: string)
	Chat:Chat(part, message, Enum.ChatColor.Blue)
	sendToChat(message)
end

-- Raycasts straight down to find the real ground height at (x, z) instead of
-- assuming a fixed baseplate Y. Avoids the NPC spawning half-buried if the
-- surrounding terrain/buildings ever change.
local function findGroundY(x: number, z: number): number
	local rayOrigin = Vector3.new(x, 500, z)
	local result = Workspace:Raycast(rayOrigin, Vector3.new(0, -1000, 0))
	if result then
		return result.Position.Y
	end
	return 0 -- fallback: matches the baseplate top in default.project.json
end

local function createNpc(x: number, z: number): Model
	local model = Instance.new("Model")
	model.Name = NPC_NAME

	local groundY = findGroundY(x, z)

	local legs = Instance.new("Part")
	legs.Name = "Legs"
	legs.Size = Vector3.new(2, 2, 1)
	legs.Anchored = true
	legs.CanCollide = true
	legs.Position = Vector3.new(x, groundY + legs.Size.Y / 2, z)
	legs.BrickColor = BrickColor.new("Dark stone grey")
	legs.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Anchored = true
	torso.CanCollide = true
	torso.Position = legs.Position + Vector3.new(0, legs.Size.Y / 2 + torso.Size.Y / 2, 0)
	torso.BrickColor = BrickColor.new("Bright blue")
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Anchored = true
	head.CanCollide = false
	head.Position = torso.Position + Vector3.new(0, torso.Size.Y / 2 + head.Size.Y / 2, 0)
	head.BrickColor = BrickColor.new("Light orange")
	head.Parent = model

	model.PrimaryPart = torso
	model.Parent = Workspace

	return model
end

local npc = createNpc(NPC_X, NPC_Z)
local head = npc:WaitForChild("Head") :: BasePart
local torso = npc:WaitForChild("HumanoidRootPart") :: BasePart
local legs = npc:WaitForChild("Legs") :: BasePart

task.wait(1)
say(head, GREETING)

local touchCooldownActive = false
local function onTouched(hit: BasePart)
	if touchCooldownActive then
		return
	end
	local character = hit.Parent
	if not character then
		return
	end
	local player = game:GetService("Players"):GetPlayerFromCharacter(character)
	if not player then
		return
	end

	touchCooldownActive = true
	say(head, TOUCH_MESSAGE)
	task.delay(TOUCH_COOLDOWN, function()
		touchCooldownActive = false
	end)
end

torso.Touched:Connect(onTouched)
legs.Touched:Connect(onTouched)
