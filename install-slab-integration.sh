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

# Function to install Node.js
install_node() {
    echo -e "${YELLOW}ℹ${NC}  Node.js is not installed. Installing now..."
    
    # Check if Homebrew is installed
    if command -v brew >/dev/null 2>&1; then
        echo "Using Homebrew to install Node.js..."
        brew install node
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Node.js installed successfully via Homebrew"
            # Reload PATH
            export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"
            return 0
        else
            echo -e "${RED}✗${NC} Homebrew installation failed"
        fi
    fi
    
    # If Homebrew isn't available or failed, download directly
    echo "Downloading Node.js LTS installer..."
    
    # Detect CPU architecture
    ARCH=$(uname -m)
    if [ "$ARCH" = "arm64" ]; then
        # Apple Silicon
        PLATFORM="darwin-arm64"
    else
        # Intel
        PLATFORM="darwin-x64"
    fi
    
    # Use latest-lts symlink to always get current LTS
    NODE_URL="https://nodejs.org/dist/latest-lts/node-latest-lts-$PLATFORM.tar.gz"
    
    # Download and extract to /usr/local
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    echo "Downloading latest Node.js LTS for $ARCH architecture..."
    if curl -L -o node.tar.gz "$NODE_URL" --progress-bar; then
        echo -e "${GREEN}✓${NC} Download complete"
        
        echo "Installing Node.js (you may be prompted for your password)..."
        tar -xzf node.tar.gz
        
        # Get the extracted directory name (it varies with version)
        NODE_DIR=$(tar -tzf node.tar.gz | head -1 | cut -f1 -d"/")
        
        # Install to /usr/local (requires sudo)
        sudo cp -R "$NODE_DIR"/* /usr/local/
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Node.js installed successfully"
            cd - > /dev/null
            rm -rf "$TEMP_DIR"
            
            # Update PATH
            export PATH="/usr/local/bin:$PATH"
            
            # Verify installation
            if command -v node >/dev/null 2>&1; then
                NODE_VERSION=$(node --version 2>/dev/null)
                echo -e "${GREEN}✓${NC} Node.js $NODE_VERSION is now installed"
                return 0
            fi
        else
            echo -e "${RED}✗${NC} Failed to install Node.js"
            cd - > /dev/null
            rm -rf "$TEMP_DIR"
            return 1
        fi
    else
        echo -e "${RED}✗${NC} Failed to download Node.js"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return 1
    fi
}

# Check if Node.js is available
echo "Checking prerequisites..."
if command -v node >/dev/null 2>&1; then
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Node.js is installed (version $NODE_VERSION)"
else
    # Auto-install Node.js
    install_node
    
    # Check again after installation
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Node.js installation failed"
        echo ""
        echo "Please install Node.js manually from https://nodejs.org"
        echo "Then run this installer again."
        exit 1
    fi
fi
echo ""

# Get Slab token
echo "Enter your Slab API Token"
echo ""

# FIX: Read from /dev/tty to get keyboard input when running via curl | bash
read -p "Slab API Token: " SLAB_TOKEN < /dev/tty

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
