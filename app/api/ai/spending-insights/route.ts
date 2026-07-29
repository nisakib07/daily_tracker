import { z } from "zod";
import { corsJson, corsPreflight } from "@/lib/ai/cors";
import { GEMINI_MODEL, getGeminiClient } from "@/lib/ai/gemini-client";
import { verifyUser } from "@/lib/ai/verify-user";

const CategorySpend = z.object({ category: z.string(), amount: z.number().nonnegative() });

const RequestSchema = z.object({
  income: z.number().nonnegative(),
  thisMonthCategorySpending: z.array(CategorySpend),
  lastMonthCategorySpending: z.array(CategorySpend),
});

const SuggestionSchema = z.object({
  suggestions: z.array(
    z.object({
      category: z.string(),
      message: z.string(),
      estimatedMonthlySaving: z.number().nonnegative(),
    }),
  ),
});

const RESPONSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    suggestions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          category: { type: "string" },
          message: { type: "string" },
          estimatedMonthlySaving: { type: "number" },
        },
        required: ["category", "message", "estimatedMonthlySaving"],
      },
    },
  },
  required: ["suggestions"],
};

export async function OPTIONS(request: Request) {
  return corsPreflight(request);
}

export async function POST(request: Request) {
  const user = await verifyUser(request);
  if (!user) {
    return corsJson(request, { error: "Unauthorized" }, { status: 401 });
  }

  let body: z.infer<typeof RequestSchema>;
  try {
    body = RequestSchema.parse(await request.json());
  } catch {
    return corsJson(request, { error: "Invalid request body" }, { status: 400 });
  }

  const prompt = [
    `This month's income so far: ~${body.income} BDT.`,
    "This month's spending by category:",
    ...body.thisMonthCategorySpending.map((c) => `- ${c.category}: ${c.amount} BDT`),
    "Last month's spending by category:",
    ...body.lastMonthCategorySpending.map((c) => `- ${c.category}: ${c.amount} BDT`),
    "Identify up to 3 concrete, specific places this person could cut " +
      "spending, based on month-over-month changes or categories that " +
      "look unusually large relative to their income. For each, give a " +
      "short, specific, encouraging message (not generic advice) and a " +
      "realistic estimated monthly saving in BDT. If nothing stands out, " +
      "return an empty suggestions array rather than inventing filler.",
  ].join("\n");

  try {
    const client = getGeminiClient();
    const interaction = await client.interactions.create({
      model: GEMINI_MODEL,
      input: prompt,
      system_instruction:
        "You are a pragmatic personal-finance assistant for a user in " +
        "Bangladesh, looking for concrete ways to reduce spending. All " +
        "amounts are in BDT (Taka). Respond only with the requested " +
        "JSON, no extra commentary.",
      response_format: {
        type: "text",
        mime_type: "application/json",
        schema: RESPONSE_JSON_SCHEMA,
      },
      // Lower thinking effort noticeably cuts latency for this kind of
      // short structured output, which doesn't need multi-step reasoning.
      // max_output_tokens is a generous safety ceiling, not a tight cap -
      // capping too low truncates the JSON before it completes.
      generation_config: { thinking_level: "low", max_output_tokens: 1200 },
    });

    const text = interaction.output_text;
    if (!text) {
      return corsJson(request, { error: "Empty response from AI" }, { status: 502 });
    }

    const parsed = SuggestionSchema.parse(JSON.parse(text));
    return corsJson(request, parsed);
  } catch (error) {
    console.error("spending-insights error:", error);
    const message = error instanceof Error ? error.message : "";
    const status = message.includes("GEMINI_API_KEY") ? 503 : 502;
    return corsJson(
      request,
      { error: "Could not generate spending suggestions." },
      { status },
    );
  }
}
