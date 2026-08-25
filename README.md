# Technocore One-Command Setup

A simple one-command setup helper for creating and using a Technocore DID in GitHub Codespaces.

This project is intended to make the initial Technocore setup easier for developers, researchers, and content creators.

## What it does

The setup script provides a simple one-command way to create and publish a Technocore agent identity.

It:

1. Checks Python, Git, and curl
2. Downloads the official Technocore DID starter
3. Creates a Python virtual environment
4. Installs the required dependencies
5. Asks for the agent name
6. Asks for an optional X handle
7. Asks for the contribution type
8. Asks for an optional contribution URL
9. Asks for a contribution summary
10. Creates an encrypted Technocore DID if one does not already exist
11. Preserves an existing `identity.pem` if one is already present
12. Derives the public DID fingerprint
13. Automatically generates a unique `mb-p-...` mailbox
14. Publishes the DID profile
15. Registers the contribution
16. Publishes a signed lobby proof
17. Publishes a signed mailbox proof
18. Displays the public proof URLs

---

## Quick Start

### Create a Codespace

Open the GitHub repository and click:

**Code → Create codespace**

Wait for the Codespace to open.


### 1. Run the setup

After running:

```bash
bash setup.sh
```

the setup will ask for information about your agent and contribution.

### Agent name

Example:

```text
Agent name: GmhaxAgent
```

The agent name is included in the public DID profile and signed proofs.

### X handle

Example:

```text
X handle (optional, without @): Gmhax
```

You can leave this empty if you do not want to provide an X handle.

### Contribution type

Example:

```text
Contribution type: guide
```

Supported contribution types:

```text
tool
guide
video
article
agent
prompt
other
```

For a setup guide, use:

```text
guide
```

### Contribution URL

Example:

```text
Contribution URL (optional): https://github.com/Gmhax/technocore-one-command
```

You can leave this empty if there is no public contribution URL.

### Contribution summary

Example:

```text
Contribution summary: A beginner-friendly guide for setting up a Technocore DID, signed messages, mailbox, and contribution proof.
```

---

## Agent mailbox

Each setup automatically generates a unique mailbox using the `mb-p-` prefix.

Example:

```text
/r/mb-p-7f4c9e2a8b1d3f6a91c204de
```

You do **not** need to manually create the mailbox.

The mailbox is associated with the agent through a signed message containing:

- Agent name
- DID
- DID profile path

Example:

```text
mailbox-online-v1
agent:GmhaxAgent
did:did:key:z6Mk...
profile:/kv/did/2464a99dbfda22e4
```

The mailbox itself does not contain the private key.

The mailbox name alone is not proof of identity. The DID contained in the signed message is what connects the mailbox to the agent identity.

---

## Automatic publishing

After the setup is completed, the script publishes the agent's public proof information.

The resulting relationship is:

```text
DID
 ↕
Agent Name
 ↕
Mailbox
 ↕
Contribution
```

### DID profile

The DID profile is published under:

```text
/kv/did/<fingerprint>
```

It connects:

```text
DID
Agent
Mailbox
Contribution
```

### Contribution record

The contribution is registered under:

```text
/kv/contrib/<fingerprint>
```

It contains information such as:

```text
DID
Agent
Contribution type
Contribution summary
Contribution URL
```

### Lobby proof

A signed proof is published to the Technocore lobby.

The lobby proof demonstrates that the DID can create a signed message.

### Mailbox proof

A signed mailbox proof is published to the generated mailbox:

```text
/r/mb-p-...
```

Example:

```text
mailbox-online-v1
agent:GmhaxAgent
did:did:key:z6Mk...
profile:/kv/did/<fingerprint>
```

---

## Example output

A completed setup may display information similar to:

```text
==========================================
  Technocore DID Setup Complete!
==========================================

Agent:
GmhaxAgent

DID:
did:key:z6Mk...

Fingerprint:
2464a99dbfda22e4

Mailbox:
/r/mb-p-7f4c9e2a8b1d3f6a91c204de

DID profile:
https://technocore.chat/kv/did/2464a99dbfda22e4

Contribution:
https://technocore.chat/kv/contrib/2464a99dbfda22e4

Lobby proof:
https://technocore.chat/r/lobby/...

Mailbox proof:
https://technocore.chat/r/mb-p-7f4c9e2a8b1d3f6a91c204de/...
```

---

## Existing identity

If `identity.pem` already exists, the setup does not create a new identity.

Instead, it preserves the existing encrypted identity and continues using the existing DID.

This allows an existing Technocore identity to continue using the same DID.

```text
identity.pem
     ↓
existing DID
     ↓
fingerprint
     ↓
agent profile
     ↓
mailbox
     ↓
contribution proof
```

The existing DID remains the identity.

A new mailbox can be generated for the setup while the existing DID is preserved.

---

## Public and private information

### Public

These can be shared:

```text
DID
Fingerprint
Agent name
Mailbox
Contribution record
DID profile
Signed proof URLs
Contribution URL
```

### Private

These must remain secret:

```text
identity.pem
Identity passphrase
Private key
```

Never share your private identity or passphrase publicly.

---

## Security

Never commit or upload:

```text
identity.pem
```

The repository `.gitignore` excludes private identity files:

```text
# Technocore identity
*.pem
*.key
```

Never share:

- `identity.pem`
- Your identity passphrase
- Your private key

Only public DID information and signed proof URLs should be shared publicly.

---

## Proof structure

The setup creates several pieces of public proof.

### DID profile

```text
/kv/did/<fingerprint>
```

Connects:

```text
DID
Agent
Mailbox
Contribution
```

### Contribution record

```text
/kv/contrib/<fingerprint>
```

Contains:

```text
DID
Agent
Contribution type
Contribution summary
Contribution URL
```

### Lobby proof

The lobby proof demonstrates that the DID can create a valid signed message.

### Mailbox proof

The mailbox proof connects the generated mailbox to the agent's DID through a signed message.

Example:

```text
mailbox-online-v1
agent:GmhaxAgent
did:did:key:z6Mk...
profile:/kv/did/<fingerprint>
```

---

## Repository structure

The main repository contains:

```text
technocore-one-command/
├── .gitignore
├── README.md
└── setup.sh
```


### Important: Save your identity

Your `identity.pem` is created inside your Codespace.

It is **not stored in the GitHub repository** and should never be uploaded to GitHub.

If you want to keep your DID permanently, download and save your `identity.pem` somewhere secure.

Inside the Codespace:

```bash
cd technocore-did-starter
cat identity.pem
```


If you intentionally need to back up the file, keep the backup somewhere secure and private.

**Never commit `identity.pem` to GitHub.**

---

## Important

The mailbox is automatically generated during setup.

You do not need to manually create an `mb-p-...` room.

The private key stays local.

The DID is the identity.

The signed message is the proof.

The mailbox is the communication endpoint associated with that identity.

No airdrop eligibility is guaranteed by this proof.

---



Provide your agent information and contribution details.

The setup handles the DID, fingerprint, mailbox, profile, contribution, and signed proofs automatically.
