#!/bin/bash

#################################################################
## This script installs and configures the Ubuntu Landscape   ###
## client and registers the device wwith it current computer  ###
## name.                                                      ###
## Company: Stryker Corp                                      ###
## Created by: Mark Briscoe                                   ###
## Date: 10/1/2025                                            ###
#################################################################

# --- Configuration Variables ---
# IMPORTANT: Replace these with your actual Landscape server details
LANDSCAPE_SERVER="192.168.86.249"
ACCOUNT_NAME="standalone" # Use the correct account name for your setup
SSL_CERT_FILENAME="landscape_server_ca.crt"
SSL_CERT_DEST_PATH="/etc/landscape/$SSL_CERT_FILENAME"
SSL_CERT_SOURCE_PATH="./$SSL_CERT_FILENAME" # Look in the current directory

# ADDED: Variable for the Landscape Registration Key
# If your Landscape server requires a key for initial registration,
# replace 'YOUR_REGISTRATION_KEY' with the actual key.
REGISTRATION_KEY="imxXYVvz*gL!7ma46XJRgv!N" 

# --- Script Logic ---

# 1. Get the local computer's hostname
BASE_COMPUTER_NAME="LNX"
COMPUTER_NAME="$BASE_COMPUTER_NAME" # Start with just the hostname

echo "Starting Landscape client setup for computer: $COMPUTER_NAME"
echo " "

# 2. Attempt to get the serial number and append it to the computer name
echo "Attempting to retrieve system serial number..."
# Check if dmidecode is installed, and if not, try to install it (optional, but good for robustness)
if ! command -v dmidecode &> /dev/null; then
    echo "dmidecode not found. Installing..."
    sudo apt update && sudo apt install -y dmidecode
fi

# Get the serial number and clean it up (trim whitespace)
SERIAL_NUMBER=$(sudo dmidecode -s system-serial-number 2>/dev/null | tr -d '[:space:]')

if [ -n "$SERIAL_NUMBER" ]; then
    # Append the serial number to the computer name, separated by a hyphen
    COMPUTER_NAME="${BASE_COMPUTER_NAME}-${SERIAL_NUMBER}"
    echo "Serial number retrieved: $SERIAL_NUMBER"
    echo "New computer title will be: $COMPUTER_NAME"
else
    echo "WARNING: Could not retrieve system serial number. Using only hostname: $COMPUTER_NAME"
fi
echo " "

# 3. Update the device hostname
echo "Step 1/6: Setting device hostname to: $COMPUTER_NAME"

if [ "$COMPUTER_NAME" != "$BASE_COMPUTER_NAME" ]; then
    # Use hostnamectl to set the static hostname permanently
    sudo hostnamectl set-hostname "$COMPUTER_NAME"
    if [ $? -eq 0 ]; then
        echo "Hostname successfully updated via hostnamectl."
    else
        echo "ERROR: Failed to set new hostname. Check logs."
    fi
else
    echo "Hostname remains unchanged (no serial number found)."
fi
echo " "

# 4. Copy the SSL certificate file
echo "Step 2/6: Checking for and copying the SSL public key..."

if [ -f "$SSL_CERT_SOURCE_PATH" ]; then
    echo "Found $SSL_CERT_FILENAME. Copying to $SSL_CERT_DEST_PATH..."
    # Create the destination directory if it doesn't exist
    sudo mkdir -p /etc/landscape/
    # Copy the file
    sudo cp "$SSL_CERT_SOURCE_PATH" "$SSL_CERT_DEST_PATH"
    if [ $? -eq 0 ]; then
        echo "Certificate copied successfully."
    else
        echo "ERROR: Failed to copy the certificate. Exiting."
        exit 1
    fi
else
    echo "WARNING: SSL Public Key ($SSL_CERT_FILENAME) not found in the current directory."
    echo "The configuration will check the destination path for the key."
fi
echo " "

# 5. Update package list and install necessary repositories
echo "Step 3/6: Updating packages and installing landscape-client..."
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:landscape/latest-stable
sudo apt update
sudo apt install -y landscape-client

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to install landscape-client. Exiting."
    exit 1
fi

echo "Landscape client installed successfully."
echo " "

# 6. Configure the Landscape client using the hostname and custom settings
echo "Step 4/6: Configuring Landscape client..."
# Start with the full command including the SSL key
CONFIG_COMMAND="sudo landscape-config \
    --computer-title \"$COMPUTER_NAME\" \
    --account-name $ACCOUNT_NAME \
    --url https://$LANDSCAPE_SERVER/message-system \
    --ping-url http://$LANDSCAPE_SERVER/ping \
    --ssl-public-key=$SSL_CERT_DEST_PATH \
    --registration-key $REGISTRATION_KEY \
    --include-manager-plugins ScriptExecution \
    --script-users root,landscape,nobody"

# Check if the certificate exists in the destination path before running the command
if [ ! -f "$SSL_CERT_DEST_PATH" ]; then
    echo "WARNING: SSL Public Key not found at $SSL_CERT_DEST_PATH. Running configuration WITHOUT --ssl-public-key."
    # Re-run the command without the --ssl-public-key parameter
    CONFIG_COMMAND="sudo landscape-config \
        --computer-title \"$COMPUTER_NAME\" \
        --account-name $ACCOUNT_NAME \
        --url https://$LANDSCAPE_SERVER/message-system \
        --ping-url http://$LANDSCAPE_SERVER/ping \
        --registration-key $REGISTRATION_KEY \
        --include-manager-plugins ScriptExecution \
        --script-users root,landscape,nobody"
fi

# Execute the configuration command
eval $CONFIG_COMMAND

if [ $? -eq 0 ]; then
    echo " "
    echo "Step 6/6: Landscape client configured successfully with title: $COMPUTER_NAME"
    echo "The client should now attempt to register with the Landscape server."
    echo "*** PLEASE REBOOT COMPUTER AFTER MICOSOFT INTUNE AND EDGE HAS BEEN INSTALLED ***"
else
    echo "ERROR: Landscape configuration failed. Please check the server details and logs."
fi

