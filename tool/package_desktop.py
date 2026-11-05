#!/usr/bin/env python3
"""Package an existing Release build using only Python and OS tools."""

import argparse
import gzip
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zipfile
import zlib


ROOT = Path(__file__).resolve().parents[1]
MACH_O_MAGIC = {
    b"\xce\xfa\xed\xfe", b"\xcf\xfa\xed\xfe",
    b"\xfe\xed\xfa\xce", b"\xfe\xed\xfa\xcf",
    b"\xca\xfe\xba\xbe", b"\xbe\xba\xfe\xca",
    b"\xca\xfe\xba\xbf", b"\xbf\xba\xfe\xca",
}


def run(*args):
    return subprocess.check_output([str(arg) for arg in args], text=True).strip()


def add_readme(stage, platform, version, architecture, minimum_macos=""):
    text = (ROOT / "packaging" / platform / "README.txt").read_text(encoding="utf-8")
    for key, value in {
        "version": version, "architecture": architecture, "minimum_macos": minimum_macos,
    }.items():
        text = text.replace("{{" + key + "}}", value)
    (stage / "README.txt").write_text(text, encoding="utf-8")


def add_notices(stage, assets):
    notices = assets / "NOTICES.Z"
    data = notices.read_bytes()
    try:
        text = gzip.decompress(data)
    except gzip.BadGzipFile:
        text = zlib.decompress(data)
    (stage / "THIRD-PARTY-NOTICES.txt").write_bytes(text)


def package_macos(stage, version, build_number):
    app = ROOT / "build/macos/Build/Products/Release/Keyboard Saver.app"
    with (app / "Contents/Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    if (info["CFBundleShortVersionString"], info["CFBundleVersion"]) != (version, build_number):
        raise RuntimeError("Release build is stale. Run flutter build macos --release first.")

    # Every executable and framework must support an advertised architecture.
    architectures = None
    for path in app.rglob("*"):
        if path.is_symlink() or not path.is_file():
            continue
        with path.open("rb") as handle:
            magic = handle.read(4)
        if magic in MACH_O_MAGIC:
            found = set(run("/usr/bin/lipo", "-archs", path).split())
            architectures = found if architectures is None else architectures & found
    if architectures == {"arm64", "x86_64"}:
        architecture = "universal"
    elif architectures == {"arm64"}:
        architecture = "arm64"
    elif architectures == {"x86_64"}:
        architecture = "x64"
    else:
        raise RuntimeError(f"Unsupported or inconsistent Mach-O architectures: {architectures}")

    staged_app = stage / app.name
    subprocess.run(["/usr/bin/ditto", str(app), str(staged_app)], check=True)
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(staged_app)], check=True)
    add_readme(stage, "macos", version, architecture, info["LSMinimumSystemVersion"])
    add_notices(stage, staged_app / "Contents/Frameworks/App.framework/Resources/flutter_assets")
    return architecture


def pe_machine(path):
    with path.open("rb") as handle:
        if handle.read(2) != b"MZ":
            raise RuntimeError(f"Not a Windows executable: {path}")
        handle.seek(0x3C)
        offset = struct.unpack("<I", handle.read(4))[0]
        handle.seek(offset)
        if handle.read(4) != b"PE\0\0":
            raise RuntimeError(f"Invalid PE header: {path}")
        return struct.unpack("<H", handle.read(2))[0]


