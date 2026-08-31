--- Core algorithm for a transit-time differential ultrasonic flow meter.
---
--- An ultrasonic signal sent across a pipe travels faster with the flow than
--- against it. Comparing the two transit times reveals the flow velocity
--- without needing to know the speed of sound in the fluid.
---
--- The module is pure: it never writes to stdout and never touches a Neovim
--- API, so `require('flowmeter')` works the same from `nvim --headless -l`,
--- from `:lua` inside a running editor, and from a plain `lua` interpreter.

local M = {}

--- A single ultrasonic beam crossing the pipe.
---
--- Lua has no records, so the constructors return plain tables and the shape
--- lives in the annotation. The path length is derived here, so the chord
--- formula `D / sin(theta)` appears exactly once.
---
---@param pipe_diameter number Pipe diameter, in meters.
---@param position number Position on the pipe diameter, normalized to -1..1.
---@param angle number Angle from the pipe axis, in radians.
---@param weight number Gauss-Jacobi weighting coefficient.
---@return table path
function M.acoustic_path(pipe_diameter, position, angle, weight)
  return {
    position = position,
    angle = angle,
    length = pipe_diameter / math.sin(angle),
    weight = weight,
  }
end

--- Upstream and downstream transit times for one path, in seconds.
---
--- `delta_t` is the difference the whole method rests on. It is computed once
--- at construction rather than on every read.
---
---@param t_upstream number
---@param t_downstream number
---@return table measurement
function M.path_measurement(t_upstream, t_downstream)
  return {
    t_upstream = t_upstream,
    t_downstream = t_downstream,
    delta_t = t_upstream - t_downstream,
  }
end

--- Bundle a pipe with the acoustic paths crossing it.
---
---@param pipe_diameter number Pipe diameter, in meters.
---@param paths table[] One entry per acoustic path.
---@return table config
function M.flow_meter_config(pipe_diameter, paths)
  local copy = {}
  for i, path in ipairs(paths) do
    copy[i] = path
  end

  return {
    pipe_diameter = pipe_diameter,
    paths = copy,
    num_paths = #paths,
  }
end

--- Cross-sectional area of the pipe, `pi (D/2)^2`, in m².
---@param config table
---@return number area
function M.pipe_area(config)
  local radius = config.pipe_diameter / 2.0
  return math.pi * radius * radius
end

--- Velocity along the pipe axis implied by one path measurement, in m/s.
---
--- Transit-time differential method:
---
---     v_path = (L / (2 sin(theta))) * (delta_t / (t_up * t_down))
---
--- Returns 0 for non-physical transit times or a degenerate path angle.
---
---@param path table
---@param measurement table
---@return number velocity
function M.calculate_path_velocity(path, measurement)
  if measurement.t_upstream <= 0 or measurement.t_downstream <= 0 then
    return 0.0
  end

  local sin_theta = math.sin(path.angle)

  -- A path along the pipe axis carries no flow information.
  if sin_theta == 0 then
    return 0.0
  end

  return (path.length / (2.0 * sin_theta))
    * (measurement.delta_t / (measurement.t_upstream * measurement.t_downstream))
end

--- Integrate the per-path velocities into a volumetric flow rate.
---
--- Gauss-Jacobi quadrature: `Q = (pi D^2 / 4) * sum(w_i v_i)`.
---
--- Raises through `error()` if the configuration has no paths or if the
--- measurements do not line up one-to-one with them.
---
---@param config table
---@param measurements table[]
---@return table result Fields `path_velocities` and `volumetric_flow`.
function M.calculate_flow_rate(config, measurements)
  if config.num_paths == 0 then
    error('flow meter configuration has no paths', 2)
  end
  if #measurements ~= config.num_paths then
    error('expected one measurement per acoustic path', 2)
  end

  local path_velocities = {}
  local weighted_velocity_sum = 0.0

  for i, path in ipairs(config.paths) do
    path_velocities[i] = M.calculate_path_velocity(path, measurements[i])
    weighted_velocity_sum = weighted_velocity_sum + path.weight * path_velocities[i]
  end

  return {
    path_velocities = path_velocities,
    volumetric_flow = M.pipe_area(config) * weighted_velocity_sum,
  }
end

--- Two 45° paths at ±0.25 D: quick, cost-effective measurement.
---@param pipe_diameter number
---@return table config
function M.create_2path_config(pipe_diameter)
  local angle = math.pi / 4.0
  return M.flow_meter_config(pipe_diameter, {
    M.acoustic_path(pipe_diameter, 0.25, angle, 0.5),
    M.acoustic_path(pipe_diameter, -0.25, angle, 0.5),
  })
end

--- Two 60° paths near the wall plus two 45° paths near the center.
---
--- Sampling the velocity profile at four heights integrates it more accurately
--- than a single pair of paths.
---
---@param pipe_diameter number
---@return table config
function M.create_4path_config(pipe_diameter)
  local outer_angle = math.pi / 3.0
  local inner_angle = math.pi / 4.0
  return M.flow_meter_config(pipe_diameter, {
    M.acoustic_path(pipe_diameter, 0.35, outer_angle, 0.25),
    M.acoustic_path(pipe_diameter, -0.35, outer_angle, 0.25),
    M.acoustic_path(pipe_diameter, 0.15, inner_angle, 0.25),
    M.acoustic_path(pipe_diameter, -0.15, inner_angle, 0.25),
  })
end

--- Convert m³/s to liters per second.
---@param m3_per_s number
---@return number
function M.cubic_meters_to_liters_per_second(m3_per_s)
  return m3_per_s * 1000.0
end

--- Convert m³/s to liters per minute.
---@param m3_per_s number
---@return number
function M.cubic_meters_to_liters_per_minute(m3_per_s)
  return m3_per_s * 60000.0
end

return M
