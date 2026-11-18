/* Which timezone the panel shows. Stored as a raw string so it survives in
   UserDefaults the way the popup's localStorage value does. */

public enum ZoneMode: String, CaseIterable, Sendable {
  case local
  case utc
}
