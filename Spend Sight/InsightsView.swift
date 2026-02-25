//
//  InsightsView.swift
//  Spend Sight
//
//  Created by Chuka Uwefoh on 2026-02-04.
//

import SwiftUI
import CoreData
import Charts

// One point on the chart: "Feb 25" -> $34.20
struct DailySpendPoint: Identifiable {
    let id = UUID()
    let day: Date
    let amount: Double
}

struct InsightsView: View {

    // Pull all receipts (you can later restrict to last 30 days in the fetch)
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Receipt.date, ascending: true)],
        animation: .default
    )
    private var receipts: FetchedResults<Receipt>

    // Change this to 7 for weekly, 30 for monthly, etc.
    private let daysToShow = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                Text("Insights")
                    .font(.largeTitle).bold()
                    .padding(.horizontal)

                // Summary
                summaryCard
                    .padding(.horizontal)

                // Chart
                chartCard
                    .padding(.horizontal)

            }
            .padding(.vertical)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - UI Pieces

    private var summaryCard: some View {
        let total = dailyPoints.reduce(0) { $0 + $1.amount }
        let avg = dailyPoints.isEmpty ? 0 : total / Double(dailyPoints.count)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Last \(daysToShow) days")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Spent")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(total, specifier: "%.2f")")
                        .font(.title2).bold()
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Avg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("$\(avg, specifier: "%.2f")")
                        .font(.title2).bold()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .cornerRadius(14)
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Spending")
                .font(.headline)

            if dailyPoints.isEmpty {
                Text("No receipts yet. Scan a receipt to start tracking.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            } else {
                Chart(dailyPoints) { p in
                    BarMark(
                        x: .value("Day", p.day, unit: .day),
                        y: .value("Spent", p.amount)
                    )
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .cornerRadius(14)
    }

    // MARK: - Data

    // Convert receipts -> [DailySpendPoint] grouped by calendar day
    private var dailyPoints: [DailySpendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.date(byAdding: .day, value: -(daysToShow - 1), to: today) ?? today

        // 1) group totals by day
        var totalsByDay: [Date: Double] = [:]

        for r in receipts {
            guard let d = r.date else { continue }
            let day = calendar.startOfDay(for: d)

            // only keep last N days
            if day < startDay || day > today { continue }

            totalsByDay[day, default: 0] += r.total
        }

        // 2) fill missing days with 0 so chart is continuous
        var points: [DailySpendPoint] = []
        for offset in 0..<daysToShow {
            if let day = calendar.date(byAdding: .day, value: offset, to: startDay) {
                let amount = totalsByDay[day, default: 0]
                points.append(DailySpendPoint(day: day, amount: amount))
            }
        }

        return points
    }
}
