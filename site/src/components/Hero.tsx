import { ImageCarousel } from './ImageCarousel'

export function Hero() {
  return (
    <section className="min-h-screen flex flex-col items-center justify-center px-6 pt-14">
      <div className="max-w-4xl mx-auto text-center">
        {/* Status Badge */}
        <div className="inline-flex items-center gap-2 px-3 py-1.5 border border-border-faint bg-bg-surface mb-8 animate-fade-in-up opacity-0">
          <span className="w-1.5 h-1.5 bg-success"></span>
          <span className="text-xs text-text-secondary font-mono uppercase tracking-wider">
            Native macOS App Available
          </span>
        </div>

        {/* Headline */}
        <h1 className="text-4xl sm:text-5xl lg:text-6xl font-semibold tracking-tight mb-4 animate-fade-in-up opacity-0 delay-100">
          <span className="text-text-primary">Your Claude Code is </span>
          <span className="text-accent">slow.</span>
        </h1>
        <h2 className="text-3xl sm:text-4xl lg:text-5xl font-semibold tracking-tight text-text-primary mb-8 animate-fade-in-up opacity-0 delay-200">
          Here&apos;s why.
        </h2>

        {/* Subheadline */}
        <p className="text-base sm:text-lg text-text-secondary max-w-2xl mx-auto mb-12 animate-fade-in-up opacity-0 delay-300 leading-relaxed">
          Stop guessing why Claude Code is eating your CPU. Get instant visibility
          into every Claude process—CPU spikes, memory leaks, orphaned
          processes—all in your menu bar.
        </p>

        {/* CTAs */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-3 mb-16 animate-fade-in-up opacity-0 delay-400">
          <a
            href="https://github.com/joemccann/claude-trace/releases/latest/download/ClaudeTrace.dmg"
            className="px-6 py-3 bg-accent text-bg-base font-medium hover:bg-accent-hover transition-colors flex items-center gap-2"
          >
            <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            Download for macOS
          </a>
          <a
            href="https://github.com/joemccann/claude-trace"
            target="_blank"
            rel="noopener noreferrer"
            className="px-6 py-3 border border-border-muted text-text-primary hover:border-accent hover:text-accent transition-colors"
          >
            View on GitHub →
          </a>
        </div>

        {/* Image Carousel */}
        <div className="animate-fade-in opacity-0 delay-500">
          <ImageCarousel />
        </div>
      </div>

      {/* Scroll indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2">
        <svg
          className="w-5 h-5 text-text-muted animate-bounce"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          strokeWidth={1.5}
        >
          <path
            strokeLinecap="square"
            strokeLinejoin="miter"
            d="M19 14l-7 7m0 0l-7-7m7 7V3"
          />
        </svg>
      </div>
    </section>
  )
}
