//
//  OCRService.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-25.
//

import Foundation
import UIKit
@preconcurrency import Vision

// Shared OCR so ScannerView + ReceiptDetailView can both reuse it.
enum OCRService {

    static func runOCR(_ image: UIImage) async -> String {

        // Vision needs CGImage
        let cgImage: CGImage? = {
            if let cg = image.cgImage { return cg }
            if let ci = image.ciImage {
                return CIContext().createCGImage(ci, from: ci.extent)
            }
            return nil
        }()

        guard let cgImage else { return "" }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in

                if let error = error {
                    print("OCR error:", error)
                    continuation.resume(returning: "")
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
                let fullText = recognizedStrings.joined(separator: "\n")

                continuation.resume(returning: fullText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform OCR:", error)
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
