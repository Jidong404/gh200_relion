#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Config
# -----------------------------
ENV_NAME="relion-5.0"
TORCH_DIR="/opt/TORCH"   

# Pinned commits for reproducibility
RELION_CLASSRANKER_COMMIT="352adf8b690ba56e9f4073cfee41c8fcad3dfb81"
RELION_BLUSH_COMMIT="87c01af09da8351adae3aa43ab99657585e3af7f"
TOPAZ_COMMIT="87e516337705f08c274ad98b6506b05d4d889553"

# -----------------------------
# Activate conda environment
# -----------------------------
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
else
    echo "ERROR: 'conda' command not found. Make sure conda is installed and on PATH."
    exit 1
fi

conda activate "${ENV_NAME}"

# -----------------------------
# Install PyTorch ARM
# -----------------------------
python -m pip install \
  "torch==2.6.0" \
  "torchvision==0.21.0" \
  "torchaudio==2.6.0" \
  --index-url https://download.pytorch.org/whl/cu126 \
  --extra-index-url https://pypi.org/simple \
  --no-cache-dir --force-reinstall \
  --no-deps

# -----------------------------
# Prepare TORCH under /opt
# -----------------------------
mkdir -p "${TORCH_DIR}"
export TORCH="${TORCH_DIR}"    
cd "${TORCH_DIR}"

# -----------------------------
# Helper: ensure repo exists and is pinned
# -----------------------------
ensure_repo() {
    local name="$1"
    local url="$2"
    local commit="$3"

    if [ ! -d "${TORCH_DIR}/${name}/.git" ]; then
        echo "Cloning ${name} from ${url} ..."
        git clone "${url}" "${TORCH_DIR}/${name}"
    else
        echo "Repo ${name} already exists, using existing clone."
    fi

    cd "${TORCH_DIR}/${name}"
    git fetch --all --tags --prune
    git checkout --force "${commit}"
}

# -----------------------------
# Clone + pin repositories
# -----------------------------
ensure_repo "relion-classranker" "https://github.com/3dem/relion-classranker" "${RELION_CLASSRANKER_COMMIT}"
ensure_repo "relion-blush"       "https://github.com/3dem/relion-blush"       "${RELION_BLUSH_COMMIT}"
ensure_repo "topaz"              "https://github.com/3dem/topaz"              "${TOPAZ_COMMIT}"

# -----------------------------
# Install relion-classranker
# -----------------------------
cd "${TORCH_DIR}/relion-classranker"
[ -f requirements.txt ] && pip install -r requirements.txt
pip install .

# -----------------------------
# Install relion-blush
# -----------------------------
cd "${TORCH_DIR}/relion-blush"
[ -f requirements.txt ] && pip install -r requirements.txt
pip install .

# -----------------------------
# Install topaz
# -----------------------------
cd "${TORCH_DIR}/topaz"
[ -f requirements.txt ] && pip install -r requirements.txt
pip install .

echo "Post-setup complete: PyTorch + relion-classranker@${RELION_CLASSRANKER_COMMIT} + relion-blush@${RELION_BLUSH_COMMIT} + topaz@${TOPAZ_COMMIT} installed in env '${ENV_NAME}' with TORCH='${TORCH}'."

