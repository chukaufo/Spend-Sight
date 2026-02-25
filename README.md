# 📸 Spend Sight

Spend Sight is an iOS receipt-scanning application that converts physical receipts into structured financial data using on-device OCR and Core Data.

The app allows users to scan or upload a receipt, extract key purchase information, categorize spending, and visualize daily and weekly trends through interactive charts.

---

## 🚀 Features

- 📷 Scan receipts using camera or photo library
- 🔎 On-device OCR powered by Apple’s Vision framework
- 🧾 Automatic extraction of:
  - Store name
  - Total amount
  - Date
- 🏷 User-selected spending category
- 🔁 Rescan functionality to replace receipt details
- 🗑 Delete receipts
- 📊 Insights dashboard with:
  - Daily spending bar chart
  - Weekly spending chart
  - 30-day summary
  - Average daily spending
- 💾 Local persistence using Core Data

---

## 📊 Insights Dashboard

Spend Sight transforms scanned receipts into actionable insights:

- Tracks daily and weekly spending
- Groups transactions by calendar day and week
- Automatically fills missing dates for continuous charts
- Calculates total spending and daily averages

---

## 🛠 Tech Stack

- **SwiftUI** – UI framework
- **Vision Framework** – Optical Character Recognition (OCR)
- **Core Data** – Local data persistence
- **Swift Charts** – Data visualization
- **UIKit (ImagePicker)** – Camera and photo library integration

---

## 🧠 Architecture Overview

1. User scans or uploads a receipt
2. Vision framework extracts raw text
3. Custom parser converts OCR text into structured data
4. Data is saved using Core Data
5. Insights view aggregates and visualizes spending trends

This project demonstrates:

- OCR processing and text extraction
- Data parsing and transformation
- Core Data modeling
- SwiftUI state management
- Chart-based data visualization
- Clean user flow design (Scan → Preview → Categorize → Save → Analyze)

---

## 📱 How to Run

1. Clone the repository:
git clone https://github.com/chukaufo/Spend-Sight.git

2. Open `Spend Sight.xcodeproj` in Xcode
3. Ensure the deployment target is **iOS 16+** (required for Swift Charts)
4. Run on simulator or physical device

> Note: Camera functionality requires a physical iPhone.

---

## 🔮 Future Improvements

- Category breakdown pie chart
- Monthly and yearly trend analysis
- Budget tracking and alerts
- Improved item-level parsing
- Search and filtering
- iCloud sync
- Export to CSV

---

## 📌 Project Purpose

Spend Sight was built to explore how unstructured financial data from physical receipts can be transformed into structured insights using native iOS technologies.

This project serves as a portfolio-level demonstration of iOS development, data modeling, and financial visualization.
