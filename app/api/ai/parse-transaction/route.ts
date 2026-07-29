import { z } from "zod";
import { corsJson, corsPreflight } from "@/lib/ai/cors";
import { GEMINI_MODEL, getGeminiClient } from "@/lib/ai/gemini-client";
import { verifyUser } from "@/lib/ai/verify-user";

const RequestSchema = z.object({
  text: z.string().min(1),
  incomeCategories: z.array(z.string()),
  expenseCategories: z.array(z.string()),
});

const ParsedTransactionSchema = z.object({
  type: z.enum(["income", "expense"]),
  amount: z.number().positive(),
  category: z.string(),
  note: z.string(),
});

const RESPONSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    type: { type: "string", enum: ["income", "expense"] },
    amount: { type: "number" },
    category: { type: "string" },
    note: { type: "string" },
  },
  required: ["type", "amount", "category", "note"],
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
    `Free-text transaction entry from the user: "${body.text}"`,
    `Known income categories: ${body.incomeCategories.join(", ") || "(none)"}.`,
    `Known expense categories: ${body.expenseCategories.join(", ") || "(none)"}.`,
    "Determine whether this is income or an expense, extract the numeric " +
      "amount (in BDT), and pick the best-fitting category. Prefer an " +
      "exact category from the matching known-categories list above when " +
      "one reasonably fits; otherwise propose a short, sensible new " +
      "category name. Write a short, cleaned-up note describing the " +
      "transaction (e.g. who/what it was for), based on the input text.",
  ].join("\n");

  try {
    const client = getGeminiClient();
    const interaction = await client.interactions.create({
      model: GEMINI_MODEL,
      input: prompt,
      system_instruction:
        "You parse short free-text finance entries for a personal " +
        "finance app used in Bangladesh. All amounts are in BDT (Taka). " +
        "Respond only with the requested JSON, no extra commentary.",
      response_format: {
        type: "text",
        mime_type: "application/json",
        schema: RESPONSE_JSON_SCHEMA,
      },
    });

    const text = interaction.output_text;
    if (!text) {
      return corsJson(request, { error: "Empty response from AI" }, { status: 502 });
    }

    const parsed = ParsedTransactionSchema.parse(JSON.parse(text));
    return corsJson(request, parsed);
  } catch (error) {
    console.error("parse-transaction error:", error);
    const message = error instanceof Error ? error.message : "";
    const status = message.includes("GEMINI_API_KEY") ? 503 : 502;
    return corsJson(
      request,
      { error: "Could not parse that transaction." },
      { status },
    );
  }
}
