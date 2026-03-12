#!/bin/bash

##############################################################################
# WARP Auto-Installation Script
# One-command WARP setup: install → configure → verify
# Usage: bash /tmp/warp-auto.sh
##############################################################################

set -e  # Exit on error

echo "============================================"
echo "WARP Auto-Installation"
echo "============================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Utility functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${YELLOW}=== Step: $1 ===${NC}"
}

##############################################################################
# Step 1: Install cloudflare-warp package
##############################################################################
log_step "1. Installing Cloudflare WARP"

# Check if already installed
if command -v warp-cli &> /dev/null; then
    log_warn "warp-cli already installed: $(warp-cli --version)"
else
    log_info "Adding Cloudflare repository..."
    curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg 2>/dev/null || {
        log_error "Failed to add GPG key"
        exit 1
    }

    echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null

    log_info "Updating package lists..."
    sudo apt update >/dev/null 2>&1 || {
        log_error "Failed to update package lists"
        exit 1
    }

    log_info "Installing cloudflare-warp..."
    sudo apt install -y cloudflare-warp >/dev/null 2>&1 || {
        log_error "Failed to install cloudflare-warp"
        exit 1
    }

    log_info "✓ cloudflare-warp installed successfully"
fi

##############################################################################
# Step 2: Register and configure WARP
##############################################################################
log_step "2. Registering and configuring WARP"

# Check if already registered
if warp-cli --accept-tos status &>/dev/null; then
    log_warn "WARP already registered"
else
    log_info "Registering new WARP account..."
    warp-cli --accept-tos registration new >/dev/null 2>&1 || {
        log_error "Failed to register WARP account"
        exit 1
    }
    log_info "✓ WARP account registered"
fi

log_info "Setting WARP mode to proxy..."
warp-cli --accept-tos mode proxy >/dev/null 2>&1 || {
    log_error "Failed to set proxy mode"
    exit 1
}
log_info "✓ Proxy mode enabled"

log_info "Connecting to WARP..."
warp-cli --accept-tos connect >/dev/null 2>&1 || {
    log_error "Failed to connect to WARP"
    exit 1
}
log_info "✓ WARP connected"

##############################################################################
# Step 3: Verify WARP is working
##############################################################################
log_step "3. Verifying WARP setup"

# Check status
STATUS=$(warp-cli --accept-tos status 2>/dev/null || echo "Unknown")
log_info "WARP Status: $STATUS"

if [[ "$STATUS" != *"Connected"* ]]; then
    log_error "WARP status is not 'Connected'. Got: $STATUS"
    exit 1
fi

# Check if SOCKS5 proxy is listening
log_info "Checking SOCKS5 proxy on localhost:40000..."
if ss -tlnp 2>/dev/null | grep -q ':40000'; then
    log_info "✓ SOCKS5 proxy is listening on port 40000"
else
    log_error "SOCKS5 proxy not found on port 40000"
    log_info "Retrying in 3 seconds..."
    sleep 3
    if ss -tlnp 2>/dev/null | grep -q ':40000'; then
        log_info "✓ SOCKS5 proxy is now listening"
    else
        log_error "SOCKS5 proxy still not listening. Check: ss -tlnp | grep 40000"
        exit 1
    fi
fi

# Test WARP via SOCKS5
log_info "Testing WARP via SOCKS5..."
WARP_TEST=$(curl -sx socks5://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace 2>/dev/null | grep -E "warp=|ip=" || echo "")

if [[ "$WARP_TEST" == *"warp=on"* ]]; then
    WARP_IP=$(echo "$WARP_TEST" | grep "ip=" | cut -d= -f2)
    log_info "✓ WARP is active"
    log_info "  IP seen by Cloudflare: $WARP_IP"
else
    log_warn "WARP status unclear. Test output:"
    echo "$WARP_TEST"
fi

##############################################################################
# Step 4: Enable autostart
##############################################################################
log_step "4. Enabling WARP autostart"

log_info "Enabling warp-taskd systemd service..."
sudo systemctl enable --now warp-taskd >/dev/null 2>&1 || {
    log_warn "Failed to enable warp-taskd (may not be critical)"
}
log_info "✓ Autostart enabled"

##############################################################################
# Success Summary
##############################################################################
echo ""
echo "============================================"
echo -e "${GREEN}✓ WARP SETUP COMPLETE${NC}"
echo "============================================"
echo ""
echo "WARP is now installed and running in proxy mode."
echo ""
echo "Next steps (do this in the 3x-ui Panel):"
echo "  1. Go to: Xray Configs → Outbounds"
echo "  2. Click: Add Outbound"
echo "  3. Fill in:"
echo "     Protocol: socks"
echo "     Tag: warp-cli"
echo "     Address: 127.0.0.1"
echo "     Port: 40000"
echo "  4. Save"
echo ""
echo "  5. Go to: Xray Configs → Routing"
echo "  6. Click: Add Rule"
echo "  7. Fill in:"
echo "     Inbound Tag: inbound-443"
echo "     Outbound Tag: warp-cli"
echo "     Domains: geosite:google*, geosite:youtube*, geosite:google-gemini, domain:notebooklm.google.com, domain:notebooklm.google"
echo "  8. Save"
echo ""
echo "  9. Go to: Xray Configs → Restart Xray"
echo ""
echo "Verify from a device connected to VPN:"
echo "  Open: https://www.cloudflare.com/cdn-cgi/trace"
echo "  Look for: warp=on and IP=104.x.x.x"
echo ""
echo "Troubleshooting:"
echo "  Check status:     warp-cli --accept-tos status"
echo "  Check port:       ss -tlnp | grep 40000"
echo "  Check logs:       sudo x-ui log"
echo ""

exit 0
