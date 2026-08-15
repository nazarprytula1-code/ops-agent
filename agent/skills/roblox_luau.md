---
description: Use when the task is Roblox, Luau, Rojo, a place/scripts under game/, or gameplay in Studio. Covers file layout, Luau style, and what this agent cannot do from Slack/GitHub.
---

# Roblox + Rojo (this repo)

Source of truth is Git under `game/` in https://github.com/nazarprytula1-code/ops-agent, not an unsynced Studio place.

In a Slack sandbox, the same tree is at `/workspace/game/` (seeded at deploy). Read that. Do not ask for a repo URL.

## Layout

| Path | Studio |
| --- | --- |
| `game/src/shared/` | `ReplicatedStorage.Shared` (ModuleScripts) |
| `game/src/server/` | `ServerScriptService.Server` (`*.server.luau` → Script) |
| `game/src/client/` | `StarterPlayer.StarterPlayerScripts.Client` (`*.client.luau` → LocalScript) |
| `game/default.project.json` | Rojo tree |

Require shared code as `require(ReplicatedStorage.Shared.<Module>)`.

## How to change code

1. Read existing modules with file tools before adding files.
2. Prefer a small module + one server or client script over a dump of `print`s.
3. Use Luau types on public functions and instance waits (`WaitForChild` + `::`).
4. Do not store secrets, Open Cloud keys, or DataStore keys in source.
5. Do not rewrite `default.project.json` unless the user asked to move services.

## What this agent cannot do

Eve runs in the cloud. It cannot open Explorer, start Play, run `execute_luau` in Studio, or publish a place. After a code change, tell the human to:

```text
cd game
rojo serve
```

Then in Studio: Plugins → Rojo → Connect, and press Play.

## Reply shape

- Paths under `game/src/...`
- What to test in Play (1–3 bullets)
- If the ask needs live Studio (parts, terrain, meshes), say to use Cursor + [Studio MCP](https://create.roblox.com/docs/studio/mcp) locally
