import Foundation
import LBAccessibility
import LBDataModels

public enum ParseableApp: String, CaseIterable, Sendable {
    case messages
    case slack
    case whatsapp
    case messenger
    //    case Telegram doesn't support a11y
    case signal
    case discord
    case mail
    case calendar
    case microsoftteams
    case microsoftoutlook
    case notion
    case obsidian
    case googlechrome

    // Title can be used for context collection app names and will be differ from enum raw values
    public var title: String {
        switch self {
        case .messages:
            return "Messages"
        case .slack:
            return "Slack"
        case .whatsapp:
            return "WhatsApp"
        case .messenger:
            return "Facebook Messenger"
        case .signal:
            return "Signal"
        case .discord:
            return "Discord"
        case .mail:
            return "Mail"
        case .calendar:
            return "Calendar"
        case .microsoftteams:
            return "Teams"
        case .microsoftoutlook:
            return "Outlook"
        case .notion:
            return "Notion"
        case .obsidian:
            return "Obsidian"
        case .googlechrome:
            return "Google Chrome"
        }
    }

    public func parser() -> (any CustomParser)? {
        // These singletons are lazily loaded
        switch self {
        case .messages:
            return MessagesParser()
        case .slack:
            return SlackParser()
        case .whatsapp:
            return WhatsAppParser()
        case .discord:
            return DiscordParser()
        case .messenger:
            return MessengerParser()
        case .signal:
            return SignalParser()
        case .mail:
            return MailParser()
        case .calendar:
            return CalendarParser()
        case .microsoftteams:
            return TeamsParser()
        case .microsoftoutlook:
            return OutlookParser()
        case .notion:
            return NotionParser()
        case .obsidian:
            return ObsidianParser()
        case .googlechrome:
            return ChromeParser()
        }
    }
}

public protocol CustomParser {
    func parse(_ params: WindowParams, deadline: Deadline) async throws -> ParseResult
    var parsedApp: ParseableApp { get }
}

public struct BrowserFrame: Codable, Sendable, ContextInput, Hashable {
    public var app: String
    public var type: ContextInputType = .browser
    public var title: String
    public var url: String
    public var content: String
    public let timestamp: Date?
    public var window: String?
    public var frameStats: FrameStats?

    // New initializer with direct field parameters
    public init(app: String, window: String = "", url: String = "", title: String = "", text: String = "") {
        self.url = url
        self.timestamp = Date()
        self.content = text.filter { char in
            char == " " || char == "\n" || !char.isWhitespace
        }
        self.title = title
        self.app = app
        self.window = window
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.url = try container.decode(String.self, forKey: .url)
        self.content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        self.timestamp = Date()
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        self.app = try container.decode(String.self, forKey: .app)

        self.window = try container.decodeIfPresent(String.self, forKey: .window)
        self.frameStats = try container.decodeIfPresent(FrameStats.self, forKey: .frameStats)
    }

    enum CodingKeys: String, CodingKey {
        case app
        case url
        case timestamp
        case content
        case title
        case type
        case window
        case frameStats
    }
}

public struct ParseResult: Codable, Sendable {
    public var conversationSummaries: [ConversationSummary]?
    public var activeConversations: [Conversation]?
    public var calendar: CalendarEvents?
    public var document: Document?
    public var browser: BrowserFrame?
    public var meeting: Meeting?

    public enum CodingKeys: String, CodingKey {
        case conversationSummaries = "conversation_summaries"
        case activeConversations = "active_conversations"
        case calendar
        case document
        case browser
        case meeting
    }

    public static let empty: Self = .init()

    public init(
        conversationSummaries: [ConversationSummary]? = nil,
        activeConversations: [Conversation]? = nil,
        calendar: CalendarEvents? = nil,
        document: Document? = nil,
        browser: BrowserFrame? = nil,
        meeting : Meeting? = nil
    ) {
        self.conversationSummaries = conversationSummaries
        self.activeConversations = activeConversations
        self.calendar = calendar
        self.document = document
        self.browser = browser
        self.meeting = meeting
    }

    public init(conversationSummaries: [ConversationSummary]? = nil, activeConversation: Conversation? = nil) {
        self.conversationSummaries = conversationSummaries
        self.activeConversations = activeConversation.map({ [$0] })
        self.calendar = nil
    }

    public var isEmpty: Bool {
        (conversationSummaries ?? []).isEmpty &&
            (activeConversations ?? []).isEmpty &&
            calendar == nil &&
            document == nil &&
            browser == nil &&
            meeting == nil
    }
}
