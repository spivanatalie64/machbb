(define-module (machbb build)
  #:export (build configure-build package run clean-build status))

(use-modules (ice-9 format) (ice-9 regex)
             (machbb util) (machbb config))

(define* (build #:optional (targets '()))
  (let ((root (or (project-root)
                  (begin (fail "Not in a Firefox/IceCat source tree") (exit 1)))))
    (let ((mach (string-append root "/python/mach")))
      (unless (file-exists? mach)
        (fail "mach not found — not a valid source tree?")
        (exit 1))

      (ok "Building...")
      (let ((cmd (string-append mach " build "
                                (string-join targets " "))))
        (run cmd)))))

(define* (configure-build #:key (mozconfig #f))
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1))))
        (mcfg (mozconfig-env mozconfig)))
    (unless mcfg
      (fail "No mozconfig found")
      (exit 1))
    (ok (format #f "Using mozconfig: ~a" mcfg))
    (run (string-append (string-append root "/python/mach") " configure"))))

(define (package)
  (let ((root (or (project-root) (begin (fail "Not in a source tree") (exit 1)))))
    (ok "Packaging...")
    (run (string-append root "/python/mach package"))))

(define* (run #:optional (args '()))
  (let ((root (or (project-root) (begin (fail "Not in a source tree") (exit 1)))))
    (ok "Launching...")
    (run (string-append root "/python/mach run "
                        (string-join args " ")))))

(define* (clean-build #:key (all #f))
  (let ((root (or (project-root) (begin (fail "Not in a source tree") (exit 1)))))
    (if all
        (begin
          (ok "Full clean...")
          (run (string-append root "/python/mach clobber")))
        (begin
          (ok "Removing build artifacts...")
          (for-each
           (lambda (d)
             (format #t "  removing ~a~%" d)
             (system (string-append "rm -rf " d)))
           (glob (string-append root "/obj-*")))))
    (ok "Clean complete")))

(define (status)
  (let ((root (project-root)))
    (format #t "~%")
    (format #t "  ~a:~t~a~%" "Version" "0.1.0")
    (format #t "  ~a:~t~a~%" "Project Root" (or root (dim "(none)")))
    (format #t "  ~a:~t~a~%" "Python" (or (run-line "python3 --version 2>&1") "?"))
    (when root
      (let ((mcfg (find-mozconfig)))
        (format #t "  ~a:~t~a~%" "mozconfig" (or mcfg (dim "(none)")))
        (format #t "  ~a:~t~a~%" "Has moz.build" (if (file-exists? (string-append root "/moz.build")) (green "Yes") (red "No")))
        (let* ((patches (glob (string-append root "/patches/*.patch")))
               (count (length patches)))
          (format #t "  ~a:~t~a~%" "Patches" count))))
    (newline)))
