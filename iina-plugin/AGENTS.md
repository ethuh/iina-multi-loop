# iina-plugin/

## OVERVIEW
Swift CLI for plugin development workflow (create template, pack, link/unlink). This is separate from the runtime plugin system in `iina/`.

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| CLI entry point | `iina-plugin/main.swift` | commands: `new`, `pack`, `link`, `unlink` |
| Template source | `iina-plugin/main.swift` | downloads zip from `https://dl.iina.io/plugin-template/master.zip` |

## CONVENTIONS
- `new` prompts for UI choices (React/Vue/None) and bundler usage; outputs a plugin directory and prints `npm install` / `npm run build` instructions.
- `pack` outputs `.iinaplgz` plugin packages.
- `link`/`unlink` manage development symlinks so IINA can load the folder as a dev package.

## ANTI-PATTERNS
- Don't confuse this tool with the runtime plugin loader; runtime is `iina/JavascriptPlugin.swift`.
