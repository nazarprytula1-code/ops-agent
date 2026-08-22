local InsertService = game:GetService("InsertService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GroundUtils = require(ReplicatedStorage.Shared.GroundUtils)

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
--
-- v2: the first version only reported success/failure via print/warn, which
-- is invisible to anyone testing on the live published client (server
-- Output is only visible from Studio, e.g. Team Test) -- that's the
-- "can't find the loaded models" report from Slack. This version also drops
-- a tall Neon beacon (with a floating label) at every test slot regardless
-- of success or failure, plus a small summary board just behind Spawn, so
-- the result is visible in-world to a normal player with no Studio access.

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

-- A few studs behind Spawn (0, 0.5, 0), facing away from the house
-- (X=24,Z=0) and the city grid (Z~260) -- clear ground with nothing else
-- built on it, and close enough that nobody has to hike 200 studs just to
-- see whether the load test worked at all.
local STATUS_BOARD_POSITION = Vector3.new(0, 0, -20)

local OK_COLOR = Color3.fromRGB(60, 220, 90)
local FAIL_COLOR = Color3.fromRGB(230, 60, 60)

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
local function placeOnGround(model: PVInstance, x: number, z: number)
	local groundY = GroundUtils.findGroundY(x, z, TestAssets)
	local boundingCFrame, size = model:GetBoundingBox()
	local rotationOnly = boundingCFrame - boundingCFrame.Position
	model:PivotTo(CFrame.new(x, groundY + size.Y / 2, z) * rotationOnly)
end

-- A tall, bright, always-on-top marker so a load attempt is visible from a
-- distance and from any camera angle, whether or not the asset itself
-- turned out to be tiny, dark, or (if the ID was bad) never loaded at all.
local function createBeacon(name: string, x: number, z: number, richText: string, color: Color3, parent: Instance)
	local groundY = GroundUtils.findGroundY(x, z, TestAssets)

	local pole = Instance.new("Part")
	pole.Name = name .. "Beacon"
	pole.Anchored = true
	pole.CanCollide = false
	pole.Material = Enum.Material.Neon
	pole.Color = color
	pole.Size = Vector3.new(2, 40, 2)
	pole.Position = Vector3.new(x, groundY + 20, z)
	pole.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Adornee = pole
	billboard.Size = UDim2.new(0, 220, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = pole

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.RichText = true
	label.Text = richText
	label.Parent = billboard
end

local function createStatusBoard(richLines: { string })
	local groundY = GroundUtils.findGroundY(STATUS_BOARD_POSITION.X, STATUS_BOARD_POSITION.Z, TestAssets)

	local board = Instance.new("Part")
	board.Name = "TestAssetLoaderStatusBoard"
	board.Anchored = true
	board.CanCollide = false
	board.Transparency = 1 -- invisible; only the BillboardGui needs to show
	board.Size = Vector3.new(1, 1, 1)
	board.Position = Vector3.new(STATUS_BOARD_POSITION.X, groundY + 6, STATUS_BOARD_POSITION.Z)
	board.Parent = TestAssets

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Summary"
	billboard.Adornee = board
	billboard.Size = UDim2.new(0, 340, 0, 160)
	billboard.AlwaysOnTop = true
	billboard.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.25
	label.BackgroundColor3 = Color3.new(0, 0, 0)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.RichText = true
	label.Text = "<b>TestAssetLoader</b> (walk west to see the beacons)\n" .. table.concat(richLines, "\n")
	label.Parent = billboard
end

-- Returns whether the asset loaded and, if not, why -- both get surfaced on
-- the in-world beacon/board, not just print/warn.
local function loadTestAsset(testAsset: TestAsset, x: number, z: number): (boolean, string?)
	local success, containerOrError = pcall(function()
		return InsertService:LoadAsset(testAsset.assetId)
	end)

	if not success or not containerOrError then
		local reason = tostring(containerOrError)
		warn(("TestAssetLoader: failed to load %s (%d): %s"):format(testAsset.name, testAsset.assetId, reason))
		return false, reason
	end

	local container = containerOrError :: Instance
	local model = container:FindFirstChildWhichIsA("Model") or container:FindFirstChildWhichIsA("BasePart")
	if not model then
		warn(("TestAssetLoader: %s (%d) contained no Model/BasePart to place"):format(testAsset.name, testAsset.assetId))
		container:Destroy()
		return false, "insert result had no Model/BasePart"
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
	return true, nil
end

local boardLines: { string } = {}

for index, testAsset in ipairs(TEST_ASSETS) do
	local x = TEST_ZONE_ORIGIN.X - (index - 1) * SPACING
	local z = TEST_ZONE_ORIGIN.Z

	local ok, err = loadTestAsset(testAsset, x, z)
	local color = ok and OK_COLOR or FAIL_COLOR

	local beaconText = ok
			and ("<b>%s</b>\n<font color=\"#3CDC5A\">OK</font> (id %d)"):format(testAsset.name, testAsset.assetId)
		or ("<b>%s</b>\n<font color=\"#E63C3C\">FAILED</font> (id %d)"):format(testAsset.name, testAsset.assetId)
	createBeacon(testAsset.name, x, z, beaconText, color, TestAssets)

	local boardLine = ok
			and ("<font color=\"#3CDC5A\">OK</font> - %s (id %d)"):format(testAsset.name, testAsset.assetId)
		or ("<font color=\"#E63C3C\">FAILED</font> - %s (id %d): %s"):format(testAsset.name, testAsset.assetId, tostring(err))
	table.insert(boardLines, boardLine)
end

createStatusBoard(boardLines)
