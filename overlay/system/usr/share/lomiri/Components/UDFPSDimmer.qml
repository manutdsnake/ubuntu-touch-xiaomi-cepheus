/*
 * Copyright 2025-2026 Volla Systeme GmbH
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.4
import QtQuick.Window 2.2
import Lomiri.Components 1.3
import Biometryd 0.0
import Utils 0.1

/* Necessary when using high brightness mode (HBM) to avoid blinding the user */

Item {
    id: udfps

    DeviceConfig {
        id: deviceConfig
    }

    // TODO: read USFPDS position from biometryd
    // cepheus: DeviceConfig returns these as quint8, which truncates any
    // coordinate above 255 - the Mi 9's sensor centre is 541,2006 (radius 86,
    // from persist.vendor.sys.fp.udfps.* in the vendor image).
    property real baseX: 541
    property real baseY: 2006
    property real sensorRadius: 86

    property real sensorLocationX : {
        switch (Screen.orientation) {
        case Qt.PortraitOrientation:
            return baseX
        case Qt.LandscapeOrientation:
            return baseY
        case Qt.InvertedPortraitOrientation:
            return udfps.width - baseX
        case Qt.InvertedLandscapeOrientation:
            return udfps.height - baseY
        default:
            return baseX
        }
    }

    property real sensorLocationY: {
        switch (Screen.orientation) {
        case Qt.PortraitOrientation:
            return baseY
        case Qt.LandscapeOrientation:
            return udfps.width - baseX
        case Qt.InvertedPortraitOrientation:
            return udfps.height - baseY
        case Qt.InvertedLandscapeOrientation:
            return baseX
        default:
            return baseY
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.9
    }

    Rectangle {
        id: indicator
        width: udfps.sensorRadius * 2
        height: width
        radius: width / 2
        color: "white"
        x: udfps.sensorLocationX - udfps.sensorRadius
        y: udfps.sensorLocationY - udfps.sensorRadius
    }
}
