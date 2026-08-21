local FootballConfig = {}

-- Shared by FootballFieldBuilder.server.luau, FieldFenceBuilder.server.luau,
-- ScoreboardBuilder.server.luau, BallBuilder.server.luau, BallKick.server.luau
-- and GoalScoring.server.luau so the pitch, fence, scoreboard and ball agree
-- on where the field is without those scripts depending on each other's run
-- order.
--
-- Placement: FIELD_POSITION is chosen clear of every other builder on the
-- Baseplate (see default.project.json, size [512, 16, 730] at [0, -8, 109],
-- i.e. X in [-256, 256] and Z in [-256, 474]):
--   - the starter house/tree/car cluster sits around X in [6, 44], Z in [-12, 18]
--   - the city grid sits at CITY_ORIGIN (0, 0, 260), spanning X in [-186, 186], Z in [74, 446]
-- v2: doubled the pitch footprint per Slack request. At double size the
-- fence (which sits FENCE_END_MARGIN/FENCE_SIDE_MARGIN beyond the pitch
-- edges, see below) would leave only ~2 studs of clearance from the
-- Baseplate's west edge (X = -256) with the original FIELD_POSITION -- so
-- the whole field also shifted from X=-150 to X=-130 to keep a comfortable
-- margin on every side:
--   pitch:  X in [-230, -30],  Z in [-64, 64]
--   fence:  X in [-244, -16],  Z in [-68, 68]
-- both still clear of the house/tree/car (X in [6, 44]) and the city grid
-- (Z in [74, 446]), and inside the Baseplate (X in [-256, 256], Z in [-256, 474]).
FootballConfig.FIELD_POSITION = Vector3.new(-130, 0, 0)

FootballConfig.FIELD_LENGTH = 200 -- along world X, goal line to goal line
FootballConfig.FIELD_WIDTH = 128 -- along world Z, touchline to touchline
FootballConfig.PITCH_THICKNESS = 0.4

FootballConfig.LINE_WIDTH = 1 -- boundary/halfway line thickness in the direction they run across
FootballConfig.LINE_THICKNESS = 0.1 -- how far the line pokes above the pitch (avoids z-fighting)

FootballConfig.GOAL_WIDTH = 32 -- along world Z, the gap the ball goes through
FootballConfig.GOAL_HEIGHT = 20
FootballConfig.GOAL_DEPTH = 10 -- how far the back net sits behind the goal line, along world X
FootballConfig.GOAL_NET_GAP = 3 -- empty pocket between the goal line and the net's front face, along world X;
-- must clear the ball's radius (BALL_DIAMETER / 2) or the solid net stops the ball
-- exactly on the goal line and it can never be detected as "past" it -- see GoalScoring.server.luau.
FootballConfig.POST_THICKNESS = 2

FootballConfig.BALL_DIAMETER = 2.2
FootballConfig.BALL_GROUND_CLEARANCE = 0.05 -- small gap above the pitch so the ball never spawns overlapping it

-- Tall perimeter fence around the pitch, per Slack request ("...зроби
-- високу огороджу для футбольного поля"). Sits outside the pitch boundary
-- (and outside the goal nets on the two ends) so it doesn't clip through
-- them, with a walk-through gap in each side fence so players can still
-- reach the pitch on foot -- a fence this tall would otherwise wall players
-- out entirely, since it's well above normal jump height.
FootballConfig.FENCE_HEIGHT = 20
FootballConfig.FENCE_THICKNESS = 0.6
FootballConfig.FENCE_SIDE_MARGIN = 4 -- beyond the touchlines (Z), where the two long fences sit
FootballConfig.FENCE_END_MARGIN = FootballConfig.GOAL_NET_GAP + FootballConfig.GOAL_DEPTH + 4 -- beyond the goal lines (X), clears the goal net
FootballConfig.FENCE_ENTRANCE_WIDTH = 14 -- gap left in the middle of each side fence for players to walk through

-- Goal counting + scoreboard, per Slack request ("зроби лічильник (велике
-- табло) голів..."). TEAM_A defends the west goal (at FIELD_POSITION.X -
-- FIELD_LENGTH/2) and scores when the ball enters the east goal; TEAM_B
-- defends the east goal and scores when the ball enters the west goal --
-- see GoalScoring.server.luau.
FootballConfig.TEAM_A_NAME = "TEAM A"
FootballConfig.TEAM_B_NAME = "TEAM B"
FootballConfig.GOAL_RESPAWN_DELAY = 1 -- seconds the ball stays hidden after a goal before reappearing at center

-- Scoreboard sits just past the north side fence (outside FENCE_SIDE_MARGIN),
-- straddling the entrance gap like an arch, tall enough to be seen over the
-- fence from anywhere on the pitch.
FootballConfig.SCOREBOARD_OFFSET_BEYOND_FENCE = 6 -- how far past the north fence line the poles stand
FootballConfig.SCOREBOARD_POLE_HEIGHT = 30
FootballConfig.SCOREBOARD_POLE_SPACING = 10 -- distance between the two support poles
FootballConfig.SCOREBOARD_POLE_THICKNESS = 1.5
FootballConfig.SCOREBOARD_CROSSBAR_THICKNESS = 1.5

FootballConfig.FOLDER_NAME = "FootballField"
FootballConfig.BALL_NAME = "Ball"

return FootballConfig
