import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor ObsidianParser: CustomParser {
    public let parsedApp: ParseableApp = .obsidian

    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        let element = params.accessWindow
        var title = ""
        var content = ""
        var gotTitle = false

        for try await element in ElementDepthFirstSequence(element: element).map(\.element) {
            if deadline.hasPassed { break }
            let role = try await element.getAttributeValue(.role) as? Role
            switch role {
            case .textArea where try await element.getAttributeValue(.value) as? String != "":
                // Assume first value as title
                if let value = try await element.getValue(), !gotTitle {
                    title = value
                    gotTitle = true
                }
                // assume last content as content
                content = try await getContent(element: element, deadline: deadline)
                continue
            default:
                break
            }
        }

        return ParseResult(document: Document(
            app: parsedApp.title,
            timestamp: nil,
            title: title,
            content: content
        ))
    }

    func getContent(element: ElementProtocol, deadline: Deadline) async throws -> String {
        var content = ""
        for try await elem in ElementDepthFirstSequence(element: element).map(\.element) {
            if deadline.hasPassed { break }

            guard let role = try await elem.getAttributeValue(.role) as? Role else { break }
            switch role {
            case .staticText:
                if let text = try await elem.getValue(), !text.isEmpty {
                    content += text.components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                        .joined(separator: " ") + "\n"
                    continue
                }
            default:
                break
            }
        }

        return content
    }
}
