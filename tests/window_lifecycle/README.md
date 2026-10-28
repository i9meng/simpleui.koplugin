# Window lifecycle regressions

Repair author: **i9meng**.

Run from the repository root with LuaJIT 2.1 installed:

```sh
sh tests/window_lifecycle/run.sh
```

Set `LUA_BIN` to use another LuaJIT executable. Lua 5.4 can also run the tests.
The runner executes 27 cases for each of the touch-only and key-enabled device
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

The five production files on this branch match the previously packaged repair.
The branch starts at upstream commit `80e5049`, whose 299 plugin files match the
original package used for diagnosis. The local regression suite passed on
LuaJIT 2.1 and Lua 5.4. Kindle Paperwhite 6 hardware and e-ink rendering have not
been tested.
