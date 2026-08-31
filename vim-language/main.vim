" main.vim -- Demonstration of the ultrasonic multipath flow meter.
"
" Synthesizes transit times for a known flow velocity, then runs them back
" through the solver to recover the volumetric flow rate. This is the only
" file that produces output.
"
" Run it headless:
"
"     vim -es -S main.vim
"
" Note the output route. In Ex silent mode (-es) Vim suppresses `:echo`
" entirely, so the program collects its lines in a list and hands them to
" writefile() against /dev/stdout at the end. That also makes the output a
" single atomic write, with no editor chrome interleaved.

" Line continuations are disabled under 'compatible' cpoptions, which is what
" `vim -es` starts in. Restored at the bottom of the file.
let s:save_cpo = &cpoptions
set cpoptions&vim

" Source the core from this script's own directory, so the program runs from
" any working directory.
execute 'source' fnameescape(expand('<sfile>:p:h') . '/flowmeter.vim')

" Speed of sound in water at 20°C, in m/s.
let s:sound_speed = 1480.0

" Lines accumulated so far, flushed once by s:flush().
let s:output = []

function! s:say(line) abort
  call add(s:output, a:line)
endfunction

function! s:flush() abort
  call writefile(s:output, '/dev/stdout')
  let s:output = []
endfunction

function! s:radians_to_degrees(radians) abort
  return a:radians * 180.0 / g:flowmeter_pi
endfunction

" Generate synthetic transit times for a known flow velocity.
"
" The acoustic path component along the flow direction is L sin(theta), and the
" signal effectively travels at c - v upstream and c + v downstream.
function! s:simulate_measurements(config, true_flow_velocity) abort
  let l:measurements = []

  for l:path in a:config.paths
    let l:path_component = l:path.length * sin(l:path.angle)
    call add(l:measurements, Flowmeter_path_measurement(
          \ l:path_component / (s:sound_speed - a:true_flow_velocity),
          \ l:path_component / (s:sound_speed + a:true_flow_velocity)))
  endfor

  return l:measurements
endfunction

function! s:print_config(config) abort
  call s:say('Flow Meter Configuration:')
  call s:say(printf('  Pipe diameter: %.3f m', a:config.pipe_diameter))
  call s:say(printf('  Number of paths: %d', a:config.num_paths))
  call s:say(printf('  Pipe area: %.6f m²', Flowmeter_pipe_area(a:config)))
  call s:say('')
  call s:say('Acoustic Paths:')

  for l:i in range(a:config.num_paths)
    let l:path = a:config.paths[l:i]
    call s:say(printf('  Path %d:', l:i + 1))
    call s:say(printf('    Position: %.2f D', l:path.position))
    call s:say(printf('    Angle: %.2f° (%.4f rad)',
          \ s:radians_to_degrees(l:path.angle), l:path.angle))
    call s:say(printf('    Path length: %.4f m', l:path.length))
    call s:say(printf('    Weight: %.3f', l:path.weight))
  endfor
endfunction

function! s:print_measurements(measurements, true_flow_velocity) abort
  call s:say('')
  call s:say(printf('Simulated Measurements (True flow velocity: %.2f m/s):',
        \ a:true_flow_velocity))

  for l:i in range(len(a:measurements))
    let l:m = a:measurements[l:i]
    call s:say(printf(
          \ '  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s',
          \ l:i + 1, l:m.t_upstream, l:m.t_downstream, l:m.delta_t))
  endfor
endfunction

function! s:print_results(result) abort
  call s:say('')
  call s:say('Flow Calculation Results:')

  for l:i in range(len(a:result.path_velocities))
    call s:say(printf('  Path %d velocity: %.4f m/s',
          \ l:i + 1, a:result.path_velocities[l:i]))
  endfor

  let l:flow = a:result.volumetric_flow
  call s:say('')
  call s:say('Volumetric Flow Rate:')
  call s:say(printf('  %.6f m³/s', l:flow))
  call s:say(printf('  %.4f L/min', Flowmeter_to_liters_per_minute(l:flow)))
  call s:say(printf('  %.2f L/s', Flowmeter_to_liters_per_second(l:flow)))
endfunction

" Run one configuration end to end: describe it, simulate it, solve it.
function! s:run_demo(title, config, true_flow_velocity) abort
  call s:say(printf('### %s ###', a:title))
  call s:say('')

  call s:print_config(a:config)

  let l:measurements = s:simulate_measurements(a:config, a:true_flow_velocity)
  call s:print_measurements(l:measurements, a:true_flow_velocity)

  call s:print_results(Flowmeter_flow_rate(a:config, l:measurements))
endfunction

function! s:main() abort
  let l:pipe_diameter = 0.1       " 100 mm
  let l:true_flow_velocity = 2.0  " 2 m/s

  call s:say('=== Ultrasonic Multipath Flow Meter ===')
  call s:say('')

  call s:run_demo('2-PATH CONFIGURATION',
        \ Flowmeter_2path_config(l:pipe_diameter), l:true_flow_velocity)

  call s:say('')
  call s:say('')

  call s:run_demo('4-PATH CONFIGURATION',
        \ Flowmeter_4path_config(l:pipe_diameter), l:true_flow_velocity)

  call s:say('')
  call s:say('=== End of Demonstration ===')

  call s:flush()
endfunction

call s:main()

let &cpoptions = s:save_cpo
unlet s:save_cpo

" Sourcing the script is the whole program, so leave once it has run. Guard the
" quit so that :source-ing this file from an interactive Vim does not close it.
if !has('gui_running') && (index(v:argv, '-es') >= 0 || index(v:argv, '-Es') >= 0)
  qall!
endif
