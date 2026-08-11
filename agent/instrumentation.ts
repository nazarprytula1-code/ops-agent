import { defineInstrumentation } from "eve/instrumentation";
import { registerOTel } from "@vercel/otel";
import { LangfuseSpanProcessor } from "@langfuse/otel";

export default defineInstrumentation({
  setup: ({ agentName }) =>
    registerOTel({
      serviceName: agentName,
      spanProcessors: [
        new LangfuseSpanProcessor({
          // Keep model/tool spans and the eve run parent; drop noisy workflow plumbing.
          shouldExportSpan: ({ otelSpan }) =>
            ["gen_ai", "eve", "langfuse-sdk"].includes(
              otelSpan.instrumentationScope.name,
            ),
        }),
      ],
    }),
});
