import { NextResponse } from "next/server";
import { z } from "zod";
import { GEMINI_MODEL, getGeminiClient } from "@/lib/ai/gemini-client";
import { verifyUser } from "@/lib/ai/verify-user";

const RequestSchema = z.object({
  avgMonthlyIncome: z.number().nonnegative(),
  avgCategorySpending: z.array(
    z.object({ category: z.string(), amount: z.number().nonnegative() }),
  ),
  categories: z.array(z.string()),
});

const SuggestionSchema = z.object({
  summary: z.string(),
  suggestions: z.array(
    z.object({
      category: z.string(),
      amount: z.number().nonnegative(),
      rationale: z.string(),
    }),
  ),
});

const RESPONSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    summary: { type: "string" },
    suggestions: {
      type: "array",
      items: {
        type: "object",
        properties: {
          category: { type: "string" },
          amount: { type: "number" },
          rationale: { type: "string" },
        },
        required: ["category", "amount", "rationale"],
      },
    },
  },
  required: ["summary", "suggestions"],
};

export async function POST(request: Request) {
  const user = await verifyUser(request);
  if (!user) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  let body: z.infer<typeof RequestSchema>;
  try {
    body = RequestSchema.parse(await request.json());
  } catch {
    return NextResponse.json({ error: "Invalid request body" }, { status: 400 });
  }

  const prompt = [
    `Monthly income: ~${body.avgMonthlyIncome} BDT.`,
    "Average monthly spending by category over recent history:",
    ...body.avgCategorySpending.map((c) => `- ${c.category}: ~${c.amount} BDT`),
    `Categories to propose a budget for: ${body.categories.join(", ") || "(none given - infer from the spending history)"}.`,
    "Propose a realistic monthly budget per category. Aim for the person " +
      "saving roughly 20% of their income where feasible, but respect " +
      "their actual habits rather than demanding an unrealistic cut. Only " +
      "include categories from the list above or the spending history. " +
      "Keep the summary to one or two sentences and keep each rationale " +
      "to one short sentence.",
  ].join("\n");

  try {
    const client = getGeminiClient();
    const interaction = await client.interactions.create({
      model: GEMINI_MODEL,
      input: prompt,
      system_instruction:
        "You are a pragmatic personal-finance budgeting assistant for a " +
        "user in Bangladesh. All amounts are in BDT (Taka). Respond only " +
        "with the requested JSON, no extra commentary.",
      response_format: {
        type: "text",
        mime_type: "application/json",
        schema: RESPONSE_JSON_SCHEMA,
      },
    });

    const text = interaction.output_text;
    if (!text) {
      return NextResponse.json(
        { error: "Empty response from AI" },
        { status: 502 },
      );
    }

    const parsed = SuggestionSchema.parse(JSON.parse(text));
    return NextResponse.json(parsed);
  } catch (error) {
    console.error("budget-suggestion error:", error);
    const message = error instanceof Error ? error.message : "";
    const status = message.includes("GEMINI_API_KEY") ? 503 : 502;
    return NextResponse.json(
      { error: "Could not generate a budget suggestion." },
      { status },
    );
  }
}
