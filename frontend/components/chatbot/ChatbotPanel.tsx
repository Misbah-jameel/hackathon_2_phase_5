'use client';

import { useEffect, useRef } from 'react';
import { ChatMessage } from './ChatMessage';
import { ChatInput } from './ChatInput';
import { ChatbotMessage } from '@/types';

interface ChatbotPanelProps {
  messages: ChatbotMessage[];
  isLoading: boolean;
  suggestions: string[];
  onSend: (message: string) => void;
  onClose: () => void;
} 

export function ChatbotPanel({
  messages,
  isLoading,
  suggestions,
  onSend,
  onClose,
}: ChatbotPanelProps) {
  const messagesEndRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  return (
    <div
      className="absolute bottom-20 right-0 w-96 max-w-[calc(100vw-2rem)]
                 bg-white dark:bg-gray-900 rounded-2xl shadow-2xl
                 border border-gray-200 dark:border-gray-700
                 flex flex-col overflow-hidden"
      style={{ height: '500px', maxHeight: 'calc(100vh - 10rem)' }}
    >
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3
                      bg-gradient-to-r from-pink-500 to-purple-500 text-white">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center">
            <svg
              className="w-5 h-5"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
              />
            </svg>
          </div>
          <div>
            <h3 className="font-semibold text-sm">Task Assistant</h3>
            <p className="text-xs text-white/70">Ask me anything about tasks</p>
          </div>
        </div>
        <button
          onClick={onClose}
          className="p-1.5 rounded-full hover:bg-white/20 transition-colors"
          aria-label="Close chat"
        >
          <svg
            className="w-5 h-5"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M6 18L18 6M6 6l12 12"
            />
          </svg>
        </button>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-1">
        {messages.length === 0 ? (
          <div className="h-full flex flex-col items-center justify-center text-center px-4">
            <div className="w-16 h-16 rounded-full bg-gradient-to-r from-pink-100 to-purple-100
                            dark:from-pink-900/30 dark:to-purple-900/30
                            flex items-center justify-center mb-4">
              <svg
                className="w-8 h-8 text-pink-500"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"
                />
              </svg>
            </div>
            <h4 className="font-medium text-gray-900 dark:text-gray-100 mb-2">
              Hi! I'm your Task Assistant
            </h4>
            <p className="text-sm text-gray-500 dark:text-gray-400 mb-4">
              I can help you manage your tasks. Try saying:
            </p>
            <div className="flex flex-wrap gap-2 justify-center">
              {['Help', 'Add task: ', 'Show my tasks'].map((cmd) => (
                <button
                  key={cmd}
                  onClick={() => onSend(cmd === 'Add task: ' ? cmd : cmd)}
                  className="text-xs px-3 py-1.5 rounded-full bg-gray-100 dark:bg-gray-800
                             text-gray-700 dark:text-gray-300 hover:bg-gray-200
                             dark:hover:bg-gray-700 transition-colors"
                >
                  {cmd}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <>
            {messages.map((message) => (
              <ChatMessage key={message.id} message={message} />
            ))}
            {isLoading && (
              <div className="flex justify-start mb-3">
                <div className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700
                                rounded-2xl px-4 py-3">
                  <div className="flex gap-1">
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '0ms' }} />
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '150ms' }} />
                    <div className="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style={{ animationDelay: '300ms' }} />
                  </div>
                </div>
              </div>
            )}
            <div ref={messagesEndRef} />
          </>
        )}
      </div>

      {/* Input */}
      <ChatInput
        onSend={onSend}
        isLoading={isLoading}
        suggestions={messages.length > 0 ? suggestions : []}
      />
    </div>
  );
}
