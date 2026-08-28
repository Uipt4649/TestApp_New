import Foundation

struct ChatbotBackendEvent: Decodable {
    let provider: String
    let providerEventID: String
    let title: String
    let startAt: String
    let doorsAt: String?
    let venueName: String?
    let address: String?
    let city: String?
    let sourceURL: String
    let details: String?
    let requiresConfirmation: Bool?

    enum CodingKeys: String, CodingKey {
        case provider
        case providerEventID = "provider_event_id"
        case title
        case startAt = "start_at"
        case doorsAt = "doors_at"
        case venueName = "venue_name"
        case address
        case city
        case sourceURL = "source_url"
        case details
        case requiresConfirmation = "requires_confirmation"
    }

    var date: Date? {
        Self.parseISO8601(startAt)
    }

    var doorsDate: Date? {
        Self.parseISO8601(doorsAt)
    }

    var locationName: String? {
        let components = [venueName, address, city]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        return components.isEmpty ? nil : components.joined(separator: " ")
    }

    var eventDetails: String {
        let description = details.map { "\($0)\n" } ?? ""
        return "\(description)取得元: \(sourceURL)"
    }

    private static func parseISO8601(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

struct ChatbotBackendResponse: Decodable {
    let artistName: String
    let message: String
    let events: [ChatbotBackendEvent]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case artistName = "artist_name"
        case message
        case events
        case warnings
    }
}

enum ChatbotAPIError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case serverMessage(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            "チャットボットの接続先が正しくありません。"
        case .invalidResponse:
            "サーバーから正しい応答を受け取れませんでした。"
        case let .serverMessage(message):
            message
        }
    }
}

struct ChatbotAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func findEvents(message: String) async throws -> ChatbotBackendResponse {
        let environment = ProcessInfo.processInfo.environment
        let baseURLString = environment["CHATBOT_BASE_URL"] ?? "http://localhost:8000"
        guard let baseURL = URL(string: baseURLString),
              let url = URL(string: "/v1/chat/events", relativeTo: baseURL) else {
            throw ChatbotAPIError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let appToken = environment["CHATBOT_APP_TOKEN"], appToken.count >= 32 {
            request.setValue(appToken, forHTTPHeaderField: "X-App-Token")
        }
        request.httpBody = try JSONEncoder().encode(
            ChatbotRequestBody(message: message, countryCode: "JP")
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatbotAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(BackendErrorResponse.self, from: data) {
                throw ChatbotAPIError.serverMessage(errorResponse.detail)
            }
            throw ChatbotAPIError.serverMessage("サーバーエラー（\(httpResponse.statusCode)）")
        }

        return try JSONDecoder().decode(ChatbotBackendResponse.self, from: data)
    }
}

private struct ChatbotRequestBody: Encodable {
    let message: String
    let countryCode: String

    enum CodingKeys: String, CodingKey {
        case message
        case countryCode = "country_code"
    }
}

private struct BackendErrorResponse: Decodable {
    let detail: String
}
