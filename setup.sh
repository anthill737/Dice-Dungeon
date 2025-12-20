#!/bin/bash
# Dice Dungeon Explorer - Linux/Mac Setup Script
# Run this file to install and setup the game

echo ""
echo "====================================================="
echo "  DICE DUNGEON EXPLORER - SETUP"
echo "====================================================="
echo ""
echo "This will automatically:"
echo "  - Check your Python installation"
echo "  - Install required dependencies"
echo "  - Create a game launcher"
echo "  - Start the game"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    echo ""
    echo "Please install Python 3.11 or higher:"
    echo "  Ubuntu/Debian: sudo apt install python3.11"
    echo "  macOS: brew install python@3.11"
    echo ""
    exit 1
fi

# Show Python version
echo "Found Python version:"
python3 --version
echo ""

# Run the setup script
python3 setup.py

read -p "Press Enter to exit..."
