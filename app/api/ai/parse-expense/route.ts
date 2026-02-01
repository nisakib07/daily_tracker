import { generateText, Output } from 'ai';
import { z } from 'zod';
import { DEFAULT_CATEGORIES_OUT } from '@/lib/types';

export async function POST(req: Request) {
  try {
    const { text, availableCategories } = await req.json();

    if (!text) {
      return Response.json({ error: 'No text provided' }, { status: 400 });
    }

    const categories = availableCategories || DEFAULT_CATEGORIES_OUT;

    const result = await generateText({
      model: 'openai/gpt-4o-mini',
      system: `You are a smart expense parser. Extract expense information from natural language text.
      
Available categories: ${categories.join(', ')}

Extract:
1. Amount (numeric value)
2. Category (must be from the available list)
3. Note/Description
4. Date (if mentioned, otherwise return null)

Be intelligent about categorizing:
- "lunch", "dinner", "breakfast", "coffee", "snacks" = "Food"
- "uber", "taxi", "bus", "rickshaw" = "Transport"
- "movie", "game", "concert" = "Entertainment"
- "medicine", "doctor", "gym" = "Health"
- "shirt", "shoes", "pants" = "Shopping"
- "electricity", "water", "internet" = "Bills"
- "book", "course", "tuition" = "Education"
- "rent", "mortgage" = "Rent"

Return ONLY valid JSON.`,
      prompt: `Parse this expense: "${text}"`,
      output: Output.object({
        schema: z.object({
          amount: z.number().describe('Expense amount'),
          category: z.enum(categories as [string, ...string[]]).describe('Category from available list'),
          note: z.string().describe('Description or note'),
          date: z.string().nullable().describe('Date in YYYY-MM-DD format if mentioned'),
        }),
      }),
    });

    const parsed = result.object as {
      amount: number;
      category: string;
      note: string;
      date: string | null;
    };

    return Response.json({
      success: true,
      data: {
        amount: parsed.amount.toString(),
        category: parsed.category,
        note: parsed.note,
        date: parsed.date || new Date().toISOString().split('T')[0],
      },
    });
  } catch (error) {
    console.error('Parse expense error:', error);
    return Response.json(
      { error: 'Failed to parse expense: ' + (error as Error).message },
      { status: 500 }
    );
  }
}
