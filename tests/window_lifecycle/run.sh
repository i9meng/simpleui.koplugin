#!/bin/sh
set -eu

test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
plugin_dir=$(CDPATH= cd -- "$test_dir/../.." && pwd)
lua_bin=${LUA_BIN:-luajit}

"$lua_bin" "$test_dir/regressions.lua" "$plugin_dir" "$test_dir" touch-only
"$lua_bin" "$test_dir/regressions.lua" "$plugin_dir" "$test_dir" keys

syntax_list=$(mktemp)
trap 'rm -f "$syntax_list"' EXIT HUP INT TERM
find "$plugin_dir" -type f -name '*.lua' ! -path '*/.git/*' > "$syntax_list"
"$lua_bin" "$test_dir/check_syntax.lua" "$syntax_list"
