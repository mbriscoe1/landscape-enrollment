#!/bin/bash

############################################################################################
##
## Script to install Intune $ MS Edge Prerequisites for Linux Enrollment
##
############################################################################################

## Copyright (c) 2020 Microsoft Corp. All rights reserved.
## Scripts are not supported under any Microsoft standard support program or service. The scripts are provided AS IS without warranty of any kind.
## Microsoft disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a
## particular purpose. The entire risk arising out of the use or performance of the scripts and documentation remains with you. In no event shall
## Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever
## (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary
## loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility
## of such damages.
## Feedback: Anders Ahl

if [ "$EUID" -ne 0 ]
  then echo "Please run this script as root"
  exit 1
fi

# Start of a bash "try-catch loop" that will safely exit the script if a command fails or causes an error. 
(
    # Set the error status
    set -e

    # Install pre-requisite packages
    apt install -y wget apt-transport-https software-properties-common

    # Download the Microsoft repository and GPG keys
    wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"

    # Register the Microsoft repository and GPG keys
    dpkg -i packages-microsoft-prod.deb

    # Update the list of packages after we have added packages.microsoft.com
    apt update

    # Remove the repository & GPG key package (as we imported it above)
    rm packages-microsoft-prod.deb

    # Install the Intune portal
    apt install -y intune-portal

    # Install MS Edge
    sudo apt update
sudo apt install software-properties-common apt-transport-https wget -y
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://packages.microsoft.com/repos/edge stable main"
sudo apt update
sudo apt install microsoft-edge-stable
)
# Catch any necessary errors to prevent the program from improperly exiting. 
ERROR_CODE=$?
if [ $ERROR_CODE -ne 0 ]; then
    echo "There was an error. Please restart the script or contact your admin if the error persists."
    exit $ERROR_CODE
fi
