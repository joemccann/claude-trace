const features = [
  {
    id: '01',
    title: 'Live CPU & Memory',
    description: 'Real-time stats for every Claude session. See exactly where your resources are going.',
  },
  {
    id: '02',
    title: 'Project Names',
    description: 'Know which project each Claude session belongs to. No more guessing.',
  },
  {
    id: '03',
    title: 'Native Notifications',
    description: 'Get alerted before your fans spin up. Set custom thresholds that match your workflow.',
  },
  {
    id: '04',
    title: 'One-Click Kill',
    description: 'Stop runaway processes instantly. No terminal needed.',
  },
  {
    id: '05',
    title: 'Orphan Detection',
    description: 'Find and clean up zombie Claude sessions that are wasting resources.',
  },
  {
    id: '06',
    title: 'Launch at Login',
    description: 'Set it and forget it. Claude Trace starts automatically with macOS.',
  },
]

export function Features() {
  return (
    <section className="py-24 px-6" id="features">
      <div className="max-w-6xl mx-auto">
        {/* Section Header */}
        <div className="mb-16">
          <p className="text-xs font-mono text-accent uppercase tracking-wider mb-3">
            Features
          </p>
          <h2 className="text-2xl sm:text-3xl font-semibold text-text-primary mb-4">
            Everything you need to debug Claude
          </h2>
          <p className="text-text-secondary max-w-xl">
            Claude Code runs multiple Node.js processes. Sometimes they spin.
            Sometimes they leak. Claude Trace makes the invisible visible.
          </p>
        </div>

        {/* Feature Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-px bg-border-faint">
          {features.map((feature) => (
            <div
              key={feature.id}
              className="group p-6 bg-bg-base hover:bg-bg-surface transition-colors"
            >
              <div className="flex items-start gap-4">
                <span className="text-xs font-mono text-text-muted">
                  [{feature.id}]
                </span>
                <div>
                  <h3 className="text-base font-medium text-text-primary mb-2 group-hover:text-accent transition-colors">
                    {feature.title}
                  </h3>
                  <p className="text-sm text-text-secondary leading-relaxed">
                    {feature.description}
                  </p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </section>
  )
}
