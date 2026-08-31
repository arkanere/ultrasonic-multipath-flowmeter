;;; main.el --- Ultrasonic flow meter demonstration  -*- lexical-binding: t; -*-

;;; Commentary:

;; Demonstration of the ultrasonic multipath flow meter.
;;
;; Synthesizes transit times for a known flow velocity, then runs them back
;; through the solver to recover the volumetric flow rate.  This is the only
;; file that prints; flowmeter.el stays pure.
;;
;; Run it headless:
;;
;;     emacs --batch -l main.el

;;; Code:

(require 'cl-lib)

;; Load flowmeter.el from this file's own directory, so the program works from
;; any working directory and without touching the user's `load-path'.
(add-to-list 'load-path
             (file-name-directory (or load-file-name buffer-file-name default-directory)))
(require 'flowmeter)

(defconst flowmeter-main-sound-speed 1480.0
  "Speed of sound in water at 20°C, in m/s.")

(defun flowmeter-main--radians-to-degrees (radians)
  "Convert RADIANS to degrees."
  (/ (* radians 180.0) float-pi))

(defun flowmeter-main--say (format-string &rest args)
  "Print FORMAT-STRING with ARGS to stdout, followed by a newline.
`princ' is used rather than `message', which would write to stderr."
  (princ (apply #'format format-string args))
  (princ "\n"))

(defun flowmeter-main--simulate-measurements (config true-flow-velocity)
  "Generate synthetic transit times for CONFIG at TRUE-FLOW-VELOCITY m/s.

The acoustic path component along the flow direction is L sin(theta), and
the signal effectively travels at c - v upstream and c + v downstream."
  (mapcar (lambda (path)
            (let ((path-component (* (flowmeter-path-length path)
                                     (sin (flowmeter-path-angle path)))))
              (flowmeter-make-measurement
               (/ path-component (- flowmeter-main-sound-speed true-flow-velocity))
               (/ path-component (+ flowmeter-main-sound-speed true-flow-velocity)))))
          (flowmeter-config-paths config)))

(defun flowmeter-main--print-config (config)
  "Describe CONFIG: the pipe, then every acoustic path crossing it."
  (flowmeter-main--say "Flow Meter Configuration:")
  (flowmeter-main--say "  Pipe diameter: %.3f m" (flowmeter-config-pipe-diameter config))
  (flowmeter-main--say "  Number of paths: %d" (flowmeter-num-paths config))
  (flowmeter-main--say "  Pipe area: %.6f m²" (flowmeter-pipe-area config))
  (flowmeter-main--say "")
  (flowmeter-main--say "Acoustic Paths:")
  (cl-loop for path in (flowmeter-config-paths config)
           for i from 1
           do (flowmeter-main--say "  Path %d:" i)
              (flowmeter-main--say "    Position: %.2f D" (flowmeter-path-position path))
              (flowmeter-main--say "    Angle: %.2f° (%.4f rad)"
                                   (flowmeter-main--radians-to-degrees
                                    (flowmeter-path-angle path))
                                   (flowmeter-path-angle path))
              (flowmeter-main--say "    Path length: %.4f m" (flowmeter-path-length path))
              (flowmeter-main--say "    Weight: %.3f" (flowmeter-path-weight path))))

(defun flowmeter-main--print-measurements (measurements true-flow-velocity)
  "Print MEASUREMENTS, taken at TRUE-FLOW-VELOCITY m/s."
  (flowmeter-main--say "")
  (flowmeter-main--say "Simulated Measurements (True flow velocity: %.2f m/s):"
                       true-flow-velocity)
  (cl-loop for m in measurements
           for i from 1
           do (flowmeter-main--say
               "  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s"
               i
               (flowmeter-measurement-t-upstream m)
               (flowmeter-measurement-t-downstream m)
               (flowmeter-measurement-delta-t m))))

(defun flowmeter-main--print-results (result)
  "Print the per-path velocities and flow rate held in RESULT."
  (flowmeter-main--say "")
  (flowmeter-main--say "Flow Calculation Results:")
  (cl-loop for velocity in (flowmeter-result-path-velocities result)
           for i from 1
           do (flowmeter-main--say "  Path %d velocity: %.4f m/s" i velocity))
  (let ((flow (flowmeter-result-volumetric-flow result)))
    (flowmeter-main--say "")
    (flowmeter-main--say "Volumetric Flow Rate:")
    (flowmeter-main--say "  %.6f m³/s" flow)
    (flowmeter-main--say "  %.4f L/min" (flowmeter-cubic-meters-to-liters-per-minute flow))
    (flowmeter-main--say "  %.2f L/s" (flowmeter-cubic-meters-to-liters-per-second flow))))

(defun flowmeter-main--run-demo (title config true-flow-velocity)
  "Run CONFIG end to end under TITLE at TRUE-FLOW-VELOCITY m/s.
Describe it, simulate it, solve it."
  (flowmeter-main--say "### %s ###" title)
  (flowmeter-main--say "")
  (flowmeter-main--print-config config)
  (let ((measurements (flowmeter-main--simulate-measurements config true-flow-velocity)))
    (flowmeter-main--print-measurements measurements true-flow-velocity)
    (flowmeter-main--print-results (flowmeter-flow-rate config measurements))))

(defun flowmeter-main ()
  "Run both demonstration configurations and print the results."
  (let ((pipe-diameter 0.1)      ; 100 mm
        (true-flow-velocity 2.0)) ; 2 m/s
    (flowmeter-main--say "=== Ultrasonic Multipath Flow Meter ===")
    (flowmeter-main--say "")
    (flowmeter-main--run-demo "2-PATH CONFIGURATION"
                              (flowmeter-2-path-config pipe-diameter)
                              true-flow-velocity)
    (flowmeter-main--say "")
    (flowmeter-main--say "")
    (flowmeter-main--run-demo "4-PATH CONFIGURATION"
                              (flowmeter-4-path-config pipe-diameter)
                              true-flow-velocity)
    (flowmeter-main--say "")
    (flowmeter-main--say "=== End of Demonstration ===")))

;; Running under --batch means there is no one to call the entry point, so the
;; file calls it itself on load.  Loading it in an interactive Emacs prints
;; into *Messages* instead; call `flowmeter-main' from `ielm' to see it there.
(flowmeter-main)

;;; main.el ends here
