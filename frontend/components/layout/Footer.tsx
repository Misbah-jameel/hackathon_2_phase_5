import Link from 'next/link';
import { ROUTES } from '@/lib/constants';

export function Footer() {
  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-white dark:bg-dark-100 border-t border-gray-border dark:border-dark-border mt-auto">
      <div className="container mx-auto px-4 py-6 sm:py-8">
        <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-6 sm:gap-8">
          {/* Brand Section */}
          <div className="space-y-4">
            <Link href={ROUTES.HOME} className="flex items-center gap-2 min-h-[44px]">
              <span className="text-xl sm:text-2xl font-bold gradient-text">Todo</span>
              <span className="text-xl sm:text-2xl font-bold text-gray-primary dark:text-white">App</span>
            </Link>
            <p className="text-sm text-gray-secondary dark:text-gray-400 max-w-xs">
              A modern, polished task management application to help you stay organized
              and productive.
            </p>
          </div>

          {/* Quick Links */}
          <div className="space-y-4">
            <h3 className="font-semibold text-gray-primary dark:text-white">Quick Links</h3>
            <nav className="flex flex-col space-y-2">
              <Link
                href={ROUTES.HOME}
                className="text-sm text-gray-secondary dark:text-gray-400 hover:text-primary transition-colors min-h-[44px] flex items-center"
              >
                Home
              </Link>
              <Link
                href={ROUTES.LOGIN}
                className="text-sm text-gray-secondary dark:text-gray-400 hover:text-primary transition-colors min-h-[44px] flex items-center"
              >
                Login
              </Link>
              <Link
                href={ROUTES.SIGNUP}
                className="text-sm text-gray-secondary dark:text-gray-400 hover:text-primary transition-colors min-h-[44px] flex items-center"
              >
                Sign Up
              </Link>
            </nav>
          </div>

          {/* Legal Links */}
          <div className="space-y-4">
            <h3 className="font-semibold text-gray-primary dark:text-white">Legal</h3>
            <nav className="flex flex-col space-y-2">
              <Link
                href="#"
                className="text-sm text-gray-secondary dark:text-gray-400 hover:text-primary transition-colors min-h-[44px] flex items-center"
              >
                Privacy Policy
              </Link>
              <Link
                href="#"
                className="text-sm text-gray-secondary dark:text-gray-400 hover:text-primary transition-colors min-h-[44px] flex items-center"
              >
                Terms of Service
              </Link>
            </nav>
          </div>
        </div>

        {/* Bottom Bar */}
        <div className="mt-6 sm:mt-8 pt-6 sm:pt-8 border-t border-gray-border dark:border-dark-border flex flex-col md:flex-row justify-between items-center gap-4">
          <p className="text-sm text-gray-secondary dark:text-gray-400">
            &copy; {currentYear} TodoApp. All rights reserved.
          </p>
          <div className="flex items-center gap-4">
            {/* Social Links */}
            <button
              type="button"
              className="text-gray-secondary dark:text-gray-400 hover:text-primary transition-colors p-2 min-w-[44px] min-h-[44px] flex items-center justify-center"
              aria-label="Twitter"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d="M22 4s-.7 2.1-2 3.4c1.6 10-9.4 17.3-18 11.6 2.2.1 4.4-.6 6-2C3 15.5.5 9.6 3 5c2.2 2.6 5.6 4.1 9 4-.9-4.2 4-6.6 7-3.8 1.1 0 3-1.2 3-1.2z" />
              </svg>
            </button>
            <button
              type="button"
              className="text-gray-secondary dark:text-gray-400 hover:text-primary transition-colors p-2 min-w-[44px] min-h-[44px] flex items-center justify-center"
              aria-label="GitHub"
            >
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
                aria-hidden="true"
              >
                <path d="M9 19c-5 1.5-5-2.5-7-3m14 6v-3.87a3.37 3.37 0 0 0-.94-2.61c3.14-.35 6.44-1.54 6.44-7A5.44 5.44 0 0 0 20 4.77 5.07 5.07 0 0 0 19.91 1S18.73.65 16 2.48a13.38 13.38 0 0 0-7 0C6.27.65 5.09 1 5.09 1A5.07 5.07 0 0 0 5 4.77a5.44 5.44 0 0 0-1.5 3.78c0 5.42 3.3 6.61 6.44 7A3.37 3.37 0 0 0 9 18.13V22" />
              </svg>
            </button>
          </div>
        </div>
      </div>
    </footer>
  );
}
