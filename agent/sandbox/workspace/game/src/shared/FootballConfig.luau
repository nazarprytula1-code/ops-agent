local FootballConfig = {}

-- Shared by FootballFieldBuilder.server.luau, BallBuilder.server.luau and
-- BallKick.server.luau so the pitch and the ball agree on where the field is
-- without the three scripts depending on each other's run order.
--
-- Placement: FIELD_POSITION is chosen clear of every other builder on the
-- Baseplate (see default.project.json, size [512, 16, 730] at [0, -8, 109],
-- i.e. X in [-256, 256] and Z in [-256, 474]):
--   - the starter house/tree/car cluster sits around X in [6, 44], Z in [-12, 18]
--   - the city grid sits at CITY_ORIGIN (0, 0, 260), spanning X in [-186, 186], Z in [74, 446]
-- The pitch below spans X in [-200, -100], Z in [-32, 32] -- clear of both.
FootballConfig.FIELD_POSITION = Vector3.new(-150, 0, 0)

FootballConfig.FIELD_LENGTH = 100 -- along world X, goal line to goal line
FootballConfig.FIELD_WIDTH = 64 -- along world Z, touchline to touchline
FootballConfig.PITCH_THICKNESS = 0.4

FootballConfig.LINE_WIDTH = 1 -- boundary/halfway line thickness in the direction they run across
FootballConfig.LINE_THICKNESS = 0.1 -- how far the line pokes above the pitch (avoids z-fighting)

FootballConfig.GOAL_WIDTH = 16 -- along world Z, the gap the ball goes through
FootballConfig.GOAL_HEIGHT = 10
FootballConfig.GOAL_DEPTH = 5 -- how far the back net sits behind the goal line, along world X
FootballConfig.POST_THICKNESS = 1

FootballConfig.BALL_DIAMETER = 2.2

FootballConfig.FOLDER_NAME = "FootballField"
FootballConfig.BALL_NAME = "Ball"

return FootballConfig
