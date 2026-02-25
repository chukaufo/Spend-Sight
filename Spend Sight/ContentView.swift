//
//  ContentView.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-04.
//

import SwiftUI
import CoreData

struct ContentView: View {
    var body: some View {
        TabView{
            ScannerView()
                .tabItem({Label("Scan",systemImage: "barcode.viewfinder")})
            ReceiptsView()
                .tabItem({Label("Receipts",systemImage: "receipt")})
            InsightsView()
                .tabItem({Label("Insights",systemImage: "chart.line.uptrend.xyaxis")})
        }
    }
}

#Preview {
    ContentView()
}
