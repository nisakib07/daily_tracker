import { z } from "zod";
import { corsJson, corsPreflight } from "@/lib/ai/cors";
import { GEMINI_MODEL, getGeminiClient } from "@/lib/ai/gemini-client";
import { verifyUser } from "@/lib/ai/verify-user";

const MonthlySummarySchema = z.object({
  month: z.string(),
  income: z.number().nonnegative(),
  expense: z.number().nonnegative(),
  expenseByCategory: z.array(
    z.object({ category: z.string(), amount: z.number().nonnegative() }),
  ),
});

const RecentTransactionSchema = z.object({
  date: z.string(),
  type: z.enum(["income", "expense"]),
  amount: z.number().nonnegative(),
  category: z.string(),
  note: z.string(),
});

const RequestSchema = z.object({
  question: z.string().min(1),
  context: z.object({
    currentBalance: z.number(),
    totalToReceive: z.number().nonnegative(),
    totalToPay: z.number().nonnegative(),
    monthlySummaries: z.array(MonthlySummarySchema),
    recentTransactions: z.array(RecentTransactionSchema).default([]),
  }),
  history: z
    .array(
      z.object({
        role: z.enum(["user", "assistant"]),
        text: z.string(),
      }),
    )
    .max(20),
});

const AnswerSchema = z.object({
  answer: z.string(),
});

const RESPONSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    answer: { type: "string" },
  },
  required: ["answer"],
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

  const { context } = body;
  const prompt = [
    `Current total account balance: ${context.currentBalance} BDT.`,
    `Total owed to the user by other people: ${context.totalToReceive} BDT.`,
    `Total the user owes other people: ${context.totalToPay} BDT.`,
    "Monthly summary (most recent months, oldest to newest):",
    ...context.monthlySummaries.map((m) =>
      [
        `- ${m.month}: income ${m.income} BDT, expense ${m.expense} BDT`,
        ...m.expenseByCategory.map(
          (c) => `    - ${c.category}: ${c.amount} BDT`,
        ),
      ].join("\n"),
    ),
    context.recentTransactions.length
      ? [
          `Individual transactions from the last ${context.recentTransactions.length <= 500 ? "90 days" : "recent period"} (most recent first, use these for anything about a specific note, item, or merchant):`,
          ...context.recentTransactions.map(
            (t) =>
              `- ${t.date} ${t.type} ${t.amount} BDT [${t.category}]${t.note ? `: ${t.note}` : ""}`,
          ),
        ].join("\n")
      : "No individual transaction records provided.",
    body.history.length
      ? [
          "Prior conversation so far:",
          ...body.history.map((h) => `${h.role}: ${h.text}`),
        ].join("\n")
      : "No prior conversation.",
    `The user's new question: "${body.question}"`,
    "Answer using only the data given above. When the question mentions a " +
      "specific item, note, or merchant (e.g. \"rickshaw\"), match it " +
      "against the note text of the individual transactions, not just " +
      "the category totals - sum whichever of those transactions " +
      "reasonably match. Keep the answer to a few concise sentences, in " +
      "BDT (Taka). If the question asks about something that isn't " +
      "covered by the data above (a period or item with no matching " +
      "transactions), say plainly that you don't have enough data to " +
      "answer it rather than guessing.",
  ].join("\n");

  try {
    const client = getGeminiClient();
    const interaction = await client.interactions.create({
      model: GEMINI_MODEL,
      input: prompt,
      system_instruction:
        "You are a personal-finance assistant answering questions about " +
        "a user's own transaction history in Bangladesh, grounded only " +
        "in the aggregated numbers provided in the prompt - never invent " +
        "figures not present there. Respond only with the requested " +
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

    const parsed = AnswerSchema.parse(JSON.parse(text));
    return corsJson(request, parsed);
  } catch (error) {
    console.error("chat error:", error);
    const message = error instanceof Error ? error.message : "";
    const status = message.includes("GEMINI_API_KEY") ? 503 : 502;
    return corsJson(
      request,
      { error: "Could not answer that right now." },
      { status },
    );
  }
}
