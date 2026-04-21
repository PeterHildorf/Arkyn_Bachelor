#!/bin/bash
# ─────────────────────────────────────────────
# Arkyn Deploy Script
# Sørg for at Homebrew's Go er tilgængeligt
export PATH="/opt/homebrew/bin:/usr/local/go/bin:$PATH"
# Brug: ./deploy.sh
# Pusher til GitHub og deployer til DTU-server
# ─────────────────────────────────────────────

set -e  # Stop ved fejl

SERVER="user@130.225.170.229"
REMOTE_MIDDLEWARE="~/arkyn-middleware/arkynServer/middleware"
LOCAL_MIDDLEWARE="./arkynServer/middleware"

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

# 3. Cross-kompilér til Linux (amd64) lokalt
echo "🔨 Bygger Linux-binær lokalt..."
cd "$LOCAL_MIDDLEWARE"
GOOS=linux GOARCH=amd64 go build -o arkyn-server ./cmd/server/
cd - > /dev/null
echo "  → Binær bygget: $(du -sh $LOCAL_MIDDLEWARE/arkyn-server | cut -f1)"

# 4. Stop servicen FØR vi kopierer
echo "⏹️  Stopper arkyn service..."
ssh "$SERVER" "sudo systemctl stop arkyn"

# 5. Kopiér binær til serveren
echo "📤 Kopierer binær til serveren..."
scp "$LOCAL_MIDDLEWARE/arkyn-server" "$SERVER:/home/user/arkyn-middleware/arkynServer/middleware/arkyn-server"

# 6. SSH ind og genstart servicen
echo "🔄 Genstarter service på DTU-server..."
ssh "$SERVER" << 'ENDSSH'
  set -e
  echo "  → Sætter executable-bit..."
  chmod +x /home/user/arkyn-middleware/arkynServer/middleware/arkyn-server
  echo "  → Genstarter arkyn service..."
  sudo systemctl restart arkyn
  sleep 1
  echo "  → Status:"
  sudo systemctl is-active arkyn
ENDSSH

echo ""
echo "✅ Deploy fuldført! Server kører på http://130.225.170.229:8080"