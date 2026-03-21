// swift-tools-version: 5.9
// LibreStage – iOS App
// Keine externen SPM-Abhängigkeiten. Keychain wird über das native Security-Framework abgewickelt.

import PackageDescription

let package = Package(
    name: "LibreStage",
    platforms: [
        .iOS(.v17)
    ],
    targets: [
        .target(
            name: "LibreStage",
            path: "LibreStage"
        )
    ]
)
