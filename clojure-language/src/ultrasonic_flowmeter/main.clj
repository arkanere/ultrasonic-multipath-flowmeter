(ns ultrasonic-flowmeter.main
  (:require [ultrasonic-flowmeter.core :as core]
            [clojure.math :as math]))

;;; Simulation and Output Functions

(defn simulate-measurements
  "Generate simulated measurement data for a flow meter configuration

   For learning purposes, creates synthetic upstream/downstream transit
   times based on a true flow velocity.

   Args:
     config: flow meter configuration
     true-flow-velocity: simulated true flow velocity (m/s)

   Returns: vector of path measurements"
  [{:keys [paths]} true-flow-velocity]
  (let [sound-speed 1480.0]  ; Sound speed in water (m/s)
    (mapv (fn [{:keys [length angle]}]
            (let [;; Acoustic path component along flow direction: L * sin(θ)
                  path-component (* length (math/sin angle))

                  ;; Calculate time with and against flow
                  v-acoustic-up (- sound-speed true-flow-velocity)
                  v-acoustic-down (+ sound-speed true-flow-velocity)

                  ;; Calculate transit times
                  t-upstream (/ path-component v-acoustic-up)
                  t-downstream (/ path-component v-acoustic-down)]

              (core/path-measurement t-upstream t-downstream)))
          paths)))

(defn degrees-to-radians
  "Convert degrees to radians (for display purposes)"
  [degrees]
  (* degrees math/PI 180.0))

(defn radians-to-degrees
  "Convert radians to degrees (for display purposes)"
  [radians]
  (* radians 180.0 (/ 1.0 math/PI)))

(defn print-config
  "Print flow meter configuration details"
  [{:keys [pipe-diameter paths]}]
  (println "Flow Meter Configuration:")
  (println (format "  Pipe diameter: %.3f m" pipe-diameter))
  (println (format "  Number of paths: %d" (count paths)))

  (let [radius (/ pipe-diameter 2.0)
        area (* math/PI radius radius)]
    (println (format "  Pipe area: %.6f m²" area)))

  (println "\nAcoustic Paths:")
  (doseq [[idx {:keys [position angle length weight]}] (map-indexed vector paths)]
    (println (format "  Path %d:" (inc idx)))
    (println (format "    Position: %.2f D" position))
    (println (format "    Angle: %.2f° (%.4f rad)" (radians-to-degrees angle) angle))
    (println (format "    Path length: %.4f m" length))
    (println (format "    Weight: %.3f" weight))))

(defn print-measurements
  "Print simulated measurement data"
  [measurements true-velocity]
  (println (format "\nSimulated Measurements (True flow velocity: %.2f m/s):" true-velocity))
  (doseq [[idx {:keys [t-upstream t-downstream]}] (map-indexed vector measurements)]
    (let [delta-t (- t-upstream t-downstream)]
      (println (format "  Path %d: t_upstream = %.8f s, t_downstream = %.8f s, Δt = %.2e s"
                       (inc idx) t-upstream t-downstream delta-t)))))

(defn print-results
  "Print flow calculation results"
  [{:keys [path-velocities volumetric-flow]} num-paths]
  (println "\nFlow Calculation Results:")
  (doseq [[idx velocity] (map-indexed vector path-velocities)]
    (println (format "  Path %d velocity: %.4f m/s" (inc idx) velocity)))

  (println "\nVolumetric Flow Rate:")
  (println (format "  %.6f m³/s" volumetric-flow))
  (println (format "  %.4f L/min" (core/cubic-meters-to-liters-per-minute volumetric-flow)))
  (println (format "  %.2f L/s" (core/cubic-meters-to-liters-per-second volumetric-flow))))

;;; Main Program

(defn demo-2path
  "Run 2-path configuration demonstration"
  [pipe-diameter true-velocity]
  (println "### 2-PATH CONFIGURATION ###\n")

  (let [config (core/create-2path-config pipe-diameter)
        measurements (simulate-measurements config true-velocity)
        result (core/calculate-flow-rate config measurements)]

    (print-config config)
    (print-measurements measurements true-velocity)
    (print-results result (count (:paths config)))))

(defn demo-4path
  "Run 4-path configuration demonstration"
  [pipe-diameter true-velocity]
  (println "\n\n### 4-PATH CONFIGURATION ###\n")

  (let [config (core/create-4path-config pipe-diameter)
        measurements (simulate-measurements config true-velocity)
        result (core/calculate-flow-rate config measurements)]

    (print-config config)
    (print-measurements measurements true-velocity)
    (print-results result (count (:paths config)))))

(defn -main
  "Main entry point for the demo program"
  [& _args]
  (println "=== Ultrasonic Multipath Flow Meter ===\n")

  ;; Pipe parameters
  (let [pipe-diameter 0.1       ; 100 mm
        true-flow-velocity 2.0] ; 2 m/s

    ;; Run demonstrations
    (demo-2path pipe-diameter true-flow-velocity)
    (demo-4path pipe-diameter true-flow-velocity))

  (println "\n=== End of Demonstration ==="))

;; Allow running from REPL
(comment
  ;; Example usage from REPL:
  (let [config (core/create-2path-config 0.1)
        measurements (simulate-measurements config 2.0)
        result (core/calculate-flow-rate config measurements)]
    result))
