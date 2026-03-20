#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# lovable-local-cloud — Smoke Tests
# Quick health checks for all stack services
# ============================================================

FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}"
API_URL="${API_URL:-http://localhost:54321}"
MAILHOG_URL="${MAILHOG_URL:-http://localhost:8025}"

PASS=0
FAIL=0
TOTAL=0

check() {
  local name="$1"
  local url="$2"
  local expected_code="${3:-200}"
  TOTAL=$((TOTAL + 1))
  
  local code
  code=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 10 "$url" 2>/dev/null || echo "000")
  
  if [ "$code" = "$expected_code" ]; then
    echo "✅ PASS: $name ($url) — HTTP $code"
    PASS=$((PASS + 1))
  else
    echo "❌ FAIL: $name ($url) — expected HTTP $expected_code, got HTTP $code"
    FAIL=$((FAIL + 1))
  fi
}

echo ""
echo "🔍 lovable-local-cloud smoke tests"
echo "===================================="
echo ""

# Frontend
check "Frontend serves HTML" "$FRONTEND_URL"
check "Frontend health endpoint" "$FRONTEND_URL/health"

# REST API (PostgREST)
check "REST API root" "$API_URL/rest/v1/" "200"

# Auth (GoTrue)
check "Auth health" "$API_URL/auth/v1/health"

# Storage
check "Storage health" "$API_URL/storage/v1/status" "200"

# Functions (smoke function)
check "Edge Functions (smoke)" "$API_URL/functions/v1/smoke"

# Realtime
# Realtime typically returns a websocket upgrade or a page — check it responds
TOTAL=$((TOTAL + 1))
REALTIME_CODE=$(curl -sf -o /dev/null -w '%{http_code}' --max-time 10 "$API_URL/realtime/v1/" 2>/dev/null || echo "000")
if [ "$REALTIME_CODE" != "000" ]; then
  echo "✅ PASS: Realtime is responding ($API_URL/realtime/v1/) — HTTP $REALTIME_CODE"
  PASS=$((PASS + 1))
else
  echo "❌ FAIL: Realtime is not responding ($API_URL/realtime/v1/)"
  FAIL=$((FAIL + 1))
fi

# MailHog
check "MailHog UI" "$MAILHOG_URL"

echo ""
echo "===================================="
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "===================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

echo ""
echo "🎉 All smoke tests passed!"
