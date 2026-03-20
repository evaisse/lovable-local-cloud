#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# lovable-local-cloud — Reset Script
# Tears down the stack and removes volumes for a fresh start
# ============================================================

echo "🧹 Resetting lovable-local-cloud stack..."
echo ""

# Stop and remove containers
docker compose down -v --remove-orphans 2>/dev/null || true

echo ""
echo "✅ Stack torn down and volumes removed."
echo ""
echo "To rebuild from scratch:"
echo "  docker compose up --build -d"
echo ""
