//! claude-diagnose - Advanced diagnostics for Claude Code CLI CPU issues on macOS
//!
//! Performs deep analysis including:
//! - Stack sampling via macOS 'sample' command
//! - File descriptor analysis
//! - FSEvents watcher detection
//! - Node.js event loop diagnostics
//! - Memory pressure analysis
//! - DTrace/dtruss syscall tracing

use anyhow::Result;
use chrono::Utc;
use clap::Parser;
use colored::Colorize;
use inferno::flamegraph::{self, Options as FlamegraphOptions};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::{BufReader, Write};
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

    /// Enable DTrace/dtruss syscall tracing
    #[arg(short = 'D', long)]
    dtrace: bool,

    /// DTrace: Focus on I/O operations (read, write, open, close)
    #[arg(long, requires = "dtrace")]
    io: bool,

    /// DTrace: Focus on network operations (socket, connect, send, recv)
    #[arg(long, requires = "dtrace")]
    network: bool,

    /// DTrace: Generate flame graph SVG from stack traces
    #[arg(long, requires = "dtrace")]
    flamegraph: bool,

    /// Output file path for flame graph or trace data
    #[arg(short = 'o', long)]
    output: Option<String>,

    /// Duration for DTrace tracing in seconds
    #[arg(long, default_value = "5")]
    duration: u32,
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

