import Foundation
import UIKit

/// Calls the Claude API (vision) to estimate calories from a meal photo.
/// Raw HTTP via URLSession — there is no official Swift SDK.
enum ClaudeService {

    struct MealEstimate: Codable {
        let meal_name: String
        let items: [String]
        let calories: Int
        let protein_g: Int
        let carbs_g: Int
        let fat_g: Int
        let confidence: String
    }

    enum ScanError: LocalizedError {
        case noAPIKey, imageEncoding, badResponse(String), refused

        var errorDescription: String? {
            switch self {
            case .noAPIKey: return "Add your Anthropic API key in Settings first."
            case .imageEncoding: return "Could not process the photo."
            case .badResponse(let msg): return msg
            case .refused: return "The AI declined to analyze this image."
            }
        }
    }

    static var apiKey: String {
        get { UserDefaults.standard.string(forKey: "anthropic_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "anthropic_api_key") }
    }

    static func estimateMeal(from image: UIImage) async throws -> MealEstimate {
        guard !apiKey.isEmpty else { throw ScanError.noAPIKey }

        // Downscale + compress: plenty for food recognition, keeps tokens cheap.
        guard let jpeg = downscaled(image, maxDimension: 1024).jpegData(compressionQuality: 0.7) else {
            throw ScanError.imageEncoding
        }
        let base64 = jpeg.base64EncodedString()

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "meal_name": ["type": "string", "description": "Short name for the meal"],
                "items": ["type": "array", "items": ["type": "string"], "description": "Food items with estimated portions"],
                "calories": ["type": "integer"],
                "protein_g": ["type": "integer"],
                "carbs_g": ["type": "integer"],
                "fat_g": ["type": "integer"],
                "confidence": ["type": "string", "enum": ["high", "medium", "low"]]
            ],
            "required": ["meal_name", "items", "calories", "protein_g", "carbs_g", "fat_g", "confidence"],
            "additionalProperties": false
        ] as [String: Any]

        let body: [String: Any] = [
            "model": "claude-opus-4-8",
            "max_tokens": 1024,
            "system": "You estimate nutrition from food photos. The user is in India, so recognize Indian dishes (roti, dal, sabzi, biryani, dosa, etc.) and use typical Indian portion sizes. Estimate the TOTAL for everything visible on the plate/table that appears to be one person's meal.",
            "output_config": [
                "format": ["type": "json_schema", "schema": schema]
            ],
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": base64]],
                    ["type": "text", "text": "Estimate the nutrition of this meal."]
                ]
            ]]
        ]

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw ScanError.badResponse("No response") }
        guard http.statusCode == 200 else {
            let apiMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { $0["error"] as? [String: Any] }
                .flatMap { $0["message"] as? String }
            throw ScanError.badResponse(apiMessage ?? "API error \(http.statusCode)")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ScanError.badResponse("Unreadable API response")
        }
        if json["stop_reason"] as? String == "refusal" { throw ScanError.refused }
        guard let content = json["content"] as? [[String: Any]],
              let text = content.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let textData = text.data(using: .utf8) else {
            throw ScanError.badResponse("No text in API response")
        }
        return try JSONDecoder().decode(MealEstimate.self, from: textData)
    }

    private static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1)
        guard scale < 1 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
