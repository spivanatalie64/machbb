(define-module (machbb bootstrap)
  #:export (bootstrap-run bootstrap-list bootstrap-status))

(use-modules (ice-9 format) (ice-9 popen) (ice-9 textual-ports)
             (machbb util) (machbb config))

(define (bootstrap/apt)
  (let ((packages '("rustc" "cargo" "libgtk-3-dev" "libgdk-pixbuf2.0-dev"
                     "libpango1.0-dev" "libcairo2-dev" "libdbus-1-dev"
                     "libsqlite3-dev" "cmake" "ninja-build" "llvm-dev"
                     "libclang-dev" "clang" "libasound2-dev" "libpulse-dev"
                     "libx11-dev" "libxext-dev" "libxdamage-dev" "libxfixes-dev"
                     "libxcomposite-dev" "libncurses-dev" "python3" "python3-pip"
                     "yasm" "nasm" "autoconf2.13" "libffi-dev"
                     "nodejs" "npm" "libavcodec-dev" "libavformat-dev")))
    (info "Installing build dependencies (apt)...")
    (let ((ret (run (format #f "sudo apt-get install -y ~a" (string-join packages " "))
                    #:silent #t)))
      (unless (zero? ret)
        (fail "apt install failed")
        (exit 1)))))

(define (bootstrap/pacman)
  (let ((packages '("rust" "cargo" "gtk3" "gdk-pixbuf2" "pango" "cairo"
                     "dbus" "sqlite" "cmake" "ninja" "llvm" "clang"
                     "alsa-lib" "libpulse" "libx11" "libxext" "libxdamage"
                     "libxfixes" "libxcomposite" "ncurses" "python" "python-pip"
                     "yasm" "nasm" "autoconf2.13" "libffi"
                     "nodejs" "npm" "ffmpeg" "base-devel")))
    (info "Installing build dependencies (pacman)...")
    (let ((ret (run (format #f "sudo pacman -S --needed --noconfirm ~a" (string-join packages " "))
                    #:silent #t)))
      (unless (zero? ret)
        (fail "pacman install failed")
        (exit 1)))))

(define (bootstrap/dnf)
  (let ((packages '("rust" "cargo" "gtk3-devel" "gdk-pixbuf2-devel"
                     "pango-devel" "cairo-devel" "dbus-devel" "sqlite-devel"
                     "cmake" "ninja-build" "llvm-devel" "clang"
                     "alsa-lib-devel" "pulseaudio-libs-devel"
                     "libX11-devel" "libXext-devel" "libXdamage-devel"
                     "libXfixes-devel" "libXcomposite-devel" "ncurses-devel"
                     "python3" "python3-pip" "yasm" "nasm" "autoconf2.13"
                     "libffi-devel" "nodejs" "npm" "ffmpeg-devel")))
    (info "Installing build dependencies (dnf)...")
    (let ((ret (run (format #f "sudo dnf install -y ~a" (string-join packages " "))
                    #:silent #t)))
      (unless (zero? ret)
        (fail "dnf install failed")
        (exit 1)))))

(define (detect-pm)
  (cond
   ((which "apt-get") 'apt)
   ((which "pacman") 'pacman)
   ((which "dnf") 'dnf)
   (else #f)))

(define (bootstrap-run)
  (let ((root (project-root)))
    (unless root
      (fail "Not in a source tree. Run machbb init first.")
      (exit 1))
    (ok "Bootstrapping build environment...")
    (format #t "       platform:   ~a~%" (platform-arch))
    (format #t "       cores:      ~a~%" (cpu-count))
    (let ((pyver (run-line "python3 --version 2>&1")))
      (if pyver
          (ok (format #f "Python: ~a" pyver))
          (fail "Python 3 not found!")))
    (let ((pm (detect-pm)))
      (if pm
          (case pm
            ((apt) (bootstrap/apt))
            ((pacman) (bootstrap/pacman))
            ((dnf) (bootstrap/dnf)))
          (begin
            (warn "Could not detect package manager")
            (warn "Please install build dependencies manually"))))
    (unless (which "rustc")
      (info "Installing Rust via rustup...")
      (run "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y" #:silent #t)
      (ok "Rust installed"))
    (let ((mach (string-append root "/python/mach")))
      (when (file-exists? mach)
        (ok "Running mach bootstrap...")
        (run (string-append mach " bootstrap"))))
    (info "Installing Python dependencies...")
    (run "python3 -m pip install --user --upgrade pip setuptools wheel" #:silent #t)
    (ok "Bootstrap complete!")
    (info (format #f "Run 'machbb configure' to configure the build"))))

(define (bootstrap-list)
  (format #t "Available bootstrap packages:~%")
  (format #t "  System: rustc, cargo, gtk3, dbus, sqlite, cmake, ninja, llvm, clang~%")
  (format #t "  Python: pip, setuptools, wheel~%")
  (format #t "  Rust:   rustup, cargo~%"))

(define (bootstrap-status)
  (let ((checks `(("python3"  . ,(if (which "python3") (green "✓") (red "✗")))
                  ("rustc"    . ,(if (which "rustc") (green "✓") (red "✗")))
                  ("cargo"    . ,(if (which "cargo") (green "✓") (red "✗")))
                  ("clang"    . ,(if (which "clang") (green "✓") (red "✗")))
                  ("ninja"    . ,(if (which "ninja") (green "✓") (red "✗")))
                  ("cmake"    . ,(if (which "cmake") (green "✓") (red "✗")))
                  ("pkg-config" . ,(if (which "pkg-config") (green "✓") (red "✗")))
                  ("git"      . ,(if (which "git") (green "✓") (red "✗"))))))
    (format #t "  ~%")
    (format #t "  Build environment status:~%")
    (for-each (lambda (c)
                (format #t "    ~a  ~a~%" (cdr c) (car c)))
              checks)
    (format #t "  ~%")))
