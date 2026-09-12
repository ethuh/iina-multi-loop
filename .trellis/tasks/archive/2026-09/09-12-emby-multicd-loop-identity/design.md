# 技术设计

## 根因

身份解析只有一个入口 `MultiLoopVideoIdentity.resolve(url:externalMetadata:)`（`iina/MultiLoopStore.swift:30`），其 Emby 分支的前置条件是调用方传入 `externalMetadata.mediaID`。

两条启动链路：

| 链路 | 入口 | 元数据 | 结果 |
|---|---|---|---|
| embytest 脚本 | `iina://weblink` → `AppDelegate.parsePendingURL` → `openURLString(_:multiLoopMediaTitle:multiLoopMediaID:)` | `media_title` + `media_id` | `emby:host:itemId` + 真实文件名 ✅ |
| embyToLocalPlayer | `iina-cli` → `applicationWillFinishLaunching` 命令行分支 → `openURL`/`openURLs` | 无 | 落到网络文件名分支 → `original.mp4` ❌ |

第二条链路完全绕开 `openURLString`，所以 `requestedMultiLoopExternalMetadata` 为 nil。而 `isGenericStreamName` 只拦 `stream`/`master`/`playlist`，`original.mp4` 被当成合法文件名，于是全站 Emby 串流共用一个身份。

## 改动点

### 1. `iina/MultiLoopStore.swift` — URL 推导 Emby item id（承重修复）

把现有 `embyExternalID(for:)` 中解析 item id 的部分抽成 `static func embyMediaID(for url: URL) -> String?`，`embyExternalID(for:)` 改为复用它（`MultiLoopLegacyRecovery` 的行为不变）。

`resolve` 的 mediaID 取值改为：

```swift
let mediaID = safeMediaID(externalMetadata?.mediaID) ?? embyMediaID(for: url)
```

其余分支顺序不变，因此：

- 显式 mediaID 仍然最优先 → embytest 路径逐字节不变。
- 无显式 mediaID 时，Emby URL 现在也进入 Emby 分支，得到稳定的 `emby:<host>[:port]:<itemId>`。
- 非 Emby URL（路径中无 `videos/{id}`）行为不变。

同时把 `"original"` 加入 `isGenericStreamName`：这只在「非 Emby 的网络 URL 且无标题」时才会走到，作用是防止未来某种不含 `/videos/` 的 Emby 路径重新塌陷成一个桶。本地文件在更早的分支返回，不受影响。

### 2. `iina/PlayerCore.swift` — 用 `force-media-title` 补显示名（观感修复）

唯一的解析点在 `openMainWindow`（`PlayerCore.swift:472`）。改为：

```swift
info.multiLoopVideoIdentity = MultiLoopVideoIdentity.resolve(
  url: url,
  externalMetadata: requestedMultiLoopExternalMetadata ?? forcedMediaTitleMetadata(for: url))
```

新增私有方法：

```swift
/// mpv `force-media-title` 作为网络播放的身份显示名兜底。
/// embyToLocalPlayer 经 iina-cli 传入 `--mpv-force-media-title=<emby 标题>  |  <文件名>`，
/// 命令行分支在 open 之前已调用 applyMPVArguments，此处可读。
/// 仅用于网络 URL：该选项可能被用户在 mpv.conf 中全局设置，
/// 若用于本地文件会把所有本地文件挤进同一个身份。
private func forcedMediaTitleMetadata(for url: URL) -> MultiLoopExternalMetadata? {
  guard !url.isFileURL,
        let forced = mpv.getString(MPVOption.Miscellaneous.forceMediaTitle),
        !forced.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
  let trailing = forced.components(separatedBy: "|").last?
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let title = (trailing?.isEmpty == false) ? trailing! : forced
  return MultiLoopExternalMetadata(title: title, mediaID: nil)
}
```

`|` 切分放在 PlayerCore 而不是 `safeDisplayName`：后者同时服务 embytest 路径，那条路径传入的是 `mediaSource.Path`，不能改其语义。`.last` 同时覆盖 `  |  ` 与 ` | ` 两种分隔符，且当 Emby 标题本身含 `|` 时仍取到 basename。

`fileStarted`（`PlayerCore.swift:2046`）的 else 分支保持仅用 URL——`force-media-title` 在播放列表中是粘性的（`utils/players.py:66` 明确记录了这个 IINA 行为），在那里读会污染下一项；它本来就能通过改动 1 免费拿到 externalID。

### 3. `Tests/MultiLoopStoreHarness/main.swift` — 更新并扩展断言

现有 `expect(MultiLoopVideoIdentity.resolve(url: embyURL) == nil, …)` 与新行为冲突，改为断言它现在产出 `emby:media.example.test:item-1` / `Emby-item-1`。新增：

- 两个不同 itemId 的 `original.mp4` URL → 不同 externalID。
- 显式元数据形状的结果与旧值逐字段相等（回归锁）。
- 非 Emby 的 `original.mp4` 网络 URL → nil。

`|` 切分逻辑在 `PlayerCore` 中、harness 不编译该文件，因此用 `MultiLoopExternalMetadata(title: "A  |  B.mp4")` 形状无法覆盖；改为在 harness 中直接验证 `resolve` 对已切分标题的处理，切分本身通过 Release 构建 + 实机验证覆盖。

## 兼容性 / 回滚

- 数据库 schema 不变，无迁移。
- 旧的 `original.mp4` 行成为孤儿：`ensureVideo` 先查 externalID 再查 normalizedName，修复后二者都不会命中它。
- 自愈：若某次启动没有 `force-media-title`，显示名为 `Emby-<id>` 但 externalID 正确；下次带标题启动时 `updateVideo` 会把显示名修正，loop 记录不丢。
- 回滚 = revert 单个 commit；无数据侧残留。

## 风险

| 风险 | 缓解 |
|---|---|
| 用户全局设置了 `force-media-title` | 仅对网络 URL 生效 |
| Emby 标题本身含 `|` | `.last` 取 basename，结果仍稳定且唯一 |
| item id 为 GUID 而非数字 | `safeMediaID` 已允许任意无 `?&=/#` 的 ≤256 字符串 |
| 未来 Emby 路径不含 `/videos/` | `"original"` 进入 generic 名单，退化为「无身份」而非「共用身份」 |
