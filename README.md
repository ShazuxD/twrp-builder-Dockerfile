# TWRP Builder (Docker)

A ready-to-go Docker image for building TWRP recovery. 
Build TWRP without redoing the whole build-environment setup every time.

AutoSetup for Github Codespace: [Codespace-TWRP-Builder](https://github.com/ShazuxD/Codespace-TWRP-Builder).

```
docker pull shazuxdd/twrp-builder:latest
```

Docker Hub: `shazuxdd/twrp-builder:latest`

---

## What you need

- Docker, and roughly 100 GB or more of free disk space for a TWRP building
- A config file describing your device tree and all
- Optional: Telegram bot token if you want build notifications on your Bot

---

## Using it from Codespaces

[Codespace-TWRP-Builder](https://github.com/ShazuxD/Codespace-TWRP-Builder) already points its `devcontainer.json` at this image and ships with a `config.sh`. Just edit the config for your device and run `twrp-build`.

# With GH CLI
```bash
gh cs create -R ShazuxD/Codespace-TWRP-Builder -b main -m standardLinux32gb
gh cs ssh
```
---

## Local Start

### 1. Run the container

The script makes `swap` and uses `mergerfs`, so the container needs extra privileges:
```bash
docker run -it --rm \
  --privileged \
  -e RepositoryName=my-twrp-config \
  -v "$PWD/twrp:/twrp" \
  shazuxdd/twrp-builder:latest
```
By default `/twrp` is just a normal folder, nothing is merged. `merge-storage` only helps if the container can see more than one disk. A plain docker run starts on its own overlay filesystem, so it has nothing to merge. To pool real disks, bind them in and then `run sudo merge-storage`:
```bash
docker run -it --rm --privileged \
  -e RepositoryName=my-twrp-config \
  -v /tmp:/tmp -v /vscode:/vscode -v /workspaces:/workspaces \
  shazuxdd/twrp-builder:latest
```
(Only useful if those paths exist on your host, like inside a Codespace.)
`RepositoryName` is the name of the folder that holds your config.sh. The script looks for `/twrp/$RepositoryName/config.sh`. It's already set in the Codespace's own terminal, but not inside a container you start with `docker run`, so pass it with `-e`.

### 2. Add your config

Put a `config.sh` in your repo folder (so it ends up at `/twrp/<RepositoryName>/config.sh`). Here's a starting point:

```bash
# Where to get the TWRP source
MANIFEST_URL="https://github.com/minimal-manifest-twrp/platform_manifest_twrp_aosp"
MANIFEST_BRANCH="twrp-12.1"

# Your device tree
DEVICE_TREE_URL="https://github.com/youruser/device_vendor_codename"
DEVICE_TREE_BRANCH="android-12.1"
DEVICE_PATH="device/vendor/codename"

# Optional: a common tree, if your device needs one
# COMMON_TREE_URL=""
# COMMON_DEVICE_TREE_BRANCH=""
# COMMON_PATH=""

# What to build
MAKEFILE_NAME="twrp_codename"
BUILD_TARGET="boot"        # use "boot" for bootimage / boot.img
                           # use "recovery" for recoveryimage / recovery.img
                           # use "vendorboot" for vendorbootimage

# Optional extras
SWAP_SIZE=16               # 16, 16G or 8192M. Bare numbers mean GB
SWAP_FILE="/tmp/swapfile"  # always kept inside /tmp
UPLOAD_CCACHE=y            # use ccache for the build, then upload it afterwards
CCACHE_URL=                # ccache url, uses aria2
TG_CHAT_ID=""              # Telegram notifications
TG_TOKEN=""
```

### 3. Build

```bash
twrp-build
```

That's it. For a clean build:

```bash
twrp-build --build_type clean
```

When it finishes, you get a download link for the image in the terminal (and on Telegram if you set that up).

---

## Options

| Option | What it does |
| --- | --- |
| `--build_type normal` | Default. Incremental build |
| `--build_type clean` | Runs `make clean` before building |
| `--config <file>` | Use a different config file instead of `/twrp/$RepositoryName/config.sh` |
| `-h`, `--help` | Show help |

Typing just `clean` also works, for old habits.

## Config variables

| Variable | Required | Notes |
| --- | --- | --- |
| `MANIFEST_URL`, `MANIFEST_BRANCH` | Yes | The TWRP manifest |
| `DEVICE_TREE_URL`, `DEVICE_TREE_BRANCH`, `DEVICE_PATH` | Yes | Device tree gets cloned into `DEVICE_PATH` |
| `COMMON_TREE_URL`, `COMMON_DEVICE_TREE_BRANCH`, `COMMON_PATH` | No | For a common tree (optional) |
| `MAKEFILE_NAME` | Yes | The lunch target |
| `BUILD_TARGET` | Yes | `boot`, `recovery`, `vendorboot`, etc.|
| `SWAP_SIZE` | No | Skipped if unset. Eg: 16G |
| `SWAP_FILE` | No | Defaults to `/tmp/swapfile`. Anything outside `/tmp` gets moved into `/tmp` |
| `UPLOAD_CCACHE` | No | Set to `y` to build with ccache |
| `CCACHE_URL` | No | Add ccache url to download ccache, set `UPLOAD_CCACHE` to `y`|
| `TG_CHAT_ID`, `TG_TOKEN` | No | Telegram notifications |

## Good to know
- **Git identity.** The image ships with a default git name and email. Change them inside the container if you plan to commit:
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "you@example.com"
  ```

## Building the image yourself

```bash
git clone https://github.com/ShazuxD/twrp-builder-Dockerfile
cd twrp-builder-Dockerfile
docker build -t twrp-builder .
```

## Credits

- [ghostrider-reborn/scripts](https://github.com/ghostrider-reborn/scripts) for the Ubuntu build-environment setup

Issues and PRs are welcome. If something breaks, paste the full terminal output and I'll take a look.