// ============================================================================
// DTrace/Syscall Tracing Structures
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SyscallEntry {
    name: String,
    count: u32,
    total_time_us: u64,
    avg_time_us: f64,
    errors: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct IoOperation {
    syscall: String,
    fd: i32,
    path: Option<String>,
    bytes: u64,
    latency_us: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct NetworkOperation {
    syscall: String,
    fd: i32,
    address: Option<String>,
    port: Option<u16>,
    bytes: u64,
    latency_us: u64,
}

#[derive(Debug, Serialize, Deserialize)]
struct DtraceResult {
    pid: u32,
    duration_secs: u32,
    success: bool,
    method: String, // "dtruss", "dtrace", "fs_usage", or "fallback"
    syscall_summary: Vec<SyscallEntry>,
    io_operations: Vec<IoOperation>,
    network_operations: Vec<NetworkOperation>,
    top_syscalls: Vec<SyscallEntry>,
    stack_samples: Vec<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    flamegraph_path: Option<String>,
    issues: Vec<Diagnosis>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    fallback_reason: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum DtraceMode {
    General,
    Io,
    Network,
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
    #[serde(skip_serializing_if = "Option::is_none")]
    dtrace: Option<DtraceResult>,
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

// ============================================================================
// DTrace/dtruss Execution and Parsing
// ============================================================================

/// Check if DTrace/dtruss is available and not blocked by SIP
fn check_dtrace_available() -> (bool, Option<String>) {
    // Try running dtruss with a quick test
    let result = Command::new("sudo")
        .args(["-n", "dtruss", "-h"])
        .output();

    match result {
        Ok(output) => {
            let stderr = String::from_utf8_lossy(&output.stderr);
            if stderr.contains("Operation not permitted") || stderr.contains("SIP") {
                return (false, Some("System Integrity Protection (SIP) is blocking DTrace. Disable SIP or use fallback tools.".to_string()));
            }
            if !output.status.success() && stderr.contains("sudo") {
                return (false, Some("sudo access required for dtruss. Run with sudo or configure sudoers.".to_string()));
            }
            (true, None)
        }
        Err(e) => (false, Some(format!("dtruss not available: {}", e))),
    }
}

/// Run dtruss for general syscall tracing
fn run_dtruss(pid: u32, duration: u32) -> (bool, String, String) {
    eprintln!("{} Running dtruss on PID {} for {}s...", "→".cyan(), pid, duration);

    // Use timeout to limit dtruss duration
    let result = Command::new("sudo")
        .args([
            "timeout",
            &format!("{}s", duration),
            "dtruss",
            "-p",
            &pid.to_string(),
        ])
        .output();

    match result {
        Ok(output) => {
            // dtruss outputs to stderr
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            // timeout exit code 124 means it timed out (expected)
            let success = output.status.success() || output.status.code() == Some(124);
            (success, stdout, stderr)
        }
        Err(e) => (false, String::new(), e.to_string()),
    }
}

/// Parse dtruss output into structured syscall data
fn parse_dtruss_output(output: &str) -> Vec<SyscallEntry> {
    let mut syscall_counts: HashMap<String, (u32, u64, u32)> = HashMap::new(); // (count, total_time, errors)

    // dtruss format: "SYSCALL(args) = result  time_us"
    // or with -e: "SYSCALL(args) Err#N time_us"
    let syscall_pattern = Regex::new(r"^\s*(\w+)\([^)]*\)\s*=?\s*(-?\d+|Err#\d+)?\s+(\d+)?").unwrap();

    for line in output.lines() {
        if let Some(caps) = syscall_pattern.captures(line) {
            let syscall = caps.get(1).map(|m| m.as_str().to_string()).unwrap_or_default();
            let result = caps.get(2).map(|m| m.as_str()).unwrap_or("0");
            let time_us = caps.get(3)
                .and_then(|m| m.as_str().parse::<u64>().ok())
                .unwrap_or(0);

            let is_error = result.starts_with("Err") || result.starts_with("-1");

            let entry = syscall_counts.entry(syscall).or_insert((0, 0, 0));
            entry.0 += 1;
            entry.1 += time_us;
            if is_error {
                entry.2 += 1;
            }
        }
    }

    let mut syscalls: Vec<SyscallEntry> = syscall_counts
        .into_iter()
        .map(|(name, (count, total_time, errors))| SyscallEntry {
            name,
            count,
            total_time_us: total_time,
            avg_time_us: if count > 0 { total_time as f64 / count as f64 } else { 0.0 },
            errors,
        })
        .collect();

    // Sort by count descending
    syscalls.sort_by(|a, b| b.count.cmp(&a.count));
    syscalls
}

/// Extract I/O operations from dtruss output
fn extract_io_operations(output: &str) -> Vec<IoOperation> {
    let mut ops = Vec::new();
    let io_syscalls = ["read", "write", "pread", "pwrite", "open", "close", "stat", "fstat", "lstat"];

    // Pattern: syscall(fd, ...) = bytes time_us
    let io_pattern = Regex::new(r"^\s*(read|write|pread|pwrite|open|close|stat|fstat|lstat)\((\d+|0x[0-9a-f]+)?,?\s*([^)]*)\)\s*=\s*(-?\d+)\s+(\d+)").unwrap();

    for line in output.lines() {
        if let Some(caps) = io_pattern.captures(line) {
            let syscall = caps.get(1).map(|m| m.as_str().to_string()).unwrap_or_default();
            if !io_syscalls.contains(&syscall.as_str()) {
                continue;
            }

            let fd = caps.get(2)
                .and_then(|m| {
                    let s = m.as_str();
                    if s.starts_with("0x") {
                        i32::from_str_radix(&s[2..], 16).ok()
                    } else {
                        s.parse::<i32>().ok()
                    }
                })
                .unwrap_or(-1);

            let path = caps.get(3).map(|m| {
                let s = m.as_str();
                // Extract quoted path if present
                if let Some(start) = s.find('"') {
                    if let Some(end) = s[start+1..].find('"') {
                        return s[start+1..start+1+end].to_string();
                    }
                }
                String::new()
            }).filter(|s| !s.is_empty());

            let bytes = caps.get(4)
                .and_then(|m| m.as_str().parse::<i64>().ok())
                .map(|b| if b < 0 { 0 } else { b as u64 })
                .unwrap_or(0);

            let latency = caps.get(5)
                .and_then(|m| m.as_str().parse::<u64>().ok())
                .unwrap_or(0);

            ops.push(IoOperation {
                syscall,
                fd,
                path,
                bytes,
                latency_us: latency,
            });
        }
    }

    ops
}

/// Extract network operations from dtruss output
fn extract_network_operations(output: &str) -> Vec<NetworkOperation> {
    let mut ops = Vec::new();
    let net_syscalls = ["socket", "connect", "bind", "listen", "accept", "send", "recv", "sendto", "recvfrom", "sendmsg", "recvmsg"];

    let net_pattern = Regex::new(r"^\s*(socket|connect|bind|listen|accept|send|recv|sendto|recvfrom|sendmsg|recvmsg)\((\d+)?,?\s*([^)]*)\)\s*=\s*(-?\d+)\s+(\d+)").unwrap();

    for line in output.lines() {
        if let Some(caps) = net_pattern.captures(line) {
            let syscall = caps.get(1).map(|m| m.as_str().to_string()).unwrap_or_default();
            if !net_syscalls.contains(&syscall.as_str()) {
                continue;
            }

            let fd = caps.get(2)
                .and_then(|m| m.as_str().parse::<i32>().ok())
                .unwrap_or(-1);

            let args = caps.get(3).map(|m| m.as_str()).unwrap_or("");

            // Try to extract address/port from sockaddr
            let (address, port) = extract_sockaddr(args);

            let bytes = caps.get(4)
                .and_then(|m| m.as_str().parse::<i64>().ok())
                .map(|b| if b < 0 { 0 } else { b as u64 })
                .unwrap_or(0);

            let latency = caps.get(5)
                .and_then(|m| m.as_str().parse::<u64>().ok())
                .unwrap_or(0);

            ops.push(NetworkOperation {
                syscall,
                fd,
                address,
                port,
                bytes,
                latency_us: latency,
            });
        }
    }

    ops
}

/// Extract IP address and port from sockaddr representation
fn extract_sockaddr(args: &str) -> (Option<String>, Option<u16>) {
    // Look for IP:port patterns
    let ip_pattern = Regex::new(r"(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(\d+)").unwrap();
    if let Some(caps) = ip_pattern.captures(args) {
        let addr = caps.get(1).map(|m| m.as_str().to_string());
        let port = caps.get(2).and_then(|m| m.as_str().parse::<u16>().ok());
        return (addr, port);
    }
    (None, None)
}

/// Run fs_usage as a fallback when DTrace is unavailable
fn run_fs_usage_fallback(pid: u32, duration: u32) -> (bool, String, String) {
    eprintln!("{} Running fs_usage fallback for PID {} for {}s...", "→".yellow(), pid, duration);

    let result = Command::new("sudo")
        .args([
            "timeout",
            &format!("{}s", duration),
            "fs_usage",
            "-w",
            "-f", "filesys",
            &pid.to_string(),
        ])
        .output();

    match result {
        Ok(output) => {
            let stdout = String::from_utf8_lossy(&output.stdout).to_string();
            let stderr = String::from_utf8_lossy(&output.stderr).to_string();
            let success = output.status.success() || output.status.code() == Some(124);
            (success, stdout, stderr)
        }
        Err(e) => (false, String::new(), e.to_string()),
    }
}

/// Parse fs_usage output into I/O operations
fn parse_fs_usage_output(output: &str) -> Vec<IoOperation> {
    let mut ops = Vec::new();

    // fs_usage format: timestamp operation path (process.pid)
    let fs_pattern = Regex::new(r"^\s*[\d:.]+\s+(\w+)\s+(.+?)\s+\d+\.\d+\s+\w").unwrap();

    for line in output.lines() {
        if let Some(caps) = fs_pattern.captures(line) {
            let syscall = caps.get(1).map(|m| m.as_str().to_string()).unwrap_or_default();
            let path = caps.get(2).map(|m| m.as_str().trim().to_string());

            ops.push(IoOperation {
                syscall,
                fd: -1,
                path,
                bytes: 0,
                latency_us: 0,
            });
        }
    }

    ops
}

/// Main DTrace tracing function
fn trace_process(pid: u32, duration: u32, mode: DtraceMode) -> DtraceResult {
    let mut result = DtraceResult {
        pid,
        duration_secs: duration,
        success: false,
        method: String::new(),
        syscall_summary: Vec::new(),
        io_operations: Vec::new(),
        network_operations: Vec::new(),
        top_syscalls: Vec::new(),
        stack_samples: Vec::new(),
        flamegraph_path: None,
        issues: Vec::new(),
        error: None,
        fallback_reason: None,
    };

    // Check if DTrace is available
    let (dtrace_available, dtrace_error) = check_dtrace_available();

    if dtrace_available {
        result.method = "dtruss".to_string();
        let (success, _stdout, stderr) = run_dtruss(pid, duration);

        if success {
            result.success = true;
            result.syscall_summary = parse_dtruss_output(&stderr);

            // Get top 10 syscalls
            result.top_syscalls = result.syscall_summary.iter().take(10).cloned().collect();

            // Extract I/O and network operations based on mode
            match mode {
                DtraceMode::Io | DtraceMode::General => {
                    result.io_operations = extract_io_operations(&stderr);
                }
                _ => {}
            }

            match mode {
                DtraceMode::Network | DtraceMode::General => {
                    result.network_operations = extract_network_operations(&stderr);
                }
                _ => {}
            }

            // Analyze for issues
            analyze_dtrace_issues(&mut result);
        } else {
            result.error = Some(stderr);
        }
    } else {
        // Fallback to fs_usage for I/O tracing
        result.method = "fs_usage".to_string();
        result.fallback_reason = dtrace_error;

        let (success, stdout, stderr) = run_fs_usage_fallback(pid, duration);
        if success {
            result.success = true;
            result.io_operations = parse_fs_usage_output(&stdout);

            result.issues.push(Diagnosis {
                issue: "Using Fallback Tracing".to_string(),
                severity: "low".to_string(),
                description: "DTrace unavailable, using fs_usage for limited file system tracing".to_string(),
                remedy: "Disable SIP or run with appropriate privileges for full DTrace support".to_string(),
            });
        } else {
            result.error = Some(stderr);
        }
    }

    result
}

/// Analyze DTrace results for common issues
fn analyze_dtrace_issues(result: &mut DtraceResult) {
    // Check for excessive polling
    let poll_count: u32 = result.syscall_summary.iter()
        .filter(|s| s.name == "poll" || s.name == "select" || s.name == "kevent" || s.name == "kevent64")
        .map(|s| s.count)
        .sum();

    if poll_count > 1000 {
        result.issues.push(Diagnosis {
            issue: "Excessive Event Polling".to_string(),
            severity: "high".to_string(),
            description: format!("{} poll/select/kevent calls detected - event loop may be spinning", poll_count),
            remedy: "Check for busy-wait loops or misconfigured event handlers".to_string(),
        });
    }

    // Check for high I/O error rate
    let io_errors: u32 = result.syscall_summary.iter()
        .filter(|s| ["read", "write", "open", "stat"].contains(&s.name.as_str()))
        .map(|s| s.errors)
        .sum();

    if io_errors > 100 {
        result.issues.push(Diagnosis {
            issue: "High I/O Error Rate".to_string(),
            severity: "medium".to_string(),
            description: format!("{} I/O errors detected", io_errors),
            remedy: "Check file permissions, paths, and disk health".to_string(),
        });
    }

    // Check for slow syscalls
    for syscall in &result.syscall_summary {
        if syscall.avg_time_us > 10000.0 && syscall.count > 10 {
            result.issues.push(Diagnosis {
                issue: format!("Slow {} syscalls", syscall.name),
                severity: "medium".to_string(),
                description: format!("Average time: {:.1}ms across {} calls", syscall.avg_time_us / 1000.0, syscall.count),
                remedy: "Investigate blocking operations or resource contention".to_string(),
            });
        }
    }

    // Check for excessive file operations
    let file_ops: u32 = result.syscall_summary.iter()
        .filter(|s| ["open", "close", "stat", "fstat", "lstat", "access"].contains(&s.name.as_str()))
        .map(|s| s.count)
        .sum();

    if file_ops > 5000 {
        result.issues.push(Diagnosis {
            issue: "Excessive File Operations".to_string(),
            severity: "medium".to_string(),
            description: format!("{} file metadata operations", file_ops),
            remedy: "Consider caching file metadata or reducing directory traversals".to_string(),
        });
    }
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

    // Determine DTrace mode
    let dtrace_mode = if args.io {
        DtraceMode::Io
    } else if args.network {
        DtraceMode::Network
    } else {
        DtraceMode::General
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
            dtrace: None,
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

        // DTrace analysis
        if args.dtrace {
            let dtrace_result = trace_process(proc.pid, args.duration, dtrace_mode);

            for issue in &dtrace_result.issues {
                match issue.severity.as_str() {
                    "high" => report.summary.critical_issues.push(
                        format!("PID {}: {}", proc.pid, issue.issue)
                    ),
                    "medium" => report.summary.warnings.push(
                        format!("PID {}: {}", proc.pid, issue.issue)
                    ),
                    _ => {}
                }
            }

            // Handle flamegraph generation
            if args.flamegraph && dtrace_result.success {
                if let Some(ref output_path) = args.output {
                    match generate_flamegraph(&dtrace_result, output_path) {
                        Ok(path) => {
                            eprintln!("{} Flamegraph written to: {}", "✓".green(), path);
                        }
                        Err(e) => {
                            eprintln!("{} Failed to generate flamegraph: {}", "✗".red(), e);
                        }
                    }
                }
            }

            proc_report.dtrace = Some(dtrace_result);
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

/// Generate a flamegraph SVG from DTrace syscall data using inferno
fn generate_flamegraph(dtrace: &DtraceResult, output_path: &str) -> Result<String> {
    // Create folded stack format
    let mut folded_lines: Vec<String> = Vec::new();

    // Group syscalls by category for better visualization
    for syscall in &dtrace.syscall_summary {
        let category = categorize_syscall(&syscall.name);
        // Format: category;syscall count
        let line = format!("claude-process;{};{} {}", category, syscall.name, syscall.count);
        folded_lines.push(line);
    }

    // Add I/O operations if present
    for op in &dtrace.io_operations {
        let path_part = op.path.as_ref().map(|p| {
            // Truncate long paths
            if p.len() > 30 {
                format!("...{}", &p[p.len()-27..])
            } else {
                p.clone()
            }
        }).unwrap_or_else(|| format!("fd:{}", op.fd));
        folded_lines.push(format!("claude-process;io;{};{} 1", op.syscall, path_part));
    }

    let folded_content = folded_lines.join("\n");

    // Determine output path
    let svg_path = if output_path.ends_with(".svg") {
        output_path.to_string()
    } else {
        format!("{}.svg", output_path)
    };

    // Also write the folded format for external tool compatibility
    let folded_path = svg_path.replace(".svg", ".folded");
    let mut folded_file = fs::File::create(&folded_path)?;
    folded_file.write_all(folded_content.as_bytes())?;

    // Generate SVG using inferno
    let mut options = FlamegraphOptions::default();
    options.title = format!("Claude Process Syscalls - PID {} ({}s)", dtrace.pid, dtrace.duration_secs);
    options.subtitle = Some(format!("Method: {}", dtrace.method));
    options.count_name = "calls".to_string();
    options.colors = flamegraph::color::Palette::Basic(flamegraph::color::BasicPalette::Mem);

    let folded_reader = BufReader::new(folded_content.as_bytes());
    let mut svg_file = fs::File::create(&svg_path)?;

    flamegraph::from_reader(&mut options, folded_reader, &mut svg_file)?;

    Ok(svg_path)
}

/// Categorize syscalls for flamegraph grouping
fn categorize_syscall(name: &str) -> &'static str {
    match name {
        // File operations
        "open" | "openat" | "close" | "read" | "write" | "pread" | "pwrite" |
        "stat" | "fstat" | "lstat" | "access" | "unlink" | "rename" | "mkdir" |
        "rmdir" | "readdir" | "getdirentries" | "fsync" | "ftruncate" => "file",

        // Network operations
        "socket" | "connect" | "bind" | "listen" | "accept" | "send" | "recv" |
        "sendto" | "recvfrom" | "sendmsg" | "recvmsg" | "shutdown" | "getsockopt" |
        "setsockopt" | "getpeername" | "getsockname" => "network",

        // Memory operations
        "mmap" | "munmap" | "mprotect" | "madvise" | "brk" | "sbrk" => "memory",

        // Process/thread operations
        "fork" | "vfork" | "clone" | "execve" | "exit" | "wait4" | "waitpid" |
        "kill" | "sigaction" | "sigprocmask" | "pthread_create" => "process",

        // Event/polling operations
        "poll" | "select" | "kevent" | "kevent64" | "epoll_wait" | "kqueue" => "event",

        // Time operations
        "gettimeofday" | "clock_gettime" | "nanosleep" => "time",

        // IPC operations
        "pipe" | "dup" | "dup2" | "fcntl" | "ioctl" => "ipc",

        _ => "other",
    }
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

        // DTrace analysis
        if let Some(ref dtrace) = proc.dtrace {
            println!();
            let method_str = format!("DTrace ({}, {}s)", dtrace.method, dtrace.duration_secs);
            if dtrace.success {
                println!("    {}:", method_str.cyan());
            } else {
                println!("    {} {}", method_str.red(), "(failed)".red());
                if let Some(ref err) = dtrace.error {
                    println!("      Error: {}", err.dimmed());
                }
            }

            if let Some(ref reason) = dtrace.fallback_reason {
                println!("      {}: {}", "Fallback reason".yellow(), reason);
            }

            // Top syscalls
            if !dtrace.top_syscalls.is_empty() {
                println!();
                println!("      {}:", "Top Syscalls".cyan());
                println!("      {:20} {:>8} {:>12} {:>10}", "SYSCALL", "COUNT", "TOTAL (ms)", "AVG (us)");
                for syscall in dtrace.top_syscalls.iter().take(10) {
                    let count_colored = if syscall.count > 1000 {
                        format!("{}", syscall.count).yellow()
                    } else {
                        format!("{}", syscall.count).normal()
                    };
                    println!("      {:20} {:>8} {:>12.2} {:>10.1}",
                        syscall.name,
                        count_colored,
                        syscall.total_time_us as f64 / 1000.0,
                        syscall.avg_time_us
                    );
                }
            }

            // I/O operations summary
            if !dtrace.io_operations.is_empty() {
                println!();
                println!("      {}: {} operations", "I/O Activity".cyan(), dtrace.io_operations.len());

                // Aggregate by syscall type
                let mut io_by_type: HashMap<&str, (u32, u64)> = HashMap::new();
                for op in &dtrace.io_operations {
                    let entry = io_by_type.entry(&op.syscall).or_insert((0, 0));
                    entry.0 += 1;
                    entry.1 += op.bytes;
                }
                for (syscall, (count, bytes)) in io_by_type.iter() {
                    println!("        {}: {} calls, {} bytes", syscall, count, bytes);
                }
            }

            // Network operations summary
            if !dtrace.network_operations.is_empty() {
                println!();
                println!("      {}: {} operations", "Network Activity".cyan(), dtrace.network_operations.len());

                let mut net_by_type: HashMap<&str, u32> = HashMap::new();
                for op in &dtrace.network_operations {
                    *net_by_type.entry(&op.syscall).or_insert(0) += 1;
                }
                for (syscall, count) in net_by_type.iter() {
                    println!("        {}: {} calls", syscall, count);
                }
            }

            // DTrace-specific issues
            if !dtrace.issues.is_empty() {
                println!();
                println!("      {}:", "Issues".cyan());
                for issue in &dtrace.issues {
                    let sev_colored = match issue.severity.as_str() {
                        "high" => format!("[{}]", issue.severity.to_uppercase()).red(),
                        "medium" => format!("[{}]", issue.severity.to_uppercase()).yellow(),
                        _ => format!("[{}]", issue.severity.to_uppercase()).normal(),
                    };
                    println!("        {} {}", sev_colored, issue.issue);
                    println!("          {}", issue.description.dimmed());
                    println!("          Remedy: {}", issue.remedy);
                }
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
        println!("  3. {}: Trace syscalls for deeper analysis", "DTrace".cyan());
        println!("     $ sudo claude-diagnose --dtrace --pid <pid> --duration 10");
        println!("     $ sudo claude-diagnose -D --io --pid <pid>  # I/O focused");
        println!();
        println!("  4. {}: Watch for recurrence", "Monitor".cyan());
        println!("     $ claude-trace -w 5 -k 50");
    } else {
        println!("  {} No immediate action required", "✓".green());
    }

    // Check if any DTrace issues were found
    let has_dtrace_issues = report.processes.iter()
        .any(|p| p.dtrace.as_ref().map(|d| !d.issues.is_empty()).unwrap_or(false));

    if has_dtrace_issues {
        println!();
        println!("  {}: DTrace analysis revealed issues - see process details above", "Note".yellow());
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
