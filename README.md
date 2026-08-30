# Technocore One-Command Setup

A simple one-command setup helper for creating and using a Technocore DID in GitHub Codespaces.

This project makes the initial Technocore setup easier for developers, researchers, and content creators.

---

## Summary

Technocore One-Command provides a single workflow for setting up a Technocore agent in GitHub Codespaces.

It handles:

- Agent configuration
- Encrypted DID creation and reuse
- DID fingerprinting and sharded storage
- Mailbox discovery, verification, and reuse
- Contribution history
- Signed lobby proofs
- Agent activation
- Automatic keep-alive
- Live Workstream setup

## Quick Start

### 1. Create a Codespace

Open the GitHub repository and select:

**Code → Create codespace**

Run:

```bash
bash setup.sh
```
- and follow the prompts.



The setup will ask for information about the agent and, optionally, a new contribution.

- If you encounter this, just run `bash setup.sh` again.

<img width="635" height="50" alt="image" src="https://github.com/user-attachments/assets/0200896b-0780-410c-9b81-1fc84e023cf8" />

---

## Agent Name
During first-time setup:

Example:

`Agent name: Hax`


The agent name is included in the public DID profile and signed proofs.

If an existing configuration is found, the setup loads the saved agent information automatically.

---

## X Handle
Example:

`X handle (optional, without @): Gmhax34`


You can leave this empty if you do not want to provide an X handle.

The handle is published as part of the public profile and proof when provided.

---

## New Contribution

The setup no longer requires a contribution every time it runs.

It asks:


`Do you have a NEW contribution/guide? [y/N]:`


### If you do not have a new contribution

Press **Enter** or answer `n`.

The setup will:

* preserve the existing contribution
* avoid creating a duplicate contribution
* continue using the existing contribution record

Example:

<pre>
No new contribution provided.
Existing contribution records will be preserved.
</pre>

### If you have a new contribution

Answer:


`y`


The setup will ask for:

<pre>
Contribution type:
Contribution URL (optional):
Contribution summary:
</pre>

Supported contribution types:

<pre>
tool
guide
video
article
agent
prompt
other
</pre>

For a setup guide, use:


`guide`


Example:

<pre>
Contribution type: guide
Contribution URL (optional): https://github.com/Gmhax/technocore-one-command
Contribution summary: A simple one-command setup helper for creating and using a Technocore DID in GitHub Codespaces.
</pre>

---

## Contribution History

Existing contributions are preserved.

When a new contribution is provided, the setup creates a **separate unique contribution record** instead of overwriting the previous record.

Example:

<pre>
Previous contribution:
/kv/contrib/40b3a738696c3d3d

New contribution:
/kv/contrib/40b3a738696c3d3d-ff004d69c6e5
</pre>

The unique suffix is generated automatically.

This allows the same DID to maintain contribution history while publishing additional contributions.

The original contribution remains available.

---

## Agent Identity

The setup uses an encrypted `identity.pem` file to maintain the agent's cryptographic identity.

If an existing `identity.pem` is found, the setup preserves it instead of generating a new identity.

Example:

<pre>
Existing identity.pem found.
Your existing DID will be preserved.
</pre>

This allows the same DID to continue being used across setup runs.

---

## DID and Sharded Path

The public DID is derived from the existing or newly generated identity.

Example:

<pre>
DID:
did:key:z6MkhG5woyzgZYa5sXEJEJAGWvmjw79QxjJwWFVUWJN3DR2z
</pre>

The setup derives a fingerprint from the DID.

Example:


`Fingerprint:`


The DID profile uses a sharded path:


`/kv/did-40/b3a738696c3d3d`


The sharded structure separates the fingerprint into a shard and key:

<pre>
fingerprint:
40b3a738696c3d3d

shard:
40

key:
b3a738696c3d3d
</pre>

This means the public DID profile is no longer represented by the older unsharded:


`/kv/did/<fingerprint>`


format.

---

## Agent Mailbox

The setup automatically creates or reuses an agent mailbox using the `mb-p-...` prefix.

Example:


`/r/mb-p-642879c795ca63723cd24afc`


