//
//  MultiLoopStore.swift
//  iina
//
//  Durable multi-loop persistence, media identity, import/export, and legacy recovery.
//

import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum MultiLoopSourceKind: String {
  case local
  case emby
  case network
}

struct MultiLoopExternalMetadata {
  let title: String?
  let mediaID: String?
}

struct MultiLoopVideoIdentity: Equatable {
  let displayName: String
  let normalizedName: String
  let externalID: String?
  let sourceKind: MultiLoopSourceKind

  static func resolve(url: URL, externalMetadata: MultiLoopExternalMetadata? = nil) -> MultiLoopVideoIdentity? {
    // The browser script supplies the Emby item ID explicitly. Launches that arrive through
    // iina-cli (embyToLocalPlayer) carry no metadata at all, so fall back to the item ID embedded
    // in the stream URL; both sources use the same Emby item ID space.
    let mediaID = safeMediaID(externalMetadata?.mediaID) ?? embyMediaID(for: url)
    let suppliedTitle = safeDisplayName(externalMetadata?.title)

    if let mediaID,
       let host = url.host?.lowercased(),
       let displayName = suppliedTitle ?? safeDisplayName("Emby-\(mediaID)") {
      let portSuffix = url.port.map { ":\($0)" } ?? ""
      return make(displayName: displayName,
                  externalID: "emby:\(host)\(portSuffix):\(mediaID)",
                  sourceKind: .emby)
    }

    if let suppliedTitle {
      return make(displayName: suppliedTitle, externalID: nil,
                  sourceKind: url.isFileURL ? .local : .network)
    }

    if url.isFileURL, let filename = safeDisplayName(url.lastPathComponent) {
      return make(displayName: filename, externalID: nil, sourceKind: .local)
    }

    guard let filename = safeDisplayName(url.lastPathComponent), !isGenericStreamName(filename) else {
      return nil
    }
    return make(displayName: filename, externalID: nil, sourceKind: .network)
  }

  static func embyExternalID(for url: URL) -> String? {
    guard let mediaID = embyMediaID(for: url), let host = url.host?.lowercased() else { return nil }
    let portSuffix = url.port.map { ":\($0)" } ?? ""
    return "emby:\(host)\(portSuffix):\(mediaID)"
  }

  /// The Emby item ID in a stream URL such as `https://host/emby/videos/3346/original.mp4?…`.
  static func embyMediaID(for url: URL) -> String? {
    let pathComponents = url.pathComponents
    guard let videosIndex = pathComponents.firstIndex(where: { $0.caseInsensitiveCompare("videos") == .orderedSame }),
          pathComponents.indices.contains(videosIndex + 1) else { return nil }
    return safeMediaID(pathComponents[videosIndex + 1])
  }

  var exportFilename: String {
    let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>\0")
    let safeName = displayName.components(separatedBy: invalid).filter { !$0.isEmpty }.joined(separator: "-")
    return "\(safeName.isEmpty ? "loops" : safeName).iina-multiloop.json"
  }

  private static func make(displayName: String,
                           externalID: String?,
                           sourceKind: MultiLoopSourceKind) -> MultiLoopVideoIdentity? {
    let normalized = displayName.precomposedStringWithCanonicalMapping
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    guard !normalized.isEmpty else { return nil }
    return MultiLoopVideoIdentity(displayName: displayName,
                                  normalizedName: normalized,
                                  externalID: externalID,
                                  sourceKind: sourceKind)
  }

  private static func safeDisplayName(_ value: String?) -> String? {
    guard var value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    value = value.replacingOccurrences(of: "\\", with: "/")
    if value.contains("/") {
      value = value.split(separator: "/", omittingEmptySubsequences: true).last.map(String.init) ?? value
    }
    let lowered = value.lowercased()
    guard !lowered.contains("://"),
          !lowered.contains("api_key="),
          !lowered.contains("embystatssession="),
          !lowered.contains("mediasourceid=") else { return nil }
    return value
  }

