# ops-agent (Eve)

Autonomous Slack + GitHub assistant built on [eve](https://eve.dev). The Roblox place is sourced under `game/` (Rojo + Luau); the agent reviews and proposes code there. Live Studio (Play, Explorer, MCP) stays on your PC.

## What you get

| Piece | Path |
| --- | --- |
| Model / runtime | `agent/agent.ts` |
| System prompt | `agent/instructions.md` |
| Slack channel | `agent/channels/slack.ts` → `/eve/v1/slack` |
| GitHub channel | `agent/channels/github.ts` → `/eve/v1/github` |
| Langfuse OTel | `agent/instrumentation.ts` |
| Skills | `agent/skills/*` (`roblox_luau.md` for this game) |
| Example tool | `agent/tools/agent_status.ts` |
| Roblox (Rojo) | `game/` |

## Prerequisites

- Node.js **24+**
- [Vercel](https://vercel.com) account (AI Gateway + Connect)
- Slack workspace where you can install an app
- GitHub org/account for the Connect GitHub App
- Rojo 7.7.0 + Roblox Studio for playtest (CLI is in `%LOCALAPPDATA%\Programs\Rojo`; plugin in `%LOCALAPPDATA%\Roblox\Plugins`)
- Optional: [Langfuse](https://cloud.langfuse.com) project for traces

## Setup

```bash
npm install
cp .env.example .env
```

### 1. Model (AI Gateway)

```bash
npm i -g vercel@latest
vercel login
vercel link
vercel env pull
```

Or set `AI_GATEWAY_API_KEY` in `.env`.

### 2. Slack (Vercel Connect)

```bash
vercel connect create slack --name ops-agent --triggers
vercel connect detach slack/ops-agent --yes
vercel connect attach slack/ops-agent --triggers --trigger-path /eve/v1/slack --yes
```

Set `SLACK_CONNECTOR` to the connector UID. Invite the bot to a channel after deploy.

### 3. GitHub (Vercel Connect)

This repo already has `agent/channels/github.ts` (`@ops-agent`). Wire Connect:

```bash
vercel connect create github --name ops-agent --triggers
vercel connect detach github/ops-agent --yes
vercel connect attach github/ops-agent --triggers --trigger-path /eve/v1/github --yes
```

Set `GITHUB_CONNECTOR` and `GITHUB_BOT_NAME=ops-agent` in `.env` and on the Vercel project. In the Connect dashboard, install the GitHub App on the org/user that owns this repository.

Push this project to GitHub if it is not already the connected repo.

### 4. Langfuse

Add `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, and `LANGFUSE_BASE_URL` to `.env` and to the Vercel project env. Traces export via `agent/instrumentation.ts`.

## Deploy (required for Slack + GitHub)

```bash
npm run deploy
```

Webhooks only hit the deployed URL, not `npm run dev`.

## Roblox loop (Git → agent → Studio)

Source of truth: `game/src` + `game/default.project.json`.

1. Push a branch / open a PR that touches `game/`.
2. Comment `@ops-agent review this PR` or `@mention` in Slack with a path like `game/src/server/`.
3. On your PC, playtest (open a **new** PowerShell so `rojo` is on PATH):

```powershell
cd d:\projects\agent\game
rojo serve
```

If `rojo` is still unknown in that window:

```powershell
& "$env:LOCALAPPDATA\Programs\Rojo\rojo.exe" serve
```

In Studio: Plugins → Rojo → Connect, then Play. You should see walk speed from `GameConfig` and `[ops-game] client ready` in Output. Restart Studio once if the Rojo plugin is missing.

Live Explorer / meshes / `execute_luau`: Cursor + [Studio MCP](https://create.roblox.com/docs/studio/mcp) on the same machine. Eve cannot drive Studio from the cloud.

Example Slack prompt after Connect works:

> @ops-agent in `game/src/shared/GameConfig.luau` add a SprintSpeed of 24 and say how to bind it later on the client.

## Publish to Roblox (Open Cloud)

Primary place: Universe `10720619997`, Place `81136506656442`. Reserve: Universe `10735659349`, Place `113088894576682` (`game/open-cloud.json`).

1. Creator Hub → credentials → API key with **`universe-places:write`** on each universe.
2. GitHub repo → Settings → Secrets and variables → Actions → `ROBLOX_API_KEY` (primary), `ROBLOX_API_KEY1` (reserve).
3. Push `game/` to `main` (publishes **reserve / secondary**), or Actions → **Publish Roblox place** → Run workflow. Pick **target** (`secondary` default, or `primary`) and **version_type** (`Saved` = cloud draft, `Published` = live).

Close Team Create / that place in Studio before the run, or Open Cloud may return **409**. Never commit the API key.

## Slack → PR → Roblox

Tools `open_game_pr` and `merge_game_pr` (Slack Approve buttons) commit only `game/` into GitHub, then squash-merge to `main` so Actions publish.

1. GitHub → Settings → Developer settings → Fine-grained token (or classic PAT): **Contents** and **Pull requests** on `nazarprytula1-code/ops-agent`.
2. Vercel project env: `GAME_GITHUB_TOKEN` = that token. Also `.env` for local TUI.
3. `npm run deploy` (tools live on the Eve deployment).
4. Slack: describe the change → Approve PR → if you want it live, Approve merge (Studio closed).

`GAME_GITHUB_TOKEN` is not `ROBLOX_API_KEY`.

## Local agent TUI

```bash
npm run dev
```

Use `/model` to pick a provider. This does not replace Slack/GitHub webhooks.

## Extend

- Add a tool: `agent/tools/<snake_case>.ts` with `defineTool`
- Add a skill: `agent/skills/<name>.md` with `description` frontmatter
- Change behavior: edit `agent/instructions.md`
- Change the game: edit `game/src/`

## Notes

- Prefer Connect over pasting bot tokens or GitHub App private keys into env when possible.
- Never commit `.env` or real credentials.