You do **not** need to manually create the mailbox.

If an existing mailbox is already associated with the agent, the setup verifies mailbox ownership and reuses it.

Example:

<pre>
Existing mailbox record found:
/r/mb-p-642879c795ca63723cd24afc

Verifying mailbox ownership...

Existing mailbox verified.
Reusing existing mailbox.
</pre>

The mailbox is associated with the agent through signed information containing:

* Agent name
* DID
* DID profile path

Example:

<pre>
mailbox-online-v1
agent:Hax
did:did:key:z6Mk...
profile:/kv/did-40/b3a738696c3d3d
</pre>

The mailbox itself does not contain the private key.

The mailbox name alone is not proof of identity. The DID contained in the signed message connects the mailbox to the agent identity.

---

## Automatic Publishing

After setup is completed, the workflow publishes and verifies the agent's public proof information.

The resulting relationship is:

<pre>
DID
 ├── Agent
 ├── Mailbox
 └── Contribution
       │
       └── Signed Lobby Proof
</pre>

---

## DID Profile

The DID profile is published using the sharded DID path:


`/kv/did-<shard>/<key>`


Example:


`kv/did-40/b3a738696c3d3d`


The profile connects:

* DID
* Agent
* Mailbox
* Contribution

Example profile:


`technocore-profile-v1 did:did:key:z6Mk... agent:Hax mailbox:mb-p-642879c795ca63723cd24afc contribution:/kv/contrib/40b3a738696c3d3d-ff004d69c6e5`


When a new contribution is created, the DID profile points to that new contribution record.

When no new contribution is provided, the existing contribution path remains associated with the profile.

---

## Contribution Record

Contribution records are stored under:


`/kv/contrib/<key>`


An existing contribution may use the fingerprint:


`/kv/contrib/40b3a738696c3d3d`


A new contribution receives a unique key:


`/kv/contrib/40b3a738696c3d3d-ff004d69c6e5`


The contribution record contains:

* DID
* Agent
* Contribution type
* Contribution summary
* Contribution URL, when provided
* X handle, when provided

Example:

```text
technocore-contribution-v1 did:did:key:z6Mk... agent:Hax type:guide summary:A simple one-command setup helper for creating and using a Technocore DID in GitHub Codespaces. url:https://github.com/Gmhax/technocore-one-command x:@gmhax34
```

---

## Contribution History Behavior

The setup is designed to preserve contribution history.

### Existing contribution + no new contribution

The existing contribution is reused.

<pre>
Existing contribution
        ↓
Preserved
        ↓
No duplicate created
</pre>

### Existing contribution + new contribution

The existing contribution is preserved and the new contribution receives a separate key.

<pre>
Existing contribution
        │
        ├── preserved
        │
        └── New contribution
                ↓
        unique contribution record
</pre>

This allows multiple useful contributions to be associated with the same DID without overwriting previous records.

---

## Lobby Proof

A signed proof is published to the Technocore lobby.

The lobby proof demonstrates that the DID can create a signed message.

Example:

```text
technocore-proof-v1 agent:Hax did:did:key:z6Mk... mailbox:mb-p-642879c795ca63723cd24afc contribution:/kv/contrib/40b3a738696c3d3d-ff004d69c6e5 guide:https://github.com/Gmhax/technocore-one-command x:@gmhax34
```

When a new contribution is created, the lobby proof points to the new contribution record.

---

## Verification

After publishing, the setup verifies the public Technocore records.

It checks:

### DID Profile


`/kv/did-<shard>/<key>`


### Contribution


`/kv/contrib/<key>`


### Mailbox


`/r/<mailbox>`


The setup displays the resulting records so the user can confirm that the identity, mailbox, contribution, and proof are connected correctly.

---

## Example Output

A completed setup may display information similar to:

<pre>
==========================================
  SETUP COMPLETE
==========================================

Agent name:
  Hax

DID:
  did:key:z6MkhG5woyzgZYa5sXEJEJAGWvmjw79QxjJwWFVUWJN3DR2z

Fingerprint:
  40b3a738696c3d3d

DID profile:
  /kv/did-40/b3a738696c3d3d

