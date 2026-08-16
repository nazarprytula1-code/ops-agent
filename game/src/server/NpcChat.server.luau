local Workspace = game:GetService("Workspace")
local Chat = game:GetService("Chat")
local TextChatService = game:GetService("TextChatService")

local NPC_NAME = "Guide"
local GREETING = "Привіт! Я NPC і пишу в чат :)"
local TOUCH_MESSAGE = "Гарного дня!"
local TOUCH_COOLDOWN = 5 -- seconds, avoids chat spam when multiple players touch at once

local function sendToChat(message: string)
	local ok, generalChannel = pcall(function()
		return TextChatService.TextChannels:WaitForChild("RBXGeneral", 5)
	end)
	if ok and generalChannel then
		(generalChannel :: TextChannel):DisplaySystemMessage(("[%s]: %s"):format(NPC_NAME, message))
	end
end

local function say(part: BasePart, message: string)
	Chat:Chat(part, message, Enum.ChatColor.Blue)
	sendToChat(message)
end

local function createNpc(): Model
	local model = Instance.new("Model")
	model.Name = NPC_NAME

	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Size = Vector3.new(2, 2, 1)
	torso.Anchored = true
	torso.CanCollide = true
	torso.Position = Vector3.new(6, 3, 0)
	torso.BrickColor = BrickColor.new("Bright blue")
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Anchored = true
	head.CanCollide = false
	head.Position = torso.Position + Vector3.new(0, 1.6, 0)
	head.BrickColor = BrickColor.new("Light orange")
	head.Parent = model

	model.PrimaryPart = torso
	model.Parent = Workspace

	return model
end

local npc = createNpc()
local head = npc:WaitForChild("Head") :: BasePart
local torso = npc:WaitForChild("HumanoidRootPart") :: BasePart

task.wait(1)
say(head, GREETING)

local touchCooldownActive = false
torso.Touched:Connect(function(hit: BasePart)
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
end)
