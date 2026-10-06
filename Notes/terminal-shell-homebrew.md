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

## Terminal, Shell, Zsh, Bash — What Each One Is

These words get used interchangeably but they mean different things.

**Terminal**
The application on your Mac that gives you a text window to type commands. It's just the window — the glass. On Mac it's called Terminal.app. It doesn't do anything itself, it just displays what's happening inside.

**Shell**
The program running *inside* the terminal that actually understands and executes your commands. When you type `az login` and press Enter, the shell reads that, figures out what to do, and runs it. The terminal is the window, the shell is the brain.

**Zsh (Z Shell)**
A specific shell. This is the default shell on modern Macs. When you open Terminal on your Mac, you're using Zsh.

**Bash (Bourne Again Shell)**
Another shell — older, and the default on Linux. Works almost identically to Zsh for everyday use. Most scripts and tutorials online are written in Bash. Your Mac has it installed but uses Zsh by default.

**Command Line**
Just another name for the terminal + shell combined. Same thing as terminal in casual usage.

**Shell Scripting**
Instead of typing commands one by one, you save them in a text file (a script) and run the whole file at once. It's still the same `az`, `git`, `ls` commands — just written in a file instead of typed live.

**Git**
A version control tool — completely separate from the shell. You use it from the shell by typing `git` commands, but Git itself is a standalone program that tracks changes to files.

```
Your Mac
└── Terminal.app (the window)
    └── Zsh (the shell — reads your commands)
        ├── az login         → talks to Azure
        ├── git push         → talks to Git
        ├── brew install     → talks to Homebrew
        └── ls               → lists files
```

Everything you type goes through the shell. The shell figures out which program to call.

---

## Commands — az, git, brew, ls and others

These are called **commands** or **CLI tools**. Each one is a separate program installed on your Mac. You call them by typing their name in the terminal:

| Command | Full name | What it does |
|---------|-----------|--------------|
| `az` | Azure CLI | Manages Azure resources |
| `git` | Git | Version control |
| `brew` | Homebrew | Installs/manages tools on Mac |
| `ls` | List | Shows files in the current folder |
| `cd` | Change Directory | Moves you into a different folder |
| `curl` | Client URL | Downloads things from the internet |
| `jq` | JSON Query | Processes and filters JSON |

The ones built into the system (`ls`, `cd`) are called **built-in commands**. The ones you install separately (`az`, `git`, `brew`) are called **CLI tools** or **command-line tools**. In everyday conversation people just call them all "commands".

---

## Bash vs Zsh — Are They Different?

Almost identical for everything you'll do day to day. 99% of commands are exactly the same.

**The same in both:**
```bash
az login
git push
ls -la
cd myfolder
RG="rg-platform-dev"
echo $RG
```

**Small differences:**

| | Zsh | Bash |
|---|---|---|
| Default on | Mac (modern) | Linux, old Mac |
| Prompt symbol | `%` | `$` |
| Script file extension | `.zsh` or `.sh` | `.sh` |
| Autocomplete | More powerful out of the box | Basic |

**Bottom line:** You're on a Mac using Zsh. Most tutorials are written in Bash. It doesn't matter — run them anyway, they work. The differences only show up in very advanced scripting you won't hit for a long time.

---
