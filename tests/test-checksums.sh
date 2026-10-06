#!/bin/bash
# test-checksums.sh — checks that setup_pkgbuild leaves a PKGBUILD whose
# checksums makepkg accepts.
#
# Uses the live AUR PKGBUILD and a fake Resolve zip, then runs
# `makepkg --verifysource`, which only verifies sources: no Resolve download,
# no build, no install, no sudo. Needs network access to the AUR.
#
# Usage: ./tests/test-checksums.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../update-resolve.sh
source "${REPO_DIR}/update-resolve.sh"
set +e  # the cases below check exit codes themselves

failures=0
pass() { echo -e "${GREEN}PASS${NC} $1"; }
fail() { echo -e "${RED}FAIL${NC} $1"; failures=$((failures + 1)); }

new_build_dir() {
    BUILD_DIR="$(mktemp -d)"
}

cleanup_build_dir() {
    find "$BUILD_DIR" -mindepth 1 -delete && rmdir "$BUILD_DIR"
}

aur_version=$(curl -fsSL "https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=${PRODUCT}" \
    | sed -n 's/^pkgver=//p')
if [[ -z "$aur_version" ]]; then
    echo "Could not read pkgver from the AUR PKGBUILD (network?)" >&2
    exit 2
fi

# Case: checksums verify after setup_pkgbuild, for a given Resolve version.
# A version newer than the AUR's exercises the pkgver-rewrite path, which is
# what happens when Blackmagic ships before the AUR package is updated.
check_version() {
    local version="$1" label="$2"
    new_build_dir
    printf 'not really resolve' > "${BUILD_DIR}/DaVinci_Resolve_${version}_Linux.zip"

    if ! setup_pkgbuild "$version" > /dev/null 2>&1; then
        fail "${label}: setup_pkgbuild returned an error"
    else
        local out
        if out=$(cd "$BUILD_DIR" && makepkg --verifysource --nodeps 2>&1); then
            pass "${label}: makepkg --verifysource accepts every checksum"
        else
            fail "${label}: makepkg --verifysource rejected the checksums"
            echo "$out" | grep -E 'FAILED|ERROR' | sed 's/^/      /'
        fi
    fi
    cleanup_build_dir
}

check_version "$aur_version" "AUR version (${aur_version})"
check_version "99.0.0" "newer than AUR (99.0.0)"

# Case: a failing updpkgsums must stop setup_pkgbuild, not report success.
new_build_dir
printf 'not really resolve' > "${BUILD_DIR}/DaVinci_Resolve_${aur_version}_Linux.zip"
shim_dir="$(mktemp -d)"
printf '#!/bin/sh\nexit 1\n' > "${shim_dir}/updpkgsums"
chmod +x "${shim_dir}/updpkgsums"
if PATH="${shim_dir}:${PATH}" setup_pkgbuild "$aur_version" > /dev/null 2>&1; then
    fail "failing updpkgsums: setup_pkgbuild still reported success"
else
    pass "failing updpkgsums: setup_pkgbuild stops with an error"
fi
rm -- "${shim_dir}/updpkgsums" && rmdir "$shim_dir"
cleanup_build_dir

echo ""
if [[ $failures -eq 0 ]]; then
    echo -e "${GREEN}All checksum tests passed.${NC}"
else
    echo -e "${RED}${failures} checksum test(s) failed.${NC}"
    exit 1
fi
