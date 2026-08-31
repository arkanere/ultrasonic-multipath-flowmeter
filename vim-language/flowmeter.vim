" flowmeter.vim -- Core algorithm for a transit-time differential ultrasonic
" flow meter.
"
" An ultrasonic signal sent across a pipe travels faster with the flow than
" against it. Comparing the two transit times reveals the flow velocity
" without needing to know the speed of sound in the fluid.
"
" Vimscript has no structs and no modules, so records are plain dictionaries
" and the namespace is a shared `Flowmeter_` prefix on ordinary global
" functions. Nothing here echoes, writes a file, or opens a buffer: the script
" can be `:source`d into a running Vim and driven from the command line with
" `:echo Flowmeter_pipe_area(Flowmeter_2path_config(0.1))`.

" Guard against sourcing the file twice into the same Vim session.
if exists('g:loaded_flowmeter')
  finish
endif
let g:loaded_flowmeter = 1

" Line continuations are disabled under 'compatible' cpoptions, which is what
" `vim -es` starts in. Every Vim plugin opens with this dance: stash the user's
" 'cpoptions', switch to the Vim defaults, and restore it at the bottom of the
" file.
let s:save_cpo = &cpoptions
set cpoptions&vim

" Vimscript has no pi constant; derive it from the arctangent once.
let g:flowmeter_pi = 4.0 * atan(1.0)

" Build a single acoustic path crossing the pipe.
"
" a:pipe_diameter  Pipe diameter, in meters.
" a:position       Position on the pipe diameter, normalized to -1..1.
" a:angle          Angle from the pipe axis, in radians.
" a:weight         Gauss-Jacobi weighting coefficient.
"
" The path length is derived here, so the chord formula D / sin(theta) appears
" exactly once.
function! Flowmeter_acoustic_path(pipe_diameter, position, angle, weight) abort
  return {
        \ 'position': a:position,
        \ 'angle': a:angle,
        \ 'length': a:pipe_diameter / sin(a:angle),
        \ 'weight': a:weight,
        \ }
endfunction

" Upstream and downstream transit times for one path, in seconds.
"
" 'delta_t' is the difference the whole method rests on. It is computed once at
" construction rather than on every read.
function! Flowmeter_path_measurement(t_upstream, t_downstream) abort
  return {
        \ 't_upstream': a:t_upstream,
        \ 't_downstream': a:t_downstream,
        \ 'delta_t': a:t_upstream - a:t_downstream,
        \ }
endfunction

" Bundle a pipe with the acoustic paths crossing it.
"
" a:paths is copied, so a later change by the caller cannot reach inside the
" configuration.
function! Flowmeter_config(pipe_diameter, paths) abort
  return {
        \ 'pipe_diameter': a:pipe_diameter,
        \ 'paths': copy(a:paths),
        \ 'num_paths': len(a:paths),
        \ }
endfunction

" Cross-sectional area of the pipe, pi (D/2)^2, in m².
function! Flowmeter_pipe_area(config) abort
  let l:radius = a:config.pipe_diameter / 2.0
  return g:flowmeter_pi * l:radius * l:radius
endfunction

" Velocity along the pipe axis implied by one path measurement, in m/s.
"
" Transit-time differential method:
"
"     v_path = (L / (2 sin(theta))) * (delta_t / (t_up * t_down))
"
" Returns 0.0 for non-physical transit times or a degenerate path angle,
" matching the C reference implementation.
function! Flowmeter_path_velocity(path, measurement) abort
  if a:measurement.t_upstream <= 0 || a:measurement.t_downstream <= 0
    return 0.0
  endif

  let l:sin_theta = sin(a:path.angle)

  " A path along the pipe axis carries no flow information.
  if l:sin_theta == 0
    return 0.0
  endif

  return (a:path.length / (2.0 * l:sin_theta)) *
        \ (a:measurement.delta_t /
        \  (a:measurement.t_upstream * a:measurement.t_downstream))
endfunction

" Integrate the per-path velocities into a volumetric flow rate.
"
" Gauss-Jacobi quadrature: Q = (pi D^2 / 4) * sum(w_i v_i).
"
" Throws if the configuration has no paths or if the measurements do not line
" up one-to-one with them.
function! Flowmeter_flow_rate(config, measurements) abort
  if a:config.num_paths == 0
    throw 'flowmeter: configuration has no paths'
  endif
  if len(a:measurements) != a:config.num_paths
    throw 'flowmeter: expected one measurement per acoustic path'
  endif

  let l:path_velocities = []
  let l:weighted_velocity_sum = 0.0

  for l:i in range(a:config.num_paths)
    let l:path = a:config.paths[l:i]
    let l:velocity = Flowmeter_path_velocity(l:path, a:measurements[l:i])
    call add(l:path_velocities, l:velocity)
    let l:weighted_velocity_sum += l:path.weight * l:velocity
  endfor

  return {
        \ 'path_velocities': l:path_velocities,
        \ 'volumetric_flow': Flowmeter_pipe_area(a:config) * l:weighted_velocity_sum,
        \ }
endfunction

" Two 45-degree paths at +/-0.25 D: quick, cost-effective measurement.
function! Flowmeter_2path_config(pipe_diameter) abort
  let l:angle = g:flowmeter_pi / 4.0
  return Flowmeter_config(a:pipe_diameter, [
        \ Flowmeter_acoustic_path(a:pipe_diameter, 0.25, l:angle, 0.5),
        \ Flowmeter_acoustic_path(a:pipe_diameter, -0.25, l:angle, 0.5),
        \ ])
endfunction

" Two 60-degree paths near the wall plus two 45-degree paths near the center.
"
" Sampling the velocity profile at four heights integrates it more accurately
" than a single pair of paths.
function! Flowmeter_4path_config(pipe_diameter) abort
  let l:outer_angle = g:flowmeter_pi / 3.0
  let l:inner_angle = g:flowmeter_pi / 4.0
  return Flowmeter_config(a:pipe_diameter, [
        \ Flowmeter_acoustic_path(a:pipe_diameter, 0.35, l:outer_angle, 0.25),
        \ Flowmeter_acoustic_path(a:pipe_diameter, -0.35, l:outer_angle, 0.25),
        \ Flowmeter_acoustic_path(a:pipe_diameter, 0.15, l:inner_angle, 0.25),
        \ Flowmeter_acoustic_path(a:pipe_diameter, -0.15, l:inner_angle, 0.25),
        \ ])
endfunction

" Convert m³/s to liters per second.
function! Flowmeter_to_liters_per_second(m3_per_s) abort
  return a:m3_per_s * 1000.0
endfunction

" Convert m³/s to liters per minute.
function! Flowmeter_to_liters_per_minute(m3_per_s) abort
  return a:m3_per_s * 60000.0
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
