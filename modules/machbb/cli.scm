(define-module (machbb cli)
  #:export (machbb-main))

(use-modules (ice-9 getopt-long) (ice-9 format)
             (machbb build) (machbb config) (machbb util)
             (machbb bootstrap))

(define (show-help)
  (format #t "Usage: machbb COMMAND [ARGS...]

mach, but better.  A modern build tool for Firefox/IceCat/Acreedom.

Commands:
  init DIR        Initialize a project with mozconfig and patches/
  bootstrap       Install build dependencies
  configure       Configure the build
  build [TARGET]  Build the project
  package         Package the build output
  run [ARGS]      Run the built browser
  clean           Clean build artifacts
  status          Show build status and environment
  help            Show this help
  version         Show version
"))

(define (show-version)
  (format #t "machbb 0.1.0~%"))

(define (dispatch cmd args)
  (cond
   ((string=? cmd "init")       (apply init args))
   ((string=? cmd "bootstrap")  (bootstrap-run))
   ((string=? cmd "configure")  (apply configure-build args))
   ((string=? cmd "build")      (apply build args))
   ((string=? cmd "package")    (package))
   ((string=? cmd "run")        (apply run args))
   ((string=? cmd "clean")      (apply clean-build args))
   ((string=? cmd "status")     (status))
   ((string=? cmd "help")       (show-help))
   ((string=? cmd "version")    (show-version))
   (else
    (format (current-error-port) "machbb: unknown command ~s~%" cmd)
    (show-help)
    (exit 1))))

(define (machbb-main args)
  (if (< (length args) 2)
      (begin (show-help) (exit 0)))
  (let ((cmd (list-ref args 1))
        (cmd-args (drop args 2)))
    (dispatch cmd cmd-args)))