  private static func safeMediaID(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty,
          value.count <= 256,
          value.rangeOfCharacter(from: CharacterSet(charactersIn: "?&=/#")) == nil else { return nil }
    return value
  }

  private static func isGenericStreamName(_ value: String) -> Bool {
    let stem = (value as NSString).deletingPathExtension.lowercased()
    return stem == "stream" || stem == "master" || stem == "playlist" || stem == "original"
  }
}

struct MultiLoopExportDocument: Codable {
  static let formatName = "iina-multiloop"
  static let currentVersion = 1

  let format: String
  let version: Int
  let sourceVideoName: String
  let segments: [MultiLoopSegment]

  init(identity: MultiLoopVideoIdentity, segments: [MultiLoopSegment]) {
    format = Self.formatName
    version = Self.currentVersion
    sourceVideoName = identity.displayName
    self.segments = segments.map { $0.normalized }
  }

  func encoded() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return try encoder.encode(self)
  }

  static func decodeSegments(from data: Data, minimumLength: Double) throws -> [MultiLoopSegment] {
    let decoder = JSONDecoder()
    let decoded: [MultiLoopSegment]
    if let document = try? decoder.decode(MultiLoopExportDocument.self, from: data) {
      guard document.format == formatName, document.version == currentVersion else {
        throw MultiLoopStoreError.unsupportedImportFormat
      }
      decoded = document.segments
    } else {
      decoded = try decoder.decode(MultiLoopPersistedState.self, from: data).segments
    }
    return try MultiLoopSegment.validatedDistinct(decoded,
                                                  minimumLength: minimumLength,
                                                  sorted: false)
  }
}

enum MultiLoopStoreError: LocalizedError {
  case sqlite(String)
  case unsupportedSchema(Int)
  case unsupportedImportFormat
  case invalidSegment
  case noVideoIdentity

  var errorDescription: String? {
    switch self {
    case .sqlite(let message): return message
    case .unsupportedSchema(let version): return "Unsupported multi-loop database version \(version)."
    case .unsupportedImportFormat: return "Unsupported multi-loop import format."
    case .invalidSegment: return "The loop file contains an invalid time segment."
    case .noVideoIdentity: return "This video does not have a safe filename or title."
    }
  }
}

extension MultiLoopSegment {
  static func validatedDistinct(_ input: [MultiLoopSegment],
                                minimumLength: Double,
                                sorted: Bool) throws -> [MultiLoopSegment] {
    var result: [MultiLoopSegment] = []
    for segment in input {
      let normalized = segment.normalized
      guard normalized.start.isFinite,
            normalized.end.isFinite,
            normalized.start >= 0,
            normalized.end >= 0,
            normalized.end - normalized.start >= minimumLength else {
        throw MultiLoopStoreError.invalidSegment
      }
      let duplicate = result.contains {
        abs($0.start - normalized.start) < 0.001 && abs($0.end - normalized.end) < 0.001
      }
      if !duplicate {
        result.append(normalized)
      }
    }
    if sorted {
      result.sort {
        $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start
      }
    }
    return result
  }
}

struct MultiLoopLegacyPayload {
  let hash: String
  let segments: [MultiLoopSegment]
}

enum MultiLoopLegacyRecovery {
  private static let fileSuffix = ".iina-multiloop.json"

  static func payloads(identity: MultiLoopVideoIdentity,
                       watchLaterKey: String?) -> [MultiLoopLegacyPayload] {
    var candidateHashes: Set<String> = []
    if let watchLaterKey {
      candidateHashes.insert(watchLaterKey)
    }

    if let externalID = identity.externalID {
      let history = HistoryController.shared.$history.withLock { $0 }
      for entry in history where MultiLoopVideoIdentity.embyExternalID(for: entry.url) == externalID {
        candidateHashes.insert(entry.url.absoluteString.md5)
      }
    }

    return candidateHashes.compactMap { hash in
      let url = Utility.watchLaterURL.appendingPathComponent(hash + fileSuffix, isDirectory: false)
      guard FileManager.default.fileExists(atPath: url.path) else { return nil }
      do {
        let data = try Data(contentsOf: url)
        let state = try JSONDecoder().decode(MultiLoopPersistedState.self, from: data)
        let segments = try MultiLoopSegment.validatedDistinct(
          state.segments,
          minimumLength: MultiLoopController.minimumSegmentLength,
          sorted: false)
        return MultiLoopLegacyPayload(hash: hash, segments: segments)
      } catch {
        Logger.log("Failed to read legacy multi-loop sidecar \(hash): \(error)", level: .warning)
        return nil
      }
    }
  }
}

