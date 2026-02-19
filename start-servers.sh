#!/bin/bash
# Startet die llama.cpp Server (Dual-GPU: RTX 5070 Ti x2)
# Unified Vision/Chat auf Port 8081, BGE-M3 Embedding auf Port 8083

MODELS_DIR="${MODELS_DIR:-$HOME/models}"
LOG_DIR="${LOG_DIR:-$HOME/logs}"

# Modell-Dateinamen
VISION_MODEL="Qwen_Qwen2.5-VL-32B-Instruct-Q4_K_M.gguf"
VISION_MMPROJ="Qwen2.5-VL-32B-Instruct-mmproj-f16.gguf"
EMBED_MODEL="bge-m3-Q8_0.gguf"

mkdir -p "$LOG_DIR"

check_model() {
    if [ ! -f "$1" ]; then
        echo "FEHLER: Modell nicht gefunden: $1"
        echo ""
        echo "Bitte zuerst ./download-models.sh ausführen!"
        exit 1
    fi
}

start_vision() {
    check_model "$MODELS_DIR/$VISION_MODEL"
    check_model "$MODELS_DIR/$VISION_MMPROJ"

    echo "Starte Qwen2.5-VL 32B (Chat + Vision unified) auf Port 8081..."
    echo "  GPU:      Dual RTX 5070 Ti (tensor-split 1,1)"
    echo "  VRAM:     ~20 GB verteilt auf beide Karten"
    echo "  Kontext:  16384 Tokens"

    nohup llama-server \
        --model         "$MODELS_DIR/$VISION_MODEL" \
        --mmproj        "$MODELS_DIR/$VISION_MMPROJ" \
        --host          0.0.0.0 \
        --port          8081 \
        --ctx-size      16384 \
        --n-gpu-layers  99 \
        --tensor-split  1,1 \
        --flash-attn on \
        --parallel      4 \
        > "$LOG_DIR/vision.log" 2>&1 &

    echo "PID: $! | Log: $LOG_DIR/vision.log"
}

start_embedding() {
    check_model "$MODELS_DIR/$EMBED_MODEL"

    echo "Starte BGE-M3 Embedding (multilingual/DE) auf Port 8083..."
    echo "  GPU:      GPU 0 (Modell ist klein, kein tensor-split nötig)"
    echo "  VRAM:     ~1.2 GB"
    echo "  Kontext:  8192 Tokens"

    # BGE-M3 läuft nur auf GPU 0 – GPU 1 bleibt vollständig für das 32B-Modell frei
    CUDA_VISIBLE_DEVICES=0 nohup llama-server \
        --model         "$MODELS_DIR/$EMBED_MODEL" \
        --host          0.0.0.0 \
        --port          8083 \
        --ctx-size      8192 \
        --n-gpu-layers  99 \
        --embedding \
        > "$LOG_DIR/embedding.log" 2>&1 &

    echo "PID: $! | Log: $LOG_DIR/embedding.log"
}

case "$1" in
    vision)
        start_vision
        ;;
    embedding)
        start_embedding
        ;;
    all)
        echo "================================================"
        echo " llama.cpp Dual-GPU Setup (2x RTX 5070 Ti)"
        echo "================================================"
        echo ""
        start_vision
        echo ""
        sleep 5
        start_embedding
        echo ""
        echo "================================================"
        echo " Alle Server gestartet."
        echo ""
        echo " Endpoints (direkt):"
        echo "   Chat/Vision:  http://localhost:8081/v1"
        echo "   Embedding:    http://localhost:8083/v1"
        echo ""
        echo " Endpoints (via Kong Gateway):"
        echo "   Chat/Vision:  http://localhost:8000/chat/v1"
        echo "   Embedding:    http://localhost:8000/embed/v1"
        echo "   Ollama:       http://localhost:8000/ollama"
        echo ""
        echo " Logs verfolgen: tail -f $LOG_DIR/*.log"
        echo "================================================"
        ;;
    stop)
        echo "Stoppe alle llama-server Prozesse..."
        pkill -f llama-server || true
        echo "Gestoppt."
        ;;
    status)
        echo "=== llama-server Prozesse ==="
        pgrep -af llama-server || echo "Keine Server laufen."
        echo ""
        echo "=== GPU Status ==="
        nvidia-smi --query-gpu=index,name,memory.used,memory.free,utilization.gpu \
            --format=csv,noheader,nounits 2>/dev/null \
            | awk -F',' '{printf "  GPU %s: %s | VRAM: %s MB used, %s MB free | Auslastung: %s%%\n", $1, $2, $3, $4, $5}' \
            || echo "nvidia-smi nicht verfügbar."
        ;;
    logs)
        tail -f "$LOG_DIR"/*.log
        ;;
    *)
        echo "Verwendung: $0 {vision|embedding|all|stop|status|logs}"
        echo ""
        echo "  vision    - Qwen2.5-VL 32B Instruct (Chat + Vision, Port 8081)"
        echo "  embedding - BGE-M3 multilingual      (Embedding,   Port 8083)"
        echo "  all       - Beide Server starten"
        echo "  stop      - Alle Server stoppen"
        echo "  status    - Laufende Server + GPU-Auslastung anzeigen"
        echo "  logs      - Logs verfolgen"
        exit 1
        ;;
esac