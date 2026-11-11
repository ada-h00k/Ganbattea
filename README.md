# Ganbattea

**Ganbattea** is a desktop timekeeping application built with Rust and Qt 6 / Qt Quick. It brings a countdown timer, a stopwatch, and daily alarms together in one focused interface.

[![Build and publish Flatpak](https://github.com/ada-h00k/Ganbattea/actions/workflows/flatpak-release.yml/badge.svg)](https://github.com/ada-h00k/Ganbattea/actions/workflows/flatpak-release.yml)
[![License: AGPL-3.0-only](https://img.shields.io/badge/license-AGPL--3.0--only-blue.svg)](LICENSE)

## Features

- **Countdown timer** — set hours, minutes, and seconds; start, pause, and reset the countdown.
- **Stopwatch** — start, pause, reset, and record lap times.
- **Daily alarms** — create multiple alarms with custom labels, enable or disable them, and remove them.
- **Local persistence** — alarm definitions are stored as JSON in the user's application data directory.
- **Alarm notification** — an in-app notification and repeating sound are triggered when a timer or alarm expires.

On Linux, daily alarms are registered as persistent systemd user timers and continue to run when Ganbattea is closed. When an alarm is due, a systemd service launches Ganbattea with the alarm ID, and the app opens the alarm dialog and plays its sound. The user session must be active for the alarm to appear. If the computer is suspended, the calendar timer is handled after resume; Ganbattea does not wake a suspended or powered-off computer. On platforms without systemd, alarms are checked while the app is open.

## Technology

- Rust 2021
- CXX-Qt 0.10
- Qt 6, Qt Quick, Qt Quick Controls, and Qt Multimedia
- QML user interface

## Run from source

### Requirements

- Rust 1.85 or newer and Cargo
- Qt 6 with Qt Declarative / Quick Controls and Qt Multimedia
- CMake 3.24 or newer
- A C++17 compiler
- `qmake` available on `PATH` (or set `QMAKE` explicitly)

### Debian / Ubuntu

```bash
sudo apt update
sudo apt install build-essential cmake ninja-build qt6-base-dev qt6-base-dev-tools \
  qt6-declarative-dev qt6-multimedia-dev qml6-module-qtquick \
  qml6-module-qtquick-controls qml6-module-qtquick-layouts \
  qml6-module-qtmultimedia
```

Install Rust using [rustup](https://rustup.rs/), then run:

```bash
cargo run --release
```

If `qmake` is not on `PATH`, set its location first:

```bash
QMAKE=/usr/lib/qt6/bin/qmake cargo run --release
```

On Windows, set `QMAKE` to the `qmake.exe` installed with your Qt 6 kit before running Cargo.

## Flatpak

Ganbattea includes a Flatpak manifest at [`packaging/flatpak/de.ganbattea.app.yml`](packaging/flatpak/de.ganbattea.app.yml). The manifest uses the KDE Qt 6.11 runtime and the Rust stable SDK extension.

### Install the latest build from the GitHub Flatpak repository

After the GitHub Actions workflow has completed and GitHub Pages has been enabled (see [GitHub publishing](#github-publishing)), install the repository and application with:

```bash
flatpak remote-add --user --if-not-exists --no-gpg-verify ganbattea \
  https://ada-h00k.github.io/Ganbattea/repo
flatpak install --user ganbattea de.ganbattea.app
```

The example above is for the unsigned repository fallback. For a signed repository, use the generated `ganbattea.flatpakrepo` file instead; it contains the repository URL and its GPG public key:

```bash
flatpak remote-add --user --if-not-exists ganbattea \
  https://ada-h00k.github.io/Ganbattea/ganbattea.flatpakrepo
flatpak install --user ganbattea de.ganbattea.app
```

You can also download the `.flatpak` bundle attached to any automated GitHub commit release and install it directly:

```bash
flatpak install --user ./Ganbattea-COMMIT.flatpak
```

### Build the Flatpak locally

Install Flatpak, Flatpak Builder, and add Flathub:

```bash
sudo apt install flatpak flatpak-builder ostree python3-aiohttp python3-tomlkit
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

Generate a Cargo lockfile if the repository does not contain one yet, then generate the offline Cargo source manifest:

```bash
if [ ! -f Cargo.lock ]; then cargo generate-lockfile; fi
curl -L https://raw.githubusercontent.com/flatpak/flatpak-builder-tools/master/cargo/flatpak-cargo-generator.py \
  -o /tmp/flatpak-cargo-generator.py
python3 /tmp/flatpak-cargo-generator.py Cargo.lock -o packaging/flatpak/cargo-sources.json
```

Build and export the application:

```bash
flatpak-builder --user --install-deps-from=flathub --force-clean \
  --disable-rofiles-fuse --collection-id=de.ganbattea.app --repo=repo build-dir \
  packaging/flatpak/de.ganbattea.app.yml
flatpak build-update-repo repo
flatpak build-bundle --runtime-repo=https://dl.flathub.org/repo/flathub.flatpakrepo \
  repo Ganbattea.flatpak de.ganbattea.app stable
```

`cargo-sources.json` and `Cargo.lock` are generated build inputs. Commit `Cargo.lock` to your Git repository so future builds resolve the same dependency versions.

## GitHub publishing

The workflow in [`.github/workflows/flatpak-release.yml`](.github/workflows/flatpak-release.yml) automates Flatpak packaging and publishing.

On every push to `main` or `master`, it:

1. Reads the pushed commit list and builds a Flatpak for each commit in that push that contains the Flatpak manifest and AGPL package metadata.
2. Creates a GitHub **pre-release** tagged `commit-<full-sha>` for every commit, with the matching `.flatpak` bundle and `.flatpakrepo` remote configuration attached.
3. Publishes the latest commit as an OSTree Flatpak repository on GitHub Pages.

For the first deployment:

> **Private repository note:** This repository is currently private. GitHub Pages is available for private repositories on GitHub Pro, Team, and Enterprise; GitHub Free requires a public repository. The published Pages site is public, even when its source repository is private. Do not place private files in the Pages artifact.

1. Push the project to a GitHub repository using `main` or `master` as the default branch.
2. Open **Settings → Pages** and set **Build and deployment → Source** to **GitHub Actions**.
3. Open **Settings → Actions → General → Workflow permissions** and allow the workflow to write repository contents. The workflow declares its required permissions explicitly; the `GITHUB_TOKEN` must be allowed to create releases.
4. Push a commit. The workflow will build and publish the Flatpak. GitHub Pages will host the repository at `https://ada-h00k.github.io/Ganbattea/`.

### Recommended: sign the Flatpak repository

Flatpak repositories should be GPG-signed. The workflow supports signing when these GitHub settings are configured:

- Add a dedicated GPG **private key** (ASCII-armored export) as the repository Actions secret `FLATPAK_GPG_PRIVATE_KEY`.
- Add the matching key ID as the repository Actions variable `FLATPAK_GPG_KEY_ID`.

The workflow imports the private key, signs the exported Flatpak commit and repository summary, and embeds the public key in `ganbattea.flatpakrepo`. Use a dedicated publishing key and protect access to the repository's Actions secrets. Do not commit a private key to the repository.

When those settings are absent, the workflow still publishes an unsigned repository. Flatpak clients must then use `--no-gpg-verify`; this is less secure and is provided only as a convenient initial setup.

## Alarm data location

- Linux: `$XDG_DATA_HOME/Ganbattea/alarms.json`, or `~/.local/share/Ganbattea/alarms.json`
- macOS: `~/Library/Application Support/Ganbattea/alarms.json`
- Windows: `%APPDATA%\Ganbattea\alarms.json`
- Flatpak: the application's private data directory, under `~/.var/app/de.ganbattea.app/data/`

## Project layout

```text
Ganbattea/
├── .github/workflows/flatpak-release.yml  # Build, GitHub Releases, and Pages publishing
├── assets/alarm.wav                       # Alarm sound
├── packaging/flatpak/                     # Flatpak manifest and generated Cargo sources
├── qml/main.qml                           # Qt Quick interface
├── src/clockwork.rs                       # Timer, stopwatch, and alarm logic
├── src/ganbattea.rs                       # CXX-Qt QObject and QML bridge
├── src/main.rs                            # Qt application entry point
├── build.rs                               # Qt/QML build configuration
├── Cargo.toml
└── LICENSE                                # GNU AGPL v3
```

## Tests

Run the Rust unit tests with:

```bash
cargo test
```

## License

Ganbattea is free software licensed under the **GNU Affero General Public License, version 3 only** (`AGPL-3.0-only`). See [LICENSE](LICENSE) for the complete license text.
