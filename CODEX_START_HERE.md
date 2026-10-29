# Codex: Start Here

You are implementing **WebDock**, a native macOS launcher/manager for website shortcuts.

## Read first

1. `AGENTS.md`
2. `docs/SPEC.md`
3. `docs/IMPLEMENTATION_PLAN.md`
4. `docs/TEST_PLAN.md`
5. `docs/DECISIONS.md`

The files under `Sources/` are a starter skeleton, not a claim that the project is already build-complete. Create the actual Xcode project/targets, integrate the source, then replace TODOs with tested implementations.

## First task

Bootstrap a buildable macOS 14+ Xcode project and get the existing skeleton compiling without changing the product contract. Add a test target and include the `.crwebloc` fixture as a test resource.

Then implement milestones in order. Do not begin visual polish before transactional import + Chrome profile launch are tested.

## Critical regression

The supplied test fixture contains:

- URL: `https://chatgpt.com/`
- CrProfile: `Profile 12`

The critical manual behavior is that an imported Chrome shortcut opens a **normal Chrome window/tab in the intended Chrome profile**, not a standalone Chrome Web App.