final class MultiLoopStore {
  static let shared = MultiLoopStore(databaseURL: Utility.multiLoopDatabaseURL)

  private let queue = DispatchQueue(label: "com.colliderli.iina.multiloop-store")
  private var connection: OpaquePointer?
  private var startupError: Error?

  init(databaseURL: URL) {
    do {
      try open(databaseURL: databaseURL)
    } catch {
      startupError = error
      if let connection {
        sqlite3_close(connection)
        self.connection = nil
      }
      Logger.log("Failed to initialize multi-loop database: \(error)", level: .error)
    }
  }

  deinit {
    if let connection {
      sqlite3_close(connection)
    }
  }

  func load(identity: MultiLoopVideoIdentity,
            merging legacyPayloads: [MultiLoopLegacyPayload]) throws -> [MultiLoopSegment] {
    return try queue.sync {
      try requireConnection()
      try beginTransaction()
      do {
        let videoID = try ensureVideo(identity)
        var segments = try loadSegments(videoID: videoID)
        var importedHashes: [String] = []

        for payload in legacyPayloads where try !isLegacyImported(payload.hash) {
          segments.append(contentsOf: payload.segments)
          importedHashes.append(payload.hash)
        }

        if !importedHashes.isEmpty {
          segments = try MultiLoopSegment.validatedDistinct(
            segments,
            minimumLength: MultiLoopController.minimumSegmentLength,
            sorted: true)
          try replaceSegments(segments, videoID: videoID)
          for hash in importedHashes {
            try markLegacyImported(hash, videoID: videoID)
          }
        }
        try commitTransaction()
        return segments
      } catch {
        rollbackTransaction()
        throw error
      }
    }
  }

  func replace(_ segments: [MultiLoopSegment], identity: MultiLoopVideoIdentity) throws {
    try queue.sync {
      try requireConnection()
      try beginTransaction()
      do {
        let videoID = try ensureVideo(identity)
        try replaceSegments(segments.map { $0.normalized }, videoID: videoID)
        try commitTransaction()
      } catch {
        rollbackTransaction()
        throw error
      }
    }
  }

  func clear(identity: MultiLoopVideoIdentity) throws {
    try replace([], identity: identity)
  }

  private func open(databaseURL: URL) throws {
    let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
    guard sqlite3_open_v2(databaseURL.path, &connection, flags, nil) == SQLITE_OK else {
      throw sqliteError("Unable to open multi-loop database")
    }
    try execute("PRAGMA foreign_keys = ON")
    try execute("PRAGMA busy_timeout = 3000")
    try execute("PRAGMA journal_mode = WAL")

    let version = try userVersion()
    guard version == 0 || version == 1 else {
      throw MultiLoopStoreError.unsupportedSchema(version)
    }
    if version == 0 {
      try beginTransaction()
      do {
        try execute("""
          CREATE TABLE videos (
            id INTEGER PRIMARY KEY,
            display_name TEXT NOT NULL,
            normalized_name TEXT NOT NULL,
            external_id TEXT UNIQUE,
            source_kind TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
          );
          CREATE INDEX videos_normalized_name_idx ON videos(normalized_name);
          CREATE TABLE loop_segments (
            video_id INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
            ordinal INTEGER NOT NULL,
            start REAL NOT NULL,
            end REAL NOT NULL,
            PRIMARY KEY (video_id, ordinal)
          );
          CREATE TABLE legacy_imports (
            sidecar_hash TEXT PRIMARY KEY,
            video_id INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
            imported_at REAL NOT NULL
          );
          PRAGMA user_version = 1;
          """)
        try commitTransaction()
      } catch {
        rollbackTransaction()
        throw error
      }
    }
  }

