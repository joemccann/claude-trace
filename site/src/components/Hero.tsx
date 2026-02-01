import Image from 'next/image'

export function Hero() {
  return (
    <section className="min-h-screen flex flex-col items-center justify-center px-6 pt-16">
      <div className="max-w-4xl mx-auto text-center">
        {/* Badge */}
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full border border-zinc-800 bg-zinc-900/50 mb-8 animate-fade-in-up opacity-0">
          <span className="w-2 h-2 rounded-full bg-green-500 animate-pulse"></span>
          <span className="text-sm text-text-secondary">
            Now with native macOS menu bar app
          </span>
        </div>

        {/* Headline */}
        <h1 className="text-5xl sm:text-6xl lg:text-7xl font-bold tracking-tight mb-4 animate-fade-in-up opacity-0 delay-100">
          <span className="text-text-primary">Your Claude Code is </span>
          <span className="text-cyan-400">slow.</span>
        </h1>
        <h2 className="text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight text-text-primary mb-8 animate-fade-in-up opacity-0 delay-200">
          Here&apos;s why.
        </h2>

        {/* Subheadline */}
        <p className="text-lg sm:text-xl text-text-secondary max-w-2xl mx-auto mb-12 animate-fade-in-up opacity-0 delay-300">
          Stop guessing why Claude Code is eating your CPU. Get instant visibility
          into every Claude process—CPU spikes, memory leaks, orphaned
          processes—all in your menu bar.
        </p>

        {/* CTAs */}
        <div className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-16 animate-fade-in-up opacity-0 delay-400">
          <a
            href="https://github.com/joemccann/claude-trace/releases/latest/download/ClaudeTrace.dmg"
            className="px-8 py-4 bg-cyan-400 text-zinc-950 font-semibold rounded-lg hover:bg-cyan-300 transition-all duration-200 shadow-[0_0_20px_rgba(34,211,238,0.3)] hover:shadow-[0_0_40px_rgba(34,211,238,0.5)] animate-glow-pulse flex items-center gap-2"
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
            className="px-8 py-4 border border-zinc-700 text-zinc-100 rounded-lg hover:border-cyan-400 hover:text-cyan-400 transition-all duration-200"
          >
            View on GitHub
          </a>
        </div>

        {/* Hero Image */}
        <div className="relative animate-scale-in opacity-0 delay-500">
          <div className="absolute inset-0 bg-gradient-to-t from-bg-primary via-transparent to-transparent z-10 pointer-events-none"></div>
          <div className="relative rounded-2xl overflow-hidden border border-zinc-800 shadow-2xl shadow-cyan-500/10">
            <Image
              src="/menubar-dropdown.png"
              alt="Claude Trace Menu Bar showing real-time CPU and memory monitoring"
              width={800}
              height={600}
              className="w-full h-auto"
              priority
            />
          </div>
          {/* Glow effect */}
          <div className="absolute -inset-4 bg-cyan-500/20 blur-3xl -z-10 rounded-3xl"></div>
        </div>
      </div>

      {/* Scroll indicator */}
      <div className="absolute bottom-8 left-1/2 -translate-x-1/2 animate-bounce">
        <svg
          className="w-6 h-6 text-text-muted"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M19 14l-7 7m0 0l-7-7m7 7V3"
          />
        </svg>
      </div>
    </section>
  )
}
