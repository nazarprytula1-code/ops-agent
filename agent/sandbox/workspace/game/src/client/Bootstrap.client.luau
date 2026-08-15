local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

print("[ops-game] client ready", GameConfig.SprintSpeed)