  private func requireConnection() throws {
    if let startupError { throw startupError }
    guard connection != nil else {
      throw MultiLoopStoreError.sqlite("The multi-loop database is unavailable.")
    }
  }

  private func userVersion() throws -> Int {
    let statement = try prepare("PRAGMA user_version")
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW else {
      throw sqliteError("Unable to read multi-loop database version")
    }
    return Int(sqlite3_column_int(statement, 0))
  }

  private func ensureVideo(_ identity: MultiLoopVideoIdentity) throws -> Int64 {
    if let externalID = identity.externalID {
      if let videoID = try findVideoID(column: "external_id", value: externalID) {
        try updateVideo(videoID, identity: identity)
        return videoID
      }
    } else if let videoID = try findVideoID(
      sql: "SELECT id FROM videos WHERE normalized_name = ? AND external_id IS NULL LIMIT 1",
      value: identity.normalizedName) {
      try updateVideo(videoID, identity: identity)
      return videoID
    }

    let statement = try prepare("""
      INSERT INTO videos
        (display_name, normalized_name, external_id, source_kind, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?)
      """)
    defer { sqlite3_finalize(statement) }
    let now = Date().timeIntervalSince1970
    try bind(identity.displayName, to: 1, in: statement)
    try bind(identity.normalizedName, to: 2, in: statement)
    try bindOptional(identity.externalID, to: 3, in: statement)
    try bind(identity.sourceKind.rawValue, to: 4, in: statement)
    sqlite3_bind_double(statement, 5, now)
    sqlite3_bind_double(statement, 6, now)
    try stepDone(statement, context: "Unable to create multi-loop video record")
    return sqlite3_last_insert_rowid(connection)
  }

  private func findVideoID(column: String, value: String) throws -> Int64? {
    return try findVideoID(sql: "SELECT id FROM videos WHERE \(column) = ? LIMIT 1", value: value)
  }

  private func findVideoID(sql: String, value: String) throws -> Int64? {
    let statement = try prepare(sql)
    defer { sqlite3_finalize(statement) }
    try bind(value, to: 1, in: statement)
    let result = sqlite3_step(statement)
    if result == SQLITE_ROW {
      return sqlite3_column_int64(statement, 0)
    }
    if result == SQLITE_DONE { return nil }
    throw sqliteError("Unable to find multi-loop video record")
  }

  private func updateVideo(_ videoID: Int64, identity: MultiLoopVideoIdentity) throws {
    let statement = try prepare("""
      UPDATE videos
      SET display_name = ?, normalized_name = ?, external_id = COALESCE(external_id, ?),
          source_kind = ?, updated_at = ?
      WHERE id = ?
      """)
    defer { sqlite3_finalize(statement) }
    try bind(identity.displayName, to: 1, in: statement)
    try bind(identity.normalizedName, to: 2, in: statement)
    try bindOptional(identity.externalID, to: 3, in: statement)
    try bind(identity.sourceKind.rawValue, to: 4, in: statement)
    sqlite3_bind_double(statement, 5, Date().timeIntervalSince1970)
    sqlite3_bind_int64(statement, 6, videoID)
    try stepDone(statement, context: "Unable to update multi-loop video record")
  }

  private func loadSegments(videoID: Int64) throws -> [MultiLoopSegment] {
    let statement = try prepare("""
      SELECT start, end FROM loop_segments WHERE video_id = ? ORDER BY ordinal
      """)
    defer { sqlite3_finalize(statement) }
    sqlite3_bind_int64(statement, 1, videoID)
    var result: [MultiLoopSegment] = []
    while true {
      switch sqlite3_step(statement) {
      case SQLITE_ROW:
        result.append(MultiLoopSegment(start: sqlite3_column_double(statement, 0),
                                       end: sqlite3_column_double(statement, 1)).normalized)
      case SQLITE_DONE:
        return result
      default:
        throw sqliteError("Unable to load multi-loop segments")
      }
    }
  }

