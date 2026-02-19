#!/bin/bash
# Startet die llama.cpp Server (Dual-GPU: RTX 5070 Ti x2)
# Qwen3-VL 32B Thinking (Chat + Vision + Reasoning) auf Port 8081
# BGE-M3 Embedding auf Port 8083

MODELS_DIR="${MODELS_DIR:-$HOME/models}"
LOG_DIR="${LOG_DIR:-$HOME/logs}"

# Modell-Dateinamen
VISION_MODEL="Qwen3VL-32B-Thinking-Q4_K_M.gguf"
VISION_MMPROJ="mmproj-Qwen3VL-32B-Thinking-F16.gguf"
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

    echo "Starte Qwen3-VL 32B Thinking (Chat + Vision + Reasoning) auf Port 8081..."
    echo "  GPU:      Dual RTX 5070 Ti (tensor-split 1,1)"
    echo "  VRAM:     ~20 GB verteilt auf beide Karten"
    echo "  Kontext:  32768 Tokens"
    echo "  Thinking: aktiviert (onPartialThinking wird befüllt)"

    nohup llama-server \
        --model         "$MODELS_DIR/$VISION_MODEL" \
        --mmproj        "$MODELS_DIR/$VISION_MMPROJ" \
        --host          0.0.0.0 \
        --port          8081 \
        --ctx-size      32768 \
        --n-gpu-layers  99 \
        --tensor-split  1,1 \
        --flash-attn    on \
        --parallel      4 \
        --jinja \
        --reasoning-format deepseek \
        --temp          1.0 \
        --top-k         20 \
        --top-p         0.95 \
        --presence-penalty 1.5 \
        > "$LOG_DIR/vision.log" 2>&1 &

    echo "PID: $! | Log: $LOG_DIR/vision.log"
}

start_embedding() {
    check_model "$MODELS_DIR/$EMBED_MODEL"

    echo "Starte BGE-M3 Embedding (multilingual/DE) auf Port 8083..."
    echo "  GPU:      GPU 0 (klein, kein tensor-split nötig)"
    echo "  VRAM:     ~1.2 GB"
    echo "  Kontext:  8192 Tokens"

    # BGE-M3 läuft nur auf GPU 0 – GPU 1 bleibt für das 32B-Modell frei
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
        echo " Modell: Qwen3-VL 32B Thinking"
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
        echo "   Chat/Vision/Thinking:  http://localhost:8081/v1"
        echo "   Embedding:             http://localhost:8083/v1"
        echo ""
        echo " Endpoints (via Kong Gateway):"
        echo "   Chat/Vision/Thinking:  http://localhost:8000/chat/v1"
        echo "   Embedding:             http://localhost:8000/embed/v1"
        echo "   Ollama:                http://localhost:8000/ollama"
        echo ""
        echo " Thinking-Modus steuern:"
        echo "   /think    → Thinking aktivieren (Standard)"
        echo "   /no_think → Thinking deaktivieren (schneller)"
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
        echo "  vision    - Qwen3-VL 32B Thinking (Chat + Vision + Reasoning, Port 8081)"
        echo "  embedding - BGE-M3 multilingual    (Embedding,              Port 8083)"
        echo "  all       - Beide Server starten"
        echo "  stop      - Alle Server stoppen"
        echo "  status    - Laufende Server + GPU-Auslastung anzeigen"
        echo "  logs      - Logs verfolgen"
        exit 1
        ;;
esac