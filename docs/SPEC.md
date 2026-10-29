# WebDock Product Specification — Manual-first Sync Architecture

Status: active for v0.2 / M9.

## 1. Product

WebDock is a native macOS Dock launcher for portable website launch rules. The user manually creates and edits shortcuts; browser-exported shortcut files are not part of the product workflow.

A canonical shortcut expresses intent:

`Name + HTTP/HTTPS URL + optional BrowserFamily + optional Account Email + Group + Order`

A Mac then resolves that intent into a local installed browser and, when applicable, a local Chromium profile directory.

## 2. Creation and editing

Primary creation surfaces:
- Launcher `+`
- Manager `+`
- future `File > New Shortcut` / `⌘N`

Editable fields:
- name
- URL
- preferred browser family
- target account email for supported Chromium-family browsers
- group/order when surfaced

WebDock does not register or import `.crwebloc`, `.webloc`, or `.url` files.

## 3. Portable browser/account identity

Browser intent uses BrowserFamily rather than an installation path or bundle instance.

Cross-device account identity is the primary signed-in account email reported in local Chromium profile metadata.

Never sync `Default`, `Profile 1`, `Profile 12`, or another local profile directory.

Email normalization:
- trim whitespace
- lowercase for comparison
- no Gmail-specific dot/plus canonicalization

## 4. Device-local resolution

Each Mac maintains DeviceShortcutBinding separately from the canonical shortcut.

Resolution order:
1. valid device-only override, if configured;
2. preferred browser family installed + one matching email profile -> exact local profile;
3. browser installed but target email absent -> browser default profile + `missingAccount` warning;
4. more than one profile with same email -> browser default + `ambiguousAccount` warning;
5. preferred browser missing -> system default browser + `missingBrowser` warning;
6. no preferred browser -> system default browser.

Fallbacks must keep the shortcut launchable. Warnings must not block launch.

## 5. Launch behavior

- System default -> open URL normally through macOS.
- Selected browser without resolved profile -> explicitly open URL in that browser.
- Chromium-family browser with resolved local profile -> create a transient `URL + CrProfile` routing `.crwebloc` and explicitly open it with that local browser.
- The transient routing file is cache/runtime state, not canonical data and never syncs.

## 6. UI

Launcher:
- search
- `+` creation
- draggable persistent ordering
- subtle warning badge when the current Mac cannot fully satisfy a rule
- click launches with graceful fallback

Manager:
- list/edit/delete shortcuts
- `Synced Launch Rule` section for BrowserFamily + Account Email
- `This Mac` section showing current resolution/warning
- per-Mac browser/profile override controls

Settings:
- Sync provider: Off / iCloud / WebDAV (planned)
- Sync Now
- sync status
- explanation of device resolution and privacy

## 7. Persistence and deletion

SwiftData stores canonical shortcuts/groups and local DeviceShortcutBinding.

Canonical deletion writes `deletedAt` tombstones instead of immediately removing record identity, preventing an offline device from reviving stale data during a later sync.

Test-era pre-M9 data is not migrated. v0.2 uses a fresh named store.

## 8. Sync contract

Only portable canonical intent syncs.

Sync:
- shortcut UUID
- name
- URL
- BrowserFamily
- target account email
- group/order
- created/updated/deleted timestamps

Never sync:
- DeviceShortcutBinding
- local bundle paths
- local profile directory
- detected local account/profile labels
- runtime cache
- warning state
- local overrides

Stable UUID is record identity. Merge uses record `updatedAt`; tombstones participate in merging.

## 9. Providers

### iCloud
First implementation uses the user's private CloudKit database and a provider-independent serialized snapshot.

CloudKit container target: `iCloud.io.github.codeaix.WebDock`.

Live iCloud access requires an Apple Developer configuration/provisioning profile that includes this container.

### WebDAV
Planned second provider using the same canonical snapshot schema. Credentials must live in macOS Keychain. Conditional writes/ETag must prevent blind overwrite; optional client-side encryption can be added later.

## 10. Privacy

Browser profile discovery reads only local metadata required to obtain profile directory, profile name and signed-in account identity. WebDock does not require cookies, passwords, history or browser page content.

## 11. Acceptance

- no shortcut-file import code or LaunchServices document handlers remain;
- manual creation/editing works without source files;
- canonical records contain account email, never Profile N;
- same account email maps to different local Profile directories correctly on different Macs;
- missing account falls back and warns;
- ambiguous account falls back and warns;
- missing browser falls back and warns;
- local override stays device-only;
- tombstone deletion prevents resurrection;
- iCloud snapshot excludes DeviceShortcutBinding/local Profile N;
- existing Dock launcher/reorder/Manager behaviors remain functional;
- CI + Release smoke build pass before merge.
