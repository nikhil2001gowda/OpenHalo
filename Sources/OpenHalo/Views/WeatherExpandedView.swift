import SwiftUI

public struct WeatherExpandedView: View {
    @ObservedObject var weatherService: WeatherService

    public init(weatherService: WeatherService? = nil) {
        self.weatherService = weatherService ?? WeatherService.shared
    }

    public var body: some View {
        VStack(spacing: 12) {
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
                    Text(weatherService.cityName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.7))

                    Button(action: {
                        Task { await weatherService.fetchWeather(force: true) }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .rotationEffect(.degrees(weatherService.isLoading ? 360 : 0))
                            .animation(weatherService.isLoading ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: weatherService.isLoading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)

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
                    Text("Fetching weather forecast...")
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
