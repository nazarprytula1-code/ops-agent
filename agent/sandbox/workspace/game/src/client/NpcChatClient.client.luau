local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local npcChatEvent = ReplicatedStorage:WaitForChild("NpcChatMessage") :: RemoteEvent

npcChatEvent.OnClientEvent:Connect(function(message: string)
	local ok, generalChannel = pcall(function()
		return TextChatService.TextChannels:WaitForChild("RBXGeneral", 5)
	end)
	if ok and generalChannel then
		(generalChannel :: TextChannel):DisplaySystemMessage(message)
	end
end)
