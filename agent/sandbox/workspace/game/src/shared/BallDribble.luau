-- Shared dribble state for the football ball, per Slack request ("зроби
-- режим ведення м'яча..."). Used by BallKick.server.luau (which starts/ends
-- a dribble in response to the G/F key presses) and GoalScoring.server.luau
-- (which must cancel an in-progress dribble before hiding/respawning the
-- ball after a goal -- otherwise the dribble's own per-frame follow loop
-- would keep overriding the position GoalScoring just set).
--
-- BallDribble.stop() holds the actual RBXScriptConnection, so calling it
-- from either script reliably disconnects the follow loop regardless of
-- which script started it -- no polling or extra coordination needed.

local BallDribble = {}

BallDribble.player = nil :: Player?

local connection: RBXScriptConnection? = nil

function BallDribble.isDribbling(): boolean
	return BallDribble.player ~= nil
end

function BallDribble.start(player: Player, followConnection: RBXScriptConnection)
	BallDribble.player = player
	connection = followConnection
end

-- Safe to call even when nothing is being dribbled.
function BallDribble.stop(ball: BasePart?)
	if connection then
		connection:Disconnect()
		connection = nil
	end
	BallDribble.player = nil
	if ball then
		ball.Anchored = false
	end
end

return BallDribble
