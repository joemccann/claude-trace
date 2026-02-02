import Link from 'next/link'

export function Footer() {
  return (
    <footer className="py-16 px-6 border-t border-border-faint">
      <div className="max-w-6xl mx-auto">
        {/* Tech stack */}
        <div className="text-center mb-12">
          <p className="text-xs font-mono text-text-muted uppercase tracking-wider mb-2">
            Built with
          </p>
          <p className="text-lg font-medium text-text-primary">
            Bash + Rust + Swift
          </p>
          <p className="text-text-muted text-sm mt-1">
            Zero dependencies. Native performance.
          </p>
        </div>

        {/* Bottom bar */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-8 border-t border-border-faint">
          <div className="flex items-center gap-2">
            <div className="w-5 h-5 bg-accent flex items-center justify-center">
              <svg
                className="w-3 h-3 text-bg-base"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
                strokeWidth={2.5}
              >
                <path
                  strokeLinecap="square"
                  strokeLinejoin="miter"
                  d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                />
              </svg>
            </div>
            <span className="text-sm text-text-secondary">Claude Trace</span>
          </div>

          <div className="flex items-center gap-6">
            <Link
              href="/guides"
              className="text-xs text-text-muted hover:text-text-primary transition-colors"
            >
              Guides
            </Link>
            <a
              href="https://github.com/joemccann/claude-trace"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-text-muted hover:text-text-primary transition-colors"
            >
              GitHub
            </a>
            <a
              href="https://github.com/joemccann/claude-trace/blob/main/docs/CLI.md"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-text-muted hover:text-text-primary transition-colors"
            >
              Docs
            </a>
            <a
              href="https://github.com/joemccann/claude-trace/issues"
              target="_blank"
              rel="noopener noreferrer"
              className="text-xs text-text-muted hover:text-text-primary transition-colors"
            >
              Issues
            </a>
          </div>

          <p className="text-xs text-text-muted font-mono">
            MIT License
          </p>
        </div>
      </div>
    </footer>
  )
}
