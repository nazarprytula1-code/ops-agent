local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)
local FootballConfig = require(ReplicatedStorage.Shared.FootballConfig)

-- Builds a tall perimeter fence around the football pitch, per Slack
-- request ("...зроби високу огороджу для футбольного поля"). Sits
-- FENCE_END_MARGIN/FENCE_SIDE_MARGIN beyond the pitch's goal lines/
-- touchlines (see FootballConfig), so it clears the goal nets on both ends
-- instead of clipping through them.
--
-- The two side fences (north/south, running along X) each leave a
-- FENCE_ENTRANCE_WIDTH gap in the middle so players can walk onto the pitch
-- on foot -- FENCE_HEIGHT is well above normal jump height, so without a
-- gap the fence would wall players out entirely. The two end fences (west/
-- east, running along Z, behind each goal) are solid.
--
-- Axis-aligned boxes only, same approach as FootballFieldBuilder/
-- HouseBuilder/CarBuilder/TreeBuilder: every panel runs straight along
-- world X or world Z, so there is no rotation math and no risk of a
-- misoriented part.
--
-- Height is derived from the real ground surface via GroundUtils, not a
-- hardcoded Y, so the fence sits correctly even if the live baseplate/
-- terrain at that spot ever differs from default.project.json.

local FENCE_COLOR = Color3.fromRGB(90, 90, 95)

local FIELD = FootballConfig.FIELD_POSITION
local LENGTH = FootballConfig.FIELD_LENGTH
local WIDTH = FootballConfig.FIELD_WIDTH
local PITCH_THICKNESS = FootballConfig.PITCH_THICKNESS
local FENCE_HEIGHT = FootballConfig.FENCE_HEIGHT
local FENCE_THICKNESS = FootballConfig.FENCE_THICKNESS
local FENCE_SIDE_MARGIN = FootballConfig.FENCE_SIDE_MARGIN
local FENCE_END_MARGIN = FootballConfig.FENCE_END_MARGIN
local FENCE_ENTRANCE_WIDTH = FootballConfig.FENCE_ENTRANCE_WIDTH

local function newPanel(name: string, size: Vector3, position: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = true
	part.Size = size
	part.Position = position
	part.Color = FENCE_COLOR
	part.Material = Enum.Material.Fabric
	part.Transparency = 0.45
	part.Parent = parent
	return part
end

local Field = Workspace:FindFirstChild(FootballConfig.FOLDER_NAME)
if not Field then
	Field = Instance.new("Folder")
	Field.Name = FootballConfig.FOLDER_NAME
	Field.Parent = Workspace
end

local existingFence = Field:FindFirstChild("Fence")
if existingFence then
	existingFence:Destroy()
end

local groundY = GroundUtils.findGroundY(FIELD.X, FIELD.Z, Field)
local pitchTopY = groundY + PITCH_THICKNESS
local fenceCenterY = pitchTopY + FENCE_HEIGHT / 2

local outerHalfLength = LENGTH / 2 + FENCE_END_MARGIN -- distance from FIELD.X to the end (west/east) fences
local outerHalfWidth = WIDTH / 2 + FENCE_SIDE_MARGIN -- distance from FIELD.Z to the side (north/south) fences

local Fence = Instance.new("Model")
Fence.Name = "Fence"

-- Side fences (north/south), each split around a middle entrance gap.
local sideSpan = (2 * outerHalfLength - FENCE_ENTRANCE_WIDTH) / 2 -- length of each half-segment
local sideSegmentCenterOffset = FENCE_ENTRANCE_WIDTH / 2 + sideSpan / 2

for _, zSign in ipairs({ -1, 1 }) do
	local z = FIELD.Z + zSign * outerHalfWidth
	local sideName = if zSign < 0 then "North" else "South"

	newPanel(
		sideName .. "West",
		Vector3.new(sideSpan, FENCE_HEIGHT, FENCE_THICKNESS),
		Vector3.new(FIELD.X - sideSegmentCenterOffset, fenceCenterY, z),
		Fence
	)
	newPanel(
		sideName .. "East",
		Vector3.new(sideSpan, FENCE_HEIGHT, FENCE_THICKNESS),
		Vector3.new(FIELD.X + sideSegmentCenterOffset, fenceCenterY, z),
		Fence
	)
end

-- End fences (west/east, behind each goal), solid.
for _, xSign in ipairs({ -1, 1 }) do
	local x = FIELD.X + xSign * outerHalfLength
	local endName = if xSign < 0 then "West" else "East"

	newPanel(
		endName,
		Vector3.new(FENCE_THICKNESS, FENCE_HEIGHT, 2 * outerHalfWidth),
		Vector3.new(x, fenceCenterY, FIELD.Z),
		Fence
	)
end

Fence.Parent = Field
