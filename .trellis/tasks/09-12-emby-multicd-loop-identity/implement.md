# 执行计划

## 分支

`git checkout -b feat/emby-multicd-loop-identity`（不直接提交 develop；merge 由 Ethan 控制）。

## 顺序

1. **`iina/MultiLoopStore.swift`**
   - [ ] 抽出 `static func embyMediaID(for url: URL) -> String?`
   - [ ] `embyExternalID(for:)` 改为复用它
   - [ ] `resolve` 的 mediaID 改为 `safeMediaID(externalMetadata?.mediaID) ?? embyMediaID(for: url)`
   - [ ] `isGenericStreamName` 增加 `"original"`
2. **`iina/PlayerCore.swift`**
   - [ ] 新增 `forcedMediaTitleMetadata(for:)`
   - [ ] `openMainWindow` 的 resolve 调用接入 `?? forcedMediaTitleMetadata(for: url)`
   - [ ] 确认 `fileStarted` else 分支未改动
3. **`Tests/MultiLoopStoreHarness/main.swift`**
   - [ ] 更新与新行为冲突的 nil 断言
   - [ ] 新增 PRD 验收项对应的断言
4. **验证**
   - [ ] `./script/test_multiloop_store.sh`
   - [ ] `./script/build_and_run.sh build Release`
   - [ ] 实机：启动 emby 后台，播一个多 CD 影片的 CD2 与 CD3，确认标题栏显示真实文件名、两者 loop 记录独立
5. **发布**
   - [ ] commit + push 特性分支
   - [ ] 在 `script/package_release.sh` 增加 DMG 产出（`hdiutil create -srcfolder`，附 `/Applications` 符号链接）
   - [ ] `gh release create v1.4.4-multiloop`，附 DMG 与 `embytest-1.1.4-mac-mpv-new-instance.user.js`

## 验证命令

```bash
./script/test_multiloop_store.sh
./script/build_and_run.sh build Release
sqlite3 ~/Library/Application\ Support/com.colliderli.iina/multiloop.sqlite3 \
  "select id,display_name,external_id,source_kind from videos order by id desc limit 10;"
```

实机后期望：新增两行 `external_id = emby:emby.tiaotiao.best:<CD2 id>` 与 `:<CD3 id>`，display_name 为真实文件名；`id=13 / original.mp4` 不再增加 segments。

## 回滚点

- 步骤 1-3 任一失败：`git checkout -- <file>`，特性分支未推送前无外部影响。
- 发布后问题：revert 单 commit，schema 未变，数据库无需回滚。

## Review Gate

编译 + harness 通过 + 实机确认 CD2/CD3 身份独立后，才进入提交与发布。
