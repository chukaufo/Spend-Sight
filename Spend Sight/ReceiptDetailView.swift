//
//  ReceiptDetailView.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-25.
//

import SwiftUI
import CoreData
import UIKit

struct ReceiptDetailView: View {
    let receipt: Receipt

    var lines: [String] {
        (receipt.rawText ?? "")
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
    }

    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    
    // Rescan UI state
    @State private var showImagePicker = false
    @State private var showSourceDialog = false
    @State private var selectedSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var newImage: UIImage?
    @State private var isProcessing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Extracted summary
                VStack(alignment: .leading, spacing: 6) {
                    
                    if isProcessing {
                        ProgressView("Rescanning…")
                            .padding(.bottom, 8)
                    }
                    
                    Text(receipt.storeName ?? "Unknown Store")
                        .font(.title3).bold()

                    Text("Total: $\(receipt.total, specifier: "%.2f")")
                        .font(.headline)
                    
                    Text(receipt.category ?? "Other")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text((receipt.date ?? Date()), style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)

                // OCR lines (line by line)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Scanned Receipt: ")
                        .font(.headline)

                    ForEach(lines.indices, id: \.self) { i in
                        Text(lines[i])
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                    }
                }
                .padding()
                .background(.thinMaterial)
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Receipt")
        .navigationBarTitleDisplayMode(.inline)
      
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {

                // Rescan: choose camera vs library
                Button {
                    showSourceDialog = true
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }

                // Delete
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .confirmationDialog(
            "Rescan Receipt",
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

            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            "Delete this receipt?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Receipt", role: .destructive) {
                deleteReceipt()
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: selectedSourceType, selectedImage: $newImage)
        }
        .onChange(of: newImage) { _, img in
            guard let img else { return }
            rescanAndReplace(with: img)
        }
        
    }
    private func deleteReceipt() {
        viewContext.delete(receipt)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Delete failed ❌", error)
        }
    }

    // Rescan -> OCR -> parse -> overwrite this SAME receipt -> save
    private func rescanAndReplace(with image: UIImage) {
        isProcessing = true

        Task {
            // 1) OCR
            let text = await OCRService.runOCR(image)

            // 2) Parse
            let parsed = ReceiptParser.parse(text)

            await MainActor.run {
                // 3) Replace fields on the existing receipt object
                receipt.rawText = text
                receipt.storeName = parsed.storeName ?? "Unknown Store"
                receipt.total = parsed.total ?? 0
                receipt.date = parsed.date ?? Date()

                // Keep existing category by default (user can change later)
                // OR set to Other if you prefer:
                // receipt.category = receipt.category ?? "Other"

                do {
                    try viewContext.save()
                    print("Rescan replaced receipt ✅")
                } catch {
                    print("Rescan save failed ❌", error)
                }

                // Reset temp UI state
                isProcessing = false
                newImage = nil
            }
        }
    }
}
