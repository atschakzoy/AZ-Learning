# General IT Notes

Practical notes on tools, concepts, and tips picked up along the way.

---

## Homebrew (macOS Package Manager)

Homebrew is a package manager for macOS. Instead of going to a website, downloading an installer, and clicking through setup — you install command-line tools with a single terminal command.

Think of it as an App Store for developer tools, but free and used from the terminal.

### Install Homebrew

Open Terminal and run:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It will ask for your Mac password and take a couple of minutes. After that, `brew` is available in your terminal from any directory.

### Core commands

```bash
brew install <tool>      # install a tool
brew uninstall <tool>    # remove a tool
brew upgrade <tool>      # update a specific tool
brew upgrade             # update everything you've installed
brew list                # see what you've installed
brew search <tool>       # check if something is available
```

### Key points

- Location doesn't matter — run `brew` from any folder, it installs system-wide
- On Apple Silicon Macs (M1/M2/M3), tools land in `/opt/homebrew/bin/`
- On Intel Macs, tools land in `/usr/local/bin/`
- After installing a tool, it's available in every terminal window immediately

### Common tools installed via Homebrew

| Tool | Command |
|------|---------|
| Azure CLI | `brew install azure-cli` |
| Git | `brew install git` |
| Terraform | `brew install terraform` |
| kubectl | `brew install kubectl` |
| Node.js | `brew install node` |
| jq (JSON processor) | `brew install jq` |
| GitHub CLI | `brew install gh` |

### Verify a tool installed correctly

After any install, confirm it worked:

```bash
brew info azure-cli    # details about the installed package
az version             # run the tool itself to confirm
```

---
