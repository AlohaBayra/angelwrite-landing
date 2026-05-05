# Versionierungs-Konvention

VoiceType folgt Semantic Versioning (MAJOR.MINOR.PATCH).

- MAJOR (1.x.x): inkompatible Architektur-Änderungen
- MINOR (x.1.x): neue Features, abwärtskompatibel
- PATCH (x.x.1): Bug-Fixes, kleine Verbesserungen

Bei jedem Release:
1. Version in Xcode Build Settings erhöhen
   (MARKETING_VERSION und CURRENT_PROJECT_VERSION)
2. CHANGELOG.md aktualisieren mit neuen Einträgen
3. Git-Commit mit Message-Pattern: "Release X.Y.Z: kurze Beschreibung"
4. Git-Tag setzen: git tag vX.Y.Z && git push origin vX.Y.Z
