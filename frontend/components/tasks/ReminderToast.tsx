'use client';

import { motion, AnimatePresence } from 'framer-motion';
import { cn } from '@/lib/utils';
import { Button } from '@/components/ui/Button';
import type { Task } from '@/types';

interface ReminderToastProps {
  task: Task;
  onDismiss: () => void;
  onViewTask?: (taskId: string) => void;
}

function getTimeUntilDue(dueDate: string): string {
  const now = Date.now();
  const due = new Date(dueDate).getTime();
  const diff = due - now;

  if (diff <= 0) return 'Overdue';

  const minutes = Math.floor(diff / 60000);
  if (minutes < 60) return `${minutes}m remaining`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ${minutes % 60}m remaining`;
  const days = Math.floor(hours / 24);
  return `${days}d ${hours % 24}h remaining`;
}

export function ReminderToast({ task, onDismiss, onViewTask }: ReminderToastProps) {
  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0, y: -20, scale: 0.95 }}
        animate={{ opacity: 1, y: 0, scale: 1 }}
        exit={{ opacity: 0, y: -20, scale: 0.95 }}
        transition={{ duration: 0.2 }}
        className={cn(
          'w-full max-w-sm rounded-lg shadow-lg border p-4',
          'bg-white dark:bg-dark-100 border-yellow-200 dark:border-yellow-800',
        )}
        role="alert"
        aria-live="assertive"
      >
        <div className="flex items-start gap-3">
          {/* Bell Icon */}
          <div className="flex-shrink-0 mt-0.5 text-yellow-500">
            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
              <path d="M13.73 21a2 2 0 0 1-3.46 0" />
            </svg>
          </div>

          <div className="flex-1 min-w-0">
            <p className="text-sm font-medium text-gray-primary truncate">
              {task.title}
            </p>
            {task.dueDate && (
              <p className={cn(
                'text-xs mt-0.5',
                task.isOverdue ? 'text-red-500 font-medium' : 'text-gray-secondary',
              )}>
                {getTimeUntilDue(task.dueDate)}
              </p>
            )}
          </div>

          {/* Actions */}
          <div className="flex items-center gap-1 flex-shrink-0">
            {onViewTask && (
              <Button
                variant="primary"
                size="sm"
                onClick={() => onViewTask(task.id)}
              >
                View
              </Button>
            )}
            <button
              onClick={onDismiss}
              className="p-1 text-gray-secondary hover:text-gray-primary transition-colors"
              aria-label="Dismiss reminder"
            >
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </button>
          </div>
        </div>
      </motion.div>
    </AnimatePresence>
  );
}
