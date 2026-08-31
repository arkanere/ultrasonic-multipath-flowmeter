--- Demonstration of the ultrasonic multipath flow meter.
---
--- Synthesizes transit times for a known flow velocity, then runs them back
--- through the solver to recover the volumetric flow rate. This is the only
--- file that writes to stdout.
---
--- Run it headless:
---
---     nvim --headless -l main.lua

-- `nvim -l` does not put the script's own directory on `package.path`, so the
-- module is located relative to this file rather than the working directory.
local script_dir = debug.getinfo(1, 'S').source:sub(2):match('(.*[/\\])') or './'
package.path = script_dir .. '?.lua;' .. package.path

local flowmeter = require('flowmeter')

--- Speed of sound in water at 20°C, in m/s.
local SOUND_SPEED = 1480.0

local function radians_to_degrees(radians)
  return radians * 180.0 / math.pi
end

--- Print one formatted line to stdout.
---
--- `io.write` rather than `print`: under `nvim --headless` the editor's own
--- `print` routes through the message area, which adds carriage returns.
local function say(format, ...)
  if select('#', ...) > 0 then
    io.write(string.format(format, ...), '\n')
  else
    io.write(format, '\n')
  end
end

--- Generate synthetic transit times for a known flow velocity.
---
--- The acoustic path component along the flow direction is `L sin(theta)`, and
--- the signal effectively travels at `c - v` upstream and `c + v` downstream.
local function simulate_measurements(config, true_flow_velocity)
  local measurements = {}

  for i, path in ipairs(config.paths) do
    local path_component = path.length * math.sin(path.angle)
    measurements[i] = flowmeter.path_measurement(
      path_component / (SOUND_SPEED - true_flow_velocity),
      path_component / (SOUND_SPEED + true_flow_velocity)
    )
  end

  return measurements
end

local function print_config(config)
  say('Flow Meter Configuration:')
  say('  Pipe diameter: %.3f m', config.pipe_diameter)
  say('  Number of paths: %d', config.num_paths)
  say('  Pipe area: %.6f m²', flowmeter.pipe_area(config))
  say('')
  say('Acoustic Paths:')

  for i, path in ipairs(config.paths) do
    say('  Path %d:', i)
    say('    Position: %.2f D', path.position)
    say('    Angle: %.2f° (%.4f rad)', radians_to_degrees(path.angle), path.angle)
    say('    Path length: %.4f m', path.length)
    say('    Weight: %.3f', path.weight)
  end
end

local function print_measurements(measurements, true_flow_velocity)
  say('')
  say('Simulated Measurements (True flow velocity: %.2f m/s):', true_flow_velocity)

  for i, m in ipairs(measurements) do
    say(
      '  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s',
      i,
      m.t_upstream,
      m.t_downstream,
      m.delta_t
    )
  end
end

local function print_results(result)
  say('')
  say('Flow Calculation Results:')

  for i, velocity in ipairs(result.path_velocities) do
    say('  Path %d velocity: %.4f m/s', i, velocity)
  end

  say('')
  say('Volumetric Flow Rate:')
  say('  %.6f m³/s', result.volumetric_flow)
  say('  %.4f L/min', flowmeter.cubic_meters_to_liters_per_minute(result.volumetric_flow))
  say('  %.2f L/s', flowmeter.cubic_meters_to_liters_per_second(result.volumetric_flow))
end

--- Run one configuration end to end: describe it, simulate it, solve it.
local function run_demo(title, config, true_flow_velocity)
  say('### %s ###', title)
  say('')

  print_config(config)

  local measurements = simulate_measurements(config, true_flow_velocity)
  print_measurements(measurements, true_flow_velocity)

  print_results(flowmeter.calculate_flow_rate(config, measurements))
end

local function main()
  local pipe_diameter = 0.1 -- 100 mm
  local true_flow_velocity = 2.0 -- 2 m/s

  say('=== Ultrasonic Multipath Flow Meter ===')
  say('')

  run_demo('2-PATH CONFIGURATION', flowmeter.create_2path_config(pipe_diameter), true_flow_velocity)

  say('')
  say('')

  run_demo('4-PATH CONFIGURATION', flowmeter.create_4path_config(pipe_diameter), true_flow_velocity)

  say('')
  say('=== End of Demonstration ===')
end

main()
