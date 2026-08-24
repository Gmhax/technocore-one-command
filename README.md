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

## Step-by-step setup

### 1. Create a Codespace

Click:

**Code → Create codespace**

Wait for the Codespace to open.

### 2. Run the setup

In the terminal, run:

```bash
bash setup.sh
```
- Create your identity passphrase (password) 12+ characters minimum
- Passphrase for /workspaces/technocore-one-command/technocore-did-starter/identity.pem: Type your identity passphrase (Password)

### Important: Save your identity

Your `identity.pem` is created inside your Codespace.

It is **not stored in the GitHub repository** and should never be uploaded to GitHub.

If you want to keep your DID permanently, download and save your `identity.pem` somewhere secure.

Inside the Codespace:

```bash
cd technocore-did-starter
cat identity.pem
```
# Done! 🎉
