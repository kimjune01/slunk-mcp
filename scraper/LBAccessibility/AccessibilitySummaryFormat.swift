import Foundation

/// Provides a method to generate a textual summary of the accessibility hierarchy for use in LLM-based parser
/// generation.
/// The goal is to preserve essential structural information and key attributes in a readable format.
public extension Element {
    /**
     Generates a hierarchical text summary of accessibility elements.

     Example output:
     ```
     - application (title: "Fantastical")
       - standard window (title: "Fantastical", id: "calendar")
         - split group (id: "_NS:21")
           - group (description: "sidebar")
             - button (description: "add new event or task", id: "add new event or task")
             - group (id: "_NS:8")
               - group (description: "April 2025")
                 - button (description: "Monday, 31 March 2025, 3 events")
                 - button (description: "Tuesday, 1 April 2025, 5 events")
                 - button (description: "Wednesday, 2 April 2025, 3 events")
                 - button (description: "Thursday, 3 April 2025, 3 events")
                 - button (description: "Friday, 4 April 2025, 4 events")
                 - ... (and 37 more elements)
     ```

     This format reduces the data size from megabytes to a few kilobytes while maintaining
     the critical hierarchy and attributes needed for parser logic.
     */
    func dumpTextSummary(appName: String? = nil, maxChildrenDisplay: Int = 31) -> String {
        let fullDump = self.dumpJSON()
        return formatDumpAsText(fullDump, appName: appName, maxDisplay: maxChildrenDisplay)
    }

    private func formatDumpAsText(
        _ dump: DumpResult,
        appName: String?,
        basePath: String = "",
        index: Int = 0,
        maxDisplay: Int = 5
    ) -> String {
        let role = dump.attributes[Attribute.role.rawValue]?.value as? String ?? "Unknown"
        let roleDescription = dump.attributes[Attribute.roleDescription.rawValue]?.value as? String
        let subrole = dump.attributes[Attribute.subrole.rawValue]?.value as? String
        let identifier = dump.attributes[Attribute.identifier.rawValue]?.value as? String
        let title = dump.attributes[Attribute.title.rawValue]?.value as? String
        let value = dump.attributes[Attribute.value.rawValue]?.value as? String
        let description = dump.attributes[Attribute.description.rawValue]?.value as? String

        // Use role or roleDescription as the node label for clarity
        let nodeLabel = roleDescription ?? subrole ?? role
        var attributes: [String] = []
        if let title, !title.isEmpty {
            attributes.append("title: \"\(title)\"")
        }
        if let value, !value.isEmpty {
            attributes.append("value: \"\(value)\"")
        }
        if let description, !description.isEmpty {
            attributes.append("description: \"\(description)\"")
        }
        if let identifier, !identifier.isEmpty {
            attributes.append("id: \"\(identifier)\"")
        }

        let descriptionText =
            "- \(nodeLabel)\(attributes.isEmpty ? "" : " (" + attributes.joined(separator: ", ") + ")")"

        var result = [descriptionText]
        if let childElements = dump.attributes[Attribute.childElements.rawValue]?.value as? [DumpResult] {
            // Truncate long lists of similar elements for brevity, using configurable limit
            var displayedCount = 0
            for (childIndex, child) in childElements.enumerated() {
                if displayedCount < maxDisplay {
                    let childText = formatDumpAsText(
                        child,
                        appName: appName,
                        basePath: "",
                        index: childIndex,
                        maxDisplay: maxDisplay
                    )
                    result.append(contentsOf: childText.split(separator: "\n").map { "  \($0)" })
                    displayedCount += 1
                }
            }
            if childElements.count > maxDisplay {
                result.append("  - ... (and \(childElements.count - maxDisplay) more elements)")
            }
        }

        return result.joined(separator: "\n")
    }
}
