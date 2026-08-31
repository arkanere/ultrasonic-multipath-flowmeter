#!/bin/bash
#
# flowmeter.sh -- Core algorithm for a transit-time differential ultrasonic
# flow meter.
#
# An ultrasonic signal sent across a pipe travels faster with the flow than
# against it. Comparing the two transit times reveals the flow velocity without
# needing to know the speed of sound in the fluid.
#
# Bash has no floating-point arithmetic: $(( )) is integer-only. So the shell
# does what a shell is good at -- naming things, looping, and gluing -- and
# every arithmetic expression is handed to awk, which computes in the same
# IEEE-754 doubles as C. fm_calc is, in effect, this program's FPU.
#
# Bash also has no structures and no way to return one from a function, so a
# "record" here is a set of parallel indexed arrays with a shared prefix, and
# functions communicate by assigning to well-known globals. Indexed arrays, not
# associative ones: macOS ships bash 3.2, which predates ${array[key]}.
#
# This file is meant to be sourced, not executed:
#
#     source flowmeter.sh

# Numbers must format and parse with '.' as the decimal separator regardless of
# the user's locale, in both bash's printf and awk's.
export LC_ALL=C

# --- Arithmetic ------------------------------------------------------------

# Evaluate an awk expression and echo the result.
#
# %.17g is the shortest format that round-trips an IEEE-754 double, so values
# passed back through the shell as strings lose no precision.
fm_calc() {
  awk "BEGIN { printf \"%.17g\", $1 }"
}

# pi, computed once at source time. awk has no pi constant either.
FM_PI=$(fm_calc 'atan2(0, -1)')

# --- Acoustic paths --------------------------------------------------------
#
# A path is one row across four parallel arrays.

FM_PATH_POSITION=()  # Position on the pipe diameter, normalized to -1..1.
FM_PATH_ANGLE=()     # Angle from the pipe axis, in radians.
FM_PATH_LENGTH=()    # Acoustic path length in meters: the chord D / sin(angle).
FM_PATH_WEIGHT=()    # Gauss-Jacobi weighting coefficient.

