# update-resolve

Automated DaVinci Resolve updater for Arch Linux.

**Script version:** 2026.09.0 | **Tested with DaVinci Resolve:** 21.1-1

Checks for new versions via Blackmagic's API, downloads the installer, fetches the latest PKGBUILD from the AUR, updates version numbers and checksums, and builds/installs the package — all in one command.

Watch the How-To Video! Click on the Thumbnail! 

[![Watch the video](https://img.youtube.com/vi/Tm3iNIgTRXw/maxresdefault.jpg)](https://www.youtube.com/watch?v=Tm3iNIgTRXw)


## What it automates

1. Queries Blackmagic's API for the latest stable Linux version
2. Compares against your currently installed version
3. Installs all runtime dependencies (official repos + AUR)
4. Downloads the ~3GB zip, submitting the web registration form for you with your saved info
5. Fetches the latest `davinci-resolve` PKGBUILD from the AUR
6. Patches `pkgver` if the AUR is behind the latest release
7. Applies a defensive patch to the AUR `prepare()` step when it hardcodes a stale bundled library version (see Troubleshooting)
8. Regenerates SHA256 checksums
9. Builds and installs via `makepkg -sric` (stays tracked in pacman/yay)
10. Checks that Resolve's runtime support directories exist, and prints fix instructions if not

## Dependencies

- `curl`
- `jq`
- `git`
- `makepkg` / `pacman` (included with Arch)
- `yay` or `paru` (AUR helper — needed for AUR-only runtime deps)
- `updpkgsums` (optional, from `pacman-contrib` — falls back to manual hash update)

If you don't have an AUR helper installed, the script will tell you how to install `yay`.
If a dependency install fails, the script will exit, and manual intervention to get that dependency package installed will be required. Re-run the script after you have the problematic dependency installed.

## Runtime dependencies

The script automatically installs these before building. Packages in official repos are installed via `pacman`; AUR-only packages are installed via your AUR helper. When a package has multiple providers, the first option is selected automatically.

| Package | Source |
|---------|--------|
| `glu` | official |
| `gtk2` | official |
| `libpng12` | AUR |
| `fuse2` | official |
| `opencl-driver` | official (multiple providers) |
| `qt5-x11extras` | official |
| `qt5-svg` | official |
| `qt5-webengine` | AUR |
| `qt5-websockets` | official |
| `qt5-quickcontrols2` | official |
| `qt5-multimedia` | official |
| `libxcrypt-compat` | AUR |
| `xmlsec` | official |
| `java-runtime` | official (multiple providers) |
| `ffmpeg4.4` | AUR |
| `gst-plugins-bad-libs` | official |
| `python-numpy` | official |
| `tbb` | official |
| `apr-util` | official |
| `luajit` | official |
| `libc++` | AUR |
| `libc++abi` | AUR |

## Installation

```bash
# Clone the repo
git clone https://github.com/drake495/Davinci-Resolve-Updater.git
cd Davinci-Resolve-Updater

# Make executable
chmod +x update-resolve.sh

# Optional: symlink to PATH
ln -s "$(pwd)/update-resolve.sh" ~/.local/bin/update-resolve
```

## Usage

```bash
# Standard update (checks version, downloads, builds, installs)
./update-resolve.sh

# Just check if an update is available
./update-resolve.sh --check-only

# Force reinstall even if already on latest
./update-resolve.sh --force

# Download and build but don't install
./update-resolve.sh --skip-install

# Re-enter your registration info
./update-resolve.sh --reconfigure
```

On first run, you'll be prompted for registration info (name, email, etc.). This is the same info Blackmagic requires on their download page. It's saved locally in a `.config` file next to the script and reused on subsequent runs.

## DaVinci Resolve Studio

To use this for the Studio edition, change the `PRODUCT` variable near the top of the script:

```bash
PRODUCT="davinci-resolve-studio"
```

## How it works

Blackmagic requires a registration POST to their API before providing a download URL. This script automates that handshake using the same API endpoints their website uses. The registration data you provide is sent directly to Blackmagic — it's not stored or sent anywhere else.

## Troubleshooting

### Build aborts in `prepare()` with `rm: cannot remove ...libglib-2.0.so.0.6800.4`

The AUR PKGBUILD strips Resolve's bundled glib before symlinking to your system copies, but it names those files with a hardcoded version suffix. Blackmagic changes the bundled glib version between Resolve releases (2.68 in 20.x, 2.82 in 21.1), so the literal filename goes stale and the build aborts.

The script now detects and patches this automatically. The patch matches the exact broken text, so it stops applying as soon as the AUR maintainer fixes the line upstream.

### Resolve installs but won't launch: `Failed to create application support directories`

Resolve creates support directories under `/opt/resolve` on first launch, but that path is owned by root, so anything it still needs to create fails and the app exits before it can even write a log. Resolve 21.1 added `Immersive/`, which the AUR package does not create.

```bash
sudo mkdir -p /opt/resolve/Immersive
sudo chown "$USER:$USER" /opt/resolve/Immersive
```

The script warns about known cases after install. Because Blackmagic adds to this set across releases, a future version may need a directory not on that list. Find it with:

```bash
strace -f -e trace=mkdir,mkdirat davinci-resolve 2>&1 | grep -E 'EACCES|EPERM'
```

### Install fails with `exists in filesystem`

pacman refuses to overwrite files it doesn't own, which happens if Resolve was ever installed outside pacman (for example via Blackmagic's own `.run` installer). Confirm the files are unowned, then let pacman take them over:

```bash
pacman -Qo /opt/resolve/libs/<file>          # "No package owns" = safe to overwrite
sudo pacman -U --overwrite '/opt/resolve/libs/<pattern>' <built-package>.pkg.tar.zst
```

## License

MIT
