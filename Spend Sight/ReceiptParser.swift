//
//  ReceiptParser.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-24.
//

import Foundation

// MARK: - Receipt Parsing (OCR text -> structured data)
//
// This file is "business logic" (not UI). It takes the raw OCR text
// and tries to extract:
// 1) store name (best guess)
// 2) date (best guess)
// 3) total (strongest signal)
// 4) line items (very basic heuristic: "name ... price")
//
// NOTE: Receipt formats vary a lot, so parsing is heuristic-based.
// Start with total + store + date, then improve item extraction later.

struct ParsedReceipt {
    let storeName: String?
    let date: Date?
    let total: Double?
    let items: [ParsedItem]
}

struct ParsedItem {
    let name: String
    let price: Double
}

enum ReceiptParser {

    // Public entry point
    static func parse(_ rawText: String) -> ParsedReceipt {
        let text = normalize(rawText)
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let store = extractStoreName(from: lines)
        let date = extractDate(from: text)
        let total = extractTotal(from: text)
        let items = extractItems(from: lines)

        return ParsedReceipt(storeName: store, date: date, total: total, items: items)
    }

    // MARK: - Normalization

    private static func normalize(_ text: String) -> String {
        // Replace common OCR weirdness (optional; add more as you notice issues)
        return text
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "O", with: "0") // sometimes OCR mistakes O/0 (can be risky)
    }

    // MARK: - Total

    
        
        // MARK: - TOTAL (robust)
        //
        // Strategy:
        // 1) Look for keyword lines (TOTAL, AMOUNT, BALANCE DUE, GRAND TOTAL...)
        // 2) Extract money values from those lines
        // 3) Prefer the LAST matching keyword line (totals usually near the bottom)
        // 4) Fallback: take the largest money value from the bottom 40% of the receipt
        static func extractTotal(from text: String) -> Double? {
            let lines = text
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Keywords that often indicate the total due
            let totalKeywords = [
                "total", "grand total", "amount", "amount due", "balance due",
                "total due", "amount payable", "due"
            ]
            
            // 1) Keyword-based scan (from bottom up)
            for line in lines.reversed() {
                let lower = line.lowercased()
                
                if totalKeywords.contains(where: { lower.contains($0) }) {
                    if let value = extractLastMoneyValue(from: line) {
                        return value
                    }
                }
            }
            
            // 2) Fallback: largest amount in bottom 40% (totals usually near bottom)
            let startIndex = max(0, Int(Double(lines.count) * 0.6))
            let bottomLines = lines[startIndex...]
            
            var candidates: [Double] = []
            for line in bottomLines {
                // Skip lines that are usually not the final total
                let lower = line.lowercased()
                if lower.contains("tax") || lower.contains("hst") || lower.contains("gst") || lower.contains("subtotal") {
                    continue
                }
                if let value = extractLastMoneyValue(from: line) {
                    candidates.append(value)
                }
            }
            
            return candidates.max()
        }
    

        // Extract the LAST money-like value from a line.
        // Handles: $12.34, 12.34, 1,234.56, 12,34 (OCR), etc.
        private static func extractLastMoneyValue(from line: String) -> Double? {
            // Matches numbers like:
            // $12.34
            // 12.34
            // 1,234.56
            // 1234.56
            let pattern = #"(?:\$|CAD\s*)?(\d{1,3}(?:[,\s]\d{3})*(?:\.\d{2})|\d+(?:\.\d{2}))"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }

            let range = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, range: range)
            guard let last = matches.last,
                  let r = Range(last.range(at: 1), in: line) else {
                return nil
            }

            // Clean commas/spaces: "1,234.56" -> "1234.56"
            let raw = String(line[r])
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: " ", with: "")

            return Double(raw)
        }
    // MARK: - Store Name (best guess)

    private static func extractStoreName(from lines: [String]) -> String? {
        // Heuristic:
        // - Use the first "good" line near the top
        // - Avoid lines that look like totals, dates, phone numbers
        // - Prefer uppercase-ish store names

        let blacklistWords = ["total", "subtotal", "tax", "visa", "mastercard", "debit", "cash", "change"]

        for line in lines.prefix(8) {
            let lower = line.lowercased()
            if blacklistWords.contains(where: { lower.contains($0) }) { continue }
            if looksLikeDate(line) { continue }
            if looksLikePhone(line) { continue }
            if line.count < 3 { continue }

            // If it’s mostly letters (store names)
            let letters = line.filter { $0.isLetter }.count
            if letters >= max(3, line.count / 2) {
                return line
            }
        }

        return lines.first
    }

    // MARK: - Date (best guess)

    private static func extractDate(from text: String) -> Date? {
        // Matches things like:
        // 2026-02-24
        // 02/24/2026 or 24/02/2026
        // 02-24-26
        let patterns = [
            #"\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b"#,  // yyyy-mm-dd
            #"\b(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b"#  // mm/dd/yyyy or dd/mm/yyyy
        ]

        for p in patterns {
            if let d = matchDate(pattern: p, in: text) { return d }
        }
        return nil
    }

    private static func matchDate(pattern: String, in text: String) -> Date? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        func group(_ i: Int) -> String? {
            guard let r = Range(match.range(at: i), in: text) else { return nil }
            return String(text[r])
        }

        // Try parsing based on capture count
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")

        if pattern.contains(#"\d{4}"#) {
            // yyyy-mm-dd
            guard let y = group(1), let m = group(2), let d = group(3) else { return nil }
            df.dateFormat = "yyyy-M-d"
            return df.date(from: "\(y)-\(m)-\(d)")
        } else {
            // mm/dd/yyyy or dd/mm/yyyy (ambiguous)
            guard let a = group(1), let b = group(2), let c = group(3) else { return nil }
            // Assume North American receipts first: mm/dd/yyyy
            df.dateFormat = (c.count == 2) ? "M-d-yy" : "M-d-yyyy"
            return df.date(from: "\(a)-\(b)-\(c)")
        }
    }

    // MARK: - Items (basic heuristic)

    private static func extractItems(from lines: [String]) -> [ParsedItem] {
        // Very basic:
        // - Find lines that end with a price like "3.49"
        // - Treat the start of the line as the item name
        // - Skip obvious non-items

        let skipWords = ["total", "subtotal", "tax", "hst", "gst", "balance", "visa", "debit", "change", "tender"]

        // price at end: " ... 12.34"
        let pricePattern = #"([0-9]+(?:\.[0-9]{2}))\s*$"#
        let regex = try? NSRegularExpression(pattern: pricePattern)

        var results: [ParsedItem] = []

        for line in lines {
            let lower = line.lowercased()
            if skipWords.contains(where: { lower.contains($0) }) { continue }

            let range = NSRange(line.startIndex..., in: line)
            guard
                let match = regex?.firstMatch(in: line, range: range),
                let priceRange = Range(match.range(at: 1), in: line),
                let price = Double(line[priceRange])
            else { continue }

            // Name = line with the price removed
            let namePart = line[..<priceRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "$", with: "")
                .replacingOccurrences(of: "  ", with: " ")

            if namePart.isEmpty { continue }
            if namePart.count < 2 { continue }

            results.append(ParsedItem(name: namePart, price: price))
        }

        return results
    }

    // MARK: - Helpers

    private static func looksLikeDate(_ line: String) -> Bool {
        return line.range(of: #"\d{1,2}[-/]\d{1,2}[-/]\d{2,4}"#, options: .regularExpression) != nil ||
               line.range(of: #"\d{4}[-/]\d{1,2}[-/]\d{1,2}"#, options: .regularExpression) != nil
    }

    private static func looksLikePhone(_ line: String) -> Bool {
        // Rough phone pattern: 123-456-7890 or (123) 456-7890
        return line.range(of: #"\(?\d{3}\)?[\s-]?\d{3}[\s-]?\d{4}"#, options: .regularExpression) != nil
    }
}
