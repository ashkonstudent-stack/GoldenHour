//
//  GeminiRater.swift
//  GoldenHour
//
//  Created by Ashkon Adjoudani on 10/11/26.
//

import Foundation
import OSLog

nonisolated struct GeminiRater {
    var model = "gemini-3.8-flash"
    var apiKey = Secrets.geminiAPIKey

    struct Rating: Decodable {
        let score: Int
        let feedback: String
    }

    enum RatingError: LocalizedError {
        case missingAPIKey
        case badResponse(String)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: "Add your Gemini API key in Secrets.swift to get scores."
            case .badResponse(let detail): "Gemini couldn't rate this photo. \(detail)"
            }
        }
    }

    private let prompt = """
        You're a friendly photography judge. Rate this sunset photo from 0 to 100, \
        considering color, light, composition and sharpness. If it isn't a sunset or sunrise, \
        rate how well it captures the sky and mention it. Give one or two short sentences of \
        feedback, including one tip to make the next photo better.
        """

    func rate(jpeg: Data) async throws -> Rating {
        guard !apiKey.isEmpty else { throw RatingError.missingAPIKey }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body(jpeg: jpeg))

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            AppLog.gallery.error("Gemini returned \(status): \(String(decoding: data, as: UTF8.self))")
            throw RatingError.badResponse("(Error \(status))")
        }

        // The reply is wrapped as candidates[0].content.parts[0].text, which holds our JSON.
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        guard let text = reply.candidates?.first?.content?.parts?.first?.text else {
            throw RatingError.badResponse("It sent back an empty reply.")
        }
        let rating = try JSONDecoder().decode(Rating.self, from: Data(text.utf8))
        return Rating(score: min(max(rating.score, 0), 100), feedback: rating.feedback)
    }

    private func body(jpeg: Data) -> [String: Any] {
        [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": jpeg.base64EncodedString()]],
                ],
            ]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": [
                    "type": "OBJECT",
                    "properties": [
                        "score": ["type": "INTEGER"],
                        "feedback": ["type": "STRING"],
                    ],
                    "required": ["score", "feedback"],
                ],
            ],
        ]
    }

    private struct Reply: Decodable {
        struct Candidate: Decodable { let content: Content? }
        struct Content: Decodable { let parts: [Part]? }
        struct Part: Decodable { let text: String? }
        let candidates: [Candidate]?
    }
}
