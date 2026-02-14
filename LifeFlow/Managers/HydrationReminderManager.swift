//
//  HydrationReminderManager.swift
//  LifeFlow
//
//  Smart hydration scheduling: Calculates drinks-per-waking-hour
//  and schedules repeating UNUserNotificationCenter notifications
//  with an inline "Log Water" action button.
//

import Foundation
import UserNotifications
import AppIntents
import WidgetKit

// MARK: - HydrationReminderManager

/// Manages smart hydration notifications based on the user's daily goal,
/// wake time, and sleep time. Notifications include an inline action
/// button that triggers `LogWaterIntent` to log water without opening the app.
///
/// This manager is intentionally **not** an `@Observable` class because it
/// has no UI-bound state. It's a stateless utility that configures the
/// notification system and writes to `@AppStorage` for mute preferences.
struct HydrationReminderManager {

    // MARK: - Notification Constants

    /// Category identifier for hydration reminder notifications.
    static let hydrationCategoryID = "HYDRATION_REMINDER"

    /// Action identifier for the "Log 8 oz" button in the notification.
    static let logWaterActionID = "LOG_WATER_ACTION"

    // MARK: - Schedule Smart Reminders

    /// Calculates the optimal hydration interval and schedules repeating
    /// notifications between wake and sleep times.
    ///
    /// Formula: (dailyGoalOz / servingSizeOz) ÷ wakingHours = drinks per hour.
    /// One notification fires per drink cadence. All times are in user's local time zone.
    ///
    /// - Parameters:
    ///   - dailyGoalOz: The user's daily water intake target in ounces (e.g., 96).
    ///   - servingSizeOz: Size of each drink in ounces (default: 8 oz cup).
    ///   - wakeHour: Hour the user wakes up (0–23). Default: 7 AM.
    ///   - sleepHour: Hour the user goes to sleep (0–23). Default: 11 PM.
    ///   - isMuted: If true, all pending hydration notifications are removed and nothing is scheduled.
    static func scheduleSmartReminders(
        dailyGoalOz: Double,
        servingSizeOz: Double = 8.0,
        wakeHour: Int = 7,
        sleepHour: Int = 23,
        isMuted: Bool = false
    ) async {
        let center = UNUserNotificationCenter.current()

        // MARK: Clear existing hydration reminders
        // Remove all pending hydration-category notifications before rescheduling.
        // This prevents stacking when the user adjusts their goal or times.
        center.removePendingNotificationRequests(withIdentifiers:
            (0..<24).map { "hydration_reminder_\($0)" }
        )

        guard !isMuted else { return }

        // MARK: Request authorization
        let granted: Bool
        do {
            granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return
        }
        guard granted else { return }

        // MARK: Register notification category with inline action
        let logAction = UNNotificationAction(
            identifier: logWaterActionID,
            title: "Add 8 oz 💧",
            options: .foreground // Open the app briefly to execute the intent
        )

        let category = UNNotificationCategory(
            identifier: hydrationCategoryID,
            actions: [logAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Hydration Reminder"
        )

        center.setNotificationCategories([category])

        // MARK: Calculate cadence
        let wakingHours = sleepHour > wakeHour ? sleepHour - wakeHour : (24 - wakeHour + sleepHour)
        guard wakingHours > 0, dailyGoalOz > 0, servingSizeOz > 0 else { return }

        let drinksNeeded = dailyGoalOz / servingSizeOz
        let drinksPerHour = drinksNeeded / Double(wakingHours)
        // Interval between notifications (in minutes), minimum 30 minutes
        let intervalMinutes = max(30, Int(60.0 / drinksPerHour))

        // MARK: Schedule notifications
        var currentMinuteOfDay = wakeHour * 60
        let endMinuteOfDay = sleepHour * 60
        var notificationIndex = 0

        while currentMinuteOfDay < endMinuteOfDay {
            let hour = currentMinuteOfDay / 60
            let minute = currentMinuteOfDay % 60

            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let content = UNMutableNotificationContent()
            content.title = "Stay Hydrated 💧"
            content.body = drinkMessage(hour: hour)
            content.categoryIdentifier = hydrationCategoryID
            content.sound = .default
            content.interruptionLevel = .passive // Respect Focus filters

            let request = UNNotificationRequest(
                identifier: "hydration_reminder_\(notificationIndex)",
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                // Non-fatal — one notification failing shouldn't stop the rest.
            }

            currentMinuteOfDay += intervalMinutes
            notificationIndex += 1
        }
    }

    // MARK: - Cancel All Reminders

    /// Removes all scheduled hydration reminders.
    static func cancelAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers:
            (0..<24).map { "hydration_reminder_\($0)" }
        )
    }

    // MARK: - Contextual Messages

    /// Returns a time-appropriate hydration message.
    private static func drinkMessage(hour: Int) -> String {
        switch hour {
        case 6..<9:
            return "Morning hydration sets the tone. Drink a glass of water."
        case 9..<12:
            return "Stay sharp this morning — time for a quick drink."
        case 12..<14:
            return "Lunchtime hydration check. Have you had water with your meal?"
        case 14..<17:
            return "Afternoon energy dip? A glass of water helps more than caffeine."
        case 17..<20:
            return "Evening reminder: keep sipping before dinner."
        case 20..<23:
            return "Wind down with one more glass before bed."
        default:
            return "Time to drink some water!"
        }
    }
}
