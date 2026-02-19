#!/bin/bash
# Modelle herunterladen mit hf CLI
set -e

MODELS_DIR="${MODELS_DIR:-$HOME/models}"
mkdir -p "$MODELS_DIR"
cd "$MODELS_DIR"

echo "=== Modelle werden nach $MODELS_DIR heruntergeladen ==="
echo ""
echo "Hinweis: Qwen2.5-VL-32B benötigt ~20 GB Speicherplatz."
echo ""

# 1. Qwen2.5-VL 32B Vision (unified Chat + Vision)
# Quelle: bartowski (Repo-Name enthält Underscore!)
echo "[1/3] Qwen2.5-VL 32B Instruct Q4_K_M (~20 GB) ..."
hf download bartowski/Qwen_Qwen2.5-VL-32B-Instruct-GGUF \
    Qwen_Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf \
    --local-dir .

# 2. Vision Projector für 32B VL-Modell
# Quelle: Mungert (einzige zuverlässige Quelle für 32B mmproj)
echo "[2/3] Vision Projector 32B (~1.5 GB) ..."
hf download Mungert/Qwen2.5-VL-32B-Instruct-GGUF \
    Qwen2.5-VL-32B-Instruct-mmproj-f16.gguf \
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