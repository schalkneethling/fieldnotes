import SwiftUI

extension Date {
    var fieldTimestamp: String {
        formatted(date: .abbreviated, time: .shortened)
    }
}
