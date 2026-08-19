local Workspace = game:GetService("Workspace")

-- Shared helper so every builder script finds the real ground surface at a
-- given XZ instead of assuming the baseplate/terrain sits at a fixed Y.
-- The live baseplate/terrain can differ from what default.project.json
-- defines (e.g. edited directly in Studio outside of Rojo), so a hardcoded
-- Y buries or floats whatever gets placed -- that was the "trunk under
-- ground" report from Slack that TreeBuilder originally fixed locally.
-- This module centralizes that fix for every other builder script.

local GroundUtils = {}

local RAYCAST_HEIGHT = 500 -- start well above anything reasonable and cast straight down
local FALLBACK_GROUND_Y = 0 -- baseplate top per default.project.json, used only if the raycast finds nothing

-- Finds the actual top-of-ground Y at (x, z) via a downward raycast.
-- `excludeFolder`, if given, is left out of the raycast so a script rebuilding
-- its own model on re-run can't hit its own stale copy instead of the real
-- ground underneath it.
function GroundUtils.findGroundY(x: number, z: number, excludeFolder: Instance?): number
	local origin = Vector3.new(x, RAYCAST_HEIGHT, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	if excludeFolder then
		params.FilterDescendantsInstances = { excludeFolder }
	end

	local result = Workspace:Raycast(origin, Vector3.new(0, -(RAYCAST_HEIGHT * 2), 0), params)
	if result then
		return result.Position.Y
	end
	return FALLBACK_GROUND_Y
end

return GroundUtils
