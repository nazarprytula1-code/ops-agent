local PhysicsService = game:GetService("PhysicsService")

-- Shared by BallBuilder.server.luau and BallBoundaryBuilder.server.luau so
-- the ball ends up in its own collision group, and the invisible boundary
-- walls (built by BallBoundaryBuilder, right at the pitch edges) only ever
-- push the ball -- never a player or anything else, which all stay in the
-- "Default" group -- per Slack request ("невидима стіна (діє тільки на
-- м'яч)").
--
-- ensureGroups() is idempotent (guards with IsCollisionGroupRegistered) and
-- safe to call from either script regardless of which one happens to run
-- first, so neither script depends on the other's run order.

local BallCollision = {}

BallCollision.BALL_GROUP = "FootballBall"
BallCollision.BOUNDARY_GROUP = "FootballBallBoundary"

function BallCollision.ensureGroups()
	if not PhysicsService:IsCollisionGroupRegistered(BallCollision.BALL_GROUP) then
		PhysicsService:RegisterCollisionGroup(BallCollision.BALL_GROUP)
	end
	if not PhysicsService:IsCollisionGroupRegistered(BallCollision.BOUNDARY_GROUP) then
		PhysicsService:RegisterCollisionGroup(BallCollision.BOUNDARY_GROUP)
	end

	-- Boundary walls never collide with Default (players, other builders'
	-- parts, etc.). They keep colliding with FootballBall since any pair
	-- not explicitly disabled defaults to collidable.
	PhysicsService:CollisionGroupSetCollidable(BallCollision.BOUNDARY_GROUP, "Default", false)
end

return BallCollision
