// libre-stage iOS App
// Copyright (C) 2026 libre-stage contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct AboutAppView: View {
    let modalPresentation: Bool
    @Environment(\.dismiss) private var dismiss

    init(modalPresentation: Bool = false) {
        self.modalPresentation = modalPresentation
    }

    var body: some View {
        List {
            Section("libre-stage") {
                Text("Die mobile App für libre-stage - die interne Band-Management-Plattform.")
                LabeledContent("Version", value: appVersion)
            }

            Section("Credits") {
                Text("Entwickelt von den libre-stage contributors.")
                Text("Open-Source-Projekt unter GPL-3.0-or-later.")
            }

            Section("Links") {
                Link(destination: URL(string: "https://calphiko.codeberg.page/libre-stage/")!) {
                    Label("Dokumentation", systemImage: "book")
                }
                Link(destination: URL(string: "https://pakleds-patentoffice.de")!) {
                    Label("pakleds-patentoffice.de", systemImage: "safari")
                }
            }
        }
        .softCardContainer()
        .appShellBackground()
        .navigationTitle("Über diese App")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if modalPresentation {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (Build \(build))"
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section("Stand") {
                Text("17. April 2026")
                Text("Diese Datenschutzrichtlinie gilt für die mobile App libre-stage (iOS).")
            }

            Section("1. Verantwortliche Stelle") {
                Text("Die iOS-App ist ein Client für selbst betriebene libre-stage-Server. Verantwortlich für die Verarbeitung personenbezogener Daten ist die jeweilige Band, Organisation oder Person, die den verbundenen libre-stage-Server betreibt.")
                Text("Wenn du unsicher bist, wer in deinem Fall verantwortlich ist, wende dich an die in deiner Instanz benannte Administratorin oder den Administrator.")
            }

            Section("2. Welche Daten verarbeitet werden") {
                policyBullet("Kontodaten: Benutzername, Klarname, E-Mail-Adresse, Rollen- und Statusinformationen.")
                policyBullet("Inhaltsdaten: von dir erfasste oder gelesene Inhalte wie Songs, Proben, Gigs, Umfragen und Kommentare.")
                policyBullet("Technische Daten: Server-URL der Instanz, Sitzungs-Token und app-interne Diagnoseinformationen.")
            }

            Section("3. Zwecke der Verarbeitung") {
                policyBullet("Bereitstellung von Login, Sitzungsverwaltung und Zugriff auf die Funktionen der Band-Organisation.")
                policyBullet("Synchronisierung und Darstellung von Daten des verbundenen libre-stage-Servers.")
                policyBullet("Fehleranalyse durch freiwillig genutzte Diagnosefunktionen in der App.")
            }

            Section("4. Rechtsgrundlagen") {
                Text("Die Verarbeitung erfolgt je nach Einsatzszenario insbesondere auf Grundlage von Art. 6 Abs. 1 lit. b DSGVO (Vertrag/Nutzerverhältnis), lit. f DSGVO (berechtigtes Interesse an sicherem und stabilem Betrieb) und – falls erforderlich – lit. a DSGVO (Einwilligung).")
            }

            Section("5. Speicherung und Sicherheit") {
                policyBullet("Anmeldetoken werden auf dem Gerät im iOS-Keychain gespeichert.")
                policyBullet("Die Kommunikation mit dem Server erfolgt über dessen API-Endpunkte.")
                policyBullet("Die App speichert keine vollständige Offline-Kopie aller Daten; Inhalte werden überwiegend live vom Server geladen.")
            }

            Section("6. Empfänger und Drittland") {
                Text("Empfänger der Daten ist primär der von dir konfigurierte libre-stage-Server. Ob und in welchem Umfang weitere Auftragsverarbeiter oder Drittdienste eingesetzt werden, richtet sich nach der Server-Instanz und liegt in der Verantwortung der betreibenden Stelle.")
            }

            Section("7. Speicherdauer") {
                Text("Die Speicherdauer richtet sich nach den Einstellungen und Prozessen der jeweiligen libre-stage-Instanz. Lokal gespeicherte Anmeldedaten verbleiben bis zur Abmeldung oder bis zur Entfernung der App auf dem Gerät.")
            }

            Section("8. Deine Rechte") {
                policyBullet("Auskunft über verarbeitete personenbezogene Daten")
                policyBullet("Berichtigung unrichtiger Daten")
                policyBullet("Löschung oder Einschränkung der Verarbeitung")
                policyBullet("Widerspruch gegen bestimmte Verarbeitungen")
                policyBullet("Datenübertragbarkeit, soweit anwendbar")
                policyBullet("Beschwerde bei einer zuständigen Datenschutzaufsichtsbehörde")
            }

            Section("9. Bereitstellungspflicht") {
                Text("Ohne die für Login und Nutzung erforderlichen Daten ist ein Zugriff auf die App-Funktionen nicht oder nur eingeschränkt möglich.")
            }

            Section("10. Änderungen") {
                Text("Diese Datenschutzrichtlinie kann bei technischen oder rechtlichen Änderungen aktualisiert werden. Maßgeblich ist die jeweils in der App angezeigte Fassung mit Stand-Datum.")
            }
        }
        .softCardContainer()
        .appShellBackground()
        .navigationTitle("Datenschutz")
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubpage()
    }

    @ViewBuilder
    private func policyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
            Text(text)
        }
    }
}
