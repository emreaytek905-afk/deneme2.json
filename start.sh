#!/bin/bash

set -e

echo "Starting ComfyUI RunPod Serverless Worker"

# Navigate to ComfyUI directory
cd /comfyui

# Start ComfyUI server in the background
echo "Starting ComfyUI server..."
python main.py --listen 0.0.0.0 --port 8188 > /tmp/comfyui.log 2>&1 &
COMFYUI_PID=$!
echo "ComfyUI started (PID: $COMFYUI_PID)"

# Give ComfyUI time to initialize
sleep 5

# Start the handler (foreground process)
echo "Starting handler..."
cd /
python handler.py

# If handler exits, kill ComfyUI
kill $COMFYUI_PID 2>/dev/null || true
