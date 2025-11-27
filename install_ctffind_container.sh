#!/usr/bin/env bash
set -euo pipefail

# ================== CONFIG ==================
VERSION="4.1.14"
URL="https://grigoriefflab.umassmed.edu/sites/default/files/ctffind-${VERSION}.tar.gz"

# Install prefix INSIDE THE CONTAINER
PREFIX="/usr/local"

# Build dir (temporary)
WORKDIR="/tmp/ctffind-build-${VERSION}"
# ============================================

echo "=== CTFFIND ${VERSION} container install ==="
echo "Install prefix: ${PREFIX}"
echo "Build dir:      ${WORKDIR}"
echo

mkdir -p "$WORKDIR"
cd "$WORKDIR"

# 1) Download source
if [[ ! -f "ctffind-${VERSION}.tar.gz" ]]; then
    echo "[1/6] Downloading ctffind-${VERSION}.tar.gz ..."
    wget -O "ctffind-${VERSION}.tar.gz" "$URL"
else
    echo "[1/6] Source archive already present, reusing."
fi

# 2) Extract
if [[ ! -d "ctffind-${VERSION}" ]]; then
    echo "[2/6] Extracting archive ..."
    tar -xzf "ctffind-${VERSION}.tar.gz"
fi

cd "ctffind-${VERSION}"

# 3) Clean any old build
echo "[3/6] Cleaning previous build (if any) ..."
make distclean || true

echo "[4/6] Patching source files ..."

# ---- Patch 1: src/core/matrix.cpp (replace asm SINCOS with sinf/cosf) ----
MATRIX_FILE="src/core/matrix.cpp"
if [[ -f "$MATRIX_FILE" ]]; then
    sed -i 's|#define _AL_SINCOS(x, s, c)  __asm__ ("fsincos" : "=t" (c), "=u" (s) : "0" (x))|#define _AL_SINCOS(x, s, c)  do { (s) = sinf(x); (c) = cosf(x); } while(0)|' "$MATRIX_FILE"
    sed -i 's|#define FLOATSINCOS(x, s, c)  _AL_SINCOS((x) * AL_PI / 128.0, s ,c)|#define FLOATSINCOS(x, s, c)  _AL_SINCOS((x) * AL_PI / 128.0f, s, c)|' "$MATRIX_FILE"
    echo "  Patched $MATRIX_FILE (_AL_SINCOS/FLOATSINCOS)"
else
    echo "  WARNING: $MATRIX_FILE not found; skipping that patch."
fi

# ---- Patch 2: src/programs/ctffind/ctffind.cpp (bool -> void) ----
CTFIND_FILE="src/programs/ctffind/ctffind.cpp"
if [[ -f "$CTFIND_FILE" ]]; then
    sed -i 's/\bbool ComputeRotationalAverageOfPowerSpectrum/void ComputeRotationalAverageOfPowerSpectrum/g' "$CTFIND_FILE"
    sed -i 's/\bbool RescaleSpectrumAndRotationalAverage/void RescaleSpectrumAndRotationalAverage/g' "$CTFIND_FILE"
    echo "  Patched $CTFIND_FILE (bool -> void)"
else
    echo "  WARNING: $CTFIND_FILE not found; skipping that patch."
fi

echo "[5/6] Configuring with prefix=${PREFIX} ..."

./configure \
  --prefix="$PREFIX" \
  CXXFLAGS="-g -O2 -Wno-maybe-uninitialized -Wno-error=maybe-uninitialized" \
  CFLAGS="-g -O2 -Wno-maybe-uninitialized -Wno-error=maybe-uninitialized"

echo "Building (this may take a moment) ..."
make -j"$(nproc || echo 2)"

echo "[6/6] Installing to ${PREFIX} ..."
make install

echo
echo "=== Done ==="
echo "ctffind binary should now be at: ${PREFIX}/bin/ctffind"
echo

# PATH check (usually /usr/local/bin is already on PATH inside container)
if ! command -v ctffind >/dev/null 2>&1; then
    echo "NOTE: ctffind is installed, but not found in PATH."
    echo "You may need to add this inside the container environment:"
    echo "    export PATH=\"${PREFIX}/bin:\$PATH\""
else
    echo "ctffind is on PATH: $(command -v ctffind)"
fi


