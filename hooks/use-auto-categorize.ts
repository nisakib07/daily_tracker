import { useState, useCallback } from 'react';
import { DEFAULT_CATEGORIES_OUT } from '@/lib/types';

export function useAutoCategorize() {
  const [loading, setLoading] = useState(false);

  const categorize = useCallback(
    async (note: string, amount?: number, availableCategories: string[] = DEFAULT_CATEGORIES_OUT) => {
      if (!note.trim()) return null;

      setLoading(true);
      try {
        const response = await fetch('/api/ai/categorize', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            note,
            amount,
            availableCategories,
          }),
        });

        if (!response.ok) {
          throw new Error('Failed to categorize');
        }

        const result = await response.json();
        return result.category;
      } catch (error) {
        console.error('Categorization error:', error);
        return null;
      } finally {
        setLoading(false);
      }
    },
    []
  );

  return { categorize, loading };
}
