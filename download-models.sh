#!/bin/bash
# Modelle herunterladen mit hf CLI
set -e

MODELS_DIR="${MODELS_DIR:-$HOME/models}"
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

echo "=== Modelle werden nach $MODELS_DIR heruntergeladen ==="
echo ""
echo "Hinweis: Qwen3-VL-32B-Thinking benötigt ~20 GB Speicherplatz."
echo ""

# 1. Qwen3-VL 32B Thinking (Chat + Vision + Reasoning unified)
# Quelle: offizielles Qwen-Repo
echo "[1/3] Qwen3-VL 32B Thinking Q4_K_M (~20 GB) ..."
hf download Qwen/Qwen3-VL-32B-Thinking-GGUF \
    Qwen3VL-32B-Thinking-Q4_K_M.gguf \
    --local-dir .

# 2. Vision Projector (mmproj) für Qwen3-VL 32B Thinking
echo "[2/3] Vision Projector Qwen3-VL 32B (~1.5 GB) ..."
hf download Qwen/Qwen3-VL-32B-Thinking-GGUF \
    mmproj-Qwen3VL-32B-Thinking-F16.gguf \
    --local-dir .

# 3. BGE-M3 Embedding (multilingual, Deutsch-optimiert)
echo "[3/3] BGE-M3 Embedding Q8_0 (~1.2 GB) ..."
hf download gpustack/bge-m3-GGUF \
    bge-m3-Q8_0.gguf \
    --local-dir .

echo ""
echo "=== Download abgeschlossen ==="
echo ""
ls -lh "$MODELS_DIR"/*.gguf