import Foundation

struct MultiLoopSegment: Codable, Equatable {
  var start: Double
  var end: Double

  var normalized: MultiLoopSegment {
    return start <= end ? self : MultiLoopSegment(start: end, end: start)
  }
}

struct MultiLoopPersistedState: Codable, Equatable {
  var segments: [MultiLoopSegment]
}

final class MultiLoopController {
  static let minimumSegmentLength: Double = 0.05
}

struct HistoryEntry {
  let url: URL
}

@propertyWrapper
final class HarnessLocked<Value> {
  var wrappedValue: Value
  var projectedValue: HarnessLocked<Value> { self }

  init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
  }

  func withLock<Result>(_ body: (Value) -> Result) -> Result {
    return body(wrappedValue)
  }
}

final class HistoryController {
  static let shared = HistoryController()
  @HarnessLocked var history: [HistoryEntry] = []
}

enum Logger {
  enum Level {
    case warning
    case error
  }

  static func log(_ message: String, level: Level) {}
}

enum Utility {
  static let multiLoopDatabaseURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("unused-multiloop.sqlite3")
  static let watchLaterURL = FileManager.default.temporaryDirectory
}

extension String {
  var md5: String { self }
}
