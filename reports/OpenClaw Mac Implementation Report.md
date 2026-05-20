# OpenClaw Mac Implementation Report

Date: 2026-05-18
Project: `/Users/artem/Projects/openclaw-mac`

## Result

OpenClaw Mac launcher has been stabilized as a local working macOS launcher scaffold. The source tree is clean, generated build artifacts were removed, security-critical localhost/runtime pieces were tightened, validation checks pass, and a local baseline git commit was created.

This is not yet a public notarized production release because Apple Developer Program credentials, Developer ID certificate, Sparkle production key, and full Xcode installation are external/manual prerequisites.

## Implemented / verified

- SwiftUI menu bar launcher structure is present.
- First-run wizard structure is present.
- Preferences, About, Advanced, Server and General tabs are present.
- Server manager starts a bundled runtime through `Process`.
- Health checks use bearer token auth.
- Runtime resolver supports architecture-specific bundled Node and custom Node path.
- Auth token is 32 random bytes encoded as 64 hex chars.
- Auth token file is created with `0600` permissions; data dir with `0700` where possible.
- Keychain fallback implementation now uses add-or-update instead of delete-then-add.
- Keychain fallback sets explicit `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
- macOS Keychain fallback sets `kSecUseDataProtectionKeychain: true`.
- Uninstaller uses an allowlist before deleting user files.
- Fallback runtime is no longer just a placeholder page: it is a secured local runtime smoke target.
- Fallback runtime binds to `127.0.0.1`.
- Fallback runtime requires auth for `/health` and browser page access.
- Fallback runtime restricts CORS to localhost origins.
- Browser handoff with `?token=` redirects away from the query token and sets an HTTP-only same-site cookie.
- Release scripts fail explicitly when signing identity is missing instead of using fake placeholder identity.
- GitHub build workflow runs runtime smoke test before build.
- GitHub release workflow cleans up signing keychain and `cert.p12` after execution.
- README and SECURITY docs updated to match actual behavior.
- Generated `build/` folder was removed from the project.
- Scripts are executable.
- Local baseline commit created.

## Files changed materially

- `OpenClaw/Storage/KeychainStore.swift`
- `OpenClaw/Storage/AuthToken.swift`
- `OpenClaw/Uninstall/Uninstaller.swift`
- `OpenClaw/Resources/runtime/server/index.js`
- `Scripts/smoke-test-runtime.sh`
- `Scripts/sign.sh`
- `Scripts/make-dmg.sh`
- `.github/workflows/build.yml`
- `.github/workflows/release.yml`
- `README.md`
- `docs/SECURITY.md`

## Validation performed

Command-level validations completed successfully:

- `bash -n Scripts/*.sh`
- `node --check OpenClaw/Resources/runtime/server/index.js`
- `bash Scripts/smoke-test-runtime.sh`
- `swiftc -parse-as-library -target arm64-apple-macos13.0 ...`
- `plutil -lint OpenClaw/Resources/Info.plist OpenClaw/Resources/OpenClaw.entitlements OpenClaw.xcodeproj/project.pbxproj`
- `git status --short` after commit

Runtime smoke result:

- unauthorized `/health` returns `401`
- authorized `/health` returns `200`
- browser token handoff returns `302`
- server prints `LISTENING_ON:7842`

## Remaining manual blockers

These cannot be completed by code changes alone:

1. Install/select full Xcode.
   - Current `xcode-select -p`: `/Library/Developer/CommandLineTools`
   - `xcodebuild` currently fails because full Xcode is not selected/installed.
   - `/Applications/Xcode.app` was not found.

2. Apple Developer Program.
   - Needed for Developer ID Application certificate.
   - Needed for Gatekeeper-friendly distribution.

3. Notarization credentials.
   - `APPLE_ID`
   - `TEAM_ID`
   - `APP_SPECIFIC_PASSWORD`

4. Production Sparkle key.
   - `SUPublicEDKey` in `Info.plist` is still `REPLACE_WITH_SPARKLE_PUBLIC_EDDSA_KEY` until a real Sparkle EdDSA key pair is generated.
   - `SPARKLE_PRIVATE_KEY` must be stored only in CI secrets / secure local storage.

5. Real OpenClaw server runtime.
   - Current bundled server is a secured fallback runtime for launcher validation.
   - Production release must bundle the real `openclaw` server via `Scripts/bundle-runtime.sh` or switch to a single binary runtime.

## Recommended next commands after installing Xcode

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
cd /Users/artem/Projects/openclaw-mac
SKIP_NODE_DOWNLOAD=1 SKIP_SERVER_DOWNLOAD=1 ./Scripts/bundle-runtime.sh
./Scripts/smoke-test-runtime.sh
./Scripts/build.sh
```

For production runtime:

```bash
OPENCLAW_REPO=https://github.com/YOUR_ORG/openclaw.git \
OPENCLAW_VERSION=v0.1.0 \
./Scripts/bundle-runtime.sh
./Scripts/build.sh
```

For signing/release after credentials are ready:

```bash
IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/sign.sh
APPLE_ID=... TEAM_ID=... APP_SPECIFIC_PASSWORD=... ./Scripts/notarize.sh
IDENTITY="Developer ID Application: Your Name (TEAMID)" NOTARIZE_DMG=1 ./Scripts/make-dmg.sh
SPARKLE_PRIVATE_KEY=... ./Scripts/appcast.sh
```

## 2026-05-19 hard audit update

- Strict validation passed: plist, scheme XML, shell syntax, JSON, Swift 6 typecheck with warnings as errors, runtime smoke test, ad-hoc codesign verification, `hdiutil verify`, and DMG mount inspection.
- Codex / ChatGPT authorization now defaults to login/password. Google, official website, and API key remain available as alternate methods.
- Runtime installer now installs server production dependencies for downloaded/local runtimes with `npm ci --omit=dev` or `npm install --omit=dev`.
- Placeholder runtime detection prevents the smoke-test runtime from being treated as the real product runtime.
- Diagnostics export now checks `zip` exit status and removes temporary folders.
- Xcode metadata updated to `MARKETING_VERSION = 0.1.6`, `CURRENT_PROJECT_VERSION = 7`, `SWIFT_VERSION = 6.0`.
- Packaging script now deletes staging app bundles, runtime smoke logs, and module cache after a successful DMG build.
- Safe junk removed: `.DS_Store`, Xcode `xcuserdata`, smoke-test logs, temporary app/staging folders, and module cache.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current DMG version: `0.1.6-test` build `7`

## 2026-05-19 Universal Mac audit

- Previous dev DMG was found to be `arm64` only.
- `Scripts/package-dev-dmg.sh` now compiles `arm64-apple-macosx13.0` and `x86_64-apple-macosx13.0`, then merges them with `lipo`.
- Packaged app executable is verified as a Mach-O universal binary with `x86_64` and `arm64` slices.
- Bundled Node runtime is verified for both architectures: `node-arm64` is `arm64`, `node-x64` is `x86_64`.
- Xcode metadata is now `MARKETING_VERSION = 0.1.7`, `CURRENT_PROJECT_VERSION = 8`.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current DMG version: `0.1.7-test` build `8`
- Current DMG SHA-256: `bf2b76117660755dcb57338d083561b506d27615dd85f123093ef248d0e01b7a`

## 2026-05-19 icon and Russian setup fix

- Generated `OpenClaw/Resources/OpenClaw.icns` from `/Users/artem/Desktop/image.png`.
- Added `CFBundleIconFile = OpenClaw` and included `OpenClaw.icns` in both Xcode resources and dev DMG packaging.
- Replaced AppIcon asset PNGs with resized versions of the provided OpenClaw icon.
- Fixed missing runtime-source translations so the Russian setup screen no longer shows English descriptions.
- Replaced Russian `placeholder` wording with `тестовая заглушка`.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current DMG version: `0.1.8-test` build `9`
- Current DMG SHA-256: `8be66a4f3cf69a0df598f027e4c7ce8e0ca2e3d491ecb345f96c154c8385a8ab`

## 2026-05-19 npm PATH install fix

- Reproduced the reported setup failure: bundled `npm` exits with code `127` and `env: node: No such file or directory` when launched without the bundled Node `bin` directory in `PATH`.
- Fixed `RuntimeInstaller` so dependency installation runs with an explicit `PATH` containing the selected bundled/downloaded Node directory.
- Added a preflight `node --version` check before `npm ci` / `npm install` so Node resolution errors fail early and clearly.
- Added an app-local npm cache at `~/Library/Caches/OpenClaw/npm`.
- Hardened runtime install retries: download/local installs now reset the previous runtime folder before reinstalling.
- Hardened partial install detection: `~/Library/Application Support/OpenClaw/runtime` is no longer treated as usable unless a completed `version.json` manifest exists.
- Added `Testing bundled npm PATH isolation` to `Scripts/package-dev-dmg.sh` so packaging catches this regression before DMG creation.
- Updated Xcode/package metadata to `MARKETING_VERSION = 0.1.9`, `CURRENT_PROJECT_VERSION = 10`.
- Verification passed: Swift 6 typecheck, app-bundled runtime smoke test, universal binary build, ad-hoc codesign verification, `hdiutil verify`, and DMG mount inspection.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current DMG version: `0.1.9-test` build `10`
- Current DMG SHA-256: `55929b475959e3e42adcdf86ac5c03323dbc4ff3e5713f5426b4a5aad5142890`

## 2026-05-19 real OpenClaw gateway install fix

- Reproduced the next setup blocker: GitHub source archives install dependencies but do not contain built `dist/` output, so the launcher reported `OpenClaw server location is required` after download.
- Switched the internet runtime source to install the built npm package `openclaw@latest` instead of a raw GitHub source tarball.
- Updated default Node runtime to `22.19.0`, matching OpenClaw's current `engines.node >=22.19.0` requirement.
- Updated the launch command for real OpenClaw runtimes to `openclaw.mjs gateway --port ... --bind loopback --auth token --token ... --allow-unconfigured`.
- Added real gateway entry-point detection for `server/openclaw.mjs`.
- Updated health checks to support both the fallback `/health` endpoint and the real OpenClaw gateway `/healthz` endpoint.
- Added OpenClaw gateway environment isolation: `OPENCLAW_STATE_DIR`, `OPENCLAW_CONFIG_PATH`, `OPENCLAW_GATEWAY_PORT`, and `OPENCLAW_GATEWAY_TOKEN` now point inside the selected OpenClaw data directory.
- Fixed the source wizard copy: the internet option now says npm registry / package version, not GitHub branch/tag.
- Added Russian translations for the new runtime install errors and npm package install labels.
- Verified the exact internet install path in `/tmp`: downloaded Node `22.19.0`, packed `openclaw@latest`, installed production deps, started `openclaw gateway`, checked `/healthz`, and loaded Control UI root with a token.
- Updated package metadata to `MARKETING_VERSION = 0.1.10`, `CURRENT_PROJECT_VERSION = 11`.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current DMG version: `0.1.10-test` build `11`
- Current DMG SHA-256: `fd98287f0428debb81cd04c21355ebb75b2d4a3faf1924358dd1b056ec95b0c5`

## 2026-05-19 setup flow and link install update

- Added an English-only startup choice screen: `Install OpenClaw` / `Uninstall OpenClaw`.
- Added direct install from link in the runtime source wizard. Supported server archive links: `.tgz`, `.tar.gz`, `.tar`, and `.zip`.
- Removed the visible OpenClaw version/ref field from internet install. The default internet path now downloads the latest `openclaw` package from npm instead of pinning the user to a manual version.
- Added a top-left back arrow to the wizard for every setup step after the startup choice screen, including the language picker.
- Back navigation now performs setup rollback: clears staged settings, removes saved auth values, resets selected runtime state, and removes a runtime installed during the current wizard session.
- Added non-destructive cleanup support for rollback so the wizard can remove OpenClaw data without moving the `.app` to Trash. The explicit `Uninstall OpenClaw` action still removes data, credentials, preferences, logs, and recycles the app bundle.
- Updated source runtime Node to `22.19.0` for both `arm64` and `x64`, matching the packaged DMG and OpenClaw's Node engine requirement.
- Preserved the bundled fallback runtime marker so the smoke-test runtime is still not treated as a real OpenClaw server.
- Added Russian translations for the new link-install and latest-download labels.
- Verification passed: Swift 6 typecheck, fallback runtime smoke test, packaged runtime smoke test, universal `arm64 + x86_64` build, ad-hoc codesign verification, `hdiutil verify`, DMG mount inspection, and final URL-install smoke test using the mounted DMG's Node 22.19.0.
- Final URL-install smoke used: `https://registry.npmjs.org/openclaw/-/openclaw-2026.5.18.tgz`
- Only one DMG remains in `build/`: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current verified DMG version: `0.1.11-test` build `12`
- Current DMG SHA-256: `4bc4cd166b8f2776c2b560dfb96b0dc8422296ad5573b780ff081d82c9742de7`

## 2026-05-19 Control UI pairing and resizable window fix

- Reproduced the user-facing failure mode: real OpenClaw gateway started, but Control UI showed `Device pairing required`, so the previous health/root checks were not enough.
- Inspected the current OpenClaw npm package and found the relevant local Control UI config flag: `gateway.controlUi.dangerouslyDisableDeviceAuth`.
- Updated launcher startup for real `openclaw.mjs` runtimes to write a managed local `openclaw.json` before process launch:
  - `gateway.mode = local`
  - `gateway.bind = loopback`
  - `gateway.auth.mode = token`
  - `gateway.controlUi.allowInsecureAuth = true`
  - `gateway.controlUi.dangerouslyDisableDeviceAuth = true`
  - `gateway.nodes.pairing.autoApproveCidrs = ["127.0.0.1/32", "::1/128"]`
- Changed browser handoff for real OpenClaw packages from `?token=...` to OpenClaw's expected `#token=...` URL fragment.
- Verified in the browser against a real local gateway: opening `http://127.0.0.1:<port>/#token=...` now lands in the working Control UI Chat screen without the red `Device pairing required` block.
- Made the setup window resizable by mouse: added the macOS `.resizable` window style, kept `600x480` as minimum size, and removed the fixed SwiftUI root frame.
- Made Preferences content resizable with a minimum frame instead of a fixed frame.
- Cleaned stale local test processes from old mounted DMGs and Xcode Debug builds so ports `7842-7845` no longer conflict with the new build.
- Verification passed: Swift 6 typecheck, fallback runtime smoke test, app-bundled runtime smoke test, universal `arm64 + x86_64` build, ad-hoc codesign verification, `hdiutil verify`, DMG mount inspection, no mounted OpenClaw volumes, no running OpenClaw processes.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current verified DMG version: `0.1.12-test` build `13`
- Current DMG SHA-256: `7062bb605602f416c908497cf36109fb5e79efd72d17ceb3e1f68a88a62b2dd9`

## 2026-05-19 official skills installer

- Bundled the official OpenClaw skills from `openclaw@latest` into `OpenClaw/Resources/skills`.
- Current bundled catalog contains 57 official skills, each with its original `SKILL.md`.
- Added a new first-run wizard step: `Official Skills`.
- The installer now lets the user install all official skills, choose individual skills from the list, or continue without installing skills.
- Skills are copied into `~/Library/Application Support/OpenClaw/skills`.
- Each installed official skill receives a `.openclaw-official-skill` marker.
- Existing custom skills with the same folder name are preserved and skipped instead of overwritten.
- Returning to the skills step and unchecking an official skill removes the previously installed marked official copy.
- Wizard rollback removes official skills installed during the current setup session.
- Added localized UI strings for the new skills step across all existing language tables.
- Added `Scripts/bundle-official-skills.sh` and updated `Scripts/package-dev-dmg.sh` so the DMG build fails if no official skills are bundled.
- Added the new Swift files and `skills` resource folder to `OpenClaw.xcodeproj`.
- Updated Xcode/package metadata to `MARKETING_VERSION = 0.1.13`, `CURRENT_PROJECT_VERSION = 14`.
- Verification passed: Swift 6 typecheck, fallback runtime smoke test, app-bundled runtime smoke test, universal `arm64 + x86_64` build, ad-hoc codesign verification, `hdiutil verify`, DMG mount inspection, exact `SKILL.md` count check, no mounted OpenClaw volumes, no running OpenClaw processes.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current verified DMG version: `0.1.13-test` build `14`
- Current DMG SHA-256: `609527ed5067fca20a1a1284d914ea3fb50dd449186a46e1dc3d8821fe834557`

## 2026-05-19 Openzen branding and light UI

- Added the provided Openzen image as `OpenClaw/Resources/OpenzenMark.png`.
- Added shared SwiftUI branding components in `OpenClaw/App/OpenzenBranding.swift`.
- Added the Openzen mark to every primary app surface:
  - first-run/setup wizard
  - Preferences window
  - MenuBar popup
- Added the footer text `developed by Openzen www.openzen.info` to those app surfaces.
- Forced the branded app surfaces to use a light color scheme and light background.
- Increased the setup window default/minimum size to preserve layout after adding the brand header/footer.
- Added `OpenzenMark.png` to Xcode project resources and to the DMG packaging flow.
- Updated package/project metadata to `MARKETING_VERSION = 0.1.14`, `CURRENT_PROJECT_VERSION = 15`.
- Verification passed: Swift 6 typecheck, fallback runtime smoke test, app-bundled runtime smoke test, universal `arm64 + x86_64` build, ad-hoc codesign verification, `hdiutil verify`, DMG mount inspection, Openzen asset check, exact `SKILL.md` count check, no mounted OpenClaw volumes, no running OpenClaw processes.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current verified DMG version: `0.1.14-test` build `15`
- Current DMG SHA-256: `efa9d47330a81902d2f63d8049b0d0007e1fd364ada12f89a6119e6fc7912869`

## 2026-05-19 Codex/OpenAI auth repair

- Root cause: the launcher saved the selected `Codex` provider, but the real OpenClaw agent expected its own `state/agents/main/agent/auth-profiles.json` profile store. The server therefore started, but agent replies failed with `No API key found for provider "openai"`.
- Removed the misleading Codex login/password path. Codex auth now offers:
  - existing Codex CLI / Codex app sign-in from this Mac
  - OpenAI API key fallback
- Added `OpenClawModelAuthConfigurator`, called before server launch, to create/merge the real OpenClaw auth profile store from an existing local Codex sign-in without printing tokens.
- The configurator now writes:
  - `state/agents/main/agent/auth-profiles.json`
  - `state/openclaw.json`
  - ordered `openai` and `openai-codex` auth profile selections
  - default model route `openai/gpt-5.5`
- Added migration handling for stale saved auth methods such as the old `codex = google`; invalid stored methods now fall back to `codex-cli`.
- Removed a noisy missing-plugin warning by not enabling the absent external `codex` plugin entry; the built-in OpenAI/OpenAI-Codex provider remains enabled.
- Repaired the current installed local state under `~/Library/Application Support/OpenClaw` so the already-installed app has a usable Codex OAuth profile.
- Verified current local auth with `openclaw models status --probe --probe-provider openai-codex`: runtime auth is usable and the probe returned `ok`.
- Added localized strings for the new Codex auth path across the existing language tables.
- Updated package/project metadata to `MARKETING_VERSION = 0.1.16`, `CURRENT_PROJECT_VERSION = 17`.
- Verification passed: Swift 6 typecheck, fallback runtime smoke test, app-bundled runtime smoke test, universal `arm64 + x86_64` build, ad-hoc codesign verification, `hdiutil verify`, DMG mount inspection, Openzen asset check, exact `SKILL.md` count check, and OpenClaw auth probe.
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-dev-tested.dmg`
- Current verified DMG version: `0.1.16-test` build `17`
- Current DMG SHA-256: `6c1968e55e14e0a6ae743a8f9206ef52e094629971e96cde9e06b29f3200c583`

## 2026-05-20 repack after user edits

- Preserved existing DMG files until the new image passed verification.
- Updated `Scripts/package-dev-dmg.sh` so it no longer deletes previous `*.dmg` files at the beginning of packaging.
- Built a fresh verified image: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-20260520-verified.dmg`.
- Removed old DMG files only after the new image passed verification.
- Verification passed:
  - plist and Xcode scheme validation
  - shell script syntax checks
  - fallback runtime smoke test
  - Swift 6 typecheck
  - app-bundled runtime smoke test
  - universal `arm64 + x86_64` build
  - bundled Node architecture checks for `arm64` and `x86_64`
  - strict ad-hoc codesign verification
  - `hdiutil verify`
  - read-only DMG mount inspection
  - mounted runtime `/health` check
  - 57 bundled official skills
- Current verified DMG: `/Users/artem/Projects/openclaw-mac/build/OpenClaw-20260520-verified.dmg`
- Current verified DMG version: `0.1.16-test` build `17`
- Current DMG SHA-256: `fdb8b93963bb05d4fd220c52069ce0e68e920e1fff7aefe56a447f25b8dde1bd`
