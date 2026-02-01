import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: {
    template: '%s | Claude Trace Guides',
    default: 'Claude Code Troubleshooting Guides | Claude Trace',
  },
  description: 'Troubleshooting guides for common Claude Code CLI issues. Learn how to debug CPU spikes, memory leaks, orphan processes, and more.',
}

export default function GuidesLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return children
}
