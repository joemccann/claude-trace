//! claude-diagnose - Advanced diagnostics for Claude Code CLI CPU issues on macOS
//!
//! Performs deep analysis including:
//! - Stack sampling via macOS 'sample' command
//! - File descriptor analysis
//! - FSEvents watcher detection
//! - Node.js event loop diagnostics
//! - Memory pressure analysis

use anyhow::Result;
use chrono::Utc;
use clap::Parser;
use colored::Colorize;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::process::Command;

/// Advanced diagnostics for Claude Code CLI processes
#[derive(Parser, Debug)]
#[command(name = "claude-diagnose")]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Perform deep analysis (sampling, fd analysis)
    #[arg(short, long)]
    deep: bool,

    /// Include stack sampling (implies --deep)
    #[arg(short, long)]
    sample: bool,

    /// Sampling duration in seconds
    #[arg(long, default_value = "5")]
    sample_duration: u32,

    /// Output as JSON
    #[arg(short, long)]
    json: bool,

    /// Analyze specific PID only
    #[arg(long)]
    pid: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct ProcessInfo {
    pid: u32,
    ppid: u32,
    cpu: f64,
    mem: f64,
    rss_kb: u64,
    vsz_kb: u64,
    state: String,
    etime: String,
    command: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct Diagnosis {
    issue: String,
    severity: String,
    description: String,
    remedy: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct HotFunction {
    function: String,
    samples: u32,
}

#[derive(Debug, Serialize, Deserialize)]
struct SampleResult {
    pid: u32,
    success: bool,
    sample_file: Option<String>,
    thread_count: u32,
    hot_functions: Vec<HotFunction>,
    diagnosis: Vec<Diagnosis>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct FdResult {
    pid: u32,
    total_fds: u32,
    by_type: HashMap<String, u32>,
    watched_paths: Vec<String>,
    network_connections: Vec<NetworkConnection>,
    issues: Vec<Diagnosis>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct NetworkConnection {
    conn_type: String,
    connection: String,
}

#[derive(Debug, Serialize, Deserialize)]
struct MemoryInfo {
    pressure_level: String,
    free_memory_mb: u64,
}

#[derive(Debug, Serialize, Deserialize)]
struct ProcessReport {
    pid: u32,
    cpu: f64,
    mem: f64,
    rss_mb: u64,
    command: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    sample: Option<SampleResult>,
    #[serde(skip_serializing_if = "Option::is_none")]
    file_descriptors: Option<FdResult>,
}

#[derive(Debug, Serialize, Deserialize)]
struct SystemInfo {
    memory: MemoryInfo,
}

#[derive(Debug, Serialize, Deserialize)]
struct Summary {
    total_cpu: f64,
    total_mem: f64,
    total_rss_mb: u64,
    critical_issues: Vec<String>,
    warnings: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
struct DiagnosticReport {
    timestamp: String,
    hostname: String,
    os_version: String,
    process_count: usize,
    processes: Vec<ProcessReport>,
    system: SystemInfo,
    summary: Summary,
}

/// Run a command and return (success, stdout, stderr)
fn run_cmd(cmd: &str, args: &[&str]) -> (bool, String, String) {
    let result = Command::new(cmd)
        .args(args)
        .output();

    match result {
        Ok(output) => (
            output.status.success(),
            String::from_utf8_lossy(&output.stdout).to_string(),
            String::from_utf8_lossy(&output.stderr).to_string(),
        ),
        Err(e) => (false, String::new(), e.to_string()),
    }
}

/// Find all Claude Code CLI processes
fn get_claude_pids() -> Vec<ProcessInfo> {
    let mut processes = Vec::new();

    let (success, stdout, _) = run_cmd(
        "ps",
        &["-Ao", "pid,ppid,pcpu,pmem,rss,vsz,state,etime,command"],
    );

    if !success {
        return processes;
    }

    let claude_pattern = Regex::new(r"(?i)(claude|anthropic)").unwrap();
    let exclude_pattern = Regex::new(r"(grep|claude-trace|claude-diagnose)").unwrap();

    for line in stdout.lines().skip(1) {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        if !claude_pattern.is_match(line) {
            continue;
        }

        if exclude_pattern.is_match(line) {
            continue;
        }

        let parts: Vec<&str> = line.splitn(9, char::is_whitespace)
            .filter(|s| !s.is_empty())
            .collect();

        if parts.len() >= 9 {
            if let (Ok(pid), Ok(ppid), Ok(cpu), Ok(mem), Ok(rss), Ok(vsz)) = (
                parts[0].parse::<u32>(),
                parts[1].parse::<u32>(),
                parts[2].parse::<f64>(),
                parts[3].parse::<f64>(),
                parts[4].parse::<u64>(),
                parts[5].parse::<u64>(),
            ) {
                processes.push(ProcessInfo {
                    pid,
                    ppid,
                    cpu,
                    mem,
                    rss_kb: rss,
                    vsz_kb: vsz,
                    state: parts[6].to_string(),
                    etime: parts[7].to_string(),
                    command: parts[8].to_string(),
                });
            }
        }
    }

    processes
}

/// Sample a process using macOS 'sample' command
fn sample_process(pid: u32, duration: u32) -> SampleResult {
    eprintln!("{} Sampling PID {} for {}s...", "→".cyan(), pid, duration);

    let sample_file = format!("/tmp/claude_sample_{}.txt", pid);

    let (success, _, stderr) = run_cmd(
        "sample",
        &[
            &pid.to_string(),
            &duration.to_string(),
            "-file",
            &sample_file,
        ],
    );

    let mut result = SampleResult {
        pid,
        success,
        sample_file: Some(sample_file.clone()),
        thread_count: 0,
        hot_functions: Vec::new(),
        diagnosis: Vec::new(),
        error: None,
    };

    if !success {
        result.error = Some(stderr);
        return result;
    }

    // Parse sample output
    let content = match fs::read_to_string(&sample_file) {
        Ok(c) => c,
        Err(e) => {
            result.error = Some(e.to_string());
            return result;
        }
    };

    // Extract thread count
    if let Some(caps) = Regex::new(r"(\d+)\s+threads?").unwrap().captures(&content) {
        if let Ok(n) = caps[1].parse::<u32>() {
            result.thread_count = n;
        }
    }

    // Find hot functions
    let func_pattern = Regex::new(r"\+\[(.*?)\]|(\w+::\w+)\s*\(").unwrap();
    let mut func_counts: HashMap<String, u32> = HashMap::new();

    for caps in func_pattern.captures_iter(&content) {
        let func = caps.get(1).or(caps.get(2)).map(|m| m.as_str().to_string());
        if let Some(f) = func {
            if f.len() > 3 {
                *func_counts.entry(f).or_insert(0) += 1;
            }
        }
    }

    let mut sorted_funcs: Vec<_> = func_counts.into_iter().collect();
    sorted_funcs.sort_by(|a, b| b.1.cmp(&a.1));

    result.hot_functions = sorted_funcs
        .into_iter()
        .take(20)
        .map(|(function, samples)| HotFunction { function, samples })
        .collect();

    // Diagnose common issues
    if content.contains("FSEvents") || content.contains("fseventsd") {
        result.diagnosis.push(Diagnosis {
            issue: "FSEvents Activity".to_string(),
            severity: "medium".to_string(),
            description: "Process is actively watching filesystem events".to_string(),
            remedy: "Check .claude/settings.json for watchPaths config".to_string(),
        });
    }

    let kevent_count = content.matches("kevent").count();
    let poll_count = content.matches("poll").count();
    if kevent_count > 50 || poll_count > 50 {
        result.diagnosis.push(Diagnosis {
            issue: "High Polling Activity".to_string(),
            severity: "high".to_string(),
            description: "Process spinning on event polling (kevent/poll)".to_string(),
            remedy: "Likely a bug in event loop - consider restarting".to_string(),
        });
    }

    if content.contains("GCRuntime") || content.contains("Scavenge") || content.contains("MarkCompact") {
        result.diagnosis.push(Diagnosis {
            issue: "Garbage Collection Pressure".to_string(),
            severity: "medium".to_string(),
            description: "V8 garbage collector is running frequently".to_string(),
            remedy: "Consider increasing --max-old-space-size".to_string(),
        });
    }

    if content.contains("CRYPTO") || content.contains("SSL") || content.contains("TLS") {
        result.diagnosis.push(Diagnosis {
            issue: "Cryptographic Operations".to_string(),
            severity: "low".to_string(),
            description: "Process is performing crypto/TLS operations".to_string(),
            remedy: "Normal if establishing connections".to_string(),
        });
    }

    let cfrunloop_count = content.matches("CFRunLoop").count();
    if cfrunloop_count > 100 {
        result.diagnosis.push(Diagnosis {
            issue: "CFRunLoop Spinning".to_string(),
            severity: "high".to_string(),
            description: "Core Foundation run loop is spinning excessively".to_string(),
            remedy: "Indicates event loop issue - restart session".to_string(),
        });
    }

    result
}

/// Analyze file descriptors using lsof
fn analyze_file_descriptors(pid: u32) -> FdResult {
    eprintln!("{} Analyzing file descriptors for PID {}...", "→".cyan(), pid);

    let (success, stdout, stderr) = run_cmd("lsof", &["-p", &pid.to_string()]);

    let mut result = FdResult {
        pid,
        total_fds: 0,
        by_type: HashMap::new(),
        watched_paths: Vec::new(),
        network_connections: Vec::new(),
        issues: Vec::new(),
        error: None,
    };

    if !success {
        result.error = Some(stderr);
        return result;
    }

    let lines: Vec<&str> = stdout.lines().skip(1).collect();
    result.total_fds = lines.len() as u32;

    let mut watched = std::collections::HashSet::new();

    for line in lines {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() < 9 {
            continue;
        }

        let fd_type = parts.get(4).unwrap_or(&"unknown");
        *result.by_type.entry(fd_type.to_string()).or_insert(0) += 1;

        let name = parts.last().unwrap_or(&"");

        // Detect file watchers
        let line_lower = line.to_lowercase();
        if line_lower.contains("fsevents") || line_lower.contains("kqueue") {
            watched.insert(name.to_string());
        }

        // Detect network connections
        if *fd_type == "IPv4" || *fd_type == "IPv6" || line.contains("TCP") || line.contains("UDP") {
            result.network_connections.push(NetworkConnection {
                conn_type: fd_type.to_string(),
                connection: name.to_string(),
            });
            if result.network_connections.len() >= 20 {
                break;
            }
        }
    }

    result.watched_paths = watched.into_iter().take(50).collect();

    // Check for issues
    if result.total_fds > 1000 {
        result.issues.push(Diagnosis {
            issue: "High File Descriptor Count".to_string(),
            severity: "high".to_string(),
            description: format!("Process has {} open file descriptors", result.total_fds),
            remedy: "Possible fd leak - check for unclosed handles".to_string(),
        });
    }

    if result.watched_paths.len() > 100 {
        result.issues.push(Diagnosis {
            issue: "Excessive File Watching".to_string(),
            severity: "high".to_string(),
            description: format!("Watching {} paths", result.watched_paths.len()),
            remedy: "Too many watched paths - add exclusions".to_string(),
        });
    }

    result
}

/// Check system memory pressure
fn check_memory_pressure() -> MemoryInfo {
    let mut result = MemoryInfo {
        pressure_level: "unknown".to_string(),
        free_memory_mb: 0,
    };

    // memory_pressure command
    let (success, stdout, _) = run_cmd("memory_pressure", &[]);
    if success {
        let stdout_lower = stdout.to_lowercase();
        if stdout_lower.contains("normal") {
            result.pressure_level = "normal".to_string();
        } else if stdout_lower.contains("warn") {
            result.pressure_level = "warning".to_string();
        } else if stdout_lower.contains("critical") {
            result.pressure_level = "critical".to_string();
        }
    }

    // vm_stat for more details
    let (success, stdout, _) = run_cmd("vm_stat", &[]);
    if success {
        let mut page_size: u64 = 16384;

        for line in stdout.lines() {
            if line.to_lowercase().contains("page size") {
                if let Some(caps) = Regex::new(r"(\d+)").unwrap().captures(line) {
                    if let Ok(n) = caps[1].parse::<u64>() {
                        page_size = n;
                    }
                }
            } else if line.contains("Pages free") {
                if let Some(caps) = Regex::new(r"(\d+)").unwrap().captures(line) {
                    if let Ok(n) = caps[1].parse::<u64>() {
                        result.free_memory_mb = (n * page_size) / (1024 * 1024);
                    }
                }
            }
        }
    }

    result
}

/// Get hostname
fn get_hostname() -> String {
    let (_, stdout, _) = run_cmd("hostname", &[]);
    stdout.trim().to_string()
}

/// Get OS version
fn get_os_version() -> String {
    let (_, stdout, _) = run_cmd("uname", &["-r"]);
    stdout.trim().to_string()
}

/// Generate diagnostic report
fn generate_report(processes: &[ProcessInfo], args: &Args) -> DiagnosticReport {
    let mut report = DiagnosticReport {
        timestamp: Utc::now().to_rfc3339(),
        hostname: get_hostname(),
        os_version: get_os_version(),
        process_count: processes.len(),
        processes: Vec::new(),
        system: SystemInfo {
            memory: check_memory_pressure(),
        },
        summary: Summary {
            total_cpu: 0.0,
            total_mem: 0.0,
            total_rss_mb: 0,
            critical_issues: Vec::new(),
            warnings: Vec::new(),
        },
    };

    for proc in processes {
        let mut proc_report = ProcessReport {
            pid: proc.pid,
            cpu: proc.cpu,
            mem: proc.mem,
            rss_mb: proc.rss_kb / 1024,
            command: proc.command.chars().take(100).collect(),
            sample: None,
            file_descriptors: None,
        };

        report.summary.total_cpu += proc.cpu;
        report.summary.total_mem += proc.mem;
        report.summary.total_rss_mb += proc.rss_kb / 1024;

        // Deep analysis
        if args.deep || args.sample {
            if args.sample {
                let sample_result = sample_process(proc.pid, args.sample_duration);
                for diag in &sample_result.diagnosis {
                    match diag.severity.as_str() {
                        "high" => report.summary.critical_issues.push(
                            format!("PID {}: {}", proc.pid, diag.issue)
                        ),
                        "medium" => report.summary.warnings.push(
                            format!("PID {}: {}", proc.pid, diag.issue)
                        ),
                        _ => {}
                    }
                }
                proc_report.sample = Some(sample_result);
            }

            let fd_result = analyze_file_descriptors(proc.pid);
            for issue in &fd_result.issues {
                if issue.severity == "high" {
                    report.summary.critical_issues.push(
                        format!("PID {}: {}", proc.pid, issue.issue)
                    );
                }
            }
            proc_report.file_descriptors = Some(fd_result);
        }

        report.processes.push(proc_report);
    }

    // Overall health assessment
    if report.summary.total_cpu > 100.0 {
        report.summary.critical_issues.push(
            format!("Aggregate CPU usage ({:.1}%) exceeds single core", report.summary.total_cpu)
        );
    }

    report
}

/// Print the diagnostic report in human-readable format
fn print_report(report: &DiagnosticReport) {
    println!();
    println!("{}", "═══════════════════════════════════════════════════════════════════".bold());
    println!("{}", "  CLAUDE CODE CLI DIAGNOSTIC REPORT".bold());
    println!("{}", "═══════════════════════════════════════════════════════════════════".bold());
    println!("  {} {}", "Generated:".dimmed(), report.timestamp);
    println!("  {} {} | {} Darwin {}", "Host:".dimmed(), report.hostname, "OS:".dimmed(), report.os_version);
    println!();

    // Summary
    println!("{}", "SUMMARY".bold());
    println!("  Processes found: {}", report.process_count);

    let cpu_str = format!("{:.1}%", report.summary.total_cpu);
    let cpu_colored = if report.summary.total_cpu > 100.0 {
        cpu_str.red()
    } else if report.summary.total_cpu > 50.0 {
        cpu_str.yellow()
    } else {
        cpu_str.green()
    };
    println!("  Total CPU: {}", cpu_colored);
    println!("  Total Memory: {:.1}%", report.summary.total_mem);
    println!("  Total RSS: {} MB", report.summary.total_rss_mb);

    // Memory pressure
    let pressure = &report.system.memory.pressure_level;
    let pressure_colored = match pressure.as_str() {
        "normal" => pressure.green(),
        "warning" => pressure.yellow(),
        "critical" => pressure.red(),
        _ => pressure.normal(),
    };
    println!("  System Memory Pressure: {}", pressure_colored);

    // Critical issues
    if !report.summary.critical_issues.is_empty() {
        println!();
        println!("{}", "CRITICAL ISSUES".bold().red());
        for issue in &report.summary.critical_issues {
            println!("  {} {}", "✗".red(), issue);
        }
    }

    // Warnings
    if !report.summary.warnings.is_empty() {
        println!();
        println!("{}", "WARNINGS".bold().yellow());
        for warning in &report.summary.warnings {
            println!("  {} {}", "⚠".yellow(), warning);
        }
    }

    // Per-process details
    println!();
    println!("{}", "PROCESS DETAILS".bold());

    for proc in &report.processes {
        println!();
        let cpu_str = format!("{:.1}% CPU", proc.cpu);
        let cpu_colored = if proc.cpu > 80.0 {
            cpu_str.red()
        } else if proc.cpu > 30.0 {
            cpu_str.yellow()
        } else {
            cpu_str.normal()
        };
        println!("  {}: {}, {:.1}% MEM, {} MB RSS",
            format!("PID {}", proc.pid).bold(),
            cpu_colored,
            proc.mem,
            proc.rss_mb
        );
        println!("  {}", proc.command.chars().take(80).collect::<String>().dimmed());

        // Sample results
        if let Some(ref sample) = proc.sample {
            if !sample.hot_functions.is_empty() {
                println!();
                println!("    {}:", "Hot Functions".cyan());
                for hf in sample.hot_functions.iter().take(5) {
                    println!("      {:4} samples: {}", hf.samples, hf.function);
                }
            }

            if !sample.diagnosis.is_empty() {
                println!();
                println!("    {}:", "Diagnosis".cyan());
                for diag in &sample.diagnosis {
                    let sev_colored = match diag.severity.as_str() {
                        "high" => format!("[{}]", diag.severity.to_uppercase()).red(),
                        "medium" => format!("[{}]", diag.severity.to_uppercase()).yellow(),
                        _ => format!("[{}]", diag.severity.to_uppercase()).normal(),
                    };
                    println!("      {} {}", sev_colored, diag.issue);
                    println!("        {}", diag.description.dimmed());
                    println!("        Remedy: {}", diag.remedy);
                }
            }
        }

        // File descriptor analysis
        if let Some(ref fd) = proc.file_descriptors {
            println!();
            println!("    {}: {} open", "File Descriptors".cyan(), fd.total_fds);
            if !fd.by_type.is_empty() {
                let types_str: String = fd.by_type.iter()
                    .take(5)
                    .map(|(k, v)| format!("{}:{}", k, v))
                    .collect::<Vec<_>>()
                    .join(", ");
                println!("      Types: {}", types_str);
            }
            if !fd.network_connections.is_empty() {
                println!("      Network: {} connections", fd.network_connections.len());
            }
        }
    }

    // Remediation suggestions
    println!();
    println!("{}", "═══════════════════════════════════════════════════════════════════".bold());
    println!("{}", "RECOMMENDED ACTIONS".bold());

    if report.summary.total_cpu > 100.0 {
        println!();
        println!("  1. {}: Restart high-CPU sessions", "Immediate".cyan());
        println!("     $ kill -TERM <pid>  # Graceful termination");
        println!();
        println!("  2. {}: Sample the highest-CPU process", "Diagnose".cyan());
        println!("     $ sample <pid> 10 -file /tmp/claude_sample.txt");
        println!("     $ filtercalltree /tmp/claude_sample.txt");
        println!();
        println!("  3. {}: Watch for recurrence", "Monitor".cyan());
        println!("     $ claude-trace -w 5 -k 50");
    } else {
        println!("  {} No immediate action required", "✓".green());
    }

    println!("{}", "═══════════════════════════════════════════════════════════════════".bold());
    println!();
}

fn main() -> Result<()> {
    let mut args = Args::parse();

    // Sampling implies deep mode
    if args.sample {
        args.deep = true;
    }

    // Find processes
    let mut processes = get_claude_pids();

    // Filter to specific PID if requested
    if let Some(pid) = args.pid {
        processes.retain(|p| p.pid == pid);
        if processes.is_empty() {
            eprintln!("{}: PID {} not found or not a Claude process", "Error".red(), pid);
            std::process::exit(1);
        }
    }

    if processes.is_empty() {
        if args.json {
            println!("{{\"error\": \"No Claude Code CLI processes found\"}}");
        } else {
            println!("{}", "No Claude Code CLI processes found.".yellow());
        }
        return Ok(());
    }

    // Generate report
    let report = generate_report(&processes, &args);

    // Output
    if args.json {
        println!("{}", serde_json::to_string_pretty(&report)?);
    } else {
        print_report(&report);
    }

    Ok(())
}
