# Emby 多 CD 影片的循环记录身份识别（兼容 embyToLocalPlayer）

## Goal

让通过 `embyToLocalPlayer`（greasyfork 448648 油猴脚本 + 本地 Python 服务）启动的 Emby 串流，在 IINA 中获得与 `embytest` 脚本一致的、按 Emby item 区分的视频身份，使多 CD 影片的 CD2/CD3 各自拥有独立的多段循环记录，并显示可读的影片名。两个油猴脚本必须同时兼容。

## User Value

- 多 CD 影片的每个分段（CD1/CD2/CD3…）各自保存独立的 loop 记录，不再相互串档。
- 窗口标题与 Loop 面板显示真实文件名，而不是 `original.mp4`。
- 已有的 `embytest` 启动路径行为完全不变。

## Confirmed Facts

以下均由本地数据与源码验证，非推测：

- `embyToLocalPlayer` 走 `iina-cli` 直接传裸串流 URL：
  `https://<host>/emby/videos/{itemId}/original.mp4?DeviceId=…&MediaSourceId=…&api_key=…&Static=true`
  （`~/Documents/embyToLocalPlayer/log.txt` 多条 `command line:` 记录，最新为 09/12 11:04:51，itemId=3346）。
- 同一次启动附带 `--mpv-force-media-title=FC2-PPV-2574551-CD3  |  FC2-PPV-2574551-CD3.mp4`，格式来自 `utils/data_parser.py:128` 的 `f'{emby_title}  |  {basename}'`（另一条路径 `data_parser.py:234` 用单空格 `f'{title} | {basename}'`）。
- 命令行分支在 `AppDelegate.swift:400-405` 调用的是 `openURL` / `openURLs`，**不经过** `openURLString`，因此 `requestedMultiLoopExternalMetadata` 恒为 nil。
- `AppDelegate.swift:386` 的 `applyMPVArguments(to:)` 在 open 之前执行，所以 `force-media-title` 在 `openMainWindow` 解析身份时已可读。`MPVOption.Miscellaneous.forceMediaTitle` 常量已存在（`MPVOption.swift:1464`）。
- `MultiLoopVideoIdentity.resolve` 仅在调用方显式传入 `mediaID` 时才生成 Emby externalID；否则落到网络文件名分支，`isGenericStreamName` 只识别 `stream` / `master` / `playlist`，不含 `original`，于是所有 Emby 串流统一得到 `original.mp4`。
- 生产库 `~/Library/Application Support/com.colliderli.iina/multiloop.sqlite3` 中存在污染行：`id=13, display_name='original.mp4', external_id=NULL, source_kind='network', 6 个 segments`，即所有 CD2+ 共用的那一条。
- CD1 正常是因为它由 `embytest-1.1.4-mac-mpv-new-instance.user.js` 启动，该脚本第 334 行发送 `iina://weblink?url=…&media_title=…&media_id=…`，`media_id = mediaInfo.itemInfo.Id`（第 333 行）。
- 两个脚本的 item id 属于同一命名空间：数据库中 18 个 `emby:…` externalID 的数字部分，全部命中 IINA `history.plist` 里 `/emby/videos/{id}/` 的路径段（18/18）。因此用 URL 路径推导 item id 与 `embytest` 传入的 `media_id` 等价。
- `getMediaTitle()`（`PlayerCore.swift:3010`）优先返回 `multiLoopVideoIdentity.displayName`，这就是标题栏显示 `original.mp4` 的原因。
- `Tests/MultiLoopStoreHarness/main.swift:21` 现有断言 `resolve(url: embyURL) == nil`，与本次期望行为相反，需随本次变更更新。

## Requirements

- 当调用方未提供 `media_id` 时，从 URL 路径 `…/videos/{itemId}/…` 推导 Emby item id，生成与 `embytest` 路径一致的 `emby:<host>[:<port>]:<itemId>` externalID。
- 当调用方未提供 `media_title` 时，对**网络 URL**使用 mpv `force-media-title` 作为显示名；取其以 `|` 分隔的末段并去空白，使显示名与 `embytest` 的 `mediaSource.Path` basename 命名约定一致。
- 本地文件不得受 `force-media-title` 影响（用户可能在 mpv.conf / IINA 高级设置中全局设置该选项，会把所有本地文件挤进同一身份）。
- `embytest` 路径（显式 `media_title` / `media_id`）行为逐字节不变，显式元数据优先级最高。
- `fileStarted` 的兜底解析保持仅依赖 URL，不读 `force-media-title`（该选项在播放列表内是粘性的，会污染下一项）。
- externalID 与导出文件中不得出现 api_key、PlaySessionId、DeviceId 或完整签名 URL。
- 不修改第三方 `embyToLocalPlayer`（Python 与油猴脚本）的任何文件；适配全部在 IINA 侧完成。
- 编译、提交、推送到特性分支，并发布带 DMG 资产的新版本。

## Acceptance Criteria

- [ ] `resolve` 对 `https://h/emby/videos/3346/original.mp4?…`（无外部元数据）产出 `externalID == "emby:h:3346"`、`sourceKind == .emby`。
- [ ] 两个不同 itemId 的 `original.mp4` URL 产出两个不同身份，互不共用 loop 记录。
- [ ] 传入 `force-media-title` 为 `A  |  B.mp4` 时显示名为 `B.mp4`；单空格 `A | B.mp4` 同样得到 `B.mp4`；不含 `|` 时取整串。
- [ ] `force-media-title` 缺失时，显示名退化为 `Emby-<itemId>`，且下次带标题启动时被 `updateVideo` 修正。
- [ ] 显式 `media_title` + `media_id`（embytest 形状）解析结果与变更前完全一致。
- [ ] 本地文件身份不受 `force-media-title` 影响。
- [ ] externalID / 导出内容不含 `api_key`、`PlaySessionId`、`DeviceId`。
- [ ] `script/test_multiloop_store.sh` 全部通过，并新增覆盖上述解析行为的断言。
- [ ] `script/build_and_run.sh build Release` 编译通过。
- [ ] 变更提交在特性分支并推送；GitHub Release 附带 `.dmg`。

## Out of Scope

- 修改 `embyToLocalPlayer` 的 Python 代码或其油猴脚本。
- 迁移 / 拆分数据库中已污染的 `original.mp4` 行（见 Notes）。
- 多版本（multi-version）媒体源 `MediaSourceId` 层面的区分。

## Notes

- 污染行（id=13，6 个 segments）在修复后自然成为孤儿：`ensureVideo` 先按 externalID 命中，未命中再按 normalizedName 命中，两者都不会再落到 `original.mp4`，因此无需迁移，也不会被复用。其中 6 段循环来自多部影片混合，无法归属，保留原样供用户自行处理。
