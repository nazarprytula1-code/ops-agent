# ops-agent (Eve)

Autonomous Slack + GitHub assistant built on [eve](https://eve.dev): filesystem-first agent, sandbox, MCP-ready tools, and Langfuse traces.

## What you get

| Piece | Path |
| --- | --- |
| Model / runtime | `agent/agent.ts` |
| System prompt | `agent/instructions.md` |
| Slack channel | `agent/channels/slack.ts` → `/eve/v1/slack` |
| GitHub channel | `agent/channels/github.ts` → `/eve/v1/github` |
| Langfuse OTel | `agent/instrumentation.ts` |
| Skills | `agent/skills/*` |
| Example tool | `agent/tools/agent_status.ts` |

## Prerequisites

- Node.js **24+**
- [Vercel](https://vercel.com) account (AI Gateway + Connect)
- Slack workspace where you can install an app
- GitHub org/account for the Connect GitHub App
- Optional: [Langfuse](https://cloud.langfuse.com) project for traces

## Setup

```bash
npm install
cp .env.example .env
```

### 1. Model (AI Gateway)

```bash
npm i -g vercel@latest
vercel link
vercel env pull
```

Or set `AI_GATEWAY_API_KEY` in `.env`.

### 2. Slack (Vercel Connect)

```bash
vercel connect create slack --triggers
vercel connect detach <uid> --yes
vercel connect attach <uid> --triggers --trigger-path /eve/v1/slack --yes
```

Set `SLACK_CONNECTOR` to the connector UID (e.g. `slack/my-agent`).

### 3. GitHub (Vercel Connect)

From the project directory (after deps are installed):

```bash
npx eve add channel/github
```

Or create a GitHub Connect client, point its trigger at `/eve/v1/github`, and set `GITHUB_CONNECTOR`. Invocation token defaults to `@ops-agent` (`GITHUB_BOT_NAME`).

### 4. Langfuse

Add `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, and `LANGFUSE_BASE_URL` to `.env` and to the Vercel project env. Traces export via `agent/instrumentation.ts`.

## Local dev

```bash
npm run dev
```

Chat in the TUI (`/model` to pick a provider). Slack and GitHub webhooks only work against a **deployed** URL.

## Deploy

```bash
npm run deploy
```

Uses `eve deploy` (wraps production deploy + env). Invite the Slack bot to a channel and @mention it; on GitHub, comment `@ops-agent` on an issue or PR.

## Extend

- Add a tool: `agent/tools/<snake_case>.ts` with `defineTool`
- Add a skill: `agent/skills/<name>.md` with `description` frontmatter
- Change behavior: edit `agent/instructions.md`

## Notes

- Prefer Connect over pasting bot tokens or GitHub App private keys into env when possible.
- Never commit `.env` or real credentials.
# ops-agent
