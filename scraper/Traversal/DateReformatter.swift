import Foundation

enum DateReformatter {
    static let outputFormatter: DateFormatter = {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return outputFormatter
    }()

    static let inputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    static let whatsappFullInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMMd h:mm a"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let whatsappPartialInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let dayMap: [String: Int] = {
        let calendar = Calendar.current
        let shortWeekdaySymbols = calendar.shortWeekdaySymbols
        let fullWeekdaySymbols = calendar.weekdaySymbols
        let startOfWeekdayIndex = calendar.firstWeekday - 1 // Calendar's firstWeekday is 1-indexed

        // Generate dayMap dynamically
        var dayMap: [String: Int] = [:]
        for (index, (shortSymbol, fullSymbol)) in zip(shortWeekdaySymbols, fullWeekdaySymbols).enumerated() {
            let adjustedIndex = (index - startOfWeekdayIndex + 7) % 7 // Adjust for the first weekday
            dayMap[shortSymbol.uppercased()] = adjustedIndex
            dayMap[fullSymbol.uppercased()] = adjustedIndex
        }
        return dayMap
    }()

    static let monthMap: [String: Int] = {
        let calendar = Calendar.current
        let monthSymbols = calendar.shortMonthSymbols

        // Generate monthMap dynamically
        var monthMap: [String: Int] = [:]
        for (index, symbol) in monthSymbols.enumerated() {
            monthMap[symbol.uppercased()] = index + 1
        }
        return monthMap
    }()

    static func reformatMessages(dateString: String) -> Date? {
        let inputString = dateString
        let dateFormatter = inputFormatter
        let calendar = Calendar.current

        // Try parsing with full date
        dateFormatter.dateFormat = "MMM d, yyyy 'at' h:mm a"
        if let date = dateFormatter.date(from: inputString) {
            return date
        }

        // Try parsing without year (current year)
        dateFormatter.dateFormat = "EEE, MMM d 'at' h:mm a"
        if let date = dateFormatter.date(from: inputString) {
            let currentYear = calendar.component(.year, from: Date())
            var dateComponents = calendar.dateComponents([.month, .day, .hour, .minute], from: date)
            dateComponents.year = currentYear
            if let final = calendar.date(from: dateComponents) {
                return final
            }
        }
        // Try weekday format
        if dayMap.keys.contains(where: { inputString.uppercased().contains($0) }),
           let weekday = parseDayTime(inputString) {
            return weekday
        }

        // If no parsing succeeds, return nil.
        return nil
    }

    private static func formatOutputDate(_ date: Date) -> String {
        return outputFormatter.string(from: date)
    }

    private static func findMostRecentDay(for timeDate: Date) -> String {
        let calendar = Calendar.current
        let today = Date()

        // Extract time components from the input date
        let timeDateComponents = calendar.dateComponents([.hour, .minute], from: timeDate)

        // Find the most recent date matching the day of week
        for daysBack in 0..<7 {
            if let potentialDate = calendar.date(byAdding: .day, value: -daysBack, to: today),
               calendar.component(.weekday, from: potentialDate) == calendar.component(.weekday, from: timeDate) {
                // Combine the potential date with the extracted time
                var combinedDateComponents = calendar.dateComponents([.year, .month, .day], from: potentialDate)
                combinedDateComponents.hour = timeDateComponents.hour
                combinedDateComponents.minute = timeDateComponents.minute

                if let finalDate = calendar.date(from: combinedDateComponents) {
                    return formatOutputDate(finalDate)
                }
            }
        }

        // Fallback to today with the given time
        var todayComponents = calendar.dateComponents([.year, .month, .day], from: today)
        todayComponents.hour = timeDateComponents.hour
        todayComponents.minute = timeDateComponents.minute

        if let finalDate = calendar.date(from: todayComponents) {
            return formatOutputDate(finalDate)
        }

        // Absolute fallback
        return formatOutputDate(today)
    }

    static func parseDiscordDateString(_ dateString: String) -> Date? {
        let dateFormatter = inputFormatter

        let now = Date()
        let calendar = Calendar.current

        if dateString.contains("Today") {
            // Handle "Today at ..."
            let todayString = dateString.replacingOccurrences(of: "Today at ", with: "")
            dateFormatter.dateFormat = "h:mm a"
            if let time = dateFormatter.date(from: todayString) {
                return calendar.date(
                    bySettingHour: calendar.component(.hour, from: time),
                    minute: calendar.component(.minute, from: time),
                    second: 0,
                    of: now
                )
            }
        } else if dateString.contains("Yesterday") {
            // Handle "Yesterday at ..."
            let yesterdayString = dateString.replacingOccurrences(of: "Yesterday at ", with: "")
            dateFormatter.dateFormat = "h:mm a"
            if let time = dateFormatter.date(from: yesterdayString) {
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: now) {
                    return calendar.date(
                        bySettingHour: calendar.component(.hour, from: time),
                        minute: calendar.component(.minute, from: time),
                        second: 0,
                        of: yesterday
                    )
                }
            }
        } else if dateString.contains(" at ") {
            // Handle "November 17, 2024 at 4:55 PM"
            dateFormatter.dateFormat = "MMMM d, yyyy 'at' h:mm a"
            return dateFormatter.date(from: dateString)
        } else {
            // Handle full date strings like "2024-11-30, 1:32 PM"
            dateFormatter.dateFormat = "yyyy-MM-dd, h:mm a"
            return dateFormatter.date(from: dateString)
        }

        return nil
    }

    static func parseMessengerDateTime(_ value: String) -> Date? {
        // First try full date format
        if value.contains("/") {
            return parseFullDate(value)
        }

        // Try month day time format
        if monthMap.keys.contains(where: { value.uppercased().contains($0) }) {
            return parseMonthDayTime(value)
        }

        // Try day time format
        if dayMap.keys.contains(where: { value.uppercased().contains($0) }) {
            return parseDayTime(value)
        }

        // Try just time
        return parseTime(value)
    }

    private static func parseTime(_ timeStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let now = Date()
        if var date = formatter.date(from: timeStr) {
            // Set today's date components
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: now)
            date = calendar.date(
                bySettingHour: calendar.component(.hour, from: date),
                minute: calendar.component(.minute, from: date),
                second: 0,
                of: calendar.date(from: components) ?? now
            ) ?? now
            return date
        }
        return nil
    }

    private static func parseDayTime(_ dayTimeStr: String) -> Date? {
        let calendar = Calendar.current

        let components = dayTimeStr.split(separator: " ", maxSplits: 1)
        guard components.count == 2,
              let dayStr = components.first?.uppercased(),
              let targetDay = dayMap[dayStr] else {
            return nil
        }

        let timeStr = String(components[1])
        guard let timeDate = parseTime(timeStr) else {
            return nil
        }

        let currentDate = Date()
        let currentDay = calendar.component(.weekday, from: currentDate) - 1 // Convert to 0-based

        // Calculate days to go back
        var daysBack = (currentDay - targetDay + 7) % 7
        if daysBack == 0, timeDate > currentDate {
            daysBack = 7
        }

        return calendar.date(byAdding: .day, value: -daysBack, to: timeDate)
    }

    private static func parseMonthDayTime(_ dateStr: String) -> Date? {
        let calendar = Calendar.current

        // Parse "NOV 07, 4:27 AM" format
        let pattern = #"^([A-Z]{3})\s+(\d{2}),\s+(\d{1,2}):(\d{2})\s+([AP]M)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: dateStr.uppercased(),
                  range: NSRange(dateStr.startIndex..., in: dateStr)
              ) else {
            return nil
        }

        let ranges = (0..<match.numberOfRanges).map { match.range(at: $0) }
        guard ranges.count == 6,
              let monthRange = Range(ranges[1], in: dateStr),
              let dayRange = Range(ranges[2], in: dateStr),
              let hourRange = Range(ranges[3], in: dateStr),
              let minuteRange = Range(ranges[4], in: dateStr),
              let ampmRange = Range(ranges[5], in: dateStr) else {
            return nil
        }

        let monthStr = String(dateStr[monthRange]).uppercased()
        guard let month = monthMap[monthStr],
              let day = Int(String(dateStr[dayRange])),
              let hour = Int(String(dateStr[hourRange])),
              let minute = Int(String(dateStr[minuteRange])) else {
            return nil
        }

        let ampm = String(dateStr[ampmRange])
        var adjustedHour = hour
        if ampm == "PM", hour != 12 {
            adjustedHour += 12
        } else if ampm == "AM", hour == 12 {
            adjustedHour = 0
        }

        var components = DateComponents()
        components.month = month
        components.day = day
        components.hour = adjustedHour
        components.minute = minute

        // Determine year
        components.year = calendar.component(.year, from: Date())
        if let date = calendar.date(from: components),
           date > Date() {
            components.year = components.year! - 1
        }

        return calendar.date(from: components)
    }

    private static func parseFullDate(_ dateStr: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy, h:mm a"
        return formatter.date(from: dateStr)
    }

    // Slack
    static func convertSlackTimestamp(_ timestamp: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        // Create time formatter for parsing the time portion
        let minutesFormatter = DateFormatter()
        minutesFormatter.dateFormat = "h:mm a"
        let secondsFormatter = DateFormatter()
        secondsFormatter.dateFormat = "h:mm:ss a"

        // Extract and parse the time portion (e.g., "3:27:40 PM")
        let timestampParts = timestamp.components(separatedBy: " at ")
        guard timestampParts.count == 2,
              let timeString = timestampParts.last?.trimmingCharacters(in: .whitespaces) else {
            return nil // if it's a non-date, return nil
        }

        // Parse the relative date part
        let relativePart = timestampParts[0].lowercased().replacingOccurrences(
            of: "(\\d+)(st|nd|rd|th)",
            with: "$1",
            options: .regularExpression
        )

        var dateToUse: Date

        switch relativePart {
        case "today":
            dateToUse = now
        case "yesterday":
            dateToUse = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        default:
            // e.g. "Nov 21st"
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "MMM d"
            if let parsedDate = dayFormatter.date(from: relativePart) {
                dateToUse = parsedDate
            } else {
                return nil
            }
            var refMonthDay = calendar.dateComponents([.year, .month, .day], from: dateToUse)
            let nowYearMonthDay = calendar.dateComponents([.year, .month, .day], from: now)
            refMonthDay.year = nowYearMonthDay.year // for checking if it's last year
            if let nowYear = nowYearMonthDay.year,
               let refDate = calendar.date(from: refMonthDay),
               let nowDate = calendar.date(from: nowYearMonthDay) {
                // if ref > now, that means it was last year. adjust by one year
                let yearAdjustment = refDate > nowDate ? 1 : 0
                var newComponents = calendar.dateComponents([.month, .day], from: dateToUse)
                newComponents.year = nowYear - yearAdjustment
                if let newDate = calendar.date(from: newComponents) {
                    dateToUse = newDate
                }
            }
        }
        // Parse the time string
        guard let parsedTime = minutesFormatter.date(from: timeString) ??
            secondsFormatter.date(from: timeString) else {
            return nil
        }

        // Combine the date and time
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: dateToUse)
        let parsedTimeComponents = calendar.dateComponents([.hour, .minute, .second], from: parsedTime)

        dateComponents.hour = parsedTimeComponents.hour
        dateComponents.minute = parsedTimeComponents.minute
        dateComponents.second = parsedTimeComponents.second
        return calendar.date(from: dateComponents)
    }

    static func formatWhatsAppTime(_ dateString: String) -> Date? {
        let dateFormatter = whatsappFullInputFormatter
        if let parsedDate = dateFormatter.date(from: dateString) {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            var dateComponents = calendar.dateComponents([.month, .day, .hour, .minute], from: parsedDate)
            dateComponents.year = currentYear
            return calendar.date(from: dateComponents)
        }
        let partialFormatter = whatsappPartialInputFormatter
        if let parsedDate = partialFormatter.date(from: dateString) {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let currentMonth = calendar.component(.month, from: Date())
            let currentDay = calendar.component(.day, from: Date())
            var dateComponents = calendar.dateComponents([.hour, .minute], from: parsedDate)
            dateComponents.year = currentYear
            dateComponents.month = currentMonth
            dateComponents.day = currentDay
            return calendar.date(from: dateComponents)
        }
        return nil
    }
}
