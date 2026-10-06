# Strata

Bar widget for local model servers. It finds every installed engine and its ready models by itself,
runs one model at a time, and gives each model its own port.

- **Glyph**: a chip icon (lit while a model runs) and the selected model's name. Click to open the panel.
- **Panel**: models grouped by engine, each with its port; the selected model's address; START / STOP.

## Engines and models (auto-detected)

| Engine | Found when | Models | Unit |
|---|---|---|---|
| Strata | `~/Strata/serve/server.py` exists | every `~/Strata/strata-<name>.json` (port from its `"port"`) | `strata.service` |
| TabbyAPI | `~/tabbyAPI/run.sh` exists | every finished folder in `~/tabbyAPI/models/` (EXL3) | `tabby.service` |
| llama.cpp | `llama-server` is on the PATH | every `*.gguf` in `~/llm-src/gguf/` and `~/models/` (first shard; no mmproj/imatrix) | `llama.service` |

A model with no fixed port gets the next free one from 8081 (skipping 8080 and ports in use) the
first time it is seen, kept in `ports` under the state dir so it never changes.

## What it runs, reads, writes

- `bin/strata-models list` every 5 s (reads the folders above, `ss -ltn` when assigning a port) and
  `systemctl --user is-active` on the engines' units.
- On click: `use` writes `current`; `start` writes the engine's env file (`model.env`, `tabby.env`,
  `llama.env`), stops every other unit and any model server started by hand (`pkill` on the server
  command lines), then restarts the engine's unit; `stop` stops all units.
- Writes only under `$XDG_STATE_HOME/ryoku/plugins/strata/`. No privileged commands. Network: none itself; it only shows the local servers' `127.0.0.1` address.
- The units are the user's (`~/.config/systemd/user/`); none is enabled, nothing starts at login.
