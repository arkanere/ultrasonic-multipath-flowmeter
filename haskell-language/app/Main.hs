-- | Demonstration program: builds the 2-path and 4-path meters, simulates
-- transit times for a known flow velocity, solves for the flow rate, and prints
-- the result.
--
-- All @IO@ lives here, leaving "Flowmeter.Core" completely pure.
module Main (main) where

import Flowmeter.Core
import System.IO (hSetEncoding, stdout, utf8)
import Text.Printf (printf)

-- | Speed of sound in water (approximation), m/s.
soundSpeed :: Double
soundSpeed = 1480.0

-- | Demonstration pipe diameter, in meters (100 mm).
demoPipeDiameter :: Double
demoPipeDiameter = 0.1

-- | Demonstration flow velocity, in m/s.
demoFlowVelocity :: Double
demoFlowVelocity = 2.0

--------------------------------------------------------------------------------
-- Configuration builders
--------------------------------------------------------------------------------

-- | A 2-path configuration with 45-degree diagonal paths.
--
-- Typical quick-measurement layout: two paths at ±0.25 D, averaged evenly.
create2PathConfig :: Double -> FlowMeterConfig
create2PathConfig diameter =
  mkFlowMeterConfig diameter
    [ AcousticPath { position =  0.25, angle = theta, pathLength = len, weight = 0.5 }
    , AcousticPath { position = -0.25, angle = theta, pathLength = len, weight = 0.5 }
    ]
  where
    theta = pi / 4.0            -- 45 degrees
    len   = diameter / sin theta

-- | A 4-path configuration mixing 60-degree and 45-degree paths.
--
-- Two paths at 60° (±0.35 D) sample near the pipe wall; two at 45° (±0.15 D)
-- sample near the center. Gauss-Jacobi weights of 0.25 each.
create4PathConfig :: Double -> FlowMeterConfig
create4PathConfig diameter =
  mkFlowMeterConfig diameter
    [ AcousticPath { position =  0.35, angle = theta60, pathLength = len60, weight = 0.25 }
    , AcousticPath { position = -0.35, angle = theta60, pathLength = len60, weight = 0.25 }
    , AcousticPath { position =  0.15, angle = theta45, pathLength = len45, weight = 0.25 }
    , AcousticPath { position = -0.15, angle = theta45, pathLength = len45, weight = 0.25 }
    ]
  where
    theta60 = pi / 3.0          -- 60 degrees
    theta45 = pi / 4.0          -- 45 degrees
    len60   = diameter / sin theta60
    len45   = diameter / sin theta45

--------------------------------------------------------------------------------
-- Simulation
--------------------------------------------------------------------------------

-- | Synthesise upstream and downstream transit times from a known flow velocity.
--
-- The pulse travels the along-flow component @L * sin θ@ at @c - v@ going
-- upstream and @c + v@ going downstream.
simulateMeasurements :: FlowMeterConfig -> Double -> [PathMeasurement]
simulateMeasurements config trueFlowVelocity = map measure (paths config)
  where
    measure path =
      let component = pathLength path * sin (angle path)
      in PathMeasurement
           { tUpstream   = component / (soundSpeed - trueFlowVelocity)
           , tDownstream = component / (soundSpeed + trueFlowVelocity)
           }

--------------------------------------------------------------------------------
-- Formatting helpers
--------------------------------------------------------------------------------

