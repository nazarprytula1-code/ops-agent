---
description: Use when asked to review a pull request, summarize a diff, or suggest review comments on GitHub.
---

# Review a pull request

1. Confirm which PR or diff is in scope (from channel context or the user message).
2. Prefer the sandbox checkout and built-in file tools (`read_file`, `grep`, `glob`) over guessing.
3. Structure the reply as:
   - **Summary** — what the change does in 1–3 sentences
   - **Risks** — bugs, missing tests, security/auth concerns
   - **Suggestions** — concrete, ordered next steps (paths when possible)
4. Keep the tone collaborative; do not rewrite the whole PR unless asked.
5. If context is incomplete (no checkout locally, huge generated files), say what you could not see.
