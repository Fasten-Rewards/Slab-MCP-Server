#!/bin/bash

# Simple Slab Integration Installer for Claude Desktop
# This script sets up Slab integration for Claude Desktop

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clear
echo "╔════════════════════════════════════════════════╗"
echo "║     Simple Slab Integration Setup              ║"
echo "╚════════════════════════════════════════════════╝"
echo ""

install_node_via_nvm() {
    echo -e "${YELLOW}ℹ${NC} Installing Node.js via NVM..."

    # Install NVM (Node Version Manager)
    if ! command -v nvm >/dev/null 2>&1; then
        echo -e "${YELLOW}ℹ${NC} Installing NVM..."
        export NVM_DIR="$HOME/.nvm"
        mkdir -p "$NVM_DIR"
        curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

        # Load NVM immediately
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    else
        echo -e "${GREEN}✓${NC} NVM is already installed"
    fi

    # Install latest LTS Node version
    if (nvm install --lts </dev/null); then
        echo -e "${GREEN}✓${NC} Node.js installed successfully"
        NODE_VERSION=$(node --version 2>/dev/null)
        echo -e "${GREEN}✓${NC} Node.js $NODE_VERSION is ready"
    else
        echo -e "${RED}✗${NC} Failed to install Node.js via NVM"
        echo ""
        echo "Please try running manually:"
        echo "  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash"
        echo "  source ~/.nvm/nvm.sh"
        echo "  nvm install --lts"
        echo ""
        echo "Then run this installer again."
        exit 1
    fi
}

echo "Checking prerequisites..."

# Step 1: Check Node.js first
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Node.js is installed (version $NODE_VERSION)"
else
    echo -e "${YELLOW}⚠${NC} Node.js is not installed."
    read -p "Install Node.js automatically? (y/n): " -n 1 -r < /dev/tty
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_node_via_nvm
    else
        echo -e "${RED}✗${NC} Node.js is required to continue. Exiting."
        exit 1
    fi
fi

# Ensure node and npx are available
if ! command -v node >/dev/null 2>&1; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

echo ""

# Step 2: Get Slab token
echo "Enter your Slab API Token"
echo ""
read -p "Slab API Token: " SLAB_TOKEN < /dev/tty

if [ -z "$SLAB_TOKEN" ]; then
    echo -e "${RED}✗${NC} No token provided. Exiting."
    exit 1
fi

# Step 3: Setup configuration
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo -e "${GREEN}✓${NC} Created config directory"
fi

if [ -f "$CONFIG_FILE" ]; then
    BACKUP="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    echo -e "${GREEN}✓${NC} Backed up existing config to:"
    echo "   $BACKUP"
fi

echo ""
echo "Creating Slab configuration..."
cat > "$CONFIG_FILE" <<EOCONFIG
{
  "mcpServers": {
    "slab": {
      "command": "npx",
      "args": ["github:Fasten-Rewards/Slab-MCP-Server"],
      "env": {
        "SLAB_API_TOKEN": "$SLAB_TOKEN"
      }
    }
  }
}
EOCONFIG

if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓${NC} Configuration file created successfully!"
    FILE_SIZE=$(wc -c < "$CONFIG_FILE")
    if [ $FILE_SIZE -gt 50 ]; then
        echo -e "${GREEN}✓${NC} Configuration verified (${FILE_SIZE} bytes)"
    else
        echo -e "${RED}✗${NC} Warning: Config file seems too small"
    fi
    echo ""
    echo "Configuration content:"
    echo "----------------------------------------"
    cat "$CONFIG_FILE"
    echo "----------------------------------------"
else
    echo -e "${RED}✗${NC} Failed to create configuration file!"
    exit 1
fi

# Step 4: Final instructions
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║            ✅ Setup Complete!                   ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "IMPORTANT - Next steps:"
echo "1. FULLY QUIT Claude Desktop (Cmd+Q)"
echo "2. Wait 5 seconds"
echo "3. Open Claude Desktop again"
echo "4. Test by asking Claude: 'Can you search Slab for documentation?'"
echo ""

if pgrep -x "Claude" > /dev/null; then
    echo -e "${YELLOW}⚠${NC} Claude is currently running!"
    read -p "Quit Claude now? (y/n): " -n 1 -r < /dev/tty
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        osascript -e 'quit app "Claude"' 2>/dev/null || true
        echo "Waiting for Claude to quit..."
        sleep 3
        read -p "Now open Claude? (y/n): " -n 1 -r < /dev/tty
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open -a "Claude" 2>/dev/null || echo "Please open Claude manually"
        fi
    fi
fi

echo ""
echo "Installation complete!"
echo ""
read -p "Press Enter to close..." < /dev/tty
