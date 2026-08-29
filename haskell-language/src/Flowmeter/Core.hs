-- | Core algorithm for the ultrasonic multipath flow meter.
--
-- This module is pure in the strong sense: no @IO@ appears anywhere in it. It
-- holds the four data types, the two solvers, and the two unit converters.
-- Simulation and printing live in "Main", mirroring the core\/main split used by
-- every other implementation in this repository.
module Flowmeter.Core
  ( -- * Data types
    AcousticPath (..)
  , FlowMeterConfig (..)
  , PathMeasurement (..)
  , FlowResult (..)
    -- * Construction
  , mkFlowMeterConfig
    -- * Core algorithm
  , calculatePathVelocity
  , calculateFlowRate
    -- * Unit conversion
  , toLitersPerSecond
  , toLitersPerMinute
  ) where

-- | A single acoustic path across the pipe.
data AcousticPath = AcousticPath
  { position   :: Double  -- ^ Position on pipe diameter (normalized: -1 to 1)
  , angle      :: Double  -- ^ Angle from pipe axis, in radians
  , pathLength :: Double  -- ^ Acoustic path length, in meters
  , weight     :: Double  -- ^ Gauss-Jacobi weighting coefficient
  } deriving (Show, Eq)

-- | Meter configuration: the pipe plus its acoustic paths.
data FlowMeterConfig = FlowMeterConfig
  { pipeDiameter :: Double         -- ^ Pipe diameter, in meters
  , numPaths     :: Int            -- ^ Number of acoustic paths (2 or 4)
  , paths        :: [AcousticPath] -- ^ Acoustic path configurations
  } deriving (Show, Eq)

-- | Transit times observed on one acoustic path.
data PathMeasurement = PathMeasurement
  { tUpstream   :: Double  -- ^ Upstream transit time, in seconds
  , tDownstream :: Double  -- ^ Downstream transit time, in seconds
  } deriving (Show, Eq)

-- | Outcome of a flow calculation.
data FlowResult = FlowResult
  { pathVelocities :: [Double]  -- ^ Velocity computed for each path (m\/s)
  , volumetricFlow :: Double    -- ^ Total volumetric flow rate (m³\/s)
  } deriving (Show, Eq)

-- | Build a configuration, deriving @numPaths@ from the path list so the two can
-- never disagree.
mkFlowMeterConfig :: Double -> [AcousticPath] -> FlowMeterConfig
mkFlowMeterConfig diameter ps =
  FlowMeterConfig { pipeDiameter = diameter, numPaths = length ps, paths = ps }

-- | Calculate velocity from a single acoustic path measurement.
--
-- Uses the transit-time differential method:
--
-- > v_path = (L / (2 * sin θ)) * (Δt / (t_up * t_down))
--
-- Returns @0.0@ for a non-positive transit time or a zero-sine angle, matching
-- the guard clauses in the reference C implementation.
calculatePathVelocity :: AcousticPath -> PathMeasurement -> Double
calculatePathVelocity path measurement
  | tUp   <= 0    = 0.0
  | tDown <= 0    = 0.0
  | sinTheta == 0 = 0.0
  | otherwise     = (pathLength path / (2.0 * sinTheta)) * (deltaT / (tUp * tDown))
  where
    tUp      = tUpstream measurement
    tDown    = tDownstream measurement
    deltaT   = tUp - tDown
    sinTheta = sin (angle path)

-- | Calculate the total volumetric flow rate from multiple path measurements.
--
-- Uses Gauss-Jacobi quadrature integration with a weighted sum:
--
-- > Q = (π * D² / 4) * Σ(w_i * v_i)
--
-- Calls 'error' when the configuration has no paths, or when the number of
-- measurements does not match the number of paths.
calculateFlowRate :: FlowMeterConfig -> [PathMeasurement] -> FlowResult
calculateFlowRate config measurements
  | null ps =
      error "calculateFlowRate: configuration must contain at least one acoustic path"
  | length ps /= length measurements =
      error $ "calculateFlowRate: expected " ++ show (length ps)
              ++ " measurements, got " ++ show (length measurements)
  | otherwise =
      FlowResult { pathVelocities = velocities, volumetricFlow = area * weightedSum }
  where
    ps          = paths config
    velocities  = zipWith calculatePathVelocity ps measurements
    weightedSum = sum (zipWith (\p v -> weight p * v) ps velocities)
    -- Cross-sectional area: A = π * (D/2)² = π * D² / 4
    radius      = pipeDiameter config / 2.0
    area        = pi * radius * radius

-- | Convert m³\/s to L\/s.
toLitersPerSecond :: Double -> Double
toLitersPerSecond cubicMetersPerSecond = cubicMetersPerSecond * 1000.0

-- | Convert m³\/s to L\/min.
toLitersPerMinute :: Double -> Double
toLitersPerMinute cubicMetersPerSecond = cubicMetersPerSecond * 60000.0
