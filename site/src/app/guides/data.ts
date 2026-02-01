export interface Guide {
  slug: string
  title: string
  description: string
  icon: string
  tags: string[]
  keywords: string[]
  content: {
    problem: string
    causes: string[]
    diagnosis: string
    solution: string
    prevention: string
    cliCommand?: string
  }
}

export const guides: Guide[] = [
  {
    slug: 'claude-code-high-cpu',
    title: 'Why is Claude Code Using So Much CPU?',
    description: 'Diagnose and fix high CPU usage from Claude Code CLI. Learn what causes CPU spikes and how to stop runaway processes.',
    icon: '🔥',
    tags: ['CPU', 'Performance', 'Debugging'],
    keywords: ['claude code high cpu', 'claude code slow', 'claude cpu usage', 'claude code performance'],
    content: {
      problem: 'Claude Code is consuming excessive CPU resources, causing your Mac to heat up, fans to spin loudly, or other applications to become sluggish.',
      causes: [
        'File watcher monitoring too many files (e.g., node_modules, large repos)',
        'Stuck or infinite loop in code generation',
        'Multiple concurrent Claude sessions competing for resources',
        'Background indexing or analysis tasks',
        'Memory pressure causing swap thrashing',
      ],
      diagnosis: `Use Claude Trace to identify which specific process is consuming CPU:

\`\`\`bash
# Quick overview of all Claude processes
claude-trace

# Watch mode for real-time monitoring
claude-trace -w 2

# Verbose mode to see project names
claude-trace -v
\`\`\`

Look for processes showing sustained CPU usage above 80%. The STATE column shows if the process is actively running (R) or sleeping (S).`,
      solution: `1. **Identify the culprit**: Use \`claude-trace -v\` to see which project is causing the spike

2. **Kill the runaway process**: Click the process in Claude Trace menu bar and select "Kill Process" or use:
   \`\`\`bash
   kill -9 <PID>
   \`\`\`

3. **Restart Claude in that project**: Close the terminal/editor session and reopen

4. **Check for file watcher issues**: If it recurs, add problematic directories to \`.claudeignore\``,
      prevention: `- Create a \`.claudeignore\` file in your project root to exclude node_modules, .git, and build directories
- Use Claude Trace's notification thresholds to get alerted before CPU spikes become critical
- Regularly check for orphaned Claude processes with \`claude-trace\``,
      cliCommand: 'claude-trace -v',
    },
  },
  {
    slug: 'claude-code-memory-leak',
    title: 'Claude Code Memory Leak: How to Diagnose and Fix',
    description: 'Identify and resolve memory leaks in Claude Code CLI. Learn why Claude consumes more memory over time and how to reclaim it.',
    icon: '💾',
    tags: ['Memory', 'Performance', 'Debugging'],
    keywords: ['claude code memory leak', 'claude code ram usage', 'claude memory high', 'claude code using too much memory'],
    content: {
      problem: 'Claude Code memory usage grows continuously over time, eventually causing your system to slow down or run out of RAM.',
      causes: [
        'Long-running sessions accumulating conversation context',
        'Large files being held in memory for analysis',
        'Multiple sessions with overlapping contexts',
        'Orphaned Node.js processes not properly garbage collected',
        'File watchers holding file handles open',
      ],
      diagnosis: `Monitor memory usage over time with Claude Trace:

\`\`\`bash
# Watch memory in real-time
claude-trace -w 2

# JSON output for tracking
claude-trace -j | jq '.processes[] | {pid, rss_kb, project}'
\`\`\`

The RSS (Resident Set Size) column shows actual memory usage. Watch for processes where this grows steadily.`,
      solution: `1. **Restart long-running sessions**: The simplest fix is to restart Claude sessions that have been running for hours

2. **Kill high-memory processes**: Use Claude Trace to identify and kill the worst offenders
   \`\`\`bash
   # Find processes using > 1GB
   claude-trace -j | jq '.processes[] | select(.rss_kb > 1048576)'
   \`\`\`

3. **Reduce context window**: Start new conversations instead of continuing very long ones

4. **Close unused sessions**: Keep only the Claude sessions you're actively using`,
      prevention: `- Set memory thresholds in Claude Trace settings (e.g., alert at 2GB per process)
- Restart Claude sessions daily if you leave them running
- Use Claude Trace's "Kill All" feature when switching projects`,
      cliCommand: 'claude-trace -j | jq \'.totals.rss_kb\'',
    },
  },
  {
    slug: 'claude-code-orphan-processes',
    title: 'Finding and Cleaning Up Orphan Claude Processes',
    description: 'Discover zombie Claude Code processes that are wasting resources. Learn how to detect and remove orphaned Claude sessions.',
    icon: '👻',
    tags: ['Orphan', 'Cleanup', 'Processes'],
    keywords: ['claude orphan process', 'claude zombie process', 'claude process cleanup', 'claude code stuck process'],
    content: {
      problem: 'Claude Code processes continue running after their parent terminal or editor session has closed, consuming resources unnecessarily.',
      causes: [
        'Terminal or VS Code crashed without properly closing Claude',
        'Force-quitting an application running Claude',
        'SSH disconnection without proper session cleanup',
        'Bug in Claude\'s process management',
        'Multiple Claude instances from different sources (CLI, IDE extension)',
      ],
      diagnosis: `Claude Trace automatically detects orphaned processes:

\`\`\`bash
# Orphaned processes show PPID of 1
claude-trace -v

# JSON format for scripting
claude-trace -j | jq '.processes[] | select(.is_orphaned == true)'
\`\`\`

In the menu bar app, orphaned processes are highlighted with a warning indicator.`,
      solution: `1. **Use Claude Trace's cleanup feature**: Click "Kill All Orphans" in the menu bar dropdown

2. **Manual cleanup**:
   \`\`\`bash
   # Find orphaned Claude processes
   claude-trace -j | jq -r '.processes[] | select(.is_orphaned) | .pid' | xargs kill -9
   \`\`\`

3. **Verify cleanup worked**:
   \`\`\`bash
   claude-trace
   \`\`\``,
      prevention: `- Use Claude Trace to monitor for orphans regularly
- Close Claude sessions properly before closing terminals
- Set up Claude Trace to launch at login for continuous monitoring
- Check for orphans after system wake from sleep`,
      cliCommand: 'claude-trace -j | jq \'.orphaned_count\'',
    },
  },
  {
    slug: 'claude-code-slow-response',
    title: 'Why is Claude Code Responding Slowly?',
    description: 'Troubleshoot slow response times from Claude Code CLI. Learn what causes delays and how to speed things up.',
    icon: '🐢',
    tags: ['Speed', 'Performance', 'Latency'],
    keywords: ['claude code slow', 'claude code response time', 'claude code lag', 'claude code delay'],
    content: {
      problem: 'Claude Code takes a long time to respond to prompts, with noticeable delays between sending a message and receiving a response.',
      causes: [
        'Network latency to Anthropic\'s API servers',
        'Large context from long conversation history',
        'Many files being analyzed or included',
        'Local resource contention from other Claude sessions',
        'System memory pressure causing swap usage',
        'Rate limiting from API',
      ],
      diagnosis: `First, rule out local resource issues:

\`\`\`bash
# Check if Claude is CPU or memory bound locally
claude-trace -v

# Look at system-wide pressure
memory_pressure
\`\`\`

If local resources look fine, the issue is likely network or API-related.`,
      solution: `1. **Reduce local resource contention**:
   - Kill unused Claude sessions with Claude Trace
   - Close other heavy applications

2. **Reduce context size**:
   - Start a new conversation
   - Use more focused prompts
   - Reference specific files instead of entire directories

3. **Check your connection**:
   - Try a different network
   - Check Anthropic status page

4. **Optimize file includes**:
   - Use \`.claudeignore\` to exclude unnecessary files
   - Be specific about which files to analyze`,
      prevention: `- Keep conversation contexts focused and restart when they get long
- Maintain a \`.claudeignore\` file in all projects
- Use Claude Trace to ensure you're not running excessive sessions
- Close Claude sessions you're not actively using`,
      cliCommand: 'claude-trace',
    },
  },
  {
    slug: 'claude-code-multiple-sessions',
    title: 'Managing Multiple Claude Code Sessions',
    description: 'Learn how to effectively manage and monitor multiple concurrent Claude Code sessions without overwhelming your system.',
    icon: '📊',
    tags: ['Sessions', 'Multi-project', 'Management'],
    keywords: ['claude multiple sessions', 'claude code many processes', 'claude session management', 'claude code concurrent'],
    content: {
      problem: 'Running Claude Code in multiple projects simultaneously causes system slowdown, confusion about which session is which, or resource exhaustion.',
      causes: [
        'Each Claude session runs multiple Node.js processes',
        'No visibility into aggregate resource usage',
        'Hard to tell which project each process belongs to',
        'Sessions accumulate when switching between projects',
      ],
      diagnosis: `Get a complete picture of all Claude activity:

\`\`\`bash
# See all processes with project names
claude-trace -v

# Aggregate stats
claude-trace -j | jq '.totals'

# Group by project
claude-trace -j | jq 'group_by(.project) | map({project: .[0].project, count: length, total_cpu: (map(.cpu_percent) | add)})'
\`\`\``,
      solution: `1. **Use Claude Trace's aggregate view**: The menu bar shows total CPU/memory across all sessions

2. **Identify which projects are active**:
   \`\`\`bash
   claude-trace -v | head -20
   \`\`\`

3. **Close sessions for inactive projects**: Use the menu bar app to kill specific processes

4. **Set up notifications**: Configure Claude Trace to alert when aggregate resources exceed thresholds`,
      prevention: `- Close Claude sessions when switching projects
- Use Claude Trace's aggregate thresholds (e.g., alert when total CPU > 200%)
- Regularly audit running sessions with \`claude-trace -v\`
- Consider whether you really need Claude active in all open projects`,
      cliCommand: 'claude-trace -v',
    },
  },
  {
    slug: 'claude-code-outdated-version',
    title: 'Detecting Outdated Claude Code Versions',
    description: 'Find and update old Claude Code installations that may have bugs or missing features.',
    icon: '📦',
    tags: ['Version', 'Updates', 'Maintenance'],
    keywords: ['claude code update', 'claude code version', 'claude outdated', 'claude code upgrade'],
    content: {
      problem: 'Different Claude Code sessions are running different versions, potentially causing inconsistent behavior or missing bug fixes.',
      causes: [
        'Long-running sessions started before an update',
        'Multiple installations (global, local, nvm versions)',
        'Failed or incomplete updates',
        'Different users on shared machines',
      ],
      diagnosis: `Claude Trace detects version mismatches:

\`\`\`bash
# See version for each process
claude-trace -j | jq '.processes[] | {pid, version, project}'

# Check for outdated
claude-trace -j | jq '.outdated_count'
\`\`\`

In the menu bar app, outdated processes are flagged with a warning.`,
      solution: `1. **Kill outdated sessions**: Restart Claude in those projects
   \`\`\`bash
   # Find outdated PIDs
   claude-trace -j | jq -r '.processes[] | select(.is_outdated) | .pid'
   \`\`\`

2. **Update Claude Code globally**:
   \`\`\`bash
   npm update -g @anthropic-ai/claude-code
   \`\`\`

3. **Restart all Claude sessions** to pick up the new version`,
      prevention: `- Enable auto-updates for Claude Code
- Restart Claude sessions after updating
- Use Claude Trace to monitor for version drift
- Set a reminder to check for updates weekly`,
      cliCommand: 'claude-trace -j | jq \'.latest_local_version\'',
    },
  },
  {
    slug: 'kill-all-claude-processes',
    title: 'How to Kill All Claude Code Processes at Once',
    description: 'Quickly stop all running Claude Code processes when you need to free up system resources or resolve issues.',
    icon: '🛑',
    tags: ['Kill', 'Cleanup', 'Emergency'],
    keywords: ['kill claude code', 'stop all claude', 'claude code kill process', 'terminate claude'],
    content: {
      problem: 'You need to immediately stop all Claude Code processes to free up system resources or troubleshoot an issue.',
      causes: [
        'System running out of memory',
        'Need to restart with clean state',
        'Troubleshooting a bug',
        'Preparing for system maintenance',
        'Mac running extremely hot',
      ],
      diagnosis: `First, see what you're about to kill:

\`\`\`bash
# List all Claude processes
claude-trace

# Get count
claude-trace -j | jq '.process_count'
\`\`\``,
      solution: `**Option 1: Claude Trace Menu Bar**
Click the menu bar icon → "Kill All Claude Processes"

**Option 2: CLI**
\`\`\`bash
# Kill all Claude processes
claude-trace -j | jq -r '.processes[].pid' | xargs kill -9
\`\`\`

**Option 3: pkill (nuclear option)**
\`\`\`bash
pkill -9 -f "claude"
\`\`\`

**Verify**:
\`\`\`bash
claude-trace
# Should show no processes
\`\`\``,
      prevention: `- Use Claude Trace to monitor and prevent resource accumulation
- Set up threshold notifications to catch problems early
- Restart Claude sessions daily if running 24/7`,
      cliCommand: 'claude-trace -j | jq -r \'.processes[].pid\' | xargs kill -9',
    },
  },
  {
    slug: 'claude-code-debug-flamegraph',
    title: 'Using Flamegraphs to Debug Claude Code Performance',
    description: 'Generate flamegraph visualizations to understand exactly what Claude Code is doing when CPU usage spikes.',
    icon: '📈',
    tags: ['Advanced', 'Flamegraph', 'Deep Debugging'],
    keywords: ['claude flamegraph', 'claude code profiling', 'claude performance analysis', 'claude code debug'],
    content: {
      problem: 'You need deeper insight into what Claude Code is actually doing during a CPU spike, beyond just knowing CPU percentage.',
      causes: [
        'Standard monitoring doesn\'t show call stacks',
        'Need to identify specific bottlenecks',
        'Reporting bugs to Anthropic',
        'Understanding internal Claude behavior',
      ],
      diagnosis: `First, identify the target process:

\`\`\`bash
# Find the high-CPU process
claude-trace -v
\`\`\`

Note the PID of the process you want to profile.`,
      solution: `**Generate a flamegraph using claude-diagnose:**

\`\`\`bash
# Build the diagnostic tool first
cd ~/claude-trace/cli && cargo build --release

# Generate flamegraph (requires sudo for DTrace)
sudo ./target/release/claude-diagnose --pid <PID> -D --flamegraph -o debug.svg --duration 10
\`\`\`

Open \`debug.svg\` in a browser. The width of each bar represents time spent in that function.

**What to look for:**
- Wide bars at the top = where most time is spent
- "poll" or "epoll" = file watching
- "read" or "write" = file I/O
- "send" or "recv" = network I/O`,
      prevention: `- Keep claude-diagnose built and ready for when you need it
- Save flamegraphs when investigating issues to track patterns
- Use simpler tools first (claude-trace) before going this deep`,
      cliCommand: 'sudo ./cli/target/release/claude-diagnose --pid <PID> -D --flamegraph -o debug.svg',
    },
  },
]
