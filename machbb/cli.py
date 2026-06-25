"""
machbb CLI — entry point for all commands.
"""

import os
import sys
from pathlib import Path

import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from . import __version__

console = Console()
err_console = Console(stderr=True)


# ── Helpers ────────────────────────────────────────────────────────────

def find_project_root() -> Path:
    """Walk up from cwd to find the project root (where .git or mozconfig is)."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists() or (parent / "mozconfig").exists():
            return parent
        # Check for Firefox source markers
        if (parent / "moz.build").exists() or (parent / "client.py").exists():
            return parent
    return cwd


def run_mozbuild(cmd: list, **kwargs):
    """Run a mozbuild/python command with clean output."""
    import subprocess
    console.print(f"[dim]⏵ {' '.join(cmd)}[/dim]")
    result = subprocess.run(cmd, **kwargs)
    return result


# ── CLI ────────────────────────────────────────────────────────────────

@click.group()
@click.version_option(version=__version__, prog_name="machbb")
def cli():
    """machbb — mach, but better."""


# ── bootstrap ──────────────────────────────────────────────────────────

@cli.command()
@click.option("--apply-to", default=None, help="Apply patches to a source directory")
def bootstrap(apply_to):
    """Install build dependencies and prepare the environment."""
    project_root = find_project_root()
    console.print(Panel("[bold]Bootstrapping build environment[/]"))

    # Detect what we're building
    if (project_root / "moz.build").exists() or (project_root / "old-configure.in").exists():
        console.print("   [green]✓[/] Firefox/IceCat source detected")
        console.print("   [cyan]…[/] Running mozbuild bootstrap...")
        run_mozbuild(
            [sys.executable, str(project_root / "python" / "mach"), "bootstrap"],
            cwd=project_root
        )
    else:
        console.print("   [yellow]![/] No Firefox source detected in", project_root)
        console.print("   Run [bold]machbb init[/] first, or run from a source directory.")

    if apply_to:
        console.print(f"   [cyan]…[/] Applying patches to {apply_to}...")
        patches_dir = project_root / "patches"
        if patches_dir.exists():
            for patch in sorted(patches_dir.glob("*.patch")):
                console.print(f"      → {patch.name}")
                run_mozbuild(["git", "am", str(patch)], cwd=apply_to)
        else:
            console.print("   [yellow]![/] No patches/ directory found")


# ── configure ──────────────────────────────────────────────────────────

@cli.command()
@click.option("-f", "--file", "mozconfig_path", default=None, help="Path to mozconfig")
@click.option("--release", is_flag=True, help="Release build configuration")
@click.option("--debug", is_flag=True, help="Debug build configuration")
def configure(mozconfig_path, release, debug):
    """Configure the build (equivalent to ./mach configure)."""
    project_root = find_project_root()
    console.print(Panel("[bold]Configuring build[/]"))

    # Handle mozconfig
    if mozconfig_path:
        mozconfig = Path(mozconfig_path)
        if not mozconfig.exists():
            err_console.print(f"[red]✗[/] mozconfig not found: {mozconfig}")
            sys.exit(1)
    else:
        # Look for mozconfig in project root
        mozconfig = project_root / "mozconfig"
        if not mozconfig.exists():
            mozconfig = project_root / "mozconfig.acreedom"
        if not mozconfig.exists():
            err_console.print("[red]✗[/] No mozconfig found. Create one or use --file")
            sys.exit(1)

    console.print(f"   Using mozconfig: [bold]{mozconfig}[/]")
    os.environ["MOZCONFIG"] = str(mozconfig)

    result = run_mozbuild(
        [sys.executable, str(project_root / "python" / "mach"), "configure"],
        cwd=project_root
    )
    if result.returncode == 0:
        console.print("   [green]✓[/] Configured successfully")
    else:
        err_console.print(f"[red]✗[/] Configure failed (exit {result.returncode})")
        sys.exit(result.returncode)


# ── build ──────────────────────────────────────────────────────────────

@cli.command()
@click.argument("targets", nargs=-1)
@click.option("-j", "--jobs", default=None, type=int, help="Number of parallel jobs")
@click.option("--clean", is_flag=True, help="Clean build")
@click.option("--mozconfig", default=None, help="Path to mozconfig")
def build(targets, jobs, clean, mozconfig):
    """Build the project (equivalent to ./mach build)."""
    project_root = find_project_root()
    console.print(Panel("[bold]Building[/]"))

    if clean:
        console.print("   [cyan]…[/] Cleaning...")
        run_mozbuild(
            [sys.executable, str(project_root / "python" / "mach"), "clobber"],
            cwd=project_root
        )

    if mozconfig:
        os.environ["MOZCONFIG"] = str(Path(mozconfig).resolve())

    cmd = [sys.executable, str(project_root / "python" / "mach"), "build"]
    if jobs:
        cmd.extend(["-j", str(jobs)])
    cmd.extend(targets)

    result = run_mozbuild(cmd, cwd=project_root)
    if result.returncode == 0:
        console.print("   [green]✓[/] Build succeeded")
    else:
        err_console.print(f"[red]✗[/] Build failed (exit {result.returncode})")
        sys.exit(result.returncode)


# ── package ────────────────────────────────────────────────────────────

@cli.command()
@click.option("--format", "-f", "pkg_format", default="tar.bz2", help="Package format")
def package(pkg_format):
    """Package the build output."""
    project_root = find_project_root()
    console.print(Panel(f"[bold]Packaging as {pkg_format}[/]"))

    result = run_mozbuild(
        [sys.executable, str(project_root / "python" / "mach"), "package"],
        cwd=project_root
    )
    if result.returncode == 0:
        console.print("   [green]✓[/] Package created")
    else:
        err_console.print(f"[red]✗[/] Packaging failed (exit {result.returncode})")
        sys.exit(result.returncode)


# ── run ────────────────────────────────────────────────────────────────

@cli.command()
@click.argument("app_args", nargs=-1)
def run(app_args):
    """Run the built browser."""
    project_root = find_project_root()
    console.print(Panel("[bold]Running[/]"))

    cmd = [sys.executable, str(project_root / "python" / "mach"), "run"]
    cmd.extend(app_args)
    run_mozbuild(cmd, cwd=project_root)


# ── clean ──────────────────────────────────────────────────────────────

@cli.command()
@click.option("--all", "all_", is_flag=True, help="Clean everything including dependencies")
def clean(all_):
    """Clean build artifacts."""
    project_root = find_project_root()
    console.print(Panel("[bold]Cleaning[/]"))

    if all_:
        console.print("   [cyan]…[/] Full clean...")
        run_mozbuild(
            [sys.executable, str(project_root / "python" / "mach"), "clobber"],
            cwd=project_root
        )
    else:
        console.print("   [cyan]…[/] Cleaning build artifacts...")
        import shutil
        obj_dir = project_root / "obj-*"
        for d in project_root.glob("obj-*"):
            if d.is_dir():
                console.print(f"     Removing {d.name}")
                shutil.rmtree(d)

    console.print("   [green]✓[/] Clean complete")


# ── status ─────────────────────────────────────────────────────────────

@cli.command()
def status():
    """Show build status and environment info."""
    project_root = find_project_root()
    table = Table(title="machbb Status")
    table.add_column("Key", style="cyan")
    table.add_column("Value")

    table.add_row("Version", __version__)
    table.add_row("Project Root", str(project_root))
    table.add_row("Python", sys.version.split()[0])

    # Check for Firefox source
    has_moz = (project_root / "moz.build").exists()
    table.add_row("Firefox Source", "[green]Yes[/]" if has_moz else "[red]No[/]")

    # Check mozconfig
    mozconfig = project_root / "mozconfig"
    if not mozconfig.exists():
        mozconfig = project_root / "mozconfig.acreedom"
    table.add_row("mozconfig", str(mozconfig) if mozconfig.exists() else "[red]Not found[/]")

    # Check patches
    patches = list(project_root.glob("patches/*.patch"))
    table.add_row("Patches", str(len(patches)))

    console.print(table)


# ── init ───────────────────────────────────────────────────────────────

@cli.command()
@click.argument("source_dir", default=".")
@click.option("--name", default="acreedom", help="Project name")
def init(source_dir, name):
    """Initialize a new machbb project in the given source directory."""
    target = Path(source_dir).resolve()
    console.print(Panel(f"[bold]Initializing {name} project[/]"))
    console.print(f"   Target: {target}")

    if not target.exists():
        console.print(f"   [red]✗[/] Source directory doesn't exist: {target}")
        sys.exit(1)

    # Create default mozconfig if none exists
    mozconfig = target / "mozconfig"
    if not mozconfig.exists():
        console.print("   [cyan]…[/] Creating default mozconfig...")
        with open(mozconfig, "w") as f:
            f.write(f"""
# machbb — {name} build configuration
# Auto-generated by machbb init

# Build options
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/obj-{name}
ac_add_options --enable-application=browser

# Optimizations
ac_add_options --enable-optimize
ac_add_options --enable-release

# Security
ac_add_options --enable-hardening
ac_add_options --enable-fuzzing

# Privacy (Acreedom defaults)
ac_add_options --disable-telemetry
ac_add_options --disable-crashreporter
ac_add_options --disable-updater
""".strip())
        console.print(f"   [green]✓[/] Created mozconfig")

    # Create patches directory
    patches_dir = target / "patches"
    if not patches_dir.exists():
        patches_dir.mkdir()
        (patches_dir / ".gitkeep").touch()
        console.print("   [green]✓[/] Created patches/")

    console.print("   [green]✓[/] Project initialized")


if __name__ == "__main__":
    cli()
