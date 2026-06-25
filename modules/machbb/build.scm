(define-module (machbb build)
  #:export (build configure-build package browser-run
           clean-build build-status
           test-build lint-build check-build fetch-source))

(use-modules (ice-9 format) (ice-9 regex)
             (srfi srfi-1) (srfi srfi-8)
             (ice-9 textual-ports) (ice-9 string-fun)
             (machbb util) (machbb config))

(define* (build #:optional (targets '())
                #:key (jobs #f) (mozconfig #f) (quiet #f))
  (let ((root (or (project-root)
                  (begin (fail "Not in a Firefox/IceCat source tree") (exit 1)))))
    (unless (check-deps root) (exit 1))
    (mozconfig-env mozconfig)
    (let* ((mach (string-append root "/python/mach"))
           (jflag (if jobs (format #f "-j~a" jobs) ""))
           (cmd (string-join
                 (filter (lambda (s) (not (string-null? s)))
                         (list mach "build" jflag
                               (string-join targets " ")))
                 " ")))
      (ok "Building...")
      (run cmd #:silent quiet))))

(define* (configure-build #:key (mozconfig #f) (options '()))
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1))))
        (mcfg (mozconfig-env mozconfig)))
    (unless mcfg
      (fail "No mozconfig found -- run machbb init first")
      (exit 1))
    (ok (format #f "Using mozconfig: ~a" mcfg))
    (info (format #f "Using ~a cores" (cpu-count)))
    (let* ((mach (string-append root "/python/mach"))
           (extra (if (pair? options)
                      (string-join
                       (map (lambda (o)
                              (format #f "--enable-~a" o))
                            options)
                       " ")
                      ""))
           (cmd (string-join (list mach "configure" extra) " ")))
      (run cmd))))

(define (package)
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1)))))
    (let ((mach (string-append root "/python/mach")))
      (unless (file-exists? mach)
        (fail "mach not found -- is this a valid Firefox/IceCat source?")
        (exit 1))
      (ok "Packaging...")
      (run (string-append mach " package")))))

(define* (browser-run #:optional (args '()))
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1)))))
    (let ((mach (string-append root "/python/mach")))
      (unless (file-exists? mach)
        (fail "mach not found")
        (exit 1))
      (ok "Launching browser...")
      (run (string-append mach " run "
                          (string-join args " "))))))

