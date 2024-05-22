#!/bin/zsh

# Script to install the AWS EMR-EKS CLI tool
echo "Installing AWS EMR-EKS CLI..."

# Navigate to the script directory (assuming the script is run from the root of the cloned repo)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
BIN_PATH="$SCRIPT_DIR/bin"

# Make the main script executable
chmod +x "$BIN_PATH/emr-eks"

# Add the bin directory to the user's PATH if not already added
if ! grep -q "$BIN_PATH" ~/.zshrc; then
    echo "Adding emr-eks to your PATH in .zshrc"
    echo "export PATH=\"\$PATH:$BIN_PATH\"" >> ~/.zshrc
    source ~/.zshrc
    echo "emr-eks has been added to your PATH."
else
    echo "emr-eks is already in your PATH."
fi

echo "Installation completed successfully."
echo "Type 'emr-eks' in your terminal to start using AWS EMR-EKS CLI."
