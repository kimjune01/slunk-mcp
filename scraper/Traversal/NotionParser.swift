import ApplicationServices
import Foundation
import LBAccessibility
import LBDataModels
import LBMetrics

actor NotionParser: CustomParser {
    public let parsedApp: ParseableApp = .notion

    public init() {}

    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult {
        let element = params.accessWindow

        var document = Document(
            app: parsedApp.title,
            timestamp: nil,
            title: "",
            content: ""
        )

        for try await element in ElementDepthFirstSequence(element: element).map(\.element) {
            if deadline.hasPassed { break }

            let role = try await element.getAttributeValue(.role) as? Role
            switch role {
            case .textArea
                where try await element.getAttributeValue(.description) as? String == "Start typing to edit text":
                try await document = getDocument(element: element, deadline: deadline)
                continue
            case .window where try await element.getLabel() == "message content":
                continue
            default:
                break
            }
        }
        return ParseResult(document: document)
    }

    func getDocument(element: ElementProtocol, deadline: Deadline) async throws -> Document {
        var gotTitle = false
        var title = ""
        var content = ""
        for try await elem in ElementDepthFirstSequence(element: element).map(\.element) {
            if deadline.hasPassed { break }
            guard let role = try await elem.getAttributeValue(.role) as? Role else { break }
            switch role {
            case .staticText:
                if !gotTitle {
                    // Assume that the first line of text is the title
                    if let text = try await elem.getValue() {
                        title = text
                        gotTitle = true
                        continue
                    }
                } else {
                    if let text = try await elem.getValue(), !text.isEmpty {
                        content += text.components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }
                            .joined(separator: " ") + "\n"
                        continue
                    }
                }
            default:
                break
            }
        }

        return Document(
            app: parsedApp.title,
            timestamp: nil,
            title: title,
            content: content
        )
    }
}
