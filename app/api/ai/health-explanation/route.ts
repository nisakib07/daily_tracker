import { NextResponse } from "next/server";
import { z } from "zod";
import { GEMINI_MODEL, getGeminiClient } from "@/lib/ai/gemini-client";
import { verifyUser } from "@/lib/ai/verify-user";

const MetricSchema = z.object({
  label: z.string(),
  score: z.number(),
  maxScore: z.number(),
  status: z.string(),
  insufficientData: z.boolean(),
});

const RequestSchema = z.object({
  overall: z.number().int(),
  grade: z.string(),
  metrics: z.array(MetricSchema),
});

const ExplanationSchema = z.object({
  explanation: z.string(),
});

const RESPONSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    explanation: { type: "string" },
  },
  required: ["explanation"],
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
    `Overall financial health score: ${body.overall}/100 (Grade ${body.grade}).`,
    "Metrics:",
    ...body.metrics.map(
      (m) =>
        `- ${m.label}: ${m.insufficientData ? "not enough data yet" : `${m.score}/${m.maxScore} (${m.status})`}`,
    ),
    "Write a short, grounded explanation of this score for the user. " +
      "Reference at least one specific metric by name and its actual " +
      "number. Keep it factual and specific to these numbers, not " +
      "generic encouragement.",
  ].join("\n");

  try {
    const client = getGeminiClient();
    const interaction = await client.interactions.create({
      model: GEMINI_MODEL,
      input: prompt,
      system_instruction:
        "You are a personal-finance assistant writing a brief, warm but " +
        "factual explanation of a user's financial health score, in 2-3 " +
        "sentences, grounded strictly in the numbers given - no generic " +
        "filler. Respond only with the requested JSON, no extra " +
        "commentary.",
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

    const parsed = ExplanationSchema.parse(JSON.parse(text));
    return NextResponse.json(parsed);
  } catch (error) {
    console.error("health-explanation error:", error);
    const message = error instanceof Error ? error.message : "";
    const status = message.includes("GEMINI_API_KEY") ? 503 : 502;
    return NextResponse.json(
      { error: "Could not generate an explanation." },
      { status },
    );
  }
}
