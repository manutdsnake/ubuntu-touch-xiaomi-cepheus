#!/bin/sh
# Install Cepheus Remote for phablet (run on the phone).
set -e
D=/home/phablet/.local/share/cepheus-remote
mkdir -p "$D" /home/phablet/.local/share/applications
cp main.qml backend.py irproto.py tvcodes.json icon.svg "$D/"
cp cepheus-remote.desktop /home/phablet/.local/share/applications/
chown -R 32011:32011 "$D" /home/phablet/.local/share/applications/cepheus-remote.desktop
