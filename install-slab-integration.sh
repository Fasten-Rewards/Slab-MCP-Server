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

# Function to install Node.js via Homebrew
install_node_via_homebrew() {
    echo -e "${YELLOW}ℹ${NC}  Installing Node.js via Homebrew..."
    brew install node

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Node.js installed successfully"
        if command -v node >/dev/null 2>&1; then
            NODE_VERSION=$(node --version 2>/dev/null)
            echo -e "${GREEN}✓${NC} Node.js $NODE_VERSION is ready"
            return 0
        fi
    fi

    echo -e "${RED}✗${NC} Failed to install Node.js via Homebrew"
    echo ""
    echo "Please try running:"
    echo "  brew install node"
    echo ""
    echo "Then run this installer again."
    exit 1
}

echo "Checking prerequisites..."

# Step 1: Check Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${RED}✗${NC} Homebrew is not installed"
    echo ""
    echo "Please install Homebrew manually before running this script:"
    echo "  https://brew.sh"
    echo ""
    exit 1
else
    echo -e "${GREEN}✓${NC} Homebrew is installed"
    # Make sure Homebrew is in PATH
    if [ -d "/opt/homebrew" ]; then
        export PATH="/opt/homebrew/bin:$PATH"
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null
    else
        export PATH="/usr/local/bin:$PATH"
        eval "$(/usr/local/bin/brew shellenv)" 2>/dev/null
    fi
fi

# Step 2: Check Node.js
if ! command -v node >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC} Node.js is not installed"
    install_node_via_homebrew
else
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Node.js is installed (version $NODE_VERSION)"
fi

echo ""

# Step 3: Get Slab token
echo "Enter your Slab API Token"
echo ""
read -p "Slab API Token: " SLAB_TOKEN < /dev/tty

if [ -z "$SLAB_TOKEN" ]; then
    echo -e "${RED}✗${NC} No token provided. Exiting."
    exit 1
fi

# Step 4: Setup configuration
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
cat > "$CONFIG_FILE" << EOCONFIG
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

# Step 5: Final instructions
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
