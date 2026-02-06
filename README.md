# update-resolve

Automated DaVinci Resolve updater for Arch Linux.

Checks for new versions via Blackmagic's API, downloads the installer, fetches the latest PKGBUILD from the AUR, updates version numbers and checksums, and builds/installs the package — all in one command.

## What it automates

1. Queries Blackmagic's API for the latest stable Linux version
2. Compares against your currently installed version
3. Downloads the ~3GB zip (bypassing the manual web registration form)
4. Fetches the latest `davinci-resolve` PKGBUILD from the AUR
5. Patches `pkgver` if the AUR is behind the latest release
6. Regenerates SHA256 checksums
7. Builds and installs via `makepkg -sric` (stays tracked in pacman/yay)

## Dependencies

- `curl`
- `jq`
- `git`
- `makepkg` / `pacman` (included with Arch)
- `updpkgsums` (optional, from `pacman-contrib` — falls back to manual hash update)

## Installation

```bash
# Clone the repo
git clone https://github.com/YOUR_USERNAME/update-resolve.git
cd update-resolve

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

## License

MIT
