#!/bin/bash

# Set colors for a better-looking menu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to install the panel
install_panel() {
    echo -e "\n${CYAN}[+] Installing dependencies... Please wait...${NC}"
    
    # Update system package index
    sudo apt update
    
    # Install curl
    sudo apt install curl -y
    
    # Setup and install Node.js 20.x
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs 
    
    # Install PM2 globally
    sudo npm install -g pm2

    echo -e "\n${CYAN}[+] Downloading and setting up the Jtg Panel...${NC}"
    
    # Check if the Jtg folder already exists
    if [ -d "Jtg" ]; then
        echo -e "${YELLOW}[!] The 'Jtg' folder already exists. Please delete it first or use the update option (Option 2).${NC}"
        return
    fi

    # Clone from GitHub
    git clone https://github.com/JishnuTheGamer/Jtg
    
    # Navigate into the directory
    cd Jtg || { echo -e "${RED}[!] Failed to enter the directory!${NC}"; return; }
    
    # Install node modules
    npm i 
    
    # Create user and build
    npm run createuser
    npm run build
    
    # Start with PM2
    pm2 start ecosystem.config.cjs
    
    echo -e "\n${GREEN}==========================================${NC}"
    echo -e "${GREEN} [✓] Panel successfully installed and started!${NC}"
    echo -e "${GREEN} MADE BY - JISHNU - POWERED BY NYROX | panel info  [Online] ${NC}"
    echo -e "${GREEN}==========================================${NC}"
    
    # Return to the main directory
    cd ..
}

# Function to update the panel
update_panel() {
    echo -e "\n${CYAN}[+] Updating the panel...${NC}"
    
    # Check if the Jtg folder exists
    if [ -d "Jtg" ]; then
        cd Jtg || { echo -e "${RED}[!] Failed to enter the directory!${NC}"; return; }
        
        # Fetch new updates from GitHub
        git stash
        git pull
        
        # Update packages and rebuild
        npm i 
        npm run build 
        
        # Restart PM2 processes
        pm2 restart all
        
        echo -e "\n${GREEN}[✓] Panel successfully updated and restarted!${NC}"
        
        # Return to the main directory
        cd ..
    else
        echo -e "${RED}[!] 'Jtg' directory not found! Please install the panel first (Option 1).${NC}"
    fi
}

# Main menu loop
while true; do
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${GREEN}       JTG PANEL MANAGER MENU           ${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${CYAN}1.${NC} Install Panel (Auto Setup)"
    echo -e "${CYAN}2.${NC} Update Panel"
    echo -e "${RED}3.${NC} Exit"
    echo -e "${YELLOW}========================================${NC}"
    
    read -p "Choose an option (1/2/3): " choice

    case $choice in
        1)
            install_panel
            ;;
        2)
            update_panel
            ;;
        3)
            echo -e "${YELLOW}Exiting script... Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Invalid option! Please enter 1, 2, or 3.${NC}"
            ;;
    esac
done
