//
//  MultiLoop.swift
//  iina
//
//  Multi-segment loop support (IINA-side).
//

import Cocoa

enum MultiLoopSetPointResult {
  case ignored
  case startSet
  case segmentAdded
}

enum MultiLoopUndoResult {
  case ignored
  case pendingCleared
  case segmentRemoved(Int)
}

struct MultiLoopSegment: Codable, Equatable {
  var start: Double
  var end: Double

  init(start: Double, end: Double) {
    self.start = start
    self.end = end
  }

  var normalized: MultiLoopSegment {
    if start <= end { return self }
    return MultiLoopSegment(start: end, end: start)
  }

  func contains(_ time: Double) -> Bool {
    let s = min(start, end)
    let e = max(start, end)
    return time >= s && time < e
  }
}

struct MultiLoopPersistedState: Codable, Equatable {
  var segments: [MultiLoopSegment]
}

final class MultiLoopStore {
  private static let fileSuffix = ".iina-multiloop.json"

  static func url(forWatchLaterKey watchLaterKey: String) -> URL {
    Utility.watchLaterURL.appendingPathComponent(watchLaterKey + fileSuffix, isDirectory: false)
  }

  static func load(watchLaterKey: String) -> MultiLoopPersistedState? {
    let fileURL = url(forWatchLaterKey: watchLaterKey)
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
    do {
      let data = try Data(contentsOf: fileURL)
      return try JSONDecoder().decode(MultiLoopPersistedState.self, from: data)
    } catch {
      Logger.log("Failed to load multiloop state: \(error)", level: .warning)
      return nil
    }
  }

  static func save(_ state: MultiLoopPersistedState, watchLaterKey: String) {
    let fileURL = url(forWatchLaterKey: watchLaterKey)
    do {
      let data = try JSONEncoder().encode(state)
      try data.write(to: fileURL, options: [.atomic])
    } catch {
      Logger.log("Failed to save multiloop state: \(error)", level: .warning)
    }
  }

  static func delete(watchLaterKey: String) {
    let fileURL = url(forWatchLaterKey: watchLaterKey)
    try? FileManager.default.removeItem(at: fileURL)
  }
}

final class MultiLoopController {
  private unowned let player: PlayerCore

  private(set) var segments: [MultiLoopSegment] = []
  private(set) var pendingStart: Double?

  private(set) var sequenceModeEnabled: Bool = false

  private var lastTickTime: CFTimeInterval = 0
  private var seekCooldownUntil: CFTimeInterval = 0
  private var lastSegmentIndex: Int?
  private var lastTimePos: Double?

  /// How close to an end boundary we treat as "end reached".
  private let boundaryEpsilon: Double = 0.08

  /// Minimum segment length (seconds). Segments shorter than this are ignored.
  private let minSegmentLength: Double = 0.05

  /// If playback overshoots a boundary by less than this amount, still treat it as reaching the end.
  private let endOvershootWindow: Double = 0.35

  init(player: PlayerCore) {
    self.player = player
  }

  func resetForNewItem() {
    segments.removeAll()
    pendingStart = nil
    sequenceModeEnabled = false
    lastTickTime = 0
    seekCooldownUntil = 0
    lastSegmentIndex = nil
    lastTimePos = nil
  }

  func loadIfAvailable() {
    guard let key = player.info.watchLaterKey else { return }
    let loaded = MultiLoopStore.load(watchLaterKey: key)
    segments = (loaded?.segments ?? []).map { $0.normalized }
  }

  func save() {
    guard let key = player.info.watchLaterKey else { return }
    MultiLoopStore.save(MultiLoopPersistedState(segments: segments.map { $0.normalized }), watchLaterKey: key)
  }

  func clearAll(deleteFromDisk: Bool) {
    segments.removeAll()
    pendingStart = nil
    sequenceModeEnabled = false
    lastSegmentIndex = nil
    lastTimePos = nil
    if deleteFromDisk, let key = player.info.watchLaterKey {
      MultiLoopStore.delete(watchLaterKey: key)
    }
  }

  func undoLastPoint() -> MultiLoopUndoResult {
    if pendingStart != nil {
      pendingStart = nil
      return .pendingCleared
    }
    guard !segments.isEmpty else { return .ignored }
    let idx = segments.count - 1
    segments.removeLast()
    lastSegmentIndex = nil
    lastTimePos = nil
    save()
    updateObservationForSegments()
    return .segmentRemoved(idx)
  }

  func removeSegment(at index: Int) {
    guard segments.indices.contains(index) else { return }
    segments.remove(at: index)
    lastSegmentIndex = nil
    lastTimePos = nil
    save()
    updateObservationForSegments()
  }

