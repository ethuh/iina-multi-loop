# deps/

## OVERVIEW
Vendored headers under `deps/include/` and downloaded runtime dylibs/executables under `deps/lib/` and `deps/executable/` (populated by scripts).

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| libmpv headers | `deps/include/mpv/client.h` `deps/include/mpv/render.h` `deps/include/mpv/render_gl.h` | included via `iina/iina-Bridging-Header.h` |
| FFmpeg headers | `deps/include/libav*/*` | vendored headers must match dylib versions |
| Downloaded dylibs | `deps/lib/` | filled by `other/download_libs.sh` or `other/change_lib_dependencies.rb` |
| Downloaded executables | `deps/executable/` | e.g. yt-dlp/youtube-dl download target |

## CONVENTIONS
- Indentation: `.editorconfig` sets `deps/include/**` to `indent_size=4`.
- Headers are treated as vendored inputs; prefer replacing from upstream builds over editing by hand.

## ANTI-PATTERNS
- Don't mix-and-match header versions and dylib versions (README explicitly warns headers must match dylibs).
- Don't re-enable deprecated mpv API surface lightly: `iina/iina-Bridging-Header.h` defines `MPV_ENABLE_DEPRECATED 0`.

## HOW UPDATES HAPPEN (FACTUAL, REPO-SPECIFIC)
- "Precompiled libraries" path: run `./other/download_libs.sh` (downloads file list from `https://iina.io/dylibs/...`).
- "Build mpv manually" path (README): copy mpv/FFmpeg headers into `deps/include/` and update dylibs into `deps/lib/`.
