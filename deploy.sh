#!/bin/bash
# ─────────────────────────────────────────────
# Arkyn Deploy Script
# Brug: ./deploy.sh
# Pusher til GitHub og deployer til DTU-server
# ─────────────────────────────────────────────

set -e  # Stop ved fejl

SERVER="user@130.225.170.229"
REMOTE_DIR="~/arkyn-middleware"

echo "🚀 Arkyn Deploy"
echo "───────────────────────────"

# 1. Commit lokale ændringer hvis der er nogen
if [[ -n $(git status --porcelain) ]]; then
  echo "📦 Committer lokale ændringer..."
  git add .
  read -p "Commit besked: " msg
  git commit -m "$msg"
fi

# 2. Push til GitHub
echo "⬆️  Pusher til GitHub..."
git push origin main

# 3. SSH ind og opdater serveren
echo "🔄 Deployer til DTU-server..."
ssh $SERVER << 'ENDSSH'
  set -e
  cd ~/arkyn-middleware
  echo "  → git pull..."
  git pull origin main
  echo "  → go build..."
  go build -o arkyn-server ./cmd/server/
  echo "  → restart service..."
  sudo systemctl restart arkyn
  echo "  → status:"
  sudo systemctl is-active arkyn
ENDSSH

echo ""
echo "✅ Deploy fuldført! Server kører på http://130.225.170.229:8080"
