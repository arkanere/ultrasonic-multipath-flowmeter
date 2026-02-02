(defproject ultrasonic-flowmeter "0.1.0-SNAPSHOT"
  :description "Ultrasonic multipath flow meter implementation in Clojure"
  :url "https://github.com/arkanere/ultrasonic-multipath-flowmeter"
  :license {:name "MIT"
            :url "https://opensource.org/licenses/MIT"}
  :dependencies [[org.clojure/clojure "1.11.1"]]
  :main ultrasonic-flowmeter.main
  :profiles {:dev {:dependencies [[org.clojure/clojure "1.11.1"]]}})
