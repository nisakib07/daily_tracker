import { generateText } from 'ai';
import { DEFAULT_CATEGORIES_OUT } from '@/lib/types';

export async function POST(req: Request) {
  try {
    const { note, availableCategories, amount } = await req.json();

    if (!note) {
      return Response.json({ error: 'No note provided' }, { status: 400 });
    }

    const categories = availableCategories || DEFAULT_CATEGORIES_OUT;

    const result = await generateText({
      model: 'openai/gpt-4o-mini',
      system: `You are a smart expense categorizer. Given a transaction note/description, determine the most appropriate category.

Available categories: ${categories.join(', ')}

Categorization rules:
- Food-related: breakfast, lunch, dinner, coffee, tea, snacks, restaurants, cafe, bakery, grocery (food items) = "Food"
- Transport-related: uber, taxi, bus, rickshaw, cab, bike, petrol, gas, parking, toll = "Transport"
- Shopping-related: clothes, shoes, shirt, pants, jacket, bag, watch, accessories, mall, store = "Shopping"
- Entertainment-related: movie, cinema, game, concert, show, book, music, sports = "Entertainment"
- Health-related: doctor, medicine, pharmacy, gym, hospital, clinic, dental = "Health"
- Bills-related: electricity, water, internet, phone, bills, subscription = "Bills"
- Education-related: course, tuition, book, school, university, training, classes = "Education"
- Rent-related: rent, mortgage, apartment = "Rent"
- Other: anything that doesn't fit above = "Other Expense"

Return ONLY the category name as plain text, nothing else.`,
      prompt: `Categorize this expense: "${note}"${amount ? ` (Amount: ${amount})` : ''}. Return ONLY the category name.`,
    });

    const category = result.text.trim();

    // Validate that returned category is in available list
    const isValid = categories.includes(category);

    if (!isValid) {
      // If AI returns invalid category, return a safe default
      return Response.json({
        success: true,
        category: 'Other Expense',
        confidence: 'low',
      });
    }

    return Response.json({
      success: true,
      category: category,
      confidence: 'high',
    });
  } catch (error) {
    console.error('Categorize error:', error);
    return Response.json(
      { error: 'Failed to categorize: ' + (error as Error).message },
      { status: 500 }
    );
  }
}
