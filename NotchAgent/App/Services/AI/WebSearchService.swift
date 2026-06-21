//
//  WebSearchService.swift
//  NotchAgent
//
//  Created by Omer Faruk Aras on 19.06.2026.
//

import Foundation

enum WebSearchService {
    
    /// Basic web search implementation using DuckDuckGo HTML parsing or a simple HTTP request.
    /// In a real scenario, you would use an API like Serper, Google Custom Search, or Tavily.
    /// For this example, we will just fetch text from Wikipedia or a basic web search if possible.
    static func performSearch(query: String) async throws -> String {
        // Here we can use a free API for demonstration, like Wikipedia API
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        // Simple heuristic: if the query sounds like a general knowledge question, use Wikipedia.
        // Otherwise, we could try to scrape DuckDuckGo HTML.
        let urlString = "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=\\(encodedQuery)&utf8=&format=json"
        
        guard let url = URL(string: urlString) else {
            return "Arama URL'si oluşturulamadı."
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        // Parse Wikipedia Search Response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let queryDict = json["query"] as? [String: Any],
              let searchResults = queryDict["search"] as? [[String: Any]] else {
            return "Sonuç bulunamadı."
        }
        
        var resultsText = ""
        for (index, result) in searchResults.prefix(3).enumerated() {
            if let title = result["title"] as? String,
               let snippet = result["snippet"] as? String {
                // Remove HTML tags from snippet
                let cleanSnippet = snippet.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                resultsText += "\\(index + 1). \\(title): \\(cleanSnippet)\\n"
            }
        }
        
        if resultsText.isEmpty {
            return "Hiçbir sonuç bulunamadı."
        }
        
        return resultsText
    }
}
