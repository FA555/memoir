//
//  ContentView.swift
//  Memoir
//
//  Created by 法伍 on 2026/4/13.
//

import Photos
import SwiftUI

struct ContentView: View {
  @State private var selectedMonth = Calendar.current.component(.month, from: Date())
  @State private var selectedDay = Calendar.current.component(.day, from: Date())
  @State private var selectedIndex = 0

  @StateObject private var store = PhotoHistoryStore()
  @Environment(\.openURL) private var openURL

  private var displayLocale: Locale {
    Locale(identifier: Locale.preferredLanguages.first ?? Locale.autoupdatingCurrent.identifier)
  }

  private var localizedMonthSymbols: [String] {
    let formatter = DateFormatter()
    formatter.locale = displayLocale
    return formatter.standaloneMonthSymbols
  }

  private var usesEnglishStyleDateLabels: Bool {
    displayLocale.identifier.lowercased().hasPrefix("en")
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          controlsBar

          if store.authorizationState == .notDetermined {
            ProgressView("loading.photo_permission")
              .frame(maxWidth: .infinity)
              .padding(.top, 28)
          } else if store.authorizationState == .denied || store.authorizationState == .restricted {
            permissionDeniedView
          } else if store.photos.isEmpty {
            ContentUnavailableView(
              "empty.no_photos_title",
              systemImage: "photo.on.rectangle.angled",
              description: Text("empty.no_photos_desc")
            )
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
          } else {
            HistoryDetailPagerView(
              photos: store.photos,
              selectedIndex: $selectedIndex,
              onDeleteCurrent: { localIdentifier in
                await deleteCurrentPhoto(localIdentifier: localIdentifier)
              }
            )
              .frame(maxWidth: .infinity)
          }

          // Leave drag space for the whole page scroll.
          Color.clear
            .frame(height: 96)
        }
      }
      .navigationTitle("app.title.memoir")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            openPhotosApp()
          } label: {
            Image(systemName: "photo.on.rectangle")
          }
          .accessibilityLabel("accessibility.open_photos_app")
        }
      }
    }
    .environment(\.locale, displayLocale)
    .task {
      await store.ensureAuthorizationAndLoad(month: selectedMonth, day: selectedDay)
      selectedIndex = 0
    }
    .onChange(of: selectedMonth) { _, newMonth in
      Task {
        let adjustedDay = min(selectedDay, maxDayInSelectedMonth)
        if adjustedDay != selectedDay {
          selectedDay = adjustedDay
        }
        await store.loadPhotos(month: newMonth, day: adjustedDay)
        selectedIndex = 0
      }
    }
    .onChange(of: selectedDay) { _, newDay in
      Task {
        await store.loadPhotos(month: selectedMonth, day: newDay)
        selectedIndex = 0
      }
    }
    .onChange(of: store.photos.count) { _, _ in
      selectedIndex = 0
    }
  }

  private var controlsBar: some View {
    HStack(spacing: 10) {
      Button {
        shiftSelectedDay(by: -1)
      } label: {
        Image(systemName: "chevron.left")
      }
      .buttonStyle(.glass)
      .controlSize(.small)
      .accessibilityLabel("accessibility.previous_day")

      Spacer(minLength: 0)

      Picker("picker.month", selection: $selectedMonth) {
        ForEach(1...12, id: \.self) { month in
          Text(monthLabel(for: month)).tag(month)
        }
      }
      .pickerStyle(.menu)
      .frame(minWidth: 80)
      .lineLimit(1)
      .layoutPriority(1)

      Picker("picker.day", selection: $selectedDay) {
        ForEach(1...maxDayInSelectedMonth, id: \.self) { day in
          Text(dayLabel(for: day)).tag(day)
        }
      }
      .pickerStyle(.menu)
      .frame(minWidth: 80)
      .lineLimit(1)
      .layoutPriority(1)

      Button("button.today") {
        jumpToToday()
      }
      .buttonStyle(.glass)
      .controlSize(.small)

      Spacer(minLength: 0)

      Button {
        shiftSelectedDay(by: 1)
      } label: {
        Image(systemName: "chevron.right")
      }
      .buttonStyle(.glass)
      .controlSize(.small)
      .accessibilityLabel("accessibility.next_day")
    }
    .padding(12)
    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    .padding(.horizontal, 12)
  }

  private var maxDayInSelectedMonth: Int {
    let year = Calendar.current.component(.year, from: Date())
    var components = DateComponents()
    components.year = year
    components.month = selectedMonth
    components.day = 1
    let date = Calendar.current.date(from: components) ?? Date()
    return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 31
  }

  private func monthLabel(for month: Int) -> String {
    if usesEnglishStyleDateLabels {
      return localizedMonthSymbols[month - 1]
    }

    return "\(month.formatted(.number.locale(displayLocale)))\(String(localized: "unit.month_suffix"))"
  }

  private func dayLabel(for day: Int) -> String {
    if usesEnglishStyleDateLabels {
      let formatter = NumberFormatter()
      formatter.locale = displayLocale
      formatter.numberStyle = .ordinal
      return formatter.string(from: NSNumber(value: day)) ?? "\(day)"
    }

    return "\(day.formatted(.number.locale(displayLocale)))\(String(localized: "unit.day_suffix"))"
  }

  private func jumpToToday() {
    let today = Date()
    selectedMonth = Calendar.current.component(.month, from: today)
    selectedDay = Calendar.current.component(.day, from: today)
  }

  private func shiftSelectedDay(by delta: Int) {
    let year = Calendar.current.component(.year, from: Date())
    var components = DateComponents()
    components.year = year
    components.month = selectedMonth
    components.day = selectedDay

    guard let baseDate = Calendar.current.date(from: components),
      let shiftedDate = Calendar.current.date(byAdding: .day, value: delta, to: baseDate)
    else {
      return
    }

    selectedMonth = Calendar.current.component(.month, from: shiftedDate)
    selectedDay = Calendar.current.component(.day, from: shiftedDate)
  }

  private func openPhotosApp() {
    guard let url = URL(string: "photos-redirect://") else { return }
    openURL(url)
  }

  private func deleteCurrentPhoto(localIdentifier: String) async {
    let didDelete = await store.deletePhoto(localIdentifier: localIdentifier)
    guard didDelete else { return }

    await store.loadPhotos(month: selectedMonth, day: selectedDay)
    if store.photos.isEmpty {
      selectedIndex = 0
    } else {
      selectedIndex = min(selectedIndex, store.photos.count - 1)
    }
  }

  private var permissionDeniedView: some View {
    ContentUnavailableView {
      Label("permission.need_photo_access", systemImage: "lock.slash")
    } description: {
      Text("permission.open_settings_desc")
    } actions: {
      Button("permission.retry") {
        Task {
          await store.ensureAuthorizationAndLoad(month: selectedMonth, day: selectedDay)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 28)
  }
}

#Preview {
  ContentView()
}