# fm_add_path PIPE_DIAMETER POSITION ANGLE WEIGHT
#
# Append one acoustic path to the configuration being built. The path length is
# derived here, so the chord formula D / sin(theta) appears exactly once.
fm_add_path() {
  local pipe_diameter="$1" position="$2" angle="$3" weight="$4"

  FM_PATH_POSITION[${#FM_PATH_POSITION[@]}]="$position"
  FM_PATH_ANGLE[${#FM_PATH_ANGLE[@]}]="$angle"
  FM_PATH_LENGTH[${#FM_PATH_LENGTH[@]}]=$(fm_calc "$pipe_diameter / sin($angle)")
  FM_PATH_WEIGHT[${#FM_PATH_WEIGHT[@]}]="$weight"
}

# --- Configuration ---------------------------------------------------------

FM_PIPE_DIAMETER=0.0
FM_NUM_PATHS=0

# fm_reset_config PIPE_DIAMETER
#
# Start a fresh configuration for a pipe of the given diameter, in meters.
fm_reset_config() {
  FM_PIPE_DIAMETER="$1"
  FM_NUM_PATHS=0
  FM_PATH_POSITION=()
  FM_PATH_ANGLE=()
  FM_PATH_LENGTH=()
  FM_PATH_WEIGHT=()
}

# Finish the configuration begun by fm_reset_config.
fm_seal_config() {
  FM_NUM_PATHS=${#FM_PATH_POSITION[@]}
}

# Echo the cross-sectional area of the pipe, pi (D/2)^2, in m².
fm_pipe_area() {
  fm_calc "$FM_PI * ($FM_PIPE_DIAMETER / 2.0) * ($FM_PIPE_DIAMETER / 2.0)"
}

# Two 45-degree paths at +/-0.25 D: quick, cost-effective measurement.
fm_create_2path_config() {
  local pipe_diameter="$1"
  local angle
  angle=$(fm_calc "$FM_PI / 4.0")

  fm_reset_config "$pipe_diameter"
  fm_add_path "$pipe_diameter" 0.25 "$angle" 0.5
  fm_add_path "$pipe_diameter" -0.25 "$angle" 0.5
  fm_seal_config
}

# Two 60-degree paths near the wall plus two 45-degree paths near the center.
#
# Sampling the velocity profile at four heights integrates it more accurately
# than a single pair of paths.
fm_create_4path_config() {
  local pipe_diameter="$1"
  local outer_angle inner_angle
  outer_angle=$(fm_calc "$FM_PI / 3.0")
  inner_angle=$(fm_calc "$FM_PI / 4.0")

  fm_reset_config "$pipe_diameter"
  fm_add_path "$pipe_diameter" 0.35 "$outer_angle" 0.25
  fm_add_path "$pipe_diameter" -0.35 "$outer_angle" 0.25
  fm_add_path "$pipe_diameter" 0.15 "$inner_angle" 0.25
  fm_add_path "$pipe_diameter" -0.15 "$inner_angle" 0.25
  fm_seal_config
}

# --- Measurements ----------------------------------------------------------

FM_T_UPSTREAM=()    # Upstream transit time per path, in seconds.
FM_T_DOWNSTREAM=()  # Downstream transit time per path, in seconds.
FM_DELTA_T=()       # t_upstream - t_downstream: what the method rests on.

# Discard any measurements from a previous cycle.
fm_reset_measurements() {
  FM_T_UPSTREAM=()
  FM_T_DOWNSTREAM=()
  FM_DELTA_T=()
}

# fm_add_measurement T_UPSTREAM T_DOWNSTREAM
#
# Record one pair of transit times. The difference is computed once, here,
# rather than recomputed at every read.
fm_add_measurement() {
  local t_upstream="$1" t_downstream="$2"

  FM_T_UPSTREAM[${#FM_T_UPSTREAM[@]}]="$t_upstream"
  FM_T_DOWNSTREAM[${#FM_T_DOWNSTREAM[@]}]="$t_downstream"
  FM_DELTA_T[${#FM_DELTA_T[@]}]=$(fm_calc "$t_upstream - $t_downstream")
}

# --- The algorithm ---------------------------------------------------------

# fm_path_velocity INDEX
#
# Echo the velocity along the pipe axis implied by one path measurement, in m/s.
#
# Transit-time differential method:
#
#     v_path = (L / (2 sin(theta))) * (delta_t / (t_up * t_down))
#
# Echoes 0.0 for non-physical transit times or a degenerate path angle,
# matching the C reference implementation.
fm_path_velocity() {
  local i="$1"
  local t_up="${FM_T_UPSTREAM[$i]}"
  local t_down="${FM_T_DOWNSTREAM[$i]}"
  local sin_theta
  sin_theta=$(fm_calc "sin(${FM_PATH_ANGLE[$i]})")

  # A path along the pipe axis carries no flow information, and a non-positive
  # transit time is not physical. String comparison will not do here, so the
  # test itself goes through awk.
  if [ "$(fm_calc "($t_up <= 0 || $t_down <= 0 || $sin_theta == 0) ? 1 : 0")" = "1" ]; then
    echo "0.0"
    return
  fi

  fm_calc "(${FM_PATH_LENGTH[$i]} / (2.0 * $sin_theta)) * (${FM_DELTA_T[$i]} / ($t_up * $t_down))"
}

FM_PATH_VELOCITIES=()  # Recovered axial velocity per path, in m/s.
FM_VOLUMETRIC_FLOW=0.0 # Integrated flow rate, in m³/s.

# Integrate the per-path velocities into a volumetric flow rate, leaving the
# answer in FM_PATH_VELOCITIES and FM_VOLUMETRIC_FLOW.
#
# Gauss-Jacobi quadrature: Q = (pi D^2 / 4) * sum(w_i v_i).
#
# Returns 1, with a message on stderr, if the configuration has no paths or if
# the measurements do not line up one-to-one with them.
fm_calculate_flow_rate() {
  if [ "$FM_NUM_PATHS" -eq 0 ]; then
    echo "flowmeter: configuration has no paths" >&2
    return 1
  fi
  if [ "${#FM_T_UPSTREAM[@]}" -ne "$FM_NUM_PATHS" ]; then
    echo "flowmeter: expected one measurement per acoustic path" >&2
    return 1
  fi

  FM_PATH_VELOCITIES=()
  local weighted_sum="0.0" i velocity
  for ((i = 0; i < FM_NUM_PATHS; i++)); do
    velocity=$(fm_path_velocity "$i")
    FM_PATH_VELOCITIES[$i]="$velocity"
    weighted_sum=$(fm_calc "$weighted_sum + ${FM_PATH_WEIGHT[$i]} * $velocity")
  done

  local area
  area=$(fm_pipe_area)
  FM_VOLUMETRIC_FLOW=$(fm_calc "$area * $weighted_sum")
}

# --- Unit conversions ------------------------------------------------------

fm_to_liters_per_second() {
  fm_calc "$1 * 1000.0"
}

fm_to_liters_per_minute() {
  fm_calc "$1 * 60000.0"
}
