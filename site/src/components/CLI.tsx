import Image from 'next/image'

const cliCommands = [
  {
    command: 'claude-trace',
    description: 'See all Claude processes',
  },
  {
    command: 'claude-trace -w',
    description: 'Watch mode — live updates every 2 seconds',
  },
  {
    command: 'claude-trace -v',
    description: 'Verbose — includes project name and working directory',
  },
  {
    command: "claude-trace -j | jq '.totals.cpu_percent'",
    description: 'JSON output for scripting',
  },
]

export function CLI() {
  return (
    <section className="py-24 px-6 bg-bg-secondary" id="install">
      <div className="max-w-6xl mx-auto">
        <div className="grid lg:grid-cols-2 gap-12 items-center">
          {/* Left: CLI examples */}
          <div>
            <h2 className="text-3xl sm:text-4xl font-bold text-text-primary mb-4">
              Command line power
            </h2>
            <p className="text-lg text-text-secondary mb-8">
              For quick checks without opening the app. Perfect for scripting and automation.
            </p>

            <div className="space-y-4">
              {cliCommands.map((cmd, index) => (
                <div
                  key={index}
                  className="p-4 bg-bg-primary rounded-lg border border-zinc-800"
                >
                  <code className="font-mono text-cyan-400 text-sm">
                    $ {cmd.command}
                  </code>
                  <p className="text-text-muted text-sm mt-1">{cmd.description}</p>
                </div>
              ))}
            </div>

            {/* Install options */}
            <div className="mt-8 space-y-4">
              {/* Direct download */}
              <div className="p-6 bg-bg-primary rounded-xl border border-cyan-500/30 shadow-[0_0_20px_rgba(34,211,238,0.1)]">
                <div className="flex items-center gap-2 mb-3">
                  <svg className="w-5 h-5 text-cyan-400" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                  </svg>
                  <p className="text-text-primary font-semibold">
                    Direct Download
                  </p>
                  <span className="px-2 py-0.5 text-xs bg-cyan-400/10 text-cyan-400 rounded-full">Recommended</span>
                </div>
                <a
                  href="https://github.com/joemccann/claude-trace/releases/latest/download/ClaudeTrace.dmg"
                  className="inline-flex items-center gap-2 px-6 py-3 bg-cyan-400 text-zinc-950 font-semibold rounded-lg hover:bg-cyan-300 transition-all duration-200"
                >
                  <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  Download ClaudeTrace.dmg
                </a>
                <p className="text-text-muted text-xs mt-3">
                  Requires macOS 14.0 (Sonoma) or later
                </p>
              </div>

              {/* Build from source */}
              <div className="p-6 bg-bg-primary rounded-xl border border-zinc-800">
                <p className="text-text-secondary text-sm mb-3">
                  Or build from source — includes CLI and menu bar app
                </p>
                <div className="flex items-center gap-3">
                  <code className="flex-1 font-mono text-sm text-text-primary bg-zinc-900 px-4 py-3 rounded-lg overflow-x-auto">
                    git clone https://github.com/joemccann/claude-trace.git && cd claude-trace && ./dev.sh deploy
                  </code>
                </div>
                <p className="text-text-muted text-xs mt-3">
                  Requires macOS 14.0+ and Xcode 15.0+
                </p>
              </div>
            </div>
          </div>

          {/* Right: CLI screenshot */}
          <div className="relative">
            <div className="rounded-xl overflow-hidden border border-zinc-800 shadow-2xl">
              <Image
                src="/cli-output.png"
                alt="Claude Trace CLI output showing process monitoring"
                width={800}
                height={500}
                className="w-full h-auto"
              />
            </div>
            {/* Glow effect */}
            <div className="absolute -inset-4 bg-cyan-500/10 blur-3xl -z-10 rounded-3xl"></div>
          </div>
        </div>
      </div>
    </section>
  )
}
