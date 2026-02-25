//
//  ReceiptsView.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-04.
//

import SwiftUI
import CoreData

struct ReceiptsView: View {
    
    // Fetch all Receipt objects, newest first
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Receipt.date, ascending: false)],
        animation: .default
    )
    private var receipts: FetchedResults<Receipt>
    
    var body: some View {
        NavigationStack{
            List {
                // If Receipt isn't Identifiable, use id: \.objectID
                ForEach(receipts, id: \.objectID) { r in
                    NavigationLink {
                        ReceiptDetailView(receipt: r)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text((r.storeName ?? "").isEmpty ? "Unknown Store" : (r.storeName ?? "Unknown Store"))
                                .font(.headline)

                            Text("Total: $\(r.total, specifier: "%.2f")")
                                .font(.subheadline)

                            Text((r.date ?? Date()), style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(r.category ?? "Other")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                
            }
            .navigationTitle("Receipts")
        }
    }
}
