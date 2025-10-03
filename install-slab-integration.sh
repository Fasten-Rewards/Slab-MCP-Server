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

# Check if Node.js is available (but don't exit if not)
echo "Checking prerequisites..."
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Node.js is installed (version $NODE_VERSION)"
else
    echo -e "${YELLOW}⚠${NC}  Node.js is not detected"
    echo "   You'll need Node.js for the integration to work."
    echo "   Install it from https://nodejs.org if you haven't already."
    echo ""
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
fi
echo ""

# Get Slab token
echo "Enter your Slab API Token"
echo ""
read -p "Slab API Token: " SLAB_TOKEN

if [ -z "$SLAB_TOKEN" ]; then
    echo -e "${RED}✗${NC} No token provided. Exiting."
    exit 1
fi

# Setup configuration
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

# Create directory if needed
if [ ! -d "$CONFIG_DIR" ]; then
    mkdir -p "$CONFIG_DIR"
    echo -e "${GREEN}✓${NC} Created config directory"
fi

# Backup existing config if it exists
if [ -f "$CONFIG_FILE" ]; then
    BACKUP="$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP"
    echo -e "${GREEN}✓${NC} Backed up existing config to:"
    echo "   $BACKUP"
fi

# Create the configuration
echo ""
echo "Creating Slab configuration..."

# Write the configuration file
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

# Check if file was created successfully
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${GREEN}✓${NC} Configuration file created successfully!"
    
    # Verify the file has content
    FILE_SIZE=$(wc -c < "$CONFIG_FILE")
    if [ $FILE_SIZE -gt 50 ]; then
        echo -e "${GREEN}✓${NC} Configuration verified (${FILE_SIZE} bytes)"
    else
        echo -e "${RED}✗${NC} Warning: Config file seems too small"
    fi
    
    # Show the actual content for verification
    echo ""
    echo "Configuration content:"
    echo "----------------------------------------"
    cat "$CONFIG_FILE"
    echo "----------------------------------------"
else
    echo -e "${RED}✗${NC} Failed to create configuration file!"
    exit 1
fi

# Final instructions
echo ""
echo "╔════════════════════════════════════════════════╗"
echo "║            ✅ Setup Complete!                   ║"
echo "╚════════════════════════════════════════════════╝"
echo ""
echo "IMPORTANT - Next steps:"
echo ""
echo "1. FULLY QUIT Claude Desktop (Cmd+Q)"
echo "   - Don't just close the window"
echo "   - Make sure it's not in the dock"
echo ""
echo "2. Wait 5 seconds"
echo ""
echo "3. Open Claude Desktop again"
echo ""
echo "4. Test by asking Claude:"
echo "   'Can you search Slab for documentation?'"
echo ""

# Check if Claude is currently running
if pgrep -x "Claude" > /dev/null; then
    echo -e "${YELLOW}⚠${NC}  Claude is currently running!"
    echo ""
    read -p "Quit Claude now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        osascript -e 'quit app "Claude"' 2>/dev/null || true
        echo "Waiting for Claude to quit..."
        sleep 3
        
        read -p "Now open Claude? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open -a "Claude" 2>/dev/null || echo "Please open Claude manually"
        fi
    fi
fi

echo ""
echo "Installation complete!"
echo ""
read -p "Press Enter to close..."
