Ganbattea – tea timer & stopwatch
=================================

Install (current user, no root needed):

    ./install.sh

This copies the binary to ~/.local/bin, adds "Ganbattea" to your start menu and installs the icon.
For all users:      ./install.sh --system
Uninstall:          ./install.sh --uninstall   (add --purge to delete saved presets)

Runtime requirements
--------------------
Qt 5.15 (Qt Quick, Window and Layouts modules) and ALSA/PulseAudio for the alarm sound.

  Debian/Ubuntu:  sudo apt install libqt5quick5 libqt5qml5 qml-module-qtquick2 \
                    qml-module-qtquick-window2 qml-module-qtquick-layouts libasound2
  Fedora:         sudo dnf install qt5-qtbase qt5-qtdeclarative alsa-lib
  Arch:           sudo pacman -S qt5-base qt5-declarative alsa-lib
  openSUSE:       sudo zypper install libQt5Quick5 libQt5Qml5 alsa-lib

Your presets are stored in ~/.config/ganbattea/presets.json
