(define-module (machbb util)
  #:export (run status ok fail dim bold cyan yellow red green white
           project-root source-dir?))

(use-modules (ice-9 popen) (ice-9 rdelim) (ice-9 regex)
             (srfi srfi-1) (ice-9 format))

(define (run cmd . args)
  (let* ((full-cmd (if (string? cmd)
                       (string-join (cons (string-append "exec " cmd) args) " ")
                       (string-join (map (lambda (x) (if (string? x) x (object->string x)))
                                        (cons cmd args)) " "))))
    (format #t " ~a ~a~%" (dim "⏵") full-cmd)
    (let ((ret (system full-cmd)))
      (unless (zero? ret)
        (format (current-error-port) " ~a exit ~a~%" (red "✗") ret))
      ret)))

(define* (run-line cmd #:key (trim #t))
  (let* ((port (open-input-pipe cmd))
         (line (read-line port)))
    (close-pipe port)
    (if trim (string-trim-both line) line)))

(define (project-root)
  (let loop ((dir (getcwd)))
    (cond
     ((file-exists? (string-append dir "/.git")) dir)
     ((file-exists? (string-append dir "/moz.build")) dir)
     ((file-exists? (string-append dir "/mozconfig")) dir)
     ((string=? dir "/") #f)
     (else (loop (dirname dir))))))

(define (source-dir? dir)
  (or (file-exists? (string-append dir "/moz.build"))
      (file-exists? (string-append dir "/old-configure.in"))))

;; Colored output
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