(define* (clean-build #:key (all #f) (dry-run #f))
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1)))))
    (if all
        (begin
          (ok "Full clean (clobber)...")
          (if dry-run
              (info "Would run: mach clobber")
              (run (string-append root "/python/mach clobber"))))
        (begin
          (ok "Removing build artifacts...")
          (let ((obj-dirs (glob (string-append root "/obj-*"))))
            (if (null? obj-dirs)
                (info "No build artifacts found")
                (for-each
                 (lambda (d)
                   (if dry-run
                       (info (format #f "Would remove ~a" d))
                       (begin
                         (format #t "       removing ~a~%" d)
                         (system (string-append "rm -rf " d)))))
                 obj-dirs)))))
    (ok "Clean complete")))

(define (build-status)
  (let ((root (project-root)))
    (format #t "~%")
    (format #t "  --- machbb status ---~%")
    (format #t "  Version:      ~a~%" "0.2.0")
    (format #t "  Platform:     ~a~%" (platform-arch))
    (format #t "  Cores:        ~a~%" (cpu-count))
    (format #t "  Project:      ~a~%" (or root (dim "(none)")))
    (format #t "  Python:       ~a~%"
            (or (run-line "python3 --version 2>&1") "?"))
    (format #t "  Guile:        ~a~%"
            (or (run-line "guile --version 2>&1 | head -1") "?"))
    (when root
      (let ((mcfg (find-mozconfig)))
        (format #t "  mozconfig:    ~a~%" (or mcfg (dim "(none)")))
        (format #t "  Has moz.build: ~a~%"
                (if (file-exists? (string-append root "/moz.build"))
                    (green "Yes") (red "No"))))
      (let* ((patches-dir (string-append root "/patches"))
             (patches (if (file-exists? patches-dir)
                          (glob (string-append patches-dir "/*.patch"))
                          '()))
             (count (length patches)))
        (format #t "  Patches:      ~a~%" count)
        (when (> count 0)
          (for-each (lambda (p)
                      (format #t "    - ~a~%" (basename p)))
                    (take patches (min count 5)))
          (when (> count 5)
            (format #t "    ... and ~a more~%" (- count 5)))))
      (let ((obj-dirs (glob (string-append root "/obj-*"))))
        (format #t "  Build dirs:   ~a~%" (length obj-dirs))
        (for-each (lambda (d)
                    (let* ((size (run-line
                                  (format #f "du -sh ~a 2>/dev/null | cut -f1" d)))
                           (s (string-trim-both size)))
                      (format #t "    - ~a (~a)~%" (basename d) s)))
                  obj-dirs))
      (let* ((git-dir (string-append root "/.git"))
             (branch (if (file-exists? git-dir)
                         (string-trim-both
                          (run-line "git rev-parse --abbrev-ref HEAD 2>/dev/null"
                                    #:dir root))
                         "?"))
             (commit (if (file-exists? git-dir)
                         (string-trim-both
                          (run-line "git rev-parse --short HEAD 2>/dev/null"
                                    #:dir root))
                         "?")))
        (format #t "  Git branch:   ~a~%" branch)
        (format #t "  Git commit:   ~a~%" commit))
      (let ((env-file (find-env-file)))
        (format #t "  Env file:     ~a~%"
                (if env-file (green "Yes") (dim "No")))))
    (newline)))

(define* (test-build #:key (suite #f))
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1)))))
    (let ((mach (string-append root "/python/mach")))
      (unless (file-exists? mach)
        (fail "mach not found")
        (exit 1))
      (if suite
          (run (string-append mach " test " suite))
          (begin
            (ok "Running all tests...")
            (run (string-append mach " test")))))))

(define* (lint-build #:key (fix #f))
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1)))))
    (let ((mach (string-append root "/python/mach")))
      (if fix
          (run (string-append mach " lint --fix"))
          (run (string-append mach " lint"))))))

(define (check-build)
  (let ((root (or (project-root)
                  (begin (fail "Not in a source tree") (exit 1)))))
    (let ((mach (string-append root "/python/mach")))
      (unless (file-exists? mach)
        (fail "mach not found")
        (exit 1))
      (check-deps root)
      (ok "Running build check...")
      (run (string-append mach " build --check")))))

(define* (fetch-source #:key (type "firefox") (dest ".") (depth #f))
  (let* ((repos '(("firefox" . "https://github.com/mozilla/gecko-dev.git")
                  ("icecat" . "https://git.savannah.gnu.org/git/gnuzilla.git")
                  ("acreedom" . "https://codeberg.org/sprunglesontheberg/acreedom.git")))
         (url (assoc-ref repos type)))
    (unless url
      (fail (format #f "Unknown source type: ~a (use: ~a)"
                    type (string-join (map car repos) ", ")))
      (exit 1))
    (let* ((target (string-append dest "/" type))
           (depth-flag (if depth (format #f "--depth=~a" depth) "--depth=1")))
      (if (file-exists? target)
          (begin
            (info (format #f "Source directory ~a already exists, updating..." target))
            (run (format #f "git -C ~a pull --ff-only" target)))
          (begin
            (ok (format #f "Fetching ~a source..." type))
            (run (format #f "git clone ~a ~a ~a" depth-flag url target)))))))

(define (check-deps root)
  (let ((required '("python3" "rustc" "cargo" "make" "perl" "clang" "llvm")))
    (let ((missing (filter (lambda (d) (not (which d))) required)))
      (if (null? missing)
          #t
          (begin
            (fail "Missing required system dependencies:")
            (for-each (lambda (d) (format #t "       ~a~%" d)) missing)
            (warn "Install them with your system package manager")
            #f)))))
