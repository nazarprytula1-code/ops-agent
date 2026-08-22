local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

-- Loads one Asset ID (owned by this place's own creator account/group, per
-- Slack) and places it clear of every other builder on the map.
--
-- History: v1 tried 3 random public catalog Asset IDs -- all failed at
-- runtime with "Asset is not trusted for this place" or "insert result had
-- no Model/BasePart". That's a deliberate Roblox platform restriction:
-- InsertService:LoadAsset only allows assets owned by the place's own
-- creator account/group (or legacy Free-marked assets) to be inserted at
-- runtime, so live scripts can't pull in arbitrary third-party models.
-- v2 added Neon beacons + a status board near Spawn to make pass/fail
-- visible on the live client (server print/warn isn't). v3 swapped in
-- Asset ID 12617535294, which was added to the owning account/group's
-- inventory -- confirmed working (it's a house). v4 (this version) drops
-- the beacons/board now that it's confirmed working, per Slack ("забери
-- тестові написи"), and relocates the house away from the football
-- stadium it landed on top of ("подалі від міста і стадіону").
--
-- Placement: LOAD_POSITION = (200, 0, 0), the open east side of the map,
-- checked clear of every builder's footprint on main as of this change:
--   - house/car/tree/workshop cluster: X in [0, 60],    Z in [-20, 40]
--   - fire station:                    X in [85, 130],  Z in [-15, 25]
--   - hotel:                           X in [75, 105],  Z in [-123, -77]
--   - police + garage:                 X in [-60, -20], Z in [-140, -80]
--   - hospital:                        X in [132, 168], Z in [-54, -26]
--   - football pitch/fence/scoreboard: X in [-247, -13], Z in [-74, 68]
--   - city grid (CITY_ORIGIN 0,0,300):  X in [-238, 238], Z in [62, 538]
-- (200, 0) falls outside all of those, with margin, and inside the
-- Baseplate's documented X range ([-256, 256] per default.project.json).
-- Ground height still comes from GroundUtils.findGroundY, not a hardcoded
-- Y, in case the live baseplate/terrain differs from that.

local OWNED_ASSET_ID = 12617535294
local MODEL_NAME = "LoadedHouse"

local LOAD_POSITION = Vector3.new(200, 0, 0)

local LoadedAssets = Workspace:FindFirstChild("LoadedAssets")
if not LoadedAssets then
	LoadedAssets = Instance.new("Folder")
	LoadedAssets.Name = "LoadedAssets"
	LoadedAssets.Parent = Workspace
else
	LoadedAssets:ClearAllChildren()
end

-- Clean up the old v1-v3 TestAssets folder (beacons/board/first placement)
-- if it's still sitting in Workspace from a previous run of this script.
local oldTestAssets = Workspace:FindFirstChild("TestAssets")
if oldTestAssets then
	oldTestAssets:Destroy()
end

-- Sits an already-parented model on top of the real ground at (x, z),
-- preserving whatever rotation the asset shipped with instead of resetting
-- it to identity.
local function placeOnGround(model: PVInstance, x: number, z: number)
	local groundY = GroundUtils.findGroundY(x, z, LoadedAssets)
	local boundingCFrame, size = model:GetBoundingBox()
	local rotationOnly = boundingCFrame - boundingCFrame.Position
	model:PivotTo(CFrame.new(x, groundY + size.Y / 2, z) * rotationOnly)
end

local success, containerOrError = pcall(function()
	return InsertService:LoadAsset(OWNED_ASSET_ID)
end)

if not success or not containerOrError then
	warn(("TestAssetLoader: failed to load asset %d: %s"):format(OWNED_ASSET_ID, tostring(containerOrError)))
	return
end

local container = containerOrError :: Instance
local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
if not model then
	warn(("TestAssetLoader: asset %d contained no Model/BasePart to place"):format(OWNED_ASSET_ID))
	container:Destroy()
	return
end

model.Name = MODEL_NAME
model.Parent = LoadedAssets

-- Anchor everything so the asset doesn't fall/scatter under gravity; keep
-- default collision fidelity so a dense mesh doesn't spike server physics
-- cost.
if model:IsA("BasePart") then
	model.Anchored = true
else
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

placeOnGround(model :: any, LOAD_POSITION.X, LOAD_POSITION.Z)
container:Destroy()

print(("TestAssetLoader: loaded asset %d at (%.0f, %.0f)"):format(OWNED_ASSET_ID, LOAD_POSITION.X, LOAD_POSITION.Z))
