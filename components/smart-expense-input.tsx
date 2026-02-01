'use client';

import React, { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Loader2, Wand2 } from 'lucide-react';
import { cn } from '@/lib/utils';

interface SmartExpenseInputProps {
  onParse: (data: {
    amount: string;
    category: string;
    note: string;
    date: string;
  }) => void;
  availableCategories: string[];
  className?: string;
  placeholder?: string;
}

export function SmartExpenseInput({
  onParse,
  availableCategories,
  className,
  placeholder = 'e.g., "Spent 500 on lunch today"',
}: SmartExpenseInputProps) {
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleParse = async () => {
    if (!input.trim()) {
      setError('Please enter an expense description');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const response = await fetch('/api/ai/parse-expense', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          text: input,
          availableCategories,
        }),
      });

      if (!response.ok) {
        throw new Error('Failed to parse expense');
      }

      const result = await response.json();

      if (result.success) {
        onParse(result.data);
        setInput('');
      } else {
        setError(result.error || 'Failed to parse expense');
      }
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className={cn('space-y-2', className)}>
      <div className='flex gap-2'>
        <Input
          placeholder={placeholder}
          value={input}
          onChange={(e) => {
            setInput(e.target.value);
            setError('');
          }}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !loading) {
              handleParse();
            }
          }}
          disabled={loading}
          className='text-sm'
        />
        <Button
          type='button'
          size='sm'
          onClick={handleParse}
          disabled={loading || !input.trim()}
          variant='outline'
          className='gap-2 whitespace-nowrap'
        >
          {loading ? (
            <>
              <Loader2 className='h-4 w-4 animate-spin' />
              Parsing...
            </>
          ) : (
            <>
              <Wand2 className='h-4 w-4' />
              AI Parse
            </>
          )}
        </Button>
      </div>
      {error && (
        <p className='text-xs text-red-600 dark:text-red-400'>{error}</p>
      )}
    </div>
  );
}
