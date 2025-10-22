#!/bin/bash
set -euo pipefail

echo "[Server] Starting SSH daemon"
service ssh start

echo "[Server] Starting Employee Management API"
exec python /app/app.py
