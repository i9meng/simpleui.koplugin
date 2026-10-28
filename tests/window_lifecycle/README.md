# Window lifecycle regressions

Repair author: **i9me** (GitHub account: `i9meng`).

Run from the repository root with LuaJIT 2.1 installed:

```sh
sh tests/window_lifecycle/run.sh
```

Set `LUA_BIN` to use another LuaJIT executable. Lua 5.4 can also run the tests.
The runner executes 33 cases for each of the touch-only and key-enabled device
configurations, then compiles every Lua file in the checkout without executing it.

The tests load the actual window, settings and quick-action modules. They use
KOReader's official `show`, `close` and `broadcastEvent` implementations from
`frontend/ui/uimanager.lua`, extracted on 2026-10-28 into
`koreader-window-api.lua`. The file header records that source. Device access,
layout building and drawing are stubbed; private Quick Settings and plugin
lifecycle entry points are loaded from their source files.

Coverage includes:

- Reusing one settings window after 100 repeated open requests.
- Removing the old Quick Settings menu before opening Settings.
- Preserving close state and callbacks across a failed close and retry.
- Handling direct UIManager closes without recursive CloseWidget dispatch.
- Continuing cleanup after one window or close callback fails.
- Cleaning up all windows during exit, restart and host closure.
- Power actions when the plugin or native event listener is absent.
- 300 settings open/close cycles without leftover wrappers.
- Dismissing a window while an official toast overlay is still on top.
- Preserving the 3.0.1 stacked/free-width grid and full-width module rows.
- Using the 3.0.1 category picker, then returning two navigation levels after
  adding singleton or instantiable modules, without creating duplicate settings.

The branch preserves its original repair history and merges upstream commit
`882ce2a125a16326a70a6b09d7c67c25cd56ac8d`. That commit matches all 304 functional
files in the official 3.0.1 release ZIP (SHA-256
`3caf86dac8e32467717ccb9e0d00ac533792d479d9042e67fa075d01d881e73e`), including its
post-tag fixes for home-screen ghosting, hold-dialog columns and toast overlays.
Compared with that official base, only the original five production files carry
the window lifecycle and power-menu repair; other official files stay identical.

The local regression suite passed on LuaJIT 2.1 and Lua 5.4. Kindle Paperwhite 6
hardware and e-ink rendering have not been tested.
