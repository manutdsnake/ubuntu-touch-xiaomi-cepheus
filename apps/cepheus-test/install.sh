#!/bin/sh
# Install Cepheus Test for phablet (run on the phone as root or phablet).
set -e
D=/home/phablet/.local/share/cepheus-test
mkdir -p "$D" /home/phablet/.local/share/applications
cp main.qml TestPage.qml backend.py icon.svg "$D/"
cp cepheus-test.desktop /home/phablet/.local/share/applications/
chown -R 32011:32011 "$D" /home/phablet/.local/share/applications/cepheus-test.desktop
