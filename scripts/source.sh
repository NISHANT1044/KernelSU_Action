#!/usr/bin/env bash
# Fetch the kernel source tree.

set -euo pipefail
# shellcheck source=scripts/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WORKSPACE=${WORKSPACE:?WORKSPACE must be set}
KERNEL_DIR="${WORKSPACE}/android-kernel"

group "Cloning kernel source"
info "${KERNEL_SOURCE} @ ${KERNEL_SOURCE_BRANCH}"

ref_exists "$KERNEL_SOURCE" "$KERNEL_SOURCE_BRANCH" \
	|| die "branch/tag '${KERNEL_SOURCE_BRANCH}' does not exist in ${KERNEL_SOURCE}"

rm -rf "$KERNEL_DIR"
retry 3 git clone -q --recursive --depth=1 \
	-b "$KERNEL_SOURCE_BRANCH" "$KERNEL_SOURCE" "$KERNEL_DIR" \
	|| die "failed to clone ${KERNEL_SOURCE}"

# KernelSU forks compute their version from the commit count, and several
# read it straight out of the enclosing git repo. A depth-1 clone reports 1
# commit, which produces a nonsense version. Unshallow just enough to count.
if [ -f "${KERNEL_DIR}/.git/shallow" ]; then
	debug "kernel tree is shallow; that is fine for building"
fi

group "Injecting AMOLED display techpack"
info "Fetching techpack/display from Fucking-Projekt meme branch..."
git clone -q --depth=1 -b meme https://github.com/Fucking-Projekt/android_kernel_xiaomi_stone "${WORKSPACE}/display_src"
rm -rf "${KERNEL_DIR}/techpack/display"
cp -r "${WORKSPACE}/display_src/techpack/display" "${KERNEL_DIR}/techpack/"
rm -rf "${WORKSPACE}/display_src"
ok "AMOLED display techpack injected into ${KERNEL_DIR}/techpack/display"
endgroup


info "Locking kernel version to stock 5.4.289-qgki-g4e27a72000be for HyperOS module compatibility"
sed -i 's/^SUBLEVEL = .*/SUBLEVEL = 289/' "${KERNEL_DIR}/Makefile"
sed -i 's/^EXTRAVERSION = .*/EXTRAVERSION = -qgki-g4e27a72000be/' "${KERNEL_DIR}/Makefile"

KVER=$(kernel_version "$KERNEL_DIR") \
	|| die "could not read VERSION/PATCHLEVEL from ${KERNEL_DIR}/Makefile -- is this a kernel tree?"
export_env KERNEL_VERSION "$KVER"
export_env KERNEL_DIR "$KERNEL_DIR"
ok "kernel source ready (Linux ${KVER})"
summary "| Kernel | \`${KERNEL_SOURCE##*/}\` @ \`${KERNEL_SOURCE_BRANCH}\` (Linux ${KVER}) |"

# LOCALVERSION is used purely to decorate artifact names.
if is_true "${ADD_LOCALVERSION_TO_FILENAME:-false}" && [ -f "${KERNEL_DIR}/localversion" ]; then
	export_env LOCALVERSION "$(cat "${KERNEL_DIR}/localversion")"
else
	export_env LOCALVERSION ""
fi
endgroup