  private func replaceSegments(_ segments: [MultiLoopSegment], videoID: Int64) throws {
    let deleteStatement = try prepare("DELETE FROM loop_segments WHERE video_id = ?")
    sqlite3_bind_int64(deleteStatement, 1, videoID)
    do {
      try stepDone(deleteStatement, context: "Unable to replace multi-loop segments")
    } catch {
      sqlite3_finalize(deleteStatement)
      throw error
    }
    sqlite3_finalize(deleteStatement)

    guard !segments.isEmpty else { return }
    let insertStatement = try prepare("""
      INSERT INTO loop_segments (video_id, ordinal, start, end) VALUES (?, ?, ?, ?)
      """)
    defer { sqlite3_finalize(insertStatement) }
    for (index, segment) in segments.enumerated() {
      sqlite3_reset(insertStatement)
      sqlite3_clear_bindings(insertStatement)
      sqlite3_bind_int64(insertStatement, 1, videoID)
      sqlite3_bind_int64(insertStatement, 2, Int64(index))
      sqlite3_bind_double(insertStatement, 3, segment.start)
      sqlite3_bind_double(insertStatement, 4, segment.end)
      try stepDone(insertStatement, context: "Unable to save multi-loop segment")
    }
  }

  private func isLegacyImported(_ hash: String) throws -> Bool {
    let statement = try prepare("SELECT 1 FROM legacy_imports WHERE sidecar_hash = ? LIMIT 1")
    defer { sqlite3_finalize(statement) }
    try bind(hash, to: 1, in: statement)
    let result = sqlite3_step(statement)
    if result == SQLITE_ROW { return true }
    if result == SQLITE_DONE { return false }
    throw sqliteError("Unable to inspect multi-loop migration state")
  }

  private func markLegacyImported(_ hash: String, videoID: Int64) throws {
    let statement = try prepare("""
      INSERT OR IGNORE INTO legacy_imports (sidecar_hash, video_id, imported_at) VALUES (?, ?, ?)
      """)
    defer { sqlite3_finalize(statement) }
    try bind(hash, to: 1, in: statement)
    sqlite3_bind_int64(statement, 2, videoID)
    sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
    try stepDone(statement, context: "Unable to record multi-loop migration")
  }

  private func bind(_ value: String, to index: Int32, in statement: OpaquePointer?) throws {
    guard sqlite3_bind_text(statement, index, value, -1, sqliteTransient) == SQLITE_OK else {
      throw sqliteError("Unable to bind multi-loop database value")
    }
  }

  private func bindOptional(_ value: String?, to index: Int32, in statement: OpaquePointer?) throws {
    if let value {
      try bind(value, to: index, in: statement)
    } else if sqlite3_bind_null(statement, index) != SQLITE_OK {
      throw sqliteError("Unable to bind multi-loop database value")
    }
  }

  private func prepare(_ sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
      throw sqliteError("Unable to prepare multi-loop database operation")
    }
    return statement
  }

  private func execute(_ sql: String) throws {
    var errorMessage: UnsafeMutablePointer<CChar>?
    let result = sqlite3_exec(connection, sql, nil, nil, &errorMessage)
    guard result == SQLITE_OK else {
      let detail = errorMessage.map { String(cString: $0) }
      sqlite3_free(errorMessage)
      throw MultiLoopStoreError.sqlite(detail ?? "Multi-loop database operation failed.")
    }
  }

  private func stepDone(_ statement: OpaquePointer?, context: String) throws {
    guard sqlite3_step(statement) == SQLITE_DONE else { throw sqliteError(context) }
  }

  private func beginTransaction() throws { try execute("BEGIN IMMEDIATE TRANSACTION") }
  private func commitTransaction() throws { try execute("COMMIT") }
  private func rollbackTransaction() { try? execute("ROLLBACK") }

  private func sqliteError(_ context: String) -> MultiLoopStoreError {
    guard let connection, let message = sqlite3_errmsg(connection) else {
      return .sqlite(context)
    }
    return .sqlite("\(context): \(String(cString: message))")
  }
}
