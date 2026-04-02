# libre-stage iOS App

Native SwiftUI-App für [libre-stage](https://github.com/libre-stage/libre-stage) – die interne Band-Management-Plattform.

## Voraussetzungen

| Tool | Version |
|---|---|
| Xcode | 15+ |
| iOS Deployment Target | 17.0+ |
| Swift | 5.9+ |
| Apple Developer Account | Für Installation auf echten Geräten erforderlich |

## Projekt öffnen

```bash
open ios/LibreStage.xcodeproj
```

Das Projekt nutzt keine externen SPM-Abhängigkeiten für die Auth-Speicherung; Tokens werden nativ über das Security-Framework im Keychain gespeichert.

## Struktur

```
ios/
├── LibreStage.xcodeproj/       ← Xcode-Projektdatei
├── Package.swift               ← SPM-Abhängigkeiten (für Referenz)
└── LibreStage/
    ├── App/                    ← Einstiegspunkt, TabView
    ├── Core/                   ← APIClient, AuthManager, SettingsStore
    ├── Models/                 ← Codable Datenmodelle (Spiegel der Backend-Schemas)
    ├── ViewModels/             ← @Observable ViewModels je Feature
    ├── Views/
    │   ├── Auth/               ← LoginView
    │   ├── Dashboard/          ← To-dos, Votes, Umfragen-Links
    │   ├── Gigs/               ← GigsView, GigDetailView, LiveModeView
    │   ├── Rehearsals/         ← RehearsalsView, RehearsalDetailView
    │   ├── Songs/              ← SongsView, CandidatesView
    │   ├── Surveys/            ← SurveysView, SurveyDetailView
    │   ├── Profile/            ← ProfileView (Passwort, Server-URL, Logout)
    │   └── Components/         ← ErrorBanner, SkeletonRow
    └── Assets.xcassets/
```

## Erster Start

1. **Xcode öffnen** → `LibreStage.xcodeproj`
2. **Signing**: `Signing & Capabilities` → eigenes Team eintragen
3. **Gerät auswählen** (Simulator oder echtes iPhone)
4. **Build & Run** (`⌘R`)
5. Im Login-Screen: Server-URL eingeben (z. B. `https://band.example.com`), dann Benutzername und Passwort

## Architektur-Entscheidungen

| Thema | Entscheidung |
|---|---|
| Token-Speicherung | Keychain via *KeychainAccess* |
| Offline-Unterstützung | Bewusst **keine** – alle Daten werden live geladen |
| Token-Rotation | Refresh-Token wird **nicht rotiert** (Multi-Device-Support) |
| Admin-Funktionen | Nicht enthalten – weiterhin über Webinterface |
| Push-Benachrichtigungen | Nicht in diesem Scope |

## Nächste Schritte

- [ ] AppIcon in `Assets.xcassets/AppIcon.appiconset/` als 1024×1024px PNG hinterlegen
- [ ] Bundle-ID in Build Settings anpassen (`de.libre-stage.app`)
- [ ] TestFlight-Distribution einrichten (Apple Developer Account erforderlich)

## Release-Hinweis

- Vor App-Store- oder TestFlight-Upload die Checkliste in `ios/APP_STORE_RELEASE_CHECKLIST.md` vollständig abhaken.
- Das Xcode-Projekt hat kein fest verdrahtetes Team; setze dein Team lokal in `Signing & Capabilities`.

