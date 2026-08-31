;;;; ultrasonic-flowmeter.asd --- ASDF system definitions for the ultrasonic flow meter.
;;;;
;;;; Two systems, matching the split every implementation in this repository
;;;; follows:
;;;;
;;;;   ultrasonic-flowmeter        the pure algorithm, safe to load anywhere
;;;;   ultrasonic-flowmeter/main   the demonstration program
;;;;
;;;; ASDF is not required to run the demo -- `sbcl --script src/main.lisp'
;;;; loads core.lisp itself -- but it is the idiomatic way to pull the core
;;;; into a larger Lisp image.

(defsystem "ultrasonic-flowmeter"
  :description "Transit-time differential ultrasonic multipath flow meter"
  :license "MIT"
  :version "0.1.0"
  :pathname "src/"
  :serial t
  :components ((:file "core")))

(defsystem "ultrasonic-flowmeter/main"
  :description "Demonstration program for the ultrasonic multipath flow meter"
  :license "MIT"
  :version "0.1.0"
  :depends-on ("ultrasonic-flowmeter")
  :pathname "src/"
  :serial t
  :components ((:file "main"))
  ;; main.lisp ends in a call to `main', so loading this system prints the
  ;; demonstration once. `ultrasonic-flowmeter/main:main' remains callable.
  :build-operation program-op
  :build-pathname "flowmeter"
  :entry-point "ultrasonic-flowmeter/main:main")
