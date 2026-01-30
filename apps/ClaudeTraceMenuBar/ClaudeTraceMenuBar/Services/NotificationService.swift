import Foundation
import UserNotifications

// MARK: - Notification Types

enum NotificationType: Hashable {
    case highAggregateCPU
    case highAggregateMemory
    case highProcessCPU(pid: Int)
    case highProcessMemory(pid: Int)

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
        }
    }

    var categoryIdentifier: String {
        switch self {
        case .highAggregateCPU, .highProcessCPU:
            return "CPU_ALERT"
        case .highAggregateMemory, .highProcessMemory:
            return "MEMORY_ALERT"
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

        center.setNotificationCategories([cpuCategory, memoryCategory])
    }

    // MARK: - Sending Notifications

    func sendNotification(type: NotificationType, title: String, body: String) {
        guard notificationsEnabled else { return }
        guard !isThrottled(type: type) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Claude Trace"
        content.subtitle = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = type.categoryIdentifier
        content.interruptionLevel = .timeSensitive

        // Add process info to userInfo for click handling
        var userInfo: [String: Any] = ["notificationType": type.identifier]

        // Include PID for per-process notifications
        switch type {
        case .highProcessCPU(let pid), .highProcessMemory(let pid):
            userInfo["pid"] = pid
        default:
            break
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
            // Extract PID if present and post notification to open menu bar popover
            let userInfo = response.notification.request.content.userInfo
            let pid = userInfo["pid"] as? Int
            NotificationCenter.default.post(
                name: .openMenuBarPopover,
                object: nil,
                userInfo: pid != nil ? ["pid": pid!] : nil
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
