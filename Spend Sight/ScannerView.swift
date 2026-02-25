//
//  ScannerView.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-04.
//

import SwiftUI
import UIKit
import CoreData
@preconcurrency import Vision


struct ScannerView: View {
    
    //Contols image picker
    @State private var showImagePicker: Bool = false
    
    //this state stores selected Image
    @State private var selectedImage: UIImage?
    
    @State private var selectedSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showSourceDialog = false
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var storeName: String = ""
    @State private var totalAmount: Double = 0
    @State private var receiptDate: Date = Date()

    @State private var category: String = "Other"
    @State private var showPreview: Bool = false
    
    private let categories = [
        "Groceries", "Dining", "Retail", "Transport", "Bills", "Subscription", "Other"
    ]
    
    var body: some View {
        NavigationStack{
            VStack(spacing: 20){
                
                Button("Scan receipt"){
                    showSourceDialog = true
                }.buttonStyle(.borderedProminent)
                    .confirmationDialog(
                        "Scan Receipt",
                        isPresented: $showSourceDialog,
                        titleVisibility: .visible
                    ) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Take Photo") {
                                selectedSourceType = .camera
                                showImagePicker = true
                            }
                        }

                        Button("Choose from Library") {
                            selectedSourceType = .photoLibrary
                            showImagePicker = true
                        }

                        Button("Cancel", role: .cancel) {}
                    }
                
                if let image = selectedImage{
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(12)
                }else {
                    Text("No image selected yet")
                    .foregroundColor(.secondary)}
                
                
                if isProcessing { ProgressView("Reading receipt…") }
                
                if showPreview {
                    VStack(alignment: .leading, spacing: 12) {

                        // Receipt summary card
                        VStack(alignment: .leading, spacing: 6) {
                            Text(storeName)
                                .font(.title3).bold()

                            Text("Total: $\(totalAmount, specifier: "%.2f")")
                                .font(.headline)

                            Text(receiptDate, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.headline)

                            Picker("Category", selection: $category) {
                                ForEach(categories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Save button
                        Button {
                            saveReceipt()
                        } label: {
                            Text("Save Receipt")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.horizontal)

                    }
                } else {
                    Text("Scan a receipt to preview it here.")
                        .foregroundStyle(.secondary)
                        .padding()
                }
                
                Spacer()
                
                
            }// VStack ends
            .padding()
            .navigationTitle("Scan Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(
                    sourceType: selectedSourceType,
                    selectedImage: $selectedImage
                )
            }
            .onChange(of: selectedImage) { _, newValue in
                // Force it to be a UIImage
                guard let image = newValue as? UIImage else { return }

                isProcessing = true
                recognizedText = ""

                Task {
                    print("OCR started")
                    let text = await runOCR(image)
                    print("OCR finished, chars:", text.count)

                    await MainActor.run {
                            recognizedText = text
                            isProcessing = false

                            // 1) Parse extracted fields
                            let parsed = ReceiptParser.parse(text)

                            // 2) Fill the UI preview fields
                            storeName = parsed.storeName ?? "Unknown Store"
                            totalAmount = parsed.total ?? 0
                            receiptDate = parsed.date ?? Date()

                            // optional default category (you can improve this later)
                            category = "Other"

                            // 3) Show preview card + category picker
                            showPreview = true
                    }
                }
            }
            

            } //Navigation stack ends
        
     
        
        }
    private func saveReceipt() {
        let receipt = Receipt(context: viewContext)
        receipt.id = UUID()
        receipt.date = receiptDate
        receipt.storeName = storeName
        receipt.total = totalAmount
        receipt.rawText = recognizedText

        
        receipt.category = category

        do {
            try viewContext.save()
            print("Saved receipt ✅")

            // Reset UI
            selectedImage = nil
            recognizedText = ""
            showPreview = false

        } catch {
            print("Save failed ❌", error)
        }
    }
    }



func runOCR(_ image: UIImage) async -> String {

    // Vision works with CGImage, not UIImage
    // If we can’t get a CGImage, OCR can’t run
    let cgImage: CGImage? = {
        if let cg = image.cgImage { return cg }
        if let ci = image.ciImage {
            return CIContext().createCGImage(ci, from: ci.extent)
        }
        return nil
    }()

    guard let cgImage else { return "" }


    // Bridge Vision’s callback-based API into async/await
    return await withCheckedContinuation { continuation in

        // Create a text-recognition request
        // This closure runs when Vision finishes processing the image
        let request = VNRecognizeTextRequest { request, error in

            // If Vision reports an error, log it and return empty text
            if let error = error {
                print("OCR error:", error)
                continuation.resume(returning: "")
                return
            }

            // Cast the results to text observations
            let observations =
                request.results as? [VNRecognizedTextObservation] ?? []

            // Extract the best (top) recognized string from each observation
            let recognizedStrings = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }

            // Combine all recognized lines into a single string
            // Each line is separated by a newline character
            let fullText = recognizedStrings.joined(separator: "\n")

            // Resume the async function and return the OCR result
            continuation.resume(returning: fullText)
        }

        // Use the most accurate recognition (slower but better for receipts)
        request.recognitionLevel = .accurate

        // Enable language correction to improve text quality
        request.usesLanguageCorrection = true

        // Create a handler that performs Vision requests on the image
        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            options: [:]
        )

        // Run the OCR work off the main thread so the UI doesn’t freeze
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Execute the text recognition request
                try handler.perform([request])
            } catch {
                // If something fails, log the error and return empty text
                print("Failed to perform OCR:", error)
                continuation.resume(returning: "")
            }
        }
    }
    
    
}



#Preview {
    ScannerView()
}
