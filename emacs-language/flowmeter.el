;;; flowmeter.el --- Transit-time ultrasonic flow meter core  -*- lexical-binding: t; -*-

;; Copyright (C) 2026  Ultrasonic Multipath Flow Meter contributors

;; Author: Ultrasonic Multipath Flow Meter contributors
;; Keywords: hardware, tools
;; Package-Requires: ((emacs "25.1"))

;;; Commentary:

;; Core algorithm for a transit-time differential ultrasonic flow meter.
;;
;; An ultrasonic signal sent across a pipe travels faster with the flow than
;; against it.  Comparing the two transit times reveals the flow velocity
;; without needing to know the speed of sound in the fluid.
;;
;; Nothing in this file prints, reads a buffer, or touches the minibuffer: it
;; is pure arithmetic over `cl-defstruct' records, so it can be loaded into a
;; running Emacs and poked at from `ielm' as readily as it can be driven by
;; the batch program in main.el.

;;; Code:

(require 'cl-lib)

(cl-defstruct (flowmeter-path (:constructor flowmeter-path--create)
                              (:copier nil))
  "A single ultrasonic beam crossing the pipe."
  (position 0.0 :read-only t :documentation "Position on the pipe diameter, normalized to -1..1.")
  (angle 0.0 :read-only t :documentation "Angle from the pipe axis, in radians.")
  (length 0.0 :read-only t :documentation "Acoustic path length in meters: the chord D / sin(angle).")
  (weight 0.0 :read-only t :documentation "Gauss-Jacobi weighting coefficient."))

(cl-defstruct (flowmeter-measurement (:constructor flowmeter-measurement--create)
                                     (:copier nil))
  "Upstream and downstream transit times for one path, in seconds."
  (t-upstream 0.0 :read-only t)
  (t-downstream 0.0 :read-only t)
  (delta-t 0.0 :read-only t :documentation "t-upstream minus t-downstream."))

(cl-defstruct (flowmeter-config (:constructor flowmeter-config--create)
                                (:copier nil))
  "A pipe bundled with the acoustic paths crossing it."
  (pipe-diameter 0.0 :read-only t :documentation "Pipe diameter, in meters.")
  (paths nil :read-only t :documentation "List of `flowmeter-path' records."))

(cl-defstruct (flowmeter-result (:constructor flowmeter-result--create)
                                (:copier nil))
  "One solved measurement cycle."
  (path-velocities nil :read-only t :documentation "Recovered axial velocity per path, in m/s.")
  (volumetric-flow 0.0 :read-only t :documentation "Integrated flow rate, in m³/s."))

(defun flowmeter-make-path (pipe-diameter position angle weight)
  "Build one acoustic path across a pipe of PIPE-DIAMETER meters.
POSITION is normalized to -1..1, ANGLE is in radians from the pipe
axis, and WEIGHT is the Gauss-Jacobi coefficient.  The path length is
derived here, so the chord formula D / sin(theta) appears exactly once."
  (flowmeter-path--create :position position
                          :angle angle
                          :length (/ pipe-diameter (sin angle))
                          :weight weight))

(defun flowmeter-make-measurement (t-upstream t-downstream)
  "Record transit times T-UPSTREAM and T-DOWNSTREAM, in seconds.
The difference the whole method rests on is computed once here rather
than on every read, so it can never drift from the times behind it."
  (flowmeter-measurement--create :t-upstream t-upstream
                                 :t-downstream t-downstream
                                 :delta-t (- t-upstream t-downstream)))

(defun flowmeter-make-config (pipe-diameter paths)
  "Bundle PIPE-DIAMETER, in meters, with the list of acoustic PATHS."
  (flowmeter-config--create :pipe-diameter pipe-diameter
                            :paths (copy-sequence paths)))

(defun flowmeter-num-paths (config)
  "Return how many acoustic paths cross the pipe in CONFIG."
  (length (flowmeter-config-paths config)))

(defun flowmeter-pipe-area (config)
  "Return the cross-sectional area of CONFIG's pipe, pi (D/2)^2, in m²."
  (let ((radius (/ (flowmeter-config-pipe-diameter config) 2.0)))
    (* float-pi radius radius)))

(defun flowmeter-path-velocity (path measurement)
  "Return the axial velocity PATH and MEASUREMENT imply, in m/s.

Transit-time differential method:

    v_path = (L / (2 sin(theta))) * (delta_t / (t_up * t_down))

Returns 0.0 for non-physical transit times or a degenerate path angle,
matching the C reference implementation."
  (let ((t-up (flowmeter-measurement-t-upstream measurement))
        (t-down (flowmeter-measurement-t-downstream measurement))
        (sin-theta (sin (flowmeter-path-angle path))))
    (if (or (<= t-up 0) (<= t-down 0)
            ;; A path along the pipe axis carries no flow information.
            (= sin-theta 0))
        0.0
      (* (/ (flowmeter-path-length path) (* 2.0 sin-theta))
         (/ (flowmeter-measurement-delta-t measurement) (* t-up t-down))))))

(defun flowmeter-flow-rate (config measurements)
  "Integrate MEASUREMENTS over CONFIG into a `flowmeter-result'.

Gauss-Jacobi quadrature: Q = (pi D^2 / 4) * sum(w_i v_i).

Signals an error if CONFIG has no paths or if MEASUREMENTS does not line
up one-to-one with them."
  (let ((paths (flowmeter-config-paths config)))
    (unless paths
      (error "Flow meter configuration has no paths"))
    (unless (= (length measurements) (length paths))
      (error "Expected one measurement per acoustic path"))
    (let* ((velocities (cl-mapcar #'flowmeter-path-velocity paths measurements))
           (weighted-sum (cl-loop for path in paths
                                  for velocity in velocities
                                  sum (* (flowmeter-path-weight path) velocity))))
      (flowmeter-result--create
       :path-velocities velocities
       :volumetric-flow (* (flowmeter-pipe-area config) weighted-sum)))))

(defun flowmeter-2-path-config (pipe-diameter)
  "Two 45° paths at ±0.25 D across a PIPE-DIAMETER pipe.
The quick, cost-effective configuration."
  (let ((angle (/ float-pi 4.0)))
    (flowmeter-make-config
     pipe-diameter
     (list (flowmeter-make-path pipe-diameter 0.25 angle 0.5)
           (flowmeter-make-path pipe-diameter -0.25 angle 0.5)))))

(defun flowmeter-4-path-config (pipe-diameter)
  "Four paths across a PIPE-DIAMETER pipe: 60° near the wall, 45° near the center.
Sampling the velocity profile at four heights integrates it more
accurately than a single pair of paths."
  (let ((outer-angle (/ float-pi 3.0))
        (inner-angle (/ float-pi 4.0)))
    (flowmeter-make-config
     pipe-diameter
     (list (flowmeter-make-path pipe-diameter 0.35 outer-angle 0.25)
           (flowmeter-make-path pipe-diameter -0.35 outer-angle 0.25)
           (flowmeter-make-path pipe-diameter 0.15 inner-angle 0.25)
           (flowmeter-make-path pipe-diameter -0.15 inner-angle 0.25)))))

(defun flowmeter-cubic-meters-to-liters-per-second (m3-per-s)
  "Convert M3-PER-S, in m³/s, to liters per second."
  (* m3-per-s 1000.0))

(defun flowmeter-cubic-meters-to-liters-per-minute (m3-per-s)
  "Convert M3-PER-S, in m³/s, to liters per minute."
  (* m3-per-s 60000.0))

(provide 'flowmeter)

;;; flowmeter.el ends here
