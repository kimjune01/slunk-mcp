import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor ChromeParser: CustomParser {
    public let parsedApp: ParseableApp = .googlechrome

    public init() {}

    public func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        let browserFrame = try await processChromeWindow(params.accessWindow, deadline: deadline)
        return ParseResult(browser: browserFrame)
    }

    public func processChromeWindow(_ element: ElementProtocol, deadline: Deadline) async throws -> BrowserFrame? {
        if let webArea = try await element.findElement(
            matching: Matchers.hasAttribute(.role, equalTo: Role.webArea),
            excludeMatchers: [Matchers.hasClass("TopContainerView")]
        ) {
            let browserUrlValue = try await webArea.getAttributeValue(.url)
            let browserUrl = (browserUrlValue as? String) ?? String(describing: browserUrlValue ?? "")
            let browserTitle = try await webArea.getAttributeValue(.title) as? String ?? ""
            let text = try await webArea.elementDescription(deadline: deadline)

            if text.isEmpty {
                return nil
            }

            return BrowserFrame(
                app: "Google Chrome",
                url: browserUrl,
                title: browserTitle,
                text: text
            )
        } else {
            return nil
        }
    }
}
