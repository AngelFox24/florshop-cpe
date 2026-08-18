//
//  TemporaryDirectory.swift
//  FlorShopCPE
//
//  Created by Angel Curi Laurente on 17/08/2026.
//

import Foundation
import FlorShopCPE

enum ExampleDateError: Error {
    case invalidLimaTimeZone
    case incompleteDate
    case unableToCalculateDate
}

struct LimaExampleDateTime {
    let instant: Date
    let issueDate: IssueDate
    let issueTime: IssueTime
}

func currentLimaExampleDateTime() throws -> LimaExampleDateTime {
    let instant = Date()
    let calendar = try limaExampleCalendar()
    let components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: instant
    )
    guard let year = components.year,
          let month = components.month,
          let day = components.day,
          let hour = components.hour,
          let minute = components.minute,
          let second = components.second else {
        throw ExampleDateError.incompleteDate
    }
    return LimaExampleDateTime(
        instant: instant,
        issueDate: IssueDate(year: year, month: month, day: day),
        issueTime: IssueTime(hour: hour, minute: minute, second: second)
    )
}

func limaExampleIssueDate(addingDays days: Int, to instant: Date) throws -> IssueDate {
    let calendar = try limaExampleCalendar()
    guard let calculatedDate = calendar.date(byAdding: .day, value: days, to: instant) else {
        throw ExampleDateError.unableToCalculateDate
    }
    let components = calendar.dateComponents([.year, .month, .day], from: calculatedDate)
    guard let year = components.year,
          let month = components.month,
          let day = components.day else {
        throw ExampleDateError.incompleteDate
    }
    return IssueDate(year: year, month: month, day: day)
}

private func limaExampleCalendar() throws -> Calendar {
    guard let timeZone = TimeZone(identifier: "America/Lima") else {
        throw ExampleDateError.invalidLimaTimeZone
    }
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar
}

func withTemporaryDirectory(
    prefix: String,
    operation: (URL) async throws -> Void
) async throws {
    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory
        .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: directory) }
    try await operation(directory)
}
