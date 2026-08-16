local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

print("[ops-game]", GameConfig.BuildId, "walk", GameConfig.WalkSpeed, "sprint", GameConfig.SprintSpeed)
