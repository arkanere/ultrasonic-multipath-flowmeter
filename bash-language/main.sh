#!/bin/bash
#
# main.sh -- Demonstration of the ultrasonic multipath flow meter.
#
# Synthesizes transit times for a known flow velocity, then runs them back
# through the solver to recover the volumetric flow rate. This is the only file
# that prints.
#
# Bash's own printf is a thin wrapper over C's, so the display formats here are
# the same %.4f / %.2e verbs the C reference uses, applied to the decimal
# strings awk handed back. Only the arithmetic needs awk; the formatting does
# not.
#
# Run it:
#
#     bash main.sh

set -u

# Load the core from this script's own directory, so the program runs from any
# working directory.
FM_MAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flowmeter.sh
source "$FM_MAIN_DIR/flowmeter.sh"

# Speed of sound in water at 20°C, in m/s.
readonly FM_SOUND_SPEED=1480.0

fm_radians_to_degrees() {
  fm_calc "$1 * 180.0 / $FM_PI"
}

# fm_simulate_measurements TRUE_FLOW_VELOCITY
#
# Generate synthetic transit times for a known flow velocity, filling the
# FM_T_UPSTREAM / FM_T_DOWNSTREAM / FM_DELTA_T arrays.
#
# The acoustic path component along the flow direction is L sin(theta), and the
# signal effectively travels at c - v upstream and c + v downstream.
fm_simulate_measurements() {
  local true_flow_velocity="$1"
  local i path_component t_upstream t_downstream

  fm_reset_measurements

  for ((i = 0; i < FM_NUM_PATHS; i++)); do
    path_component=$(fm_calc "${FM_PATH_LENGTH[$i]} * sin(${FM_PATH_ANGLE[$i]})")
    t_upstream=$(fm_calc "$path_component / ($FM_SOUND_SPEED - $true_flow_velocity)")
    t_downstream=$(fm_calc "$path_component / ($FM_SOUND_SPEED + $true_flow_velocity)")
    fm_add_measurement "$t_upstream" "$t_downstream"
  done
}

fm_print_config() {
  local i

  echo "Flow Meter Configuration:"
  printf '  Pipe diameter: %.3f m\n' "$FM_PIPE_DIAMETER"
  printf '  Number of paths: %d\n' "$FM_NUM_PATHS"
  printf '  Pipe area: %.6f m²\n' "$(fm_pipe_area)"
  echo
  echo "Acoustic Paths:"

  for ((i = 0; i < FM_NUM_PATHS; i++)); do
    printf '  Path %d:\n' "$((i + 1))"
    printf '    Position: %.2f D\n' "${FM_PATH_POSITION[$i]}"
    printf '    Angle: %.2f° (%.4f rad)\n' \
      "$(fm_radians_to_degrees "${FM_PATH_ANGLE[$i]}")" "${FM_PATH_ANGLE[$i]}"
    printf '    Path length: %.4f m\n' "${FM_PATH_LENGTH[$i]}"
    printf '    Weight: %.3f\n' "${FM_PATH_WEIGHT[$i]}"
  done
}

# fm_print_measurements TRUE_FLOW_VELOCITY
fm_print_measurements() {
  local true_flow_velocity="$1"
  local i

  echo
  printf 'Simulated Measurements (True flow velocity: %.2f m/s):\n' \
    "$true_flow_velocity"

  for ((i = 0; i < ${#FM_T_UPSTREAM[@]}; i++)); do
    printf '  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s\n' \
      "$((i + 1))" "${FM_T_UPSTREAM[$i]}" "${FM_T_DOWNSTREAM[$i]}" "${FM_DELTA_T[$i]}"
  done
}

fm_print_results() {
  local i

  echo
  echo "Flow Calculation Results:"

  for ((i = 0; i < ${#FM_PATH_VELOCITIES[@]}; i++)); do
    printf '  Path %d velocity: %.4f m/s\n' "$((i + 1))" "${FM_PATH_VELOCITIES[$i]}"
  done

  echo
  echo "Volumetric Flow Rate:"
  printf '  %.6f m³/s\n' "$FM_VOLUMETRIC_FLOW"
  printf '  %.4f L/min\n' "$(fm_to_liters_per_minute "$FM_VOLUMETRIC_FLOW")"
  printf '  %.2f L/s\n' "$(fm_to_liters_per_second "$FM_VOLUMETRIC_FLOW")"
}

# fm_run_demo TITLE TRUE_FLOW_VELOCITY
#
# Run whichever configuration is currently built, end to end: describe it,
# simulate it, solve it.
fm_run_demo() {
  local title="$1" true_flow_velocity="$2"

  printf '### %s ###\n\n' "$title"

  fm_print_config

  fm_simulate_measurements "$true_flow_velocity"
  fm_print_measurements "$true_flow_velocity"

  fm_calculate_flow_rate || return 1
  fm_print_results
}

fm_main() {
  local pipe_diameter=0.1      # 100 mm
  local true_flow_velocity=2.0 # 2 m/s

  echo "=== Ultrasonic Multipath Flow Meter ==="
  echo

  fm_create_2path_config "$pipe_diameter"
  fm_run_demo "2-PATH CONFIGURATION" "$true_flow_velocity" || return 1

  echo
  echo

  fm_create_4path_config "$pipe_diameter"
  fm_run_demo "4-PATH CONFIGURATION" "$true_flow_velocity" || return 1

  echo
  echo "=== End of Demonstration ==="
}

fm_main "$@"
