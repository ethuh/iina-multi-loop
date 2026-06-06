//
//  MultiLoopViewController.swift
//  iina
//
//  Sidebar view for managing multi-loop segments.
//

import Cocoa

class MultiLoopViewController: NSViewController {

  private weak var player: PlayerCore!
  private var tableView: NSTableView!
  private var scrollView: NSScrollView!
  private var emptyLabel: NSTextField!

  private let segmentDragType = NSPasteboard.PasteboardType("com.colliderli.iina.multiloop.segment")

  init(player: PlayerCore) {
    self.player = player
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    let container = NSView()
    container.autoresizingMask = [.width, .height]

    // Table view
    tableView = NSTableView()
    tableView.headerView = nil
    tableView.backgroundColor = NSColor(named: .sidebarTableBackground)!
    tableView.rowHeight = 32
    tableView.intercellSpacing = NSSize(width: 0, height: 1)
    tableView.delegate = self
    tableView.dataSource = self
    tableView.selectionHighlightStyle = .regular
    tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
    tableView.registerForDraggedTypes([segmentDragType])
    tableView.setDraggingSourceOperationMask(.move, forLocal: true)

    let timeColumn = NSTableColumn(identifier: .init("time"))
    timeColumn.title = ""
    timeColumn.resizingMask = .autoresizingMask
    tableView.addTableColumn(timeColumn)

    let deleteColumn = NSTableColumn(identifier: .init("delete"))
    deleteColumn.title = ""
    deleteColumn.width = 28
    deleteColumn.maxWidth = 28
    deleteColumn.minWidth = 28
    deleteColumn.resizingMask = []
    tableView.addTableColumn(deleteColumn)

    scrollView = NSScrollView()
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.documentView = tableView
    scrollView.hasVerticalScroller = true
    scrollView.autohidesScrollers = true
    scrollView.drawsBackground = false
    scrollView.wantsLayer = true
    scrollView.layer?.cornerRadius = 4
    container.addSubview(scrollView)

    // Empty state label
    emptyLabel = NSTextField(labelWithString: NSLocalizedString("multiloop.empty", comment: "No loop segments"))
    emptyLabel.translatesAutoresizingMaskIntoConstraints = false
    emptyLabel.textColor = .secondaryLabelColor
    emptyLabel.font = .systemFont(ofSize: 12)
    emptyLabel.alignment = .center
    container.addSubview(emptyLabel)

    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
      scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
      scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
      scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
      emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
      emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
    ])

    self.view = container
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    updateEmptyState()
  }

  func reload() {
    tableView.reloadData()
    updateEmptyState()
  }

  private func updateEmptyState() {
    let empty = player.multiLoop.segments.isEmpty && player.multiLoop.pendingStart == nil
    emptyLabel.isHidden = !empty
    scrollView.isHidden = empty
  }

  private func formatTime(_ seconds: Double) -> String {
    let totalSeconds = Int(seconds)
    let ms = Int((seconds - Double(totalSeconds)) * 100)
    let h = totalSeconds / 3600
    let m = (totalSeconds % 3600) / 60
    let s = totalSeconds % 60
    if h > 0 {
      return String(format: "%d:%02d:%02d.%02d", h, m, s, ms)
    }
    return String(format: "%02d:%02d.%02d", m, s, ms)
  }

  @objc private func deleteSegment(_ sender: NSButton) {
    let row = sender.tag
    let segments = player.multiLoop.segments
    if player.multiLoop.pendingStart != nil {
      // Pending row is last
      let pendingRow = segments.count
      if row == pendingRow {
        player.multiLoopUndoPoint()
        reload()
        return
      }
    }
    guard row >= 0, row < segments.count else { return }
    player.multiLoopRemoveSegment(at: row)
    reload()
  }
}

// MARK: - NSTableViewDataSource & Delegate

extension MultiLoopViewController: NSTableViewDataSource, NSTableViewDelegate {

