import Foundation
import UserNotifications

// MARK: - Notification Types

enum NotificationType: Hashable {
    case highAggregateCPU
    case highAggregateMemory
    case highProcessCPU(pid: Int)
    case highProcessMemory(pid: Int)
    case orphanedProcess(pid: Int)
    case outdatedProcess(pid: Int)

    var identifier: String {
        switch self {
        case .highAggregateCPU:
            return "aggregate_cpu"
        case .highAggregateMemory:
            return "aggregate_memory"
        case .highProcessCPU(let pid):
            return "process_cpu_\(pid)"
        case .highProcessMemory(let pid):
            return "process_memory_\(pid)"
        case .orphanedProcess(let pid):
            return "orphaned_\(pid)"
        case .outdatedProcess(let pid):
            return "outdated_\(pid)"
        }
    }

    var categoryIdentifier: String {
        switch self {
        case .highAggregateCPU, .highProcessCPU:
            return "CPU_ALERT"
        case .highAggregateMemory, .highProcessMemory:
            return "MEMORY_ALERT"
        case .orphanedProcess:
            return "ORPHAN_ALERT"
        case .outdatedProcess:
            return "OUTDATED_ALERT"
        }
    }
}

// MARK: - Notification Service

final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private var lastNotificationTime: [String: Date] = [:]

    /// Minimum time between notifications of the same type (seconds)
    var throttleInterval: TimeInterval = 60.0

    /// Whether notifications are enabled
    var notificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "notificationsEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "notificationsEnabled") }
    }

    private override init() {
        super.init()
        center.delegate = self
        setupCategories()
    }

    // MARK: - Setup

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                notificationsEnabled = true
            }
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    private func setupCategories() {
        // View Details action
        let viewAction = UNNotificationAction(
            identifier: "VIEW_DETAILS",
            title: "View Details",
            options: [.foreground]
        )

        // Dismiss action
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS",
            title: "Dismiss",
            options: []
        )

        // CPU Alert category
        let cpuCategory = UNNotificationCategory(
            identifier: "CPU_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Memory Alert category
        let memoryCategory = UNNotificationCategory(
            identifier: "MEMORY_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Orphan Alert category
        let orphanCategory = UNNotificationCategory(
            identifier: "ORPHAN_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        // Outdated Alert category
        let outdatedCategory = UNNotificationCategory(
            identifier: "OUTDATED_ALERT",
            actions: [viewAction, dismissAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        center.setNotificationCategories([cpuCategory, memoryCategory, orphanCategory, outdatedCategory])
    }

    // MARK: - Sending Notifications

    func sendNotification(
        type: NotificationType,
        title: String,
        body: String,
        threshold: String? = nil,
        actual: String? = nil,
        processName: String? = nil
    ) {
        guard notificationsEnabled else { return }
        guard !isThrottled(type: type) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Claude Trace"
        content.subtitle = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = type.categoryIdentifier
        content.interruptionLevel = .timeSensitive

        // Add alert info to userInfo for click handling
        var userInfo: [String: Any] = [
            "notificationType": type.identifier,
            "alertTitle": title,
            "alertBody": body
        ]

        // Include threshold and actual values
        if let threshold = threshold {
            userInfo["threshold"] = threshold
        }
        if let actual = actual {
            userInfo["actual"] = actual
        }
        if let processName = processName {
            userInfo["processName"] = processName
        }

        // Include PID for per-process notifications
        switch type {
        case .highProcessCPU(let pid), .highProcessMemory(let pid):
            userInfo["pid"] = pid
            userInfo["alertType"] = type.categoryIdentifier == "CPU_ALERT" ? "processCPU" : "processMemory"
        case .highAggregateCPU:
            userInfo["alertType"] = "aggregateCPU"
        case .highAggregateMemory:
            userInfo["alertType"] = "aggregateMemory"
        case .orphanedProcess(let pid):
            userInfo["pid"] = pid
            userInfo["alertType"] = "orphaned"
        case .outdatedProcess(let pid):
            userInfo["pid"] = pid
            userInfo["alertType"] = "outdated"
        }
        content.userInfo = userInfo

        let request = UNNotificationRequest(
            identifier: type.identifier + "_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }

        // Update throttle time
        lastNotificationTime[type.identifier] = Date()
    }

    private func isThrottled(type: NotificationType) -> Bool {
        guard let lastTime = lastNotificationTime[type.identifier] else {
            return false
        }
        return Date().timeIntervalSince(lastTime) < throttleInterval
    }

    // MARK: - Permission Status

    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case "VIEW_DETAILS", UNNotificationDefaultActionIdentifier:
            // User clicked the notification or View Details
            // Pass all userInfo from the notification to the popover handler
            let userInfo = response.notification.request.content.userInfo
            // Convert [AnyHashable: Any] to [String: Any] for NotificationCenter
            var info: [String: Any] = [:]
            for (key, value) in userInfo {
                if let stringKey = key as? String {
                    info[stringKey] = value
                }
            }
            NotificationCenter.default.post(
                name: .openMenuBarPopover,
                object: nil,
                userInfo: info.isEmpty ? nil : info
            )

        case "DISMISS", UNNotificationDismissActionIdentifier:
            // User dismissed the notification
            break

        default:
            break
        }

        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openMenuBarPopover = Notification.Name("openMenuBarPopover")
}
