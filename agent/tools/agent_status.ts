import { defineTool } from "eve/tools";
import { z } from "zod";

/**
 * Lightweight health check the agent can call to confirm tool wiring.
 * Replace or extend with real integrations (Linear, Notion, etc.).
 */
export default defineTool({
  description:
    "Return a short status snapshot of this agent runtime (name, time, channel hints).",
  inputSchema: z.object({
    note: z.string().optional().describe("Optional note to echo back"),
  }),
  async execute({ note }) {
    const hasGameGithubToken = Boolean(
      (process.env.GAME_GITHUB_TOKEN ?? process.env.GITHUB_TOKEN ?? "").trim(),
    );
    return {
      ok: true,
      agent: process.env.GITHUB_BOT_NAME ?? "ops-agent",
      at: new Date().toISOString(),
      note: note ?? null,
      surfaces: ["slack", "github"],
      shipping: {
        hasGameGithubToken,
        tools: ["open_game_pr", "merge_game_pr"],
        ifTokenMissing:
          "Human must set GAME_GITHUB_TOKEN on the Vercel project and redeploy. Do not invent git/ssh/gh from the sandbox.",
      },
    };
  },
});
