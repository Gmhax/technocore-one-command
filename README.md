# Technocore One-Command Setup

A simple setup helper for creating and using a Technocore DID in GitHub Codespaces.

This project is intended to make the initial Technocore setup easier for developers, researchers, and content creators.

## What it does

The setup script:

1. Checks for Python
2. Downloads the official Technocore DID starter
3. Creates a Python virtual environment
4. Installs the required dependencies
5. Creates an encrypted Technocore DID if one does not already exist
6. Displays the public DID
7. Shows the next command for publishing a signed message

## One-command setup

Open a GitHub Codespace and run:

```bash
bash setup.sh
