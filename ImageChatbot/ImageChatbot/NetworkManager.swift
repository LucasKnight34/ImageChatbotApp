//
//  NetworkManager.swift
//  ImageChatbot
//
//  Created by Lucas Knight on 5/13/25.
//

import SwiftUI
import Cocoa

// OpenAI response struct
struct OpenAIResponse: Codable {
    let id: String
    let object: String
    let model: String
    let choices: [Choice]
    let usage: Usage
}

struct Choice: Codable {
    let index: Int
    let message: Message
    let finish_reason: String
}

struct Message: Codable {
    let role: String
    let content: String
}

struct Usage: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
}

class NetworkManager {
    private let apiUrl = "https://api.openai.com/v1/chat/completions"
    
    func convertImageToBase64(image: NSImage) -> String? {
        guard let pngData = convertImageToPNGData(image: image) else { return nil }
        return pngData.base64EncodedString(options: [])
    }
    
    func convertImageToPNGData(image: NSImage) -> Data? {
        guard let imageRep = NSBitmapImageRep(data: image.tiffRepresentation!) else { return nil }
        return imageRep.representation(using: .png, properties: [:])
    }
    
    func createRequestBody(question: String, base64Images: [String]) -> [String: Any] {
        var imageUrlObjects: [[String: Any]] = []
        
        for base64Image in base64Images.prefix(4) {
            let imageObject: [String: Any] = [
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)"
                ]
            ]
            imageUrlObjects.append(imageObject)
        }
        
        let body: [String: Any] = [
            "model": "gpt-4.1",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": question]
                    ] + imageUrlObjects
                ]
            ]
        ]
        
        return body
    }

    // Query the OpenAI API with images and question
    func queryImageQuestion(question: String, images: [NSImage]) async throws -> String {
        // TODO: Cleanup bloated Error handling logic
        var base64Images: [String] = []
        
        for image in images {
            guard let base64Image = convertImageToBase64(image: image) else {
                throw NSError(domain: "ImageEncodingError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to Base64"])
            }
            base64Images.append(base64Image)
        }
        
        let body = createRequestBody(question: question, base64Images: base64Images)
        
        guard let url = URL(string: apiUrl) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(APIHelper().apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            throw NSError(domain: "SerializationError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON data"])
        }
        
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "OpenAIError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }
        
        let openAIResponse: OpenAIResponse
        do {
            openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        } catch {
            throw NSError(domain: "DecodingError", code: 1003, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response data: \(error.localizedDescription)"])
        }
        
        return openAIResponse.choices.first?.message.content ?? "No response from assistant"
    }
}
