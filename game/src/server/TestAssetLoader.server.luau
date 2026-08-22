local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")

local GroundUtils = require(game:GetService("ReplicatedStorage").Shared.GroundUtils)

-- Loads a handful of public catalog Asset IDs into a dedicated, empty test
-- zone far from every other builder (house/car/tree at ~(24,0,0), the city
-- grid centered at (0,0,260) spanning roughly X[-186,186] Z[74,446]). The
-- test zone sits west of all of that, at X=-200, so nothing in this file can
-- ever overlap something another builder placed.
--
-- IMPORTANT: these are unverified public catalog assets requested from
-- Slack for load-testing complex geometry (multi MeshPart, PBR
-- SurfaceAppearance). Nobody on this side has previewed what they actually
-- look like before they land in the published place. Swap TEST_ASSETS or
-- remove this file entirely once the load test is done -- it is not meant
-- to be permanent set dressing.

type TestAsset = {
	name: string,
	assetId: number,
}

local TEST_ASSETS: { TestAsset } = {
	{ name = "PbrTreasureChest", assetId = 6768917255 },
	{ name = "ComplexEnvironmentAsset", assetId = 9723979220 },
	{ name = "MultiPartModel", assetId = 26424808 },
}

local TEST_ZONE_ORIGIN = Vector3.new(-200, 0, 0)
local SPACING = 60 -- studs between each loaded asset along X

local TestAssets = Workspace:FindFirstChild("TestAssets")
if not TestAssets then
	TestAssets = Instance.new("Folder")
	TestAssets.Name = "TestAssets"
	TestAssets.Parent = Workspace
else
	TestAssets:ClearAllChildren()
end

-- Sits an already-parented model on top of the real ground at (x, z),
-- preserving whatever rotation the asset shipped with instead of resetting
-- it to identity.
local function placeOnGround(model: Model, x: number, z: number)
	local groundY = GroundUtils.findGroundY(x, z, TestAssets)
	local boundingCFrame, size = model:GetBoundingBox()
	local rotationOnly = boundingCFrame - boundingCFrame.Position
	model:PivotTo(CFrame.new(x, groundY + size.Y / 2, z) * rotationOnly)
end

local function loadTestAsset(testAsset: TestAsset, x: number, z: number)
	local success, containerOrError = pcall(function()
		return InsertService:LoadAsset(testAsset.assetId)
	end)

	if not success or not containerOrError then
		warn(("TestAssetLoader: failed to load %s (%d): %s"):format(testAsset.name, testAsset.assetId, tostring(containerOrError)))
		return
	end

	local container = containerOrError :: Instance
	local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
	if not model then
		warn(("TestAssetLoader: %s (%d) contained no Model/BasePart to place"):format(testAsset.name, testAsset.assetId))
		container:Destroy()
		return
	end

	model.Name = testAsset.name
	model.Parent = TestAssets

	-- Anchor everything so the asset doesn't fall/scatter under gravity
	-- while we're just eyeballing it; keep default collision fidelity so a
	-- dense mesh doesn't spike server physics cost.
	if model:IsA("BasePart") then
		model.Anchored = true
	else
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	end

	placeOnGround(model :: any, x, z)
	container:Destroy()

	print(("TestAssetLoader: loaded %s (%d) at (%.0f, %.0f)"):format(testAsset.name, testAsset.assetId, x, z))
end

for index, testAsset in ipairs(TEST_ASSETS) do
	local x = TEST_ZONE_ORIGIN.X - (index - 1) * SPACING
	local z = TEST_ZONE_ORIGIN.Z
	loadTestAsset(testAsset, x, z)
end
