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

            {/* Install command */}
            <div className="mt-8 p-6 bg-bg-primary rounded-xl border border-zinc-800">
              <p className="text-text-secondary text-sm mb-3">
                Quick install — builds CLI and installs the menu bar app
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