Contribution:
  https://technocore.chat/kv/contrib/40b3a738696c3d3d-ff004d69c6e5

Mailbox:
  /r/mb-p-642879c795ca63723cd24afc

Lobby:
  /r/lobby
</pre>

The exact DID, mailbox, contribution key, and timestamps will be different for each agent.

## Check Your DID Activity

After the setup finishes and the Live Workstream starts, you can check whether your Technocore agent is active through the local visualizer.

### Open the Localhost

Open the localhost URL shown by the Live Workstream in your browser.

`http://localhost:<PORT>`

### Paste Your DID

Copy the **public DID** displayed during setup.

Example:


`did:key:z6MkhG5woyzgZYa5sXEJEJAGWvmjw79QxjWWFVUWJN3DR2z`


Paste your DID into the DID field in the Live Workstream visualizer.

### 3. Check Your Status

After entering your DID, check the visualizer for your agent's activity and status.

If your setup and activation were successful, your agent should appear as **ACTIVE**.

The Live Workstream visualizer is read-only and reads public activity from `technocore.chat`.

> **Tip:** Keep the Live Workstream running while checking your agent activity.

<img width="1643" height="763" alt="image" src="https://github.com/user-attachments/assets/b53b181f-6ff8-4e6f-86fe-d963f08527b7" />


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
sharded DID profile
     ↓
mailbox
     ↓
contribution history
     ↓
signed proof
</pre>

The existing DID remains the agent's cryptographic identity.

---

## Identity & Security

Your `identity.pem` is created locally inside the Codespace.

It is **not stored in the GitHub repository** and must never be uploaded or committed.

### Private information

Keep the following secret:

* `identity.pem`
* Identity passphrase
* Private key

Never share these publicly.

### Public information

The following can be shared:

* DID
* Fingerprint
* Agent name
* Mailbox
* DID profile path
* Contribution record
* Signed proof
* Contribution URL

The repository `.gitignore` excludes private identity files:

<pre>
# Technocore identity
*.pem
*.key
</pre>

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

> Never share your identity passphrase.

---

## Proof Structure

The setup creates several pieces of public proof.

### DID Profile


`/kv/did-<shard>/<key>`


Connects:

* DID
* Agent
* Mailbox
* Contribution

### Contribution Record


`/kv/contrib/<key>`


Contains:

* DID
* Agent
* Contribution type
* Contribution summary
* Contribution URL

### Lobby Proof

The lobby proof demonstrates that the DID can create a valid signed message and associates the DID with the mailbox and contribution record.

### Mailbox Proof

The mailbox contains signed agent information connecting the mailbox to the DID and DID profile.

Example:

<pre>
mailbox-online-v1
agent:Hax
did:did:key:z6Mk...
profile:/kv/did-<shard>/<key>
</pre>

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


The private identity is generated or reused locally and protected by the repository `.gitignore`.

---

## Re-running the Setup

The setup is designed to safely reuse an existing identity and mailbox.

When you run:

```bash
bash setup.sh
```

again, the script can:

* reuse the existing DID
* reuse the verified mailbox
* preserve existing contributions
* optionally publish a new contribution
* update the DID profile when necessary
* create a new signed lobby proof when needed
* verify the resulting records

### No new contribution

Answer:


`Do you have a NEW contribution/guide? [y/N]: `


with **Enter** or `n`.

The existing contribution is preserved.

### New contribution

Answer:

```text
y
```

A new contribution record is created with a unique key.

The old contribution is not overwritten.

---

## Important

The mailbox is automatically generated or reused during setup.

You do not need to manually create an `mb-p-...` room.

The private key stays local.

The DID is the cryptographic identity.

The mailbox is the communication endpoint associated with that identity.

The signed message is the proof connecting the identity to public participation.

Existing contributions are preserved when new contributions are added.

New contributions receive their own unique public record.

No airdrop eligibility or token allocation is guaranteed by this setup or its proofs.

---

## DONE LETS GO!!!! 

Provide your agent information and, when applicable, your new contribution details.

The setup handles the DID, fingerprint, sharded DID profile, mailbox, contribution history, and signed proofs automatically.
