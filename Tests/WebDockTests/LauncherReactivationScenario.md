Manual scenario covered by `LauncherVisibilityStateTests` and required on a real Mac:

1. Launcher visible.
2. User clicks outside; app resigns active and launcher hides.
3. User clicks the Dock icon once.
4. Reopen queues a pending show but does not display synchronously.
5. A late resign event, if any, hides without clearing the pending request.
6. Once the app is active, a deferred main-run-loop task consumes the request and shows the launcher.
7. Launcher remains visible until the next outside click or Dock toggle.
