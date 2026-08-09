import Foundation
import XCTest
@testable import Fieldnotes

@MainActor
final class FieldnoteDomainTests: XCTestCase {
    func testEntryRangeUsesInclusiveBoundariesInTheProvidedTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let now = try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: 2026,
                    month: 3,
                    day: 15,
                    hour: 12
                )
            )
        )

        let startOfDay = calendar.startOfDay(for: now)
        let previousDay = try XCTUnwrap(calendar.date(byAdding: .second, value: -1, to: startOfDay))
        XCTAssertTrue(EntryRange.day.contains(startOfDay, now: now, calendar: calendar))
        XCTAssertFalse(EntryRange.day.contains(previousDay, now: now, calendar: calendar))

        let weekStart = try XCTUnwrap(calendar.date(byAdding: .day, value: -7, to: now))
        let beforeWeek = try XCTUnwrap(calendar.date(byAdding: .second, value: -1, to: weekStart))
        XCTAssertTrue(EntryRange.week.contains(weekStart, now: now, calendar: calendar))
        XCTAssertFalse(EntryRange.week.contains(beforeWeek, now: now, calendar: calendar))

        let monthStart = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: now))
        let beforeMonth = try XCTUnwrap(calendar.date(byAdding: .second, value: -1, to: monthStart))
        XCTAssertTrue(EntryRange.month.contains(monthStart, now: now, calendar: calendar))
        XCTAssertFalse(EntryRange.month.contains(beforeMonth, now: now, calendar: calendar))

        let future = try XCTUnwrap(calendar.date(byAdding: .second, value: 1, to: now))
        XCTAssertFalse(EntryRange.week.contains(future, now: now, calendar: calendar))
        XCTAssertFalse(EntryRange.month.contains(future, now: now, calendar: calendar))
    }

    func testReflectionCuesDescribeEmptyAndPopulatedRanges() throws {
        XCTAssertEqual(
            ReflectionCuePanel.makeCues(for: [], range: .week),
            ["No artifacts logged in the last 7 days yet."]
        )

        let calendar = Calendar.current
        let morning = try XCTUnwrap(
            calendar.date(
                bySettingHour: 8,
                minute: 0,
                second: 0,
                of: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )
        let entries = [
            Fieldnote(text: "Quiet garden light", emoji: "🌱", photoData: Data([1]), createdAt: morning),
            Fieldnote(text: "Quiet garden path", emoji: "🌱", createdAt: morning),
            Fieldnote(text: "Quiet cup", emoji: "✨", createdAt: morning)
        ]

        XCTAssertEqual(
            ReflectionCuePanel.makeCues(for: entries, range: .day),
            [
                "3 notes surfaced today.",
                "🌱 is your most frequent feeling.",
                "Most notes cluster in the morning.",
                "1 note includes a visual artifact."
            ]
        )
    }

    func testReflectionCuesSurfaceARecurringWordWhenSpacePermits() {
        let entries = [
            Fieldnote(text: "Garden shadows"),
            Fieldnote(text: "Garden birds")
        ]

        XCTAssertTrue(
            ReflectionCuePanel.makeCues(for: entries, range: .month)
                .contains("The word \"garden\" repeats across your notes.")
        )
    }

    func testDraftPolicyLimitsExtendedGraphemeClustersAndTrimsForPersistence() {
        let familyEmoji = "👨‍👩‍👧‍👦"
        let source = String(repeating: familyEmoji, count: 241)

        let limited = FieldnoteDraftPolicy.limitedText(source)

        XCTAssertEqual(limited.count, 240)
        XCTAssertEqual(limited.last.map(String.init), familyEmoji)
        XCTAssertEqual(
            FieldnoteDraftPolicy.textForPersistence("  A small moment.\n"),
            "A small moment."
        )
    }

    func testDraftSaveEligibilityRequiresTextAndSettledMedia() {
        var photoSelection = PhotoSelectionState()

        XCTAssertFalse(
            FieldnoteDraftPolicy.canSave(
                text: " \n ",
                hasLibraryPhotoSelection: false,
                photoSelection: photoSelection,
                isSaving: false
            )
        )
        XCTAssertTrue(
            FieldnoteDraftPolicy.canSave(
                text: "Ready",
                hasLibraryPhotoSelection: false,
                photoSelection: photoSelection,
                isSaving: false
            )
        )
        XCTAssertFalse(
            FieldnoteDraftPolicy.canSave(
                text: "Ready",
                hasLibraryPhotoSelection: false,
                photoSelection: photoSelection,
                isSaving: true
            )
        )

        let requestID = photoSelection.beginLibraryLoad()
        XCTAssertFalse(
            FieldnoteDraftPolicy.canSave(
                text: "Ready",
                hasLibraryPhotoSelection: true,
                photoSelection: photoSelection,
                isSaving: false
            )
        )
        XCTAssertFalse(
            FieldnoteDraftPolicy.canSave(
                text: "Ready",
                hasLibraryPhotoSelection: false,
                photoSelection: photoSelection,
                isSaving: false
            )
        )

        photoSelection.failLibraryLoad(requestID: requestID)
        XCTAssertFalse(
            FieldnoteDraftPolicy.canSave(
                text: "Ready",
                hasLibraryPhotoSelection: true,
                photoSelection: photoSelection,
                isSaving: false
            )
        )
        XCTAssertFalse(
            FieldnoteDraftPolicy.canSave(
                text: "Ready",
                hasLibraryPhotoSelection: false,
                photoSelection: photoSelection,
                isSaving: false
            )
        )
    }

    func testPhotoSelectionRemovalAndReplacementClearFailureAndIgnoreStaleLoads() {
        let staleData = Data("stale".utf8)
        let libraryReplacementData = Data("library replacement".utf8)
        let replacementData = Data("replacement".utf8)
        var photoSelection = PhotoSelectionState()
        let failedRequestID = photoSelection.beginLibraryLoad()
        photoSelection.failLibraryLoad(requestID: failedRequestID)

        photoSelection.clear()
        XCTAssertNil(photoSelection.data)
        XCTAssertNil(photoSelection.errorMessage)
        XCTAssertFalse(photoSelection.isLoading)

        let libraryReplacementID = photoSelection.beginLibraryLoad()
        photoSelection.finishLibraryLoad(
            with: libraryReplacementData,
            requestID: libraryReplacementID
        )
        XCTAssertEqual(photoSelection.data, libraryReplacementData)
        XCTAssertTrue(photoSelection.isReady)

        let staleRequestID = photoSelection.beginLibraryLoad()
        photoSelection.selectCameraPhoto(replacementData)
        photoSelection.finishLibraryLoad(with: staleData, requestID: staleRequestID)

        XCTAssertEqual(photoSelection.data, replacementData)
        XCTAssertTrue(photoSelection.isReady)
        XCTAssertNil(photoSelection.errorMessage)
    }
}