-- | Format in scientific notation with a two-digit exponent.
--
-- Haskell's @printf \"%.2e\"@ yields @1.83e-7@, whereas C's @%.2e@ yields
-- @1.83e-07@. Padding the exponent keeps this implementation byte-identical with
-- the C output.
formatScientific :: Double -> String
formatScientific 0 = "0.00e+00"
formatScientific value = printf "%.2fe%s%02d" mantissa sign (abs exponent')
  where
    rawExponent = floor (logBase 10 (abs value)) :: Int
    rawMantissa = value / (10 ^^ rawExponent)
    -- Rounding the mantissa can carry it to 10.00 — renormalize when it does.
    carried     = abs (fromIntegral (round (rawMantissa * 100) :: Integer) / 100) >= (10 :: Double)
    mantissa    = if carried then rawMantissa / 10.0 else rawMantissa
    exponent'   = if carried then rawExponent + 1 else rawExponent
    sign        = if exponent' < 0 then "-" else "+" :: String

radiansToDegrees :: Double -> Double
radiansToDegrees radians = radians * 180.0 / pi

--------------------------------------------------------------------------------
-- Printing
--------------------------------------------------------------------------------

-- | Print the meter configuration and its acoustic paths.
printConfig :: FlowMeterConfig -> IO ()
printConfig config = do
  putStrLn "Flow Meter Configuration:"
  printf "  Pipe diameter: %.3f m\n" (pipeDiameter config)
  printf "  Number of paths: %d\n" (numPaths config)
  printf "  Pipe area: %.6f m²\n" (pi * radius * radius)
  putStrLn ""
  putStrLn "Acoustic Paths:"
  mapM_ printPath (zip [1 :: Int ..] (paths config))
  where
    radius = pipeDiameter config / 2.0
    printPath (index, path) = do
      printf "  Path %d:\n" index
      printf "    Position: %.2f D\n" (position path)
      printf "    Angle: %.2f° (%.4f rad)\n" (radiansToDegrees (angle path)) (angle path)
      printf "    Path length: %.4f m\n" (pathLength path)
      printf "    Weight: %.3f\n" (weight path)

-- | Print the simulated transit times for each path.
printMeasurements :: [PathMeasurement] -> Double -> IO ()
printMeasurements measurements trueFlowVelocity = do
  putStrLn ""
  printf "Simulated Measurements (True flow velocity: %.2f m/s):\n" trueFlowVelocity
  mapM_ printMeasurement (zip [1 :: Int ..] measurements)
  where
    printMeasurement (index, m) =
      printf "  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %s s\n"
        index
        (tUpstream m)
        (tDownstream m)
        (formatScientific (tUpstream m - tDownstream m))

-- | Print the per-path velocities and the total volumetric flow rate.
printResults :: FlowResult -> IO ()
printResults result = do
  putStrLn ""
  putStrLn "Flow Calculation Results:"
  mapM_ printVelocity (zip [1 :: Int ..] (pathVelocities result))
  putStrLn ""
  putStrLn "Volumetric Flow Rate:"
  printf "  %.6f m³/s\n" flow
  printf "  %.4f L/min\n" (toLitersPerMinute flow)
  printf "  %.2f L/s\n" (toLitersPerSecond flow)
  where
    flow = volumetricFlow result
    printVelocity (index, velocity) =
      printf "  Path %d velocity: %.4f m/s\n" index velocity

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

-- | Run one configuration end to end: print it, simulate, solve, report.
runDemo :: FlowMeterConfig -> Double -> IO ()
runDemo config trueFlowVelocity = do
  printConfig config
  let measurements = simulateMeasurements config trueFlowVelocity
  printMeasurements measurements trueFlowVelocity
  printResults (calculateFlowRate config measurements)

main :: IO ()
main = do
  -- Without this the °, Δ, ² and ³ literals fail under a non-UTF-8 locale.
  hSetEncoding stdout utf8

  putStrLn "=== Ultrasonic Multipath Flow Meter ==="
  putStrLn ""

  putStrLn "### 2-PATH CONFIGURATION ###"
  putStrLn ""
  runDemo (create2PathConfig demoPipeDiameter) demoFlowVelocity

  putStrLn ""
  putStrLn ""
  putStrLn "### 4-PATH CONFIGURATION ###"
  putStrLn ""
  runDemo (create4PathConfig demoPipeDiameter) demoFlowVelocity

  putStrLn ""
  putStrLn "=== End of Demonstration ==="
