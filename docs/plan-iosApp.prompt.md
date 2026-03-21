# Plan: iOS-App für libre-stage (final & abgestimmt)

Native SwiftUI-App (iOS 17+) im Verzeichnis `ios/`, konfigurierbarer Server-URL im Login-Screen, JWT via KeychainAccess (SPM), kein Offline-Cache, Live-Modus read-only für `user`, kein Push, kein Admin-Bereich. **6 Tabs**, Live-Modus per Button aus Gig-Detail, Kandidaten als Unterseite im Songs-Tab, `.gitignore` für Xcode-Artefakte.

---

## Schritte

### ✅ 1. Xcode-Projekt `LibreStage` anlegen

- Neues SwiftUI-App-Target im Verzeichnis `ios/` des Repos
- iOS 17 Deployment Target
- SPM-Abhängigkeit: [KeychainAccess](https://github.com/kishikawakatsuki/KeychainAccess)
- Xcode-Artefakte in die bestehende `.gitignore` eintragen:
  - `ios/DerivedData/`
  - `ios/**/*.xcuserstate`
  - `ios/**/xcuserdata/`
  - `ios/.build/`

---

### ✅ 2. Infrastruktur-Schicht (`Core/`-Gruppe, 3 Dateien)

#### `SettingsStore.swift`
- Liest/schreibt Backend-URL via KeychainAccess
- Bei Änderung der URL → Tokens löschen + Login-Screen triggern

#### `AuthManager.swift`
- `@Observable`-Klasse
- Führt `POST /login`, `POST /logout`, `GET /me` aus
- Hält `accessToken`, `refreshToken`, `currentUser: UserOut`
- Berechnete Property `userRole: UserGroup` (`admin` / `editor` / `user`)
- Alles in der Keychain persistiert
- Refresh-Token wird **nicht rotiert** (Multi-Device-Support, vgl. `POST /refresh` in `main.py`)

#### `APIClient.swift`
- `URLSession async/await`-Wrapper
- `Authorization: Bearer <token>`-Header bei jedem Request
- Bei HTTP 401 → `POST /refresh` → Request automatisch wiederholen
- Typisiertes `AppError`-Enum:
  - `unauthorized`
  - `notFound`
  - `serverError(statusCode: Int)`
  - `networkError(Error)`
- Fehler werden via zentrales `ErrorBanner`-Overlay in der UI angezeigt

---

### ✅ 3. Codable-Datenmodelle (`Models/`-Gruppe)

Exakte Spiegel der Pydantic-Schemas aus `backend/schemas.py` und `backend/main.py`:

| Swift-Struct | Backend-Schema | Endpunkt |
|---|---|---|
| `UserOut`, `UserGroup`, `UserStatus` | `UserOut`, `UserGroup`, `UserStatus` | `GET /me` |
| `UserTodoList`, `UserTodo`, `SongForFeedback`, `SurveyForFeedback` | `UserTodoList` | `GET /user_todos` |
| `GigOut` | `GigOut` | `GET /gigs` |
| `GigSetlistOut`, `SetInGigOut`, `SongInSetOut` | `GigSetlistOut` | `GET /gigs/{id}/setlist` |
| `GigSetListLiveMode`, `SetInGigLM`, `SongInSetLM` | `GigSetListLiveMode` | `GET /gigs_lm/{id}` |
| `RehListElem` | `RehListElem` | `GET /reh` |
| `SongOut` | `SongOut` | `GET /songs` |
| `SongCandidateOut`, `SongFeedbackBase` | `SongCandidateOut` | `GET /songs/candidates` |
| `SurveyList` | `SurveyList` | `GET /surveys` |
| `SurveyQuestionOut` | `SurveyQuestionOut` | `GET /surveys/{id}` |
| `PasswordUpdateRequest` | `PasswordUpdateRequest` | `PUT /change_password` |

---

### ✅ 4. Login-Screen (`Views/Auth/LoginView.swift`)

- Erscheint wenn kein gültiger Token in der Keychain vorhanden ist
- Drei Felder:
  - **Server-URL** (vorausgefüllt aus letztem gespeichertem Wert in der Keychain)
  - **Benutzername**
  - **Passwort**
- „Verbinden"-Button:
  1. Validiert URL via `GET /health` (prüft ob Backend erreichbar und DB verbunden)
  2. Führt `POST /login` aus
  3. Speichert `access_token`, `refresh_token` und URL in der Keychain
- Fehler werden inline unter den jeweiligen Feldern angezeigt
- Bei Server-URL-Änderung im Profil-Tab → Tokens löschen + Login-Screen erneut anzeigen

---

### ✅ 5. Feature-Views + ViewModels

6 Tabs, je ViewModel lädt per `.task {}` frisch vom Server. Kein lokaler Cache.

---

#### Dashboard-Tab — `DashboardView` / `DashboardViewModel`

- Endpunkt: `GET /user_todos`
- Drei Sektionen:
  1. **Proben-To-dos** – abhaken via `PUT /user_todos_done` (alle Rollen)
  2. **Ausstehende Song-Votes** – NavigationLink → `CandidatesView`
  3. **Offene Umfragen** – NavigationLink → `SurveysView`
- Tab-Badge = `todo.count + songs_to_feedback.count + surveys_to_feedback.count`

---

#### Gigs-Tab — `GigsView` → `GigDetailView` → `LiveModeView`

- `GigsView`: Liste aller Gigs (`GET /gigs`), sortiert nach Datum
- `GigDetailView`: Gig-Infos + vollständige Setlist (`GET /gigs/{id}/setlist`); prominenter **„Live-Modus"**-Button öffnet `LiveModeView` via `NavigationLink`
- `LiveModeView` (`GET /gigs_lm/{id}`):
  - Zeigt Setlist mit Song-Status (übersprungen / eingeschoben / Feedback-Rating)
  - Skip-, Insert- und Feedback-Rating-Buttons nur für `editor`/`admin` aktiv
  - Für `user`: alle Controls `.disabled(true)` + Hinweis-Banner „Nur Lesezugriff"

---

#### Proben-Tab — `RehearsalsView` → `RehearsalDetailView`

- `RehearsalsView`: Liste (`GET /reh`), sortiert nach Datum absteigend
- `RehearsalDetailView`: Songliste und eigene To-do-Items der Probe

---

#### Songs-Tab — `SongsView` → `CandidatesView`

- `SongsView`:
  - Repertoire-Liste (`GET /songs`) mit Suchfeld (clientseitige Filterung)
  - NavigationLink **„Kandidaten"** → `CandidatesView`
- `CandidatesView` (`GET /songs/candidates`):
  - Kandidatenliste mit Voting-Buttons (`POST /songs/{id}/feedback`) für alle Rollen
  - Bereits abgegebener eigener Vote wird aus `SongCandidateOut.feedbacks` ermittelt und hervorgehoben

---

#### Umfragen-Tab — `SurveysView` → `SurveyDetailView`

- `SurveysView`: Liste (`GET /surveys`)
- `SurveyDetailView`: Detail + Antwort-Formular (`GET /surveys/{id}`, `POST /surveys/{id}/feedback`)
- Tab-Badge = `surveys_to_feedback.count` aus `UserTodoList`

---

#### Profil-Tab — `ProfileView`

- Eigene Daten anzeigen (`GET /me`)
- Passwort ändern (`PUT /change_password`)
- Server-URL ändern → Tokens löschen + Login-Screen
- Logout (`POST /logout` + Keychain vollständig leeren)

---

### ✅ 6. App-Rahmen & UX (`App/`-Gruppe)

#### `LibreStageApp.swift`
- `@State` `AuthManager`-Instanz als `@Environment`
- Zeigt `LoginView` wenn `!authManager.isAuthenticated`, sonst `MainTabView`

#### `MainTabView.swift`
- `TabView` mit 6 Tabs: Dashboard, Gigs, Proben, Songs, Umfragen, Profil
- Badge-Werte aus `DashboardViewModel` via `@Environment`

#### Skeleton-Loading
- `redacted(reason: .placeholder)` während laufender Requests

#### Zentrales `ErrorBanner`
- Slide-in Overlay am oberen Rand
- Automatisch nach 4 Sekunden ausgeblendet
- Zeigt `AppError`-Beschreibung an

#### App-Icon & Launch Screen
- AppIcon aus `Logo.png` exportieren (alle benötigten Größen)
- Launch Screen mit App-Name und Logo

#### Design
- Light- & Dark-Mode-Support via `Color`-Assets in `Assets.xcassets`
- Systemschrift (SF Pro), systemkonforme Abstände und Komponenten

---

## Dateistruktur (Übersicht)

```
ios/
├── LibreStage.xcodeproj/
├── LibreStage/
│   ├── App/
│   │   ├── LibreStageApp.swift
│   │   └── MainTabView.swift
│   ├── Core/
│   │   ├── APIClient.swift
│   │   ├── AuthManager.swift
│   │   └── SettingsStore.swift
│   ├── Models/
│   │   ├── User.swift
│   │   ├── Gig.swift
│   │   ├── Rehearsal.swift
│   │   ├── Song.swift
│   │   ├── Survey.swift
│   │   └── Todo.swift
│   ├── Views/
│   │   ├── Auth/
│   │   │   └── LoginView.swift
│   │   ├── Dashboard/
│   │   │   └── DashboardView.swift
│   │   ├── Gigs/
│   │   │   ├── GigsView.swift
│   │   │   ├── GigDetailView.swift
│   │   │   └── LiveModeView.swift
│   │   ├── Rehearsals/
│   │   │   ├── RehearsalsView.swift
│   │   │   └── RehearsalDetailView.swift
│   │   ├── Songs/
│   │   │   ├── SongsView.swift
│   │   │   └── CandidatesView.swift
│   │   ├── Surveys/
│   │   │   ├── SurveysView.swift
│   │   │   └── SurveyDetailView.swift
│   │   ├── Profile/
│   │   │   └── ProfileView.swift
│   │   └── Components/
│   │       ├── ErrorBanner.swift
│   │       └── SkeletonRow.swift
│   ├── ViewModels/
│   │   ├── DashboardViewModel.swift
│   │   ├── GigsViewModel.swift
│   │   ├── RehearsalsViewModel.swift
│   │   ├── SongsViewModel.swift
│   │   ├── SurveysViewModel.swift
│   │   └── ProfileViewModel.swift
│   └── Assets.xcassets/
└── LibreStageTests/
```

---

## .gitignore-Ergänzungen

Folgende Einträge werden zur bestehenden `.gitignore` im Repo-Root hinzugefügt:

```
# Xcode
ios/DerivedData/
ios/**/*.xcuserstate
ios/**/xcuserdata/
ios/.build/
*.xcuserstate
xcuserdata/
```

---

## Technische Rahmenbedingungen

| Eigenschaft | Wert |
|---|---|
| Plattform | iOS 17+ |
| Sprache | Swift 5.9 |
| UI-Framework | SwiftUI |
| Netzwerk | URLSession + async/await |
| Token-Speicherung | KeychainAccess (SPM) |
| Offline-Unterstützung | Keine (bewusste Entscheidung) |
| Push-Benachrichtigungen | Nicht in diesem Scope |
| Admin-Funktionen | Nicht in diesem Scope (weiterhin über Webinterface) |
| Deployment | Direkt via Xcode / TestFlight (nächster Schritt) |