  func numberOfRows(in tableView: NSTableView) -> Int {
    let count = player.multiLoop.segments.count
    return player.multiLoop.pendingStart != nil ? count + 1 : count
  }

  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let segments = player.multiLoop.segments
    let isPendingRow = row == segments.count && player.multiLoop.pendingStart != nil

    if tableColumn?.identifier.rawValue == "delete" {
      let button = NSButton()
      button.bezelStyle = .inline
      button.isBordered = false
      if #available(macOS 11, *) {
        button.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Delete")
      } else {
        button.title = "✕"
      }
      button.contentTintColor = .secondaryLabelColor
      button.imageScaling = .scaleProportionallyDown
      button.tag = row
      button.target = self
      button.action = #selector(deleteSegment(_:))
      return button
    }

    // Time column
    let cell = NSTextField(labelWithString: "")
    cell.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    cell.lineBreakMode = .byTruncatingTail

    if isPendingRow {
      let startTime = formatTime(player.multiLoop.pendingStart!)
      let label = Character(UnicodeScalar(65 + segments.count * 2)!)
      cell.stringValue = "  \(label): \(startTime) → ..."
      cell.textColor = .systemOrange
    } else {
      let seg = segments[row].normalized
      let labelA = Character(UnicodeScalar(65 + row * 2)!)
      let labelB = Character(UnicodeScalar(66 + row * 2)!)
      cell.stringValue = "  \(labelA)-\(labelB): \(formatTime(seg.start)) → \(formatTime(seg.end))"
      cell.textColor = .labelColor
    }

    return cell
  }

  func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
    // Click on a segment row to seek to its start
    let segments = player.multiLoop.segments
    let isPendingRow = row == segments.count && player.multiLoop.pendingStart != nil
    if isPendingRow {
      if let t = player.multiLoop.pendingStart {
        player.seek(absoluteSecond: t)
      }
    } else if segments.indices.contains(row) {
      player.seek(absoluteSecond: segments[row].normalized.start)
    }
    return true
  }

  func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
    guard player.multiLoop.segments.indices.contains(row) else { return nil }

    let item = NSPasteboardItem()
    item.setString(String(row), forType: segmentDragType)
    return item
  }

  func tableView(_ tableView: NSTableView,
                 validateDrop info: NSDraggingInfo,
                 proposedRow row: Int,
                 proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
    guard dropOperation != .on || player.multiLoop.segments.indices.contains(row) else { return [] }
    guard sourceRow(from: info, in: tableView).flatMap({ validatedInsertionRow(row, sourceRow: $0) }) != nil else { return [] }

    if dropOperation != .above {
      tableView.setDropRow(row, dropOperation: .above)
    }
    return .move
  }

  func tableView(_ tableView: NSTableView,
                 acceptDrop info: NSDraggingInfo,
                 row: Int,
                 dropOperation: NSTableView.DropOperation) -> Bool {
    guard let sourceRow = sourceRow(from: info, in: tableView),
          let insertionRow = validatedInsertionRow(row, sourceRow: sourceRow) else { return false }

    let destinationRow = insertionRow > sourceRow ? insertionRow - 1 : insertionRow
    guard player.multiLoopMoveSegment(from: sourceRow, to: insertionRow) else { return false }

    reload()
    tableView.selectRowIndexes(IndexSet(integer: destinationRow), byExtendingSelection: false)
    tableView.scrollRowToVisible(destinationRow)
    return true
  }

  private func sourceRow(from draggingInfo: NSDraggingInfo, in tableView: NSTableView) -> Int? {
    guard draggingInfo.draggingSource as? NSTableView === tableView,
          let rowString = draggingInfo.draggingPasteboard.string(forType: segmentDragType),
          let row = Int(rowString),
          player.multiLoop.segments.indices.contains(row) else { return nil }
    return row
  }

  private func validatedInsertionRow(_ row: Int, sourceRow: Int) -> Int? {
    let completedCount = player.multiLoop.segments.count
    guard row >= 0, row <= completedCount else { return nil }
    guard player.multiLoop.segments.indices.contains(sourceRow) else { return nil }
    guard row != sourceRow, row != sourceRow + 1 else { return nil }
    return row
  }
}
