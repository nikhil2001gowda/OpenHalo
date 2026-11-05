import SwiftUI

public struct WeatherExpandedView: View {
    @ObservedObject var weatherService: WeatherService
    @State private var isSearching: Bool = false
    @State private var searchCityText: String = ""

    public init(weatherService: WeatherService? = nil) {
        self.weatherService = weatherService ?? WeatherService.shared
    }

    public var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.yellow)

                    Text("Live Weather (Open-Meteo)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 6) {
                    // City Name (tap to toggle search)
                    Button(action: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            isSearching.toggle()
                            IslandCoordinator.shared.setKeyboardFocus(isSearching)
                        }
                    }) {
                        HStack(spacing: 3) {
                            Text(weatherService.cityName)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.85))

                            Image(systemName: isSearching ? "chevron.up" : "magnifyingglass")
                                .font(.system(size: 9))
                                .foregroundColor(Color.white.opacity(0.5))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("Click to search any city")

                    // Auto-Detect Current Location Button
                    Button(action: {
                        Task { await weatherService.autoDetectLocation() }
                    }) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                            .frame(width: 22, height: 22)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Auto-detect current location via IP")

                    // Refresh Button
                    Button(action: {
                        Task { await weatherService.fetchWeather(force: true) }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 22, height: 22)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                            .rotationEffect(.degrees(weatherService.isLoading ? 360 : 0))
                            .animation(weatherService.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: weatherService.isLoading)
                    }
                    .buttonStyle(.plain)
                    .help("Refresh forecast")
                }
            }
            .padding(.horizontal, 4)

            // Search Bar (Expands inline when user clicks city name or magnifying glass)
            if isSearching {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(Color.white.opacity(0.5))

                        TextField("Type city (e.g., Bengaluru, Mumbai, London)...", text: $searchCityText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                            .onSubmit {
                                submitCitySearch()
                            }

                        if !searchCityText.isEmpty {
                            Button(action: {
                                submitCitySearch()
                            }) {
                                Text("Set")
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white)
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                        }

                        Button(action: {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                isSearching = false
                                IslandCoordinator.shared.setKeyboardFocus(false)
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)

                    // Popular 1-Tap Quick City Suggestion Chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(["Bengaluru", "Mumbai", "New Delhi", "Hyderabad", "Chennai", "London", "New York", "San Francisco"], id: \.self) { city in
                                Button(action: {
                                    searchCityText = city
                                    submitCitySearch()
                                }) {
                                    Text(city)
                                        .font(.system(size: 9.5, weight: weatherService.cityName == city ? .bold : .regular))
                                        .foregroundColor(weatherService.cityName == city ? .cyan : Color.white.opacity(0.8))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(weatherService.cityName == city ? Color.cyan.opacity(0.2) : Color.white.opacity(0.08))
                                        .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Weather Metrics Card
            if let snapshot = weatherService.current {
                HStack(spacing: 16) {
                    // Big Weather Symbol & Temp
                    HStack(spacing: 10) {
                        Image(systemName: snapshot.sfSymbol)
                            .font(.system(size: 32))
                            .foregroundColor(.yellow)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.formattedTemp)
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(snapshot.conditionDescription)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }

                    Spacer()

                    // Metrics Grid
                    HStack(spacing: 14) {
                        metricItem(title: "Feels Like", value: "\(Int(round(snapshot.apparentTemperature)))°C", icon: "thermometer.medium")
                        metricItem(title: "Humidity", value: "\(snapshot.humidity)%", icon: "humidity.fill")
                        metricItem(title: "Wind", value: "\(Int(round(snapshot.windSpeed))) km/h", icon: "wind")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
            } else if weatherService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Detecting location and fetching weather...")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                }
                .frame(height: 50)
            } else {
                HStack {
                    Spacer()
                    Text("Weather unavailable (Offline or cached)")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                    Spacer()
                }
                .frame(height: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func submitCitySearch() {
        guard !searchCityText.isEmpty else { return }
        Task {
            let success = await weatherService.searchAndSetCity(searchCityText)
            if success {
                withAnimation {
                    isSearching = false
                    searchCityText = ""
                    IslandCoordinator.shared.setKeyboardFocus(false)
                }
            }
        }
    }

    private func metricItem(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.cyan)

            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)

            Text(title)
                .font(.system(size: 9))
                .foregroundColor(Color.white.opacity(0.5))
        }
    }
}
