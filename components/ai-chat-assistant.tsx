'use client';

import React, { useRef, useEffect } from 'react';
import { useChat } from '@ai-sdk/react';
import { DefaultChatTransport } from 'ai';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Card } from '@/components/ui/card';
import { Loader2, Send, Sparkles, MessageCircle, X } from 'lucide-react';
import { cn } from '@/lib/utils';

interface AIChatAssistantProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  className?: string;
}

export function AIChatAssistant({ open, onOpenChange, className }: AIChatAssistantProps) {
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const [input, setInput] = React.useState('');

  const { messages, isLoading, input: chatInput, setInput: setChatInput, append, status } = useChat({
    transport: new DefaultChatTransport({
      api: '/api/ai/chat',
    }),
  });

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim()) return;

    setChatInput(input);
    await append({ role: 'user', content: input });
    setInput('');
  };

  if (!open) {
    return null;
  }

  return (
    <div className={cn('fixed inset-0 z-50 bg-black/50', className)}>
      <Card className='fixed bottom-4 right-4 w-96 max-h-[600px] flex flex-col shadow-xl border-0 glass md:bottom-6 md:right-6'>
        {/* Header */}
        <div className='flex items-center justify-between p-4 border-b border-border/50'>
          <div className='flex items-center gap-2'>
            <Sparkles className='h-5 w-5 text-indigo-600 dark:text-indigo-400' />
            <h3 className='font-semibold text-sm'>Money Assistant</h3>
          </div>
          <Button
            variant='ghost'
            size='icon'
            className='h-7 w-7'
            onClick={() => onOpenChange(false)}
          >
            <X className='h-4 w-4' />
          </Button>
        </div>

        {/* Messages */}
        <div className='flex-1 overflow-y-auto p-4 space-y-4'>
          {messages.length === 0 ? (
            <div className='flex flex-col items-center justify-center h-full text-center'>
              <MessageCircle className='h-12 w-12 text-muted-foreground/30 mb-2' />
              <p className='text-sm text-muted-foreground'>
                Ask me anything about your spending!
              </p>
              <p className='text-xs text-muted-foreground/70 mt-2'>
                "How much did I spend this month?" or "What's my top expense category?"
              </p>
            </div>
          ) : (
            messages.map((message, i) => (
              <div
                key={i}
                className={cn(
                  'flex gap-3 animate-fade-in-up',
                  message.role === 'user' ? 'justify-end' : 'justify-start'
                )}
              >
                {message.role === 'assistant' && (
                  <div className='h-6 w-6 rounded-full bg-indigo-600/10 flex items-center justify-center flex-shrink-0'>
                    <Sparkles className='h-3 w-3 text-indigo-600' />
                  </div>
                )}
                <div
                  className={cn(
                    'max-w-xs px-3 py-2 rounded-lg text-sm',
                    message.role === 'user'
                      ? 'bg-indigo-600 text-white rounded-br-none'
                      : 'bg-muted text-foreground rounded-bl-none'
                  )}
                >
                  {message.content}
                </div>
              </div>
            ))
          )}
          {isLoading && (
            <div className='flex gap-3'>
              <div className='h-6 w-6 rounded-full bg-indigo-600/10 flex items-center justify-center flex-shrink-0'>
                <Loader2 className='h-3 w-3 text-indigo-600 animate-spin' />
              </div>
              <div className='bg-muted text-foreground rounded-lg rounded-bl-none px-3 py-2'>
                <div className='flex gap-1'>
                  <div className='w-2 h-2 rounded-full bg-muted-foreground animate-bounce' />
                  <div className='w-2 h-2 rounded-full bg-muted-foreground animate-bounce' style={{ animationDelay: '0.1s' }} />
                  <div className='w-2 h-2 rounded-full bg-muted-foreground animate-bounce' style={{ animationDelay: '0.2s' }} />
                </div>
              </div>
            </div>
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Input */}
        <form onSubmit={handleSendMessage} className='border-t border-border/50 p-3 flex gap-2'>
          <Input
            placeholder='Ask about your spending...'
            value={input}
            onChange={(e) => setInput(e.target.value)}
            disabled={isLoading}
            className='text-sm h-9'
          />
          <Button
            type='submit'
            size='sm'
            disabled={isLoading || !input.trim()}
            className='h-9 w-9 p-0'
          >
            {isLoading ? (
              <Loader2 className='h-4 w-4 animate-spin' />
            ) : (
              <Send className='h-4 w-4' />
            )}
          </Button>
        </form>
      </Card>
    </div>
  );
}
