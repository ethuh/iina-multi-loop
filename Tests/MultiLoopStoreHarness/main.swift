import Foundation

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else {
    FileHandle.standardError.write(Data("FAIL: \(message)\n".utf8))
    exit(1)
  }
}

private let embyURL = URL(string: "https://media.example.test/emby/videos/item-1/stream.mp4?api_key=secret")!
private let firstIdentity = MultiLoopVideoIdentity.resolve(
  url: embyURL,
  externalMetadata: MultiLoopExternalMetadata(title: #"D:\Videos\FC2-3363866.mp4"#, mediaID: "item-1"))!
expect(firstIdentity.displayName == "FC2-3363866.mp4", "Windows source path should resolve to its filename")
expect(firstIdentity.externalID == "emby:media.example.test:item-1", "Emby identity should omit URL path and query")
expect(!firstIdentity.externalID!.contains("secret"), "Emby identity must not contain an API key")

let fallbackIdentity = MultiLoopVideoIdentity.resolve(
  url: embyURL,
  externalMetadata: MultiLoopExternalMetadata(title: "stream.mp4?api_key=secret", mediaID: "item-1"))!
expect(fallbackIdentity.displayName == "Emby-item-1", "Unsafe supplied title should fall back to Emby item ID")
expect(MultiLoopVideoIdentity.resolve(url: embyURL) == nil, "Generic stream path must not become an identity")

let localIdentity = MultiLoopVideoIdentity.resolve(url: URL(fileURLWithPath: "/tmp/影片.mp4"))!
expect(localIdentity.displayName == "影片.mp4", "Local identity should use the filename")
expect(localIdentity.normalizedName == "影片.mp4", "Unicode filename should normalize consistently")

let exportedSegments = [MultiLoopSegment(start: 8, end: 3), MultiLoopSegment(start: 12, end: 18)]
let exported = try MultiLoopExportDocument(identity: firstIdentity, segments: exportedSegments).encoded()
let exportedText = String(decoding: exported, as: UTF8.self)
expect(!exportedText.contains("item-1"), "Export must not contain external IDs")
expect(!exportedText.contains("api_key"), "Export must not contain signed URL data")
let decoded = try MultiLoopExportDocument.decodeSegments(from: exported, minimumLength: 0.05)
expect(decoded == [MultiLoopSegment(start: 3, end: 8), MultiLoopSegment(start: 12, end: 18)],
       "Export round trip should normalize segment endpoints")

let legacyData = try JSONEncoder().encode(MultiLoopPersistedState(
  segments: [MultiLoopSegment(start: 1, end: 2)]))
let decodedLegacy = try MultiLoopExportDocument.decodeSegments(from: legacyData, minimumLength: 0.05)
expect(decodedLegacy ==
       [MultiLoopSegment(start: 1, end: 2)], "Legacy import payload should remain supported")

let databaseURL = FileManager.default.temporaryDirectory
  .appendingPathComponent("iina-multiloop-\(UUID().uuidString).sqlite3")
defer {
  try? FileManager.default.removeItem(at: databaseURL)
  try? FileManager.default.removeItem(atPath: databaseURL.path + "-wal")
  try? FileManager.default.removeItem(atPath: databaseURL.path + "-shm")
}

let initial = [MultiLoopSegment(start: 1, end: 2), MultiLoopSegment(start: 6, end: 9)]
do {
  let store = MultiLoopStore(databaseURL: databaseURL)
  try store.replace(initial, identity: firstIdentity)
  let loadedInitial = try store.load(identity: firstIdentity, merging: [])
  expect(loadedInitial == initial,
         "Stored segments should load in their saved order")

  let sameNameDifferentItem = MultiLoopVideoIdentity.resolve(
    url: URL(string: "https://media.example.test/emby/videos/item-2/stream.mp4")!,
    externalMetadata: MultiLoopExternalMetadata(title: "FC2-3363866.mp4", mediaID: "item-2"))!
  try store.replace([MultiLoopSegment(start: 20, end: 30)], identity: sameNameDifferentItem)
  let firstAfterSecondSave = try store.load(identity: firstIdentity, merging: [])
  expect(firstAfterSecondSave == initial,
         "Different Emby item IDs must remain isolated even when filenames match")

  let merged = try store.load(identity: firstIdentity, merging: [
    MultiLoopLegacyPayload(hash: "legacy-a", segments: [
      MultiLoopSegment(start: 6, end: 9),
      MultiLoopSegment(start: 40, end: 44)
    ]),
    MultiLoopLegacyPayload(hash: "legacy-b", segments: [
      MultiLoopSegment(start: 12, end: 15),
      MultiLoopSegment(start: 40.0004, end: 44.0004)
    ])
  ])
  expect(merged == [
    MultiLoopSegment(start: 1, end: 2),
    MultiLoopSegment(start: 6, end: 9),
    MultiLoopSegment(start: 12, end: 15),
    MultiLoopSegment(start: 40, end: 44)
  ], "Legacy sidecars should merge, near-deduplicate, and sort")
  try store.clear(identity: firstIdentity)
}

do {
  let reopenedStore = MultiLoopStore(databaseURL: databaseURL)
  let afterClear = try reopenedStore.load(identity: firstIdentity, merging: [
    MultiLoopLegacyPayload(hash: "legacy-a", segments: [MultiLoopSegment(start: 40, end: 44)])
  ])
  expect(afterClear.isEmpty, "Cleared records must not resurrect already-imported legacy sidecars")
  try reopenedStore.replace([MultiLoopSegment(start: 50, end: 55)], identity: firstIdentity)
}

do {
  let reopenedStore = MultiLoopStore(databaseURL: databaseURL)
  let afterRestart = try reopenedStore.load(identity: firstIdentity, merging: [])
  expect(afterRestart ==
         [MultiLoopSegment(start: 50, end: 55)], "SQLite records should survive store restart")
}

print("MultiLoopStore harness passed")
