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

# Function to install Homebrew
install_homebrew() {
    echo -e "${YELLOW}ℹ${NC}  Installing Homebrew..."
    echo ""
    echo "The Homebrew installer will ask for your password."
    echo "This is needed to install software on your Mac."
    echo ""
    
    # First, ensure we have sudo access
    echo "Please enter your password to continue:"
    sudo -v
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗${NC} Cannot proceed without administrator access"
        return 1
    fi
    
    # Keep sudo alive during the installation
    while true; do sudo -n true; sleep 60; kill -0 "$" || exit; done 2>/dev/null &
    SUDO_PID=$!
    
    # Install Homebrew using the official installer
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    INSTALL_RESULT=$?
    
    # Stop the sudo keepalive
    kill $SUDO_PID 2>/dev/null
    
    if [ $INSTALL_RESULT -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Homebrew installed successfully"
        
        # Add Homebrew to PATH for current session
        # Check for Apple Silicon vs Intel paths
        if [ -d "/opt/homebrew" ]; then
            # Apple Silicon
            export PATH="/opt/homebrew/bin:$PATH"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            # Intel
            export PATH="/usr/local/bin:$PATH"
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        # Verify Homebrew is working
        if command -v brew >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Homebrew is ready to use"
            return 0
        else
            echo -e "${YELLOW}⚠${NC}  Homebrew installed but not in PATH"
            echo "   You may need to restart your terminal"
        fi
    else
        echo -e "${RED}✗${NC} Failed to install Homebrew"
        return 1
    fi
}

# Function to install Node.js via Homebrew
install_node_via_homebrew() {
    echo -e "${YELLOW}ℹ${NC}  Installing Node.js via Homebrew..."
    
    brew install node
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Node.js installed successfully"
        
        # Verify Node is available
        if command -v node >/dev/null 2>&1; then
            NODE_VERSION=$(node --version 2>/dev/null)
            echo -e "${GREEN}✓${NC} Node.js $NODE_VERSION is ready"
            return 0
        else
            echo -e "${YELLOW}⚠${NC}  Node installed but not found in PATH"
            # Try to source the shell environment again
            if [ -d "/opt/homebrew" ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            else
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
    else
        echo -e "${RED}✗${NC} Failed to install Node.js via Homebrew"
        return 1
    fi
}

echo "Checking prerequisites..."

# Step 1: Check and install Homebrew if needed
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  Homebrew is not installed"
    install_homebrew
    
    # Verify Homebrew installation succeeded
    if ! command -v brew >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Cannot proceed without Homebrew"
        echo ""
        echo "Please install Homebrew manually:"
        echo "https://brew.sh"
        echo ""
        echo "Then run this installer again."
        exit 1
    fi
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

# Step 2: Check and install Node.js via Homebrew
if ! command -v node >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠${NC}  Node.js is not installed"
    install_node_via_homebrew
    
    # Verify Node installation succeeded
    if ! command -v node >/dev/null 2>&1; then
        echo -e "${RED}✗${NC} Node.js installation failed"
        echo ""
        echo "Please try running:"
        echo "  brew install node"
        echo ""
        echo "Then run this installer again."
        exit 1
    fi
else
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Node.js is installed (version $NODE_VERSION)"
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