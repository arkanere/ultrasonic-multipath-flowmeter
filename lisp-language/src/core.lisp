;;;; core.lisp --- Core algorithm for a transit-time differential ultrasonic
;;;; flow meter.
;;;;
;;;; An ultrasonic signal sent across a pipe travels faster with the flow than
;;;; against it.  Comparing the two transit times reveals the flow velocity
;;;; without needing to know the speed of sound in the fluid.
;;;;
;;;; Nothing in this file writes to a stream.  Every literal carries a `d0'
;;;; suffix: unsuffixed decimals in Common Lisp are single-floats, and the
;;;; whole point of the exercise is to compute in the same IEEE-754 doubles the
;;;; C reference uses.

(defpackage #:ultrasonic-flowmeter
  (:nicknames #:flowmeter)
  (:use #:common-lisp)
  (:export #:acoustic-path
           #:make-acoustic-path
           #:path-position
           #:path-angle
           #:path-length
           #:path-weight

           #:path-measurement
           #:make-path-measurement
           #:measurement-t-upstream
           #:measurement-t-downstream
           #:measurement-delta-t

           #:flow-meter-config
           #:make-flow-meter-config
           #:config-pipe-diameter
           #:config-paths
           #:config-num-paths

           #:flow-result
           #:result-path-velocities
           #:result-volumetric-flow

           #:pipe-area
           #:calculate-path-velocity
           #:calculate-flow-rate
           #:create-2path-config
           #:create-4path-config
           #:cubic-meters-to-liters-per-second
           #:cubic-meters-to-liters-per-minute

           #:flow-meter-error))

(in-package #:ultrasonic-flowmeter)

;;; Records
;;;
;;; `defstruct' gives typed slots, a constructor, and readers in one form.  The
;;; readers are named for the concept rather than the struct (`path-angle', not
;;; `acoustic-path-angle') via :conc-name.

(defstruct (acoustic-path (:conc-name path-) (:copier nil))
  "A single ultrasonic beam crossing the pipe."
  (position 0d0 :type double-float :read-only t)  ; Normalized to -1..1.
  (angle 0d0 :type double-float :read-only t)     ; Radians from the pipe axis.
  (length 0d0 :type double-float :read-only t)    ; Meters: the chord D / sin(angle).
  (weight 0d0 :type double-float :read-only t))   ; Gauss-Jacobi coefficient.

(defstruct (path-measurement (:conc-name measurement-) (:copier nil))
  "Upstream and downstream transit times for one path, in seconds."
  (t-upstream 0d0 :type double-float :read-only t)
  (t-downstream 0d0 :type double-float :read-only t)
  (delta-t 0d0 :type double-float :read-only t))

(defstruct (flow-meter-config (:conc-name config-) (:copier nil))
  "A pipe bundled with the acoustic paths crossing it."
  (pipe-diameter 0d0 :type double-float :read-only t)
  (paths nil :type list :read-only t))

(defstruct (flow-result (:conc-name result-) (:copier nil))
  "One solved measurement cycle."
  (path-velocities nil :type list :read-only t)   ; m/s, one per path.
  (volumetric-flow 0d0 :type double-float :read-only t))  ; m³/s.

(define-condition flow-meter-error (simple-error) ()
  (:documentation "Signalled for a configuration the solver cannot integrate."))

;;; Constructors

(defun acoustic-path (pipe-diameter position angle weight)
  "Build one acoustic path across a pipe of PIPE-DIAMETER meters.

POSITION is normalized to -1..1, ANGLE is in radians from the pipe axis, and
WEIGHT is the Gauss-Jacobi coefficient.  The path length is derived here, so
the chord formula D / sin(theta) appears exactly once."
  (make-acoustic-path :position (float position 0d0)
                      :angle (float angle 0d0)
                      :length (/ (float pipe-diameter 0d0) (sin (float angle 0d0)))
                      :weight (float weight 0d0)))

(defun path-measurement (t-upstream t-downstream)
  "Record transit times T-UPSTREAM and T-DOWNSTREAM, in seconds.

The difference the whole method rests on is computed once, here, and the slots
are read-only, so it can never drift from the times behind it."
  (let ((up (float t-upstream 0d0))
        (down (float t-downstream 0d0)))
    (make-path-measurement :t-upstream up
                           :t-downstream down
                           :delta-t (- up down))))

(defun flow-meter-config (pipe-diameter paths)
  "Bundle PIPE-DIAMETER, in meters, with the list of acoustic PATHS."
  (make-flow-meter-config :pipe-diameter (float pipe-diameter 0d0)
                          :paths (copy-list paths)))

(defun config-num-paths (config)
  "Return how many acoustic paths cross the pipe in CONFIG."
  (length (config-paths config)))

;;; The algorithm

(defun pipe-area (config)
  "Return the cross-sectional area of CONFIG's pipe, pi (D/2)^2, in m²."
  (let ((radius (/ (config-pipe-diameter config) 2d0)))
    (* pi radius radius)))

(defun calculate-path-velocity (path measurement)
  "Return the axial velocity PATH and MEASUREMENT imply, in m/s.

Transit-time differential method:

    v_path = (L / (2 sin(theta))) * (delta_t / (t_up * t_down))

Returns 0d0 for non-physical transit times or a degenerate path angle, matching
the C reference implementation."
  (let ((t-up (measurement-t-upstream measurement))
        (t-down (measurement-t-downstream measurement))
        (sin-theta (sin (path-angle path))))
    (if (or (<= t-up 0d0)
            (<= t-down 0d0)
            ;; A path along the pipe axis carries no flow information.
            (zerop sin-theta))
        0d0
        (* (/ (path-length path) (* 2d0 sin-theta))
           (/ (measurement-delta-t measurement) (* t-up t-down))))))

(defun calculate-flow-rate (config measurements)
  "Integrate MEASUREMENTS over CONFIG into a `flow-result'.

Gauss-Jacobi quadrature: Q = (pi D^2 / 4) * sum(w_i v_i).

Signals `flow-meter-error' if CONFIG has no paths, or if MEASUREMENTS does not
line up one-to-one with them."
  (let ((paths (config-paths config)))
    (when (null paths)
      (error 'flow-meter-error
             :format-control "flow meter configuration has no paths"))
    (unless (= (length measurements) (length paths))
      (error 'flow-meter-error
             :format-control "expected one measurement per acoustic path"))
    (let* ((velocities (mapcar #'calculate-path-velocity paths measurements))
           (weighted-sum (loop for path in paths
                               for velocity in velocities
                               sum (* (path-weight path) velocity) into total
                               finally (return (float total 0d0)))))
      (make-flow-result :path-velocities velocities
                        :volumetric-flow (* (pipe-area config) weighted-sum)))))

;;; Standard configurations

(defun create-2path-config (pipe-diameter)
  "Two 45° paths at ±0.25 D: quick, cost-effective measurement."
  (let ((angle (/ pi 4d0)))
    (flow-meter-config pipe-diameter
                       (list (acoustic-path pipe-diameter 0.25d0 angle 0.5d0)
                             (acoustic-path pipe-diameter -0.25d0 angle 0.5d0)))))

(defun create-4path-config (pipe-diameter)
  "Two 60° paths near the wall plus two 45° paths near the center.

Sampling the velocity profile at four heights integrates it more accurately
than a single pair of paths."
  (let ((outer-angle (/ pi 3d0))
        (inner-angle (/ pi 4d0)))
    (flow-meter-config pipe-diameter
                       (list (acoustic-path pipe-diameter 0.35d0 outer-angle 0.25d0)
                             (acoustic-path pipe-diameter -0.35d0 outer-angle 0.25d0)
                             (acoustic-path pipe-diameter 0.15d0 inner-angle 0.25d0)
                             (acoustic-path pipe-diameter -0.15d0 inner-angle 0.25d0)))))

;;; Unit conversions

(defun cubic-meters-to-liters-per-second (m3-per-s)
  "Convert M3-PER-S, in m³/s, to liters per second."
  (* m3-per-s 1000d0))

(defun cubic-meters-to-liters-per-minute (m3-per-s)
  "Convert M3-PER-S, in m³/s, to liters per minute."
  (* m3-per-s 60000d0))
