import { connectSlackCredentials } from "@vercel/connect/eve";
import { slackChannel } from "eve/channels/slack";

// Eve's Slack HITL decoder only resumes pauses whose `action_id` starts
// with this prefix (see `deriveHitlResponse` in the Slack channel).
const HITL_ACTION_PREFIX = "eve_input:";
const HITL_FREEFORM_ACTION_PREFIX = "eve_input_freeform:";

type HitlOption = {
  id: string;
  label: string;
  style?: "danger" | "default" | "primary";
};

type HitlRequest = {
  allowFreeform?: boolean;
  display?: string;
  options?: HitlOption[];
  prompt: string;
  requestId: string;
};

let lastHitlPostOk = false;
let lastHitlRequests: HitlRequest[] = [];

function isApprovalRequest(request: HitlRequest): boolean {
  return (
    request.display === "confirmation" &&
    request.options?.length === 2 &&
    request.options[0]?.id === "approve" &&
    request.options[1]?.id === "deny"
  );
}

function hitlButtons(request: HitlRequest) {
  const prefix = `${HITL_ACTION_PREFIX}${request.requestId}`;
  const options: HitlOption[] = isApprovalRequest(request)
    ? [
        { id: "deny", label: "Deny", style: "danger" },
        { id: "approve", label: "Allow", style: "primary" },
      ]
    : (request.options ?? []);

  return options.map((option, index) => {
    const button: Record<string, unknown> = {
      action_id: `${prefix}:button:${index}`,
      text: { emoji: false, text: option.label.slice(0, 75), type: "plain_text" },
      type: "button",
      value: option.id,
    };
    if (option.style === "primary" || option.style === "danger") {
      button.style = option.style;
    }
    return button;
  });
}

function hitlBlocks(request: HitlRequest): unknown[] {
  const buttons = hitlButtons(request);
  if (request.allowFreeform === true || buttons.length === 0) {
    buttons.push({
      action_id: `${HITL_FREEFORM_ACTION_PREFIX}${request.requestId}`,
      style: "primary",
      text: { emoji: false, text: "Type your answer", type: "plain_text" },
      type: "button",
      value: request.requestId,
    });
  }
  return [
    {
      text: { text: `*${request.prompt}*`, type: "mrkdwn" },
      type: "section",
    },
    ...(buttons.length > 0 ? [{ elements: buttons, type: "actions" }] : []),
  ];
}

async function postHitlRequests(
  requests: readonly HitlRequest[],
  post: (message: { blocks: readonly unknown[]; text: string } | string) => Promise<unknown>,
) {
  lastHitlRequests = [...requests];
  lastHitlPostOk = false;
  for (const request of requests) {
    try {
      await post({
        blocks: hitlBlocks(request),
        text: `${request.prompt} — click Allow or Deny`,
      });
    } catch {
      await post(
        `${request.prompt}\nClick *Allow* in this thread (or reply \`approve\`).`,
      );
    }
  }
  lastHitlPostOk = true;
}

export default slackChannel({
  credentials: connectSlackCredentials(
    process.env.SLACK_CONNECTOR ?? "slack/ops-agent",
  ),
  threadContext: { since: "last-agent-reply" },
  events: {
    // Default HITL uses Slack `card` blocks. Those often land late or
    // invisible, so the run parks with no clickable Allow. Post classic
    // Block Kit action buttons instead so Allow appears as soon as the
    // tool pauses.
    async "input.requested"(data, channel) {
      await postHitlRequests(data.requests, (message) =>
        channel.thread.post(message),
      );
    },
    async "session.waiting"(_data, channel) {
      if (lastHitlPostOk || lastHitlRequests.length === 0) return;
      await postHitlRequests(lastHitlRequests, (message) =>
        channel.thread.post(message),
      );
    },
  },
});
