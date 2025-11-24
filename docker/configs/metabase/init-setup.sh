#!/bin/bash
# Metabase Auto-Configuration Script
# Waits for Metabase to be ready and configures it via API if not already setup

set -e

METABASE_URL="${METABASE_URL:-http://metabase:3000}"
MAX_ATTEMPTS=30
ATTEMPT=0

echo "🔧 Waiting for Metabase to be ready..."

# Wait for Metabase to be ready
until curl -sf "${METABASE_URL}/api/health" > /dev/null 2>&1; do
    ATTEMPT=$((ATTEMPT + 1))
    if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
        echo "❌ Metabase did not become ready in time"
        exit 1
    fi
    echo "⏳ Waiting for Metabase... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 10
done

echo "✅ Metabase is ready!"

# Check if setup is already complete
SETUP_TOKEN=$(curl -sf "${METABASE_URL}/api/session/properties" | grep -o '"setup-token":"[^"]*"' | cut -d'"' -f4 || echo "")

if [ -z "$SETUP_TOKEN" ]; then
    echo "✓ Metabase is already configured"
    exit 0
fi

echo "🚀 Starting Metabase auto-configuration..."

# Create setup payload
SETUP_PAYLOAD=$(cat <<EOF
{
  "token": "${SETUP_TOKEN}",
  "user": {
    "first_name": "Admin",
    "last_name": "Pro-Mata",
    "email": "admin@promata.com.br",
    "password": "promata2025",
    "site_name": "Pro-Mata Analytics"
  },
  "database": {
    "engine": "postgres",
    "name": "promata",
    "details": {
      "host": "postgres-primary",
      "port": 5432,
      "dbname": "promata",
      "user": "admin",
      "password": "admin",
      "ssl": false,
      "tunnel-enabled": false
    }
  },
  "prefs": {
    "site_name": "Pro-Mata Analytics",
    "site_locale": "pt_BR",
    "allow_tracking": false
  }
}
EOF
)

# Execute setup via API
RESPONSE=$(curl -sf -X POST "${METABASE_URL}/api/setup" \
    -H "Content-Type: application/json" \
    -d "$SETUP_PAYLOAD" || echo "")

if echo "$RESPONSE" | grep -q '"id"'; then
    echo "✅ Metabase configured successfully!"
    echo "📊 Login: admin@promata.com.br / promata2025"
else
    echo "⚠️  Metabase setup may have failed or was already complete"
    echo "Response: $RESPONSE"
fi

echo "✓ Metabase initialization complete"
