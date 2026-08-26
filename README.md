# Technocore One-Command Setup

A simple one-command setup helper for creating and using a Technocore DID in GitHub Codespaces.

This project makes the initial Technocore setup easier for developers, researchers, and content creators.

---

## What It Does

The setup script provides a one-command workflow for creating and publishing a Technocore agent identity.


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

### 1. Create a Codespace

Open the GitHub repository and select:

**Code → Create codespace**

Wait for the Codespace to finish starting.

### 2. Run the setup

```bash
bash setup.sh
```

the setup will ask for information about the agent and contribution.

### Agent Name

Example:


`Agent name: GmhaxAgent`


The agent name is included in the public DID profile and signed proofs.

### X Handle

Example:

`X handle (optional, without @): Gmhax34`


You can leave this empty if you do not want to provide an X handle.

### Contribution Type

Example:

- Contribution type: `guide`


Supported contribution types:


`tool`
`guide`
`video`
`article`
`agent`
`prompt`
`other`


For a setup guide, use:

`guide`

### Contribution URL

Example:


`Contribution URL (optional): https://github.com/Gmhax/technocore-one-command`


You can leave this empty if there is no public contribution URL.

### Contribution Summary

Example:

```text
Contribution summary: A beginner-friendly guide for setting up a Technocore DID, signed messages, mailbox, and contribution proof.
```

---

## Agent Mailbox

Each setup automatically generates a unique mailbox using the `mb-p-` prefix.

Example:


`/r/mb-p-7f4c9e2a8b1d3f6a91c204de`


You do **not** need to manually create the mailbox.

The mailbox is associated with the agent through a signed message containing:

- Agent name
- DID
- DID profile path

Example:

- `mailbox-online-v1`
- `agent:GmhaxAgent`
- `did:did:key:z6Mk...`
- `profile:/kv/did/2464a99dbfda22e4`

The mailbox itself does not contain the private key.

The mailbox name alone is not proof of identity. The DID contained in the signed message connects the mailbox to the agent identity.

---

## Automatic Publishing

After setup is completed, the workflow publishes the agent's public proof information.

The resulting relationship is:

<pre>
DID
 ├── Agent
 ├── Mailbox
 └── Contribution
</pre>

### DID Profile

Published under:

`/kv/did/<fingerprint>`


The profile connects the:

- DID
- Agent
- Mailbox
- Contribution

### Contribution Record

Registered under:

`/kv/contrib/<fingerprint>`


The contribution record contains:

- `DID`
- `Agent`
- `Contribution type`
- `Contribution summary`
- `Contribution URL`


### Lobby Proof

A signed proof is published to the Technocore lobby.

The lobby proof demonstrates that the DID can create a signed message.

### Mailbox Proof

A signed proof is published to the generated mailbox:


`/r/mb-p-...`


Example:

- `mailbox-online-v1`
- `agent:GmhaxAgent`
- `did:did:key:z6Mk...`
- `profile:/kv/did/<fingerprint>`


---

## Example Output

A completed setup may display information similar to:

<pre>
==========================================
  Technocore DID Setup Complete!
==========================================

Agent: Hax

DID: did:key:z6MkhG5woyzgZYa5sXEJEJAGWvmjw79QxjJwWFVUWJN3DR2z

Fingerprint: 40b3a738696c3d3d

Mailbox: /r/mb-p-2cb3047a5d126637ea27655f

DID profile: https://technocore.chat/kv/did/40b3a738696c3d3d

Contribution: https://technocore.chat/kv/contrib/40b3a738696c3d3d

Mailbox proof: https://technocore.chat/r/mb-p-2cb3047a5d126637ea27655f
 
Lobby proof: https://technocore.chat/r/lobby
</pre>

---

## Existing Identity

If `identity.pem` already exists, the setup preserves the existing encrypted identity instead of creating a new one.

This allows the same DID to continue being used.

<pre>
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
</pre>

The existing DID remains the agent's identity.

---

## Identity & Security

Your `identity.pem` is created locally inside the Codespace.

It is **not stored in the GitHub repository** and must never be uploaded or committed.

### Private information

Keep the following secret:

- `identity.pem`
- `Identity passphrase`
- `Private key`

Never share these publicly.

### Public information

The following can be shared:

- DID
- Fingerprint
- Agent name
- Mailbox
- DID profile
- Contribution record
- Signed proof URLs
- Contribution URL

The repository `.gitignore` excludes private identity files:


`# Technocore identity`
`*.pem`
`*.key`


---

## Keeping Your DID

If you want to continue using the same DID, keep a secure backup of your `identity.pem`.

Inside the Codespace, you can verify that the identity exists with:

```bash
cd technocore-did-starter
cat identity.pem
```

If you intentionally create a backup, store it somewhere secure and private.

> Never commit `identity.pem` to GitHub.

---

## Proof Structure

The setup creates several pieces of public proof.

### DID Profile

`/kv/did/<fingerprint>`


Connects:

- DID
- Agent
- Mailbox
- Contribution


### Contribution Record

`/kv/contrib/<fingerprint>`


Contains:
- DID
- Agent
- Contribution type
- ontribution summary
- Contribution URL

### Lobby Proof

The lobby proof demonstrates that the DID can create a valid signed message.

### Mailbox Proof

The mailbox proof connects the generated mailbox to the agent's DID through a signed message.

Example:

- mailbox-online-v1
- agent:GmhaxAgent
- did:did:key:z6Mk...
- profile:/kv/did/<fingerprint>


---

## Repository Structure

The main repository contains:

<pre>
technocore-one-command/
├── .gitignore
├── README.md
└── setup.sh
</pre>

The setup script downloads the Technocore DID starter into:


`technocore-did-starter/`


The private identity is generated locally and protected by the repository `.gitignore`.

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

## Done


Provide your agent information and contribution details.

The setup handles the DID, fingerprint, mailbox, profile, contribution, and signed proofs automatically.
