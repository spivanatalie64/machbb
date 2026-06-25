(define-module (machbb util)
  #:export (run run/status run-line run-collected
           ok fail warn info dim bold cyan yellow red green white
           project-root source-dir? platform-arch
           cpu-count format-duration
           check-dependencies which
           spinner make-spinner
           read-env-file write-env-file))

(use-modules (ice-9 popen) (ice-9 rdelim) (ice-9 regex)
             (srfi srfi-1) (srfi srfi-8) (ice-9 format)
             (ice-9 textual-ports) (ice-9 string-fun))

;; ── System info ─────────────────────────────────────────────────────

(define (cpu-count)
  (or (and=> (getenv "NPROC") string->number)
      (and=> (run-line "nproc 2>/dev/null") (lambda (s) (string->number (string-trim-both s))))
      4))

(define (platform-arch)
  (string-trim-both (run-line "uname -m 2>/dev/null")))

(define (format-duration secs)
  (let* ((h (quotient secs 3600))
         (m (quotient (remainder secs 3600) 60))
         (s (remainder secs 60)))
    (cond
     ((> h 0) (format #f "~ah ~am ~as" h m s))
     ((> m 0) (format #f "~am ~as" m s))
     (else (format #f "~as" s)))))

;; ── Shell quoting ──────────────────────────────────────────────────

(define (shell-quote s)
  (string-append "'" (string-join (string-split s #\') "'\\''") "'"))

;; ── Command execution ───────────────────────────────────────────────

(define* (run cmd #:key (dir #f) (env '()) (silent #f))
  (let* ((dir-env (if dir (string-append "cd " (shell-quote dir) " && ") ""))
         (env-vars (if (pair? env)
                       (string-join (map (lambda (e) (format #f "~a=~a" (car e) (cdr e))) env) " ")
                       ""))
         (full-cmd (string-append dir-env env-vars " " cmd)))
    (unless silent
      (format #t " ~a ~a~%" (dim "⏵") full-cmd))
    (let ((start (current-time))
          (ret (system full-cmd)))
      (unless silent
        (let ((elapsed (- (current-time) start)))
          (if (zero? ret)
              (ok (format #f "Completed in ~a" (format-duration elapsed)))
              (fail (format #f "Failed with exit code ~a (~a)" ret (format-duration elapsed))))))
      ret)))

(define* (run/status cmd #:key (dir #f) (env '()) (spinner #f))
  (let* ((dir-env (if dir (string-append "cd " (shell-quote dir) " && ") ""))
         (env-vars (if (pair? env)
                       (string-join (map (lambda (e) (format #f "~a=~a" (car e) (cdr e))) env) " ")
                       ""))
         (full-cmd (string-append dir-env env-vars " " cmd " 2>&1")))
    (if spinner
        (spinner (format #f "Running ~a" cmd)))
    (let* ((port (open-input-pipe full-cmd))
           (output (read-string port))
           (ret (close-pipe port)))
      (if spinner (spinner #f))
      (unless (zero? ret)
        (display output)
        (fail (format #f "Command failed: ~a" cmd)))
      (values ret output))))

(define* (run-line cmd #:key (trim #t) (dir #f))
  (let* ((dir-prefix (if dir (string-append "cd " (shell-quote dir) " && ") ""))
         (port (open-input-pipe (string-append dir-prefix cmd)))
         (line (read-line port)))
    (close-pipe port)
    (if trim (string-trim-both line) line)))

(define* (run-collected cmd #:key (dir #f))
  (let* ((dir-prefix (if dir (string-append "cd " (shell-quote dir) " && ") ""))
         (port (open-input-pipe (string-append dir-prefix cmd " 2>&1")))
         (lines (string-split (read-string port) #\newline)))
    (close-pipe port)
    lines))

;; ── Dependency checking ─────────────────────────────────────────────

(define (which prog)
  (string-trim-both (run-line (format #f "command -v ~a 2>/dev/null || which ~a 2>/dev/null" prog prog))))

(define* (check-dependencies deps #:key (package-hints '()))
  (let ((missing '()))
    (for-each
     (lambda (dep)
       (unless (which dep)
         (set! missing (cons dep missing))))
     deps)
    (if (null? missing)
        #t
        (begin
          (fail "Missing dependencies:")
          (for-each (lambda (d)
                      (let ((hint (assoc-ref package-hints d)))
                        (format #t "       ~a~@[ — install: ~a~]~%" d (or hint "packages"))))
                    (reverse missing))
          #f))))

;; ── Environment file handling ────────────────────────────────────────

(define* (read-env-file #:optional (path "machbb.env"))
  (catch #t
    (lambda ()
      (call-with-input-file path
        (lambda (port)
          (let loop ((lines (get-string-all port)) (result '()))
            (if (eof-object? lines)
                (reverse result)
                (let ((parsed (string-split lines #\newline)))
                  (fold (lambda (line acc)
                          (let ((trimmed (string-trim-both line)))
                            (if (or (string-null? trimmed)
                                    (string-prefix? "#" trimmed)
                                    (not (string-index trimmed #\=)))
                                acc
                                (let* ((eq (string-index trimmed #\=))
                                       (key (string-trim-both (substring trimmed 0 eq)))
                                       (val (string-trim-both (substring trimmed (+ eq 1)))))
                                  (cons (cons key val) acc)))))
                        result parsed)))))))
    (lambda _ '())))

(define (write-env-file path alist)
  (call-with-output-file path
    (lambda (port)
      (format port "# machbb environment~%")
      (for-each (lambda (pair)
                  (format port "~a=~a~%" (car pair) (cdr pair)))
                alist)))
  (chmod path #o644))

;; ── File/directory helpers ──────────────────────────────────────────

(define (project-root)
  (let loop ((dir (getcwd)))
    (cond
     ((file-exists? (string-append dir "/.git")) dir)
     ((file-exists? (string-append dir "/moz.build")) dir)
     ((file-exists? (string-append dir "/.machbb-root")) dir)
     ((file-exists? (string-append dir "/.gclient")) dir)
     ((string=? dir "/") #f)
     (else (loop (dirname dir))))))

(define (source-dir? dir)
  (or (file-exists? (string-append dir "/moz.build"))
      (file-exists? (string-append dir "/old-configure.in"))
      (file-exists? (string-append dir "/tools/gn/bootstrap/bootstrap.py"))
      (file-exists? (string-append dir "/.gclient"))))

;; ── Spinner ─────────────────────────────────────────────────────────

(define* (make-spinner #:key (frames '("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")))
  (let ((i 0))
    (lambda* (msg #:optional (active #t))
      (if active
          (begin
            (format #t "\r ~a ~a" (cyan (list-ref frames (modulo i (length frames)))) msg)
            (set! i (+ i 1))
            (force-output))
          (begin
            (format #t "\r ✓ ~a~%" (dim msg))
            (force-output))))))

;; ── Terminal colors ─────────────────────────────────────────────────

(define (c code s) (format #f "~c[~am~a~c[0m" #\escape code s #\escape))
(define (dim s) (c "2" s))
(define (bold s) (c "1" s))
(define (cyan s) (c "36" s))
(define (yellow s) (c "33" s))
(define (green s) (c "32" s))
(define (red s) (c "31" s))
(define (white s) (c "37" s))

(define* (status icon msg #:key (newline? #t))
  (if newline?
      (format #t " ~a ~a~%" icon msg)
      (format #t " ~a ~a" icon msg)))

(define (ok msg) (status (green "✓") msg))
(define (fail msg) (status (red "✗") msg))
(define (warn msg) (status (yellow "⚠") msg))
(define (info msg) (status (cyan "ℹ") msg))
