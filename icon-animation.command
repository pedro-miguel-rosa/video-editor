#!/bin/bash

# -----------------------------------------------
# CONFIGURABLE OPTIONS
# -----------------------------------------------
REPO_URL="${REPO_URL:-https://github.com/hysamello/video-editor.git}"
BRANCH="${BRANCH:-master}"
APP_DIR="${HOME}/.video-editor-temp"
LAST_HASH_FILE="$APP_DIR/.last-git-hash"

# -----------------------------------------------
# COLOR DEFINITIONS
# -----------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# -----------------------------------------------
# CHECK REQUIRED COMMANDS
# -----------------------------------------------
for cmd in git curl sha256sum; do
  if ! command -v $cmd &>/dev/null; then
    echo -e "${RED}❌ $cmd is required but not installed.${NC}"
    exit 1
  fi
done

# -----------------------------------------------
# CLONE IF FIRST TIME
# -----------------------------------------------
if [ ! -d "$APP_DIR/.git" ]; then
  echo -e "${BLUE}📥 Cloning repository into: $APP_DIR${NC}"
  git clone --branch "$BRANCH" "$REPO_URL" "$APP_DIR" || { echo -e "${RED}❌ Git clone failed${NC}"; exit 1; }
else
  echo -e "${BLUE}📁 Using existing repo at: $APP_DIR${NC}"
fi

cd "$APP_DIR" || exit 1

# -----------------------------------------------
# CHECK FOR GIT CHANGES
# -----------------------------------------------
echo -e "${BLUE}🔍 Checking for remote updates...${NC}"
git fetch origin "$BRANCH"

CURRENT_HASH=$(git rev-parse FETCH_HEAD)
CACHED_HASH=$(cat "$LAST_HASH_FILE" 2>/dev/null || echo "none")

if [[ "$CURRENT_HASH" != "$CACHED_HASH" ]]; then
  echo -e "${YELLOW}🔄 Changes detected. Pulling and rebuilding...${NC}"
  git reset --hard "$CURRENT_HASH" || exit 1
  echo "$CURRENT_HASH" > "$LAST_HASH_FILE"

  # -----------------------------------------------
  # INSTALL NODE IF NEEDED
  # -----------------------------------------------
  if ! command -v node &>/dev/null; then
    echo -e "${YELLOW}🛠️ Node.js is not installed. Installing...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      if ! command -v brew &>/dev/null; then
        echo -e "${BLUE}Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      fi
      brew install node
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
      sudo apt-get install -y nodejs
    elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "win32" ]]; then
      echo -e "${BLUE}Downloading Node.js installer for Windows...${NC}"
      powershell.exe -Command "
        \$url = 'https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi';
        \$installer = \"\$env:TEMP\\node-installer.msi\";
        Invoke-WebRequest -Uri \$url -OutFile \$installer;
        Start-Process msiexec.exe -ArgumentList '/i', \$installer, '/quiet', '/norestart' -Wait;
      "
      export PATH="$PATH:/c/Program Files/nodejs"
      sleep 5
      if ! command -v node &>/dev/null; then
        echo -e "${RED}❌ Node.js still not available. Please restart your terminal.${NC}"
        exit 1
      fi
    else
      echo -e "${RED}❌ Unsupported OS. Please install Node.js manually.${NC}"
      exit 1
    fi
  fi

  # -----------------------------------------------
  # INSTALL DEPENDENCIES
  # -----------------------------------------------
  echo -e "${YELLOW}📦 Installing dependencies...${NC}"
  npm install || { echo -e "${RED}❌ npm install failed${NC}"; exit 1; }

  # -----------------------------------------------
  # BUILD
  # -----------------------------------------------
  echo -e "${YELLOW}🔧 Building the frontend...${NC}"
  npm run build || { echo -e "${RED}❌ Build failed${NC}"; exit 1; }

else
  echo -e "${GREEN}✅ No updates found. Using cached build.${NC}"
fi

# -----------------------------------------------
# RUN THE APP
# -----------------------------------------------
echo -e "${GREEN}🚀 Launching the app...${NC}"
npm run start
