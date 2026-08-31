;;;; main.lisp --- Demonstration of the ultrasonic multipath flow meter.
;;;;
;;;; Synthesizes transit times for a known flow velocity, then runs them back
;;;; through the solver to recover the volumetric flow rate.  This is the only
;;;; file that writes to a stream; core.lisp stays pure.
;;;;
;;;; Run it:
;;;;
;;;;     sbcl --script src/main.lisp

;;; Load the core from this file's own directory when run as a script, so the
;;; program works from any working directory.  Under ASDF the system definition
;;; has already loaded it and this is a no-op.
(eval-when (:compile-toplevel :load-toplevel :execute)
  (unless (find-package '#:ultrasonic-flowmeter)
    (load (merge-pathnames "core.lisp"
                           (or *load-truename* *default-pathname-defaults*))
          :verbose nil :print nil)))

(defpackage #:ultrasonic-flowmeter/main
  (:use #:common-lisp #:ultrasonic-flowmeter)
  (:export #:main))

(in-package #:ultrasonic-flowmeter/main)

(defconstant +sound-speed+ 1480d0
  "Speed of sound in water at 20°C, in m/s.")

(defun radians-to-degrees (radians)
  (/ (* radians 180d0) pi))

(defun format-scientific (value &optional (digits 2))
  "Format VALUE like C's %.2e: a mantissa, `e', a sign, and two exponent digits.

Common Lisp's ~E directive prints `1.83e-7', with neither a forced sign nor a
zero-padded exponent, so the conversion is done by hand.  The Basic, Pascal,
and Haskell implementations carry the same helper for the same reason."
  (if (zerop value)
      (format nil "~,vFe+00" digits (float 0 0d0))
      (let* ((negative (minusp value))
             (magnitude (abs (float value 0d0)))
             (exponent (floor (log magnitude 10d0)))
             (mantissa (/ magnitude (expt 10d0 exponent))))
        ;; log10 can land a hair to either side of an exact power of ten, so
        ;; the mantissa is walked back into [1, 10) rather than trusted.
        (loop while (>= mantissa 10d0)
              do (setf mantissa (/ mantissa 10d0))
                 (incf exponent))
        (loop while (< mantissa 1d0)
              do (setf mantissa (* mantissa 10d0))
                 (decf exponent))
        ;; Rounding for display can push the mantissa back up to 10.00.
        (when (>= (+ mantissa (/ 5d0 (expt 10d0 (1+ digits)))) 10d0)
          (setf mantissa (/ mantissa 10d0))
          (incf exponent))
        (format nil "~:[~;-~]~,vFe~:[+~;-~]~2,'0D"
                negative digits mantissa (minusp exponent) (abs exponent)))))

(defun simulate-measurements (config true-flow-velocity)
  "Generate synthetic transit times for CONFIG at TRUE-FLOW-VELOCITY m/s.

The acoustic path component along the flow direction is L sin(theta), and the
signal effectively travels at c - v upstream and c + v downstream."
  (mapcar (lambda (path)
            (let ((path-component (* (path-length path) (sin (path-angle path)))))
              (path-measurement (/ path-component (- +sound-speed+ true-flow-velocity))
                                (/ path-component (+ +sound-speed+ true-flow-velocity)))))
          (config-paths config)))

(defun print-config (config)
  "Describe CONFIG: the pipe, then every acoustic path crossing it."
  (format t "Flow Meter Configuration:~%")
  (format t "  Pipe diameter: ~,3F m~%" (config-pipe-diameter config))
  (format t "  Number of paths: ~D~%" (config-num-paths config))
  (format t "  Pipe area: ~,6F m²~%" (pipe-area config))
  (format t "~%Acoustic Paths:~%")
  (loop for path in (config-paths config)
        for i from 1
        do (format t "  Path ~D:~%" i)
           (format t "    Position: ~,2F D~%" (path-position path))
           (format t "    Angle: ~,2F° (~,4F rad)~%"
                   (radians-to-degrees (path-angle path))
                   (path-angle path))
           (format t "    Path length: ~,4F m~%" (path-length path))
           (format t "    Weight: ~,3F~%" (path-weight path))))

(defun print-measurements (measurements true-flow-velocity)
  "Print MEASUREMENTS, taken at TRUE-FLOW-VELOCITY m/s."
  (format t "~%Simulated Measurements (True flow velocity: ~,2F m/s):~%"
          true-flow-velocity)
  (loop for m in measurements
        for i from 1
        do (format t "  Path ~D: t_upstream = ~,8F s, t_downstream = ~,8F s, Δt = ~A s~%"
                   i
                   (measurement-t-upstream m)
                   (measurement-t-downstream m)
                   (format-scientific (measurement-delta-t m)))))

(defun print-results (result)
  "Print the per-path velocities and flow rate held in RESULT."
  (format t "~%Flow Calculation Results:~%")
  (loop for velocity in (result-path-velocities result)
        for i from 1
        do (format t "  Path ~D velocity: ~,4F m/s~%" i velocity))
  (let ((flow (result-volumetric-flow result)))
    (format t "~%Volumetric Flow Rate:~%")
    (format t "  ~,6F m³/s~%" flow)
    (format t "  ~,4F L/min~%" (cubic-meters-to-liters-per-minute flow))
    (format t "  ~,2F L/s~%" (cubic-meters-to-liters-per-second flow))))

(defun run-demo (title config true-flow-velocity)
  "Run CONFIG end to end under TITLE at TRUE-FLOW-VELOCITY m/s.
Describe it, simulate it, solve it."
  (format t "### ~A ###~%~%" title)
  (print-config config)
  (let ((measurements (simulate-measurements config true-flow-velocity)))
    (print-measurements measurements true-flow-velocity)
    (print-results (calculate-flow-rate config measurements))))

(defun main ()
  "Run both demonstration configurations and print the results."
  (let ((pipe-diameter 0.1d0)      ; 100 mm
        (true-flow-velocity 2d0))  ; 2 m/s
    (format t "=== Ultrasonic Multipath Flow Meter ===~%~%")
    (run-demo "2-PATH CONFIGURATION" (create-2path-config pipe-diameter)
              true-flow-velocity)
    (format t "~%~%")
    (run-demo "4-PATH CONFIGURATION" (create-4path-config pipe-diameter)
              true-flow-velocity)
    (format t "~%=== End of Demonstration ===~%")))

;;; `sbcl --script' has no one to call the entry point, so the file calls it
;;; itself.  Loading this file into a REPL runs the demo once and leaves `main'
;;; available to call again.
(main)
