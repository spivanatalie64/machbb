(define-module (machbb bootstrap)
  #:export (bootstrap-run))

(use-modules (ice-9 format) (machbb util) (machbb config))

(define (bootstrap-run)
  (let ((root (project-root)))
    (unless root
      (fail "Not in a source tree. Run machbb init first.")
      (exit 1))

    (ok "Bootstrapping build environment...")

    (cond
     ;; IceCat / Firefox source
     ((file-exists? (string-append root "/moz.build"))
      (let ((mach (string-append root "/python/mach")))
        (if (file-exists? mach)
            (begin
              (ok "Running mach bootstrap...")
              (run (string-append mach " bootstrap")))
            (fail "mach not found — is this a valid Firefox/IceCat source?"))))

     ;; Unknown source
     (else
      (fail "Unknown source tree type")))
    (ok "Bootstrap complete")))
