(ns ultrasonic-flowmeter.core
  (:require [clojure.math :as math]))

;;; Data Structure Helpers

(defn acoustic-path
  "Create an acoustic path configuration

   Args:
     position: position on pipe diameter (normalized: -1 to 1)
     angle: angle from pipe axis in radians
     length: acoustic path length in meters
     weight: Gauss-Jacobi weighting coefficient

   Returns: map representing the acoustic path"
  [position angle length weight]
  {:position position
   :angle angle
   :length length
   :weight weight})

(defn flow-meter-config
  "Create a flow meter configuration

   Args:
     pipe-diameter: pipe diameter in meters
     paths: collection of acoustic paths

   Returns: map representing the flow meter configuration"
  [pipe-diameter paths]
  {:pipe-diameter pipe-diameter
   :num-paths (count paths)
   :paths paths})

(defn path-measurement
  "Create a measurement from a single acoustic path

   Args:
     t-upstream: upstream transit time in seconds
     t-downstream: downstream transit time in seconds

   Returns: map representing the measurement"
  [t-upstream t-downstream]
  {:t-upstream t-upstream
   :t-downstream t-downstream})

(defn flow-result
  "Create a flow result with velocities and total flow

   Args:
     path-velocities: vector of velocities (one per path)
     volumetric-flow: total volumetric flow rate

   Returns: map representing the result"
  [path-velocities volumetric-flow]
  {:path-velocities path-velocities
   :volumetric-flow volumetric-flow})

;;; Core Algorithm Functions

(defn calculate-path-velocity
  "Calculate velocity from a single acoustic path measurement

   Uses the transit-time differential method:
   v_path = (L / (2 * sin(θ))) * (Δt / (t_up * t_down))

   Args:
     path: acoustic path configuration map
     measurement: path measurement map

   Returns: calculated velocity for this path (m/s)"
  [{:keys [angle length]} {:keys [t-upstream t-downstream]}]
  (let [t-up t-upstream
        t-down t-downstream]
    (cond
      ;; Handle edge cases
      (<= t-up 0) 0.0
      (<= t-down 0) 0.0

      ;; Calculate velocity
      :else
      (let [delta-t (- t-up t-down)
            sin-theta (math/sin angle)]
        (cond
          (zero? sin-theta) 0.0
          :else
          (* (/ length (* 2.0 sin-theta))
             (/ delta-t (* t-up t-down))))))))

(defn calculate-flow-rate
  "Calculate total volumetric flow rate from multiple path measurements

   Uses Gauss-Jacobi quadrature integration with weighted sum:
   Q = (π * D² / 4) * Σ(w_i * v_i)

   Args:
     config: flow meter configuration map
     measurements: collection of path measurements

   Returns: flow result map with path velocities and total flow rate"
  [{:keys [pipe-diameter paths]} measurements]
  (let [;; Calculate velocity for each path
        velocities (mapv calculate-path-velocity paths measurements)

        ;; Calculate weighted velocity sum
        weighted-sum (apply + (mapv (fn [path velocity]
                                       (* (:weight path) velocity))
                                     paths velocities))

        ;; Calculate cross-sectional area: A = π * (D/2)² = π * D² / 4
        radius (/ pipe-diameter 2.0)
        area (* math/PI radius radius)

        ;; Calculate volumetric flow rate
        volumetric-flow (* area weighted-sum)]

    (flow-result velocities volumetric-flow)))

;;; Helper functions for unit conversion

(defn cubic-meters-to-liters-per-second
  "Convert m³/s to L/s"
  [cubic-meters-per-second]
  (* cubic-meters-per-second 1000.0))

(defn cubic-meters-to-liters-per-minute
  "Convert m³/s to L/min"
  [cubic-meters-per-second]
  (* cubic-meters-per-second 60000.0))

;;; Configuration builders

(defn create-2path-config
  "Create a 2-path flow meter configuration with 45-degree angles

   Typical configuration for quick measurement with diagonal paths.

   Args:
     pipe-diameter: pipe diameter in meters

   Returns: flow meter configuration map"
  [pipe-diameter]
  (let [angle (/ math/PI 4.0)  ; 45 degrees
        path-length (/ pipe-diameter (math/sin angle))
        paths [(acoustic-path 0.25 angle path-length 0.5)
               (acoustic-path -0.25 angle path-length 0.5)]]
    (flow-meter-config pipe-diameter paths)))

(defn create-4path-config
  "Create a 4-path flow meter configuration with mixed angles

   Mix of 60-degree and 45-degree paths for improved accuracy.
   - 2 paths at 60° (outer positions) - sample near edges
   - 2 paths at 45° (inner positions) - sample near center

   Args:
     pipe-diameter: pipe diameter in meters

   Returns: flow meter configuration map"
  [pipe-diameter]
  (let [angle-60 (/ math/PI 3.0)   ; 60 degrees
        angle-45 (/ math/PI 4.0)   ; 45 degrees
        path-length-60 (/ pipe-diameter (math/sin angle-60))
        path-length-45 (/ pipe-diameter (math/sin angle-45))
        paths [(acoustic-path 0.35 angle-60 path-length-60 0.25)
               (acoustic-path -0.35 angle-60 path-length-60 0.25)
               (acoustic-path 0.15 angle-45 path-length-45 0.25)
               (acoustic-path -0.15 angle-45 path-length-45 0.25)]]
    (flow-meter-config pipe-diameter paths)))
