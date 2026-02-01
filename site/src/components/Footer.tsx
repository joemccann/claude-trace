import Link from 'next/link'

export function Footer() {
  return (
    <footer className="py-16 px-6 border-t border-zinc-800">
      <div className="max-w-6xl mx-auto">
        {/* Tech stack */}
        <div className="text-center mb-12">
          <p className="text-text-secondary mb-2">Built with</p>
          <p className="text-xl font-semibold text-text-primary">
            Bash + Rust + Swift
          </p>
          <p className="text-text-muted mt-1">
            Zero dependencies. Native performance.
          </p>
        </div>

        {/* Bottom bar */}
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4 pt-8 border-t border-zinc-800">
          <div className="flex items-center gap-2">
            <div className="w-6 h-6 rounded bg-gradient-to-br from-cyan-400 to-cyan-600 flex items-center justify-center">
              <svg
                className="w-4 h-4 text-zinc-950"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"
                />
              </svg>
            </div>
            <span className="text-sm text-text-secondary">Claude Trace</span>
          </div>

          <div className="flex items-center gap-6">
            <Link
              href="/guides"
              className="text-sm text-text-muted hover:text-text-primary transition-colors"
            >
              Guides
            </Link>
            <a
              href="https://github.com/joemccann/claude-trace"
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-text-muted hover:text-text-primary transition-colors"
            >
              GitHub
            </a>
            <a
              href="https://github.com/joemccann/claude-trace/blob/main/docs/CLI.md"
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-text-muted hover:text-text-primary transition-colors"
            >
              Documentation
            </a>
            <a
              href="https://github.com/joemccann/claude-trace/issues"
              target="_blank"
              rel="noopener noreferrer"
              className="text-sm text-text-muted hover:text-text-primary transition-colors"
            >
              Issues
            </a>
          </div>

          <p className="text-sm text-text-muted">
            MIT License
          </p>
        </div>
      </div>
    </footer>
  )
}