def package_windows(stage, version):
    bundle = ROOT / "build/windows/x64/runner/Release"
    required = ["keyboard_saver.exe", "flutter_windows.dll", "keyboard_guard_plugin.dll", "data/app.so", "data/icudtl.dat"]
    for relative in required:
        if not (bundle / relative).is_file():
            raise RuntimeError(f"Missing {bundle / relative}. Run flutter build windows --release first.")
    shutil.copytree(bundle, stage, dirs_exist_ok=True)
    for symbols in stage.rglob("*.pdb"):
        symbols.unlink()

    vswhere = Path(os.environ["ProgramFiles(x86)"]) / "Microsoft Visual Studio/Installer/vswhere.exe"
    installation = Path(run(vswhere, "-latest", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64", "-property", "installationPath"))
    candidates = list((installation / "VC/Redist/MSVC").glob("*/x64/Microsoft.VC*.CRT"))
    if not candidates:
        raise RuntimeError("Visual C++ x64 redistributable DLLs were not found in Visual Studio.")
    runtime = max(candidates, key=lambda path: tuple(int(part) for part in path.parts[-3].split(".")))
    for dll in runtime.glob("*.dll"):
        shutil.copy2(dll, stage / dll.name)
    for name in ["vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll"]:
        if not (stage / name).is_file():
            raise RuntimeError(f"Missing Visual C++ runtime: {name}")
    for binary in [*stage.glob("*.exe"), *stage.glob("*.dll")]:
        if pe_machine(binary) != 0x8664:
            raise RuntimeError(f"Expected an x64 binary: {binary}")

    add_readme(stage, "windows", version, "x64")
    add_notices(stage, stage / "data/flutter_assets")
    with (stage / "THIRD-PARTY-NOTICES.txt").open("a", encoding="utf-8") as handle:
        handle.write("\n\nMicrosoft Visual C++ Runtime\nCopyright (c) Microsoft Corporation.\n"
                     "https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files\n")
    return "x64"


def verify_archive(archive, platform, temporary):
    with zipfile.ZipFile(archive) as zipped:
        corrupt = zipped.testzip()
        if corrupt:
            raise RuntimeError(f"ZIP integrity check failed: {corrupt}")
    extracted = temporary / "extracted"
    if platform == "macos":
        subprocess.run(["/usr/bin/ditto", "-x", "-k", str(archive), str(extracted)], check=True)
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(extracted / "Keyboard Saver.app")], check=True)
    else:
        with zipfile.ZipFile(archive) as zipped:
            zipped.extractall(extracted)
        # Verify that the distributed app starts with its bundled DLLs. The app
        # starts idle, so this does not install a keyboard hook or block input.
        with (temporary / "launch.log").open("w+b") as log:
            process = subprocess.Popen([str(extracted / "keyboard_saver.exe")], cwd=extracted, stdout=log, stderr=log)
            try:
                try:
                    code = process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    pass
                else:
                    log.seek(0)
                    raise RuntimeError(f"Packaged app exited on startup ({code}): {log.read().decode(errors='replace')}")
            finally:
                if process.poll() is None:
                    process.terminate()
                    process.wait(timeout=10)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    if sys.platform not in ("darwin", "win32"):
        parser.error("Run on macOS or Windows after building that platform's Release app.")
    match = re.search(r"^version:\s*([0-9A-Za-z.-]+)\+(\d+)\s*$", (ROOT / "pubspec.yaml").read_text(), re.MULTILINE)
    if not match:
        raise RuntimeError("Expected version: major.minor.patch+build in pubspec.yaml.")
    version, build_number = match.groups()
    platform = "macos" if sys.platform == "darwin" else "windows"
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix="keyboard-saver-package-") as directory:
        temporary = Path(directory)
        stage = temporary / "package"
        stage.mkdir()
        if platform == "macos":
            architecture = package_macos(stage, version, build_number)
        else:
            architecture = package_windows(stage, version)
        filename = f"keyboard-saver-{version}-{platform}-{architecture}.zip"
        archive = temporary / filename
        if platform == "macos":
            subprocess.run(["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", str(stage), str(archive)], check=True)
        else:
            shutil.make_archive(str(archive.with_suffix("")), "zip", stage)
        verify_archive(archive, platform, temporary)
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        shutil.copy2(archive, output / filename)
        (output / (filename + ".sha256")).write_text(f"{digest}  {filename}\n", encoding="utf-8")
    print(f"Created: {output / filename}")
    print(f"SHA-256: {digest}")


if __name__ == "__main__":
    main()
