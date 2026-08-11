import { connectSlackCredentials } from "@vercel/connect/eve";
import { slackChannel } from "eve/channels/slack";

// Provision with:
//   vercel connect create slack --triggers
//   vercel connect detach <uid> --yes
//   vercel connect attach <uid> --triggers --trigger-path /eve/v1/slack --yes
// Then set SLACK_CONNECTOR to the connector UID (e.g. slack/my-agent).
export default slackChannel({
  credentials: connectSlackCredentials(
    process.env.SLACK_CONNECTOR ?? "slack/my-agent",
  ),
  threadContext: { since: "last-agent-reply" },
});
