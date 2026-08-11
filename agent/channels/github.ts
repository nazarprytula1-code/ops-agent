import { connectGitHubCredentials } from "@vercel/connect/eve";
import { githubChannel } from "eve/channels/github";

// Provision with `eve add channel/github` (recommended) or:
//   vercel connect create github --triggers
// Point the trigger at /eve/v1/github and set GITHUB_CONNECTOR to the UID.
// Default dispatch: comments that include @botName (e.g. @ops-agent).
export default githubChannel({
  botName: process.env.GITHUB_BOT_NAME ?? "ops-agent",
  credentials: connectGitHubCredentials(
    process.env.GITHUB_CONNECTOR ?? "github/my-agent",
  ),
});