  func moveSegment(from sourceIndex: Int, to insertionIndex: Int) -> Bool {
    guard segments.indices.contains(sourceIndex) else { return false }
    guard insertionIndex >= 0, insertionIndex <= segments.count else { return false }

    let adjustedDestination = insertionIndex > sourceIndex ? insertionIndex - 1 : insertionIndex
    guard adjustedDestination != sourceIndex else { return false }
    guard adjustedDestination >= 0, adjustedDestination <= segments.count - 1 else { return false }

    let segment = segments.remove(at: sourceIndex)
    segments.insert(segment, at: adjustedDestination)
    lastSegmentIndex = nil
    lastTimePos = nil
    save()
    updateObservationForSegments()
    return true
  }

  func sortSegmentsByStartTime() -> Bool {
    guard segments.count > 1 else { return false }
    let sortedSegments = segments.enumerated().sorted { lhs, rhs in
      let lhsStart = lhs.element.normalized.start
      let rhsStart = rhs.element.normalized.start
      if lhsStart == rhsStart {
        return lhs.offset < rhs.offset
      }
      return lhsStart < rhsStart
    }.map { $0.element.normalized }
    guard sortedSegments != segments else { return false }
    segments = sortedSegments
    lastSegmentIndex = nil
    lastTimePos = nil
    save()
    updateObservationForSegments()
    return true
  }

  func setPointAtCurrentTime() -> MultiLoopSetPointResult {
    guard player.info.state.active else { return .ignored }
    let now = player.mpv.getDouble(MPVProperty.timePos)
    guard now.isFinite && now >= 0 else { return .ignored }

    if let start = pendingStart {
      pendingStart = nil
      let seg = MultiLoopSegment(start: start, end: now).normalized
      if abs(seg.end - seg.start) >= minSegmentLength {
        segments.append(seg)
        lastSegmentIndex = nil
        lastTimePos = nil
        save()
        updateObservationForSegments()
        return .segmentAdded
      }
      return .ignored
    } else {
      pendingStart = now
      return .startSet
    }
  }

  func startSequenceFromFirstSegment() -> Bool {
    guard !segments.isEmpty, player.info.state.active else { return false }
    sequenceModeEnabled = true
    pendingStart = nil
    lastSegmentIndex = nil
    lastTimePos = nil
    updateObservationForSegments()
    seek(to: segments[0].start)
    return true
  }

  func updateObservationForSegments() {
    player.mpv.setMultiLoopTimePosObservationEnabled(!segments.isEmpty)
  }

  func markerTimes() -> [Double] {
    var result: [Double] = []
    for s in segments {
      let n = s.normalized
      result.append(n.start)
      result.append(n.end)
    }
    if let p = pendingStart {
      result.append(p)
    }
    return result
  }

  func handleTimePosUpdate(_ timePos: Double) {
    guard !segments.isEmpty, player.info.state.active else { return }
    guard timePos.isFinite else { return }

    // Throttle to avoid excessive work.
    let now = CACurrentMediaTime()
    if now - lastTickTime < 0.10 { return }
    lastTickTime = now

    // Avoid repeated seeks due to near-boundary jitter.
    if now < seekCooldownUntil { return }

    if sequenceModeEnabled {
      let idx = indexOfSegment(containing: timePos)
      if idx == nil, let lastIdx = lastSegmentIndex {
        let lastSeg = segments[lastIdx].normalized
        if let prev = lastTimePos,
           prev < lastSeg.end,
           timePos >= lastSeg.end - boundaryEpsilon,
           timePos <= lastSeg.end + endOvershootWindow {
          let nextIdx = (lastIdx + 1) % segments.count
          seek(to: segments[nextIdx].normalized.start)
          return
        }
      }
      guard let idx else {
        lastSegmentIndex = nil
        lastTimePos = timePos
        return
      }
      let seg = segments[idx].normalized
      lastSegmentIndex = idx
      if timePos >= seg.end - boundaryEpsilon {
        let nextIdx = (idx + 1) % segments.count
        seek(to: segments[nextIdx].normalized.start)
      }
      lastTimePos = timePos
      return
    }

    let idx = indexOfSegment(containing: timePos)
    if idx == nil, let lastIdx = lastSegmentIndex {
      let lastSeg = segments[lastIdx].normalized
      if let prev = lastTimePos,
         prev < lastSeg.end,
         timePos >= lastSeg.end - boundaryEpsilon,
         timePos <= lastSeg.end + endOvershootWindow {
        seek(to: lastSeg.start)
        return
      }
    }
    guard let idx else {
      lastSegmentIndex = nil
      lastTimePos = timePos
      return
    }
    let seg = segments[idx].normalized
    lastSegmentIndex = idx
    if timePos >= seg.end - boundaryEpsilon {
      seek(to: seg.start)
    }
    lastTimePos = timePos
  }

  private func indexOfSegment(containing time: Double) -> Int? {
    for (i, seg) in segments.enumerated() {
      if seg.contains(time) { return i }
    }
    return nil
  }

  private func seek(to absoluteSecond: Double) {
    let target = max(0, absoluteSecond)
    seekCooldownUntil = CACurrentMediaTime() + 0.25
    player.seek(absoluteSecond: target)
  }
}
