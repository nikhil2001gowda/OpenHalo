import Foundation
import Combine

public struct WeatherSnapshot: Sendable, Codable, Equatable {
    public let temperature: Double
    public let apparentTemperature: Double
    public let humidity: Int
    public let windSpeed: Double
    public let weatherCode: Int
    public let isDay: Bool
    public let conditionDescription: String
    public let sfSymbol: String
    public let fetchedAt: Date

    public init(
        temperature: Double,
        apparentTemperature: Double,
        humidity: Int,
        windSpeed: Double,
        weatherCode: Int,
        isDay: Bool,
        conditionDescription: String,
        sfSymbol: String,
        fetchedAt: Date = Date()
    ) {
        self.temperature = temperature
        self.apparentTemperature = apparentTemperature
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.weatherCode = weatherCode
        self.isDay = isDay
        self.conditionDescription = conditionDescription
        self.sfSymbol = sfSymbol
        self.fetchedAt = fetchedAt
    }

    public var formattedTemp: String {
        return "\(Int(round(temperature)))°C"
    }

    public static let placeholder = WeatherSnapshot(
        temperature: 20.0,
        apparentTemperature: 20.0,
        humidity: 50,
        windSpeed: 10.0,
        weatherCode: 0,
        isDay: true,
        conditionDescription: "Clear",
        sfSymbol: "sun.max.fill",
        fetchedAt: Date()
    )
}

@MainActor
public final class WeatherService: ObservableObject {
    public static let shared = WeatherService()

    @Published public var current: WeatherSnapshot? = nil
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var cityName: String = "San Francisco"

    // Default coordinates (User customizable)
    @Published public var latitude: Double = 37.7749
    @Published public var longitude: Double = -122.4194

    private let cacheTTL: TimeInterval = 1200 // 20 minutes
    private var lastFetchTime: Date? = nil

    public init() {
        Task {
            await fetchWeather()
        }
    }

    public func setLocation(name: String, lat: Double, lon: Double) {
        self.cityName = name
        self.latitude = lat
        self.longitude = lon
        self.lastFetchTime = nil
        Task {
            await fetchWeather(force: true)
        }
    }

    public func refreshIfStale() {
        if let last = lastFetchTime, Date().timeIntervalSince(last) < cacheTTL {
            return
        }
        Task {
            await fetchWeather()
        }
    }

    public func fetchWeather(force: Bool = false) async {
        if !force, let last = lastFetchTime, Date().timeIntervalSince(last) < cacheTTL {
            return
        }

        isLoading = true
        errorMessage = nil

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&temperature_unit=celsius&wind_speed_unit=kmh"

        guard let url = URL(string: urlString) else {
            isLoading = false
            errorMessage = "Invalid URL"
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                errorMessage = "Network response code not 200"
                return
            }

            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let curr = decoded.current

            let desc = mapWeatherCodeToDescription(curr.weather_code)
            let symbol = mapWeatherCodeToSFSymbol(curr.weather_code, isDay: curr.is_day == 1)

            let snapshot = WeatherSnapshot(
                temperature: curr.temperature_2m,
                apparentTemperature: curr.apparent_temperature,
                humidity: curr.relative_humidity_2m,
                windSpeed: curr.wind_speed_10m,
                weatherCode: curr.weather_code,
                isDay: curr.is_day == 1,
                conditionDescription: desc,
                sfSymbol: symbol,
                fetchedAt: Date()
            )

            self.current = snapshot
            self.lastFetchTime = Date()
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
            // If offline, provide a sensible fallback if empty
            if self.current == nil {
                self.current = WeatherSnapshot.placeholder
            }
        }
    }

    public func mapWeatherCodeToDescription(_ code: Int) -> String {
        switch code {
        case 0: return "Clear Sky"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Partly Cloudy"
        }
    }

    public func mapWeatherCodeToSFSymbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 61, 63, 65:
            return "cloud.rain.fill"
        case 71, 73, 75:
            return "snowflake"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return isDay ? "sun.max.fill" : "moon.fill"
        }
    }
}

// Internal Open-Meteo JSON schema
private struct OpenMeteoResponse: Codable {
    let current: CurrentUnits
}

private struct CurrentUnits: Codable {
    let temperature_2m: Double
    let relative_humidity_2m: Int
    let apparent_temperature: Double
    let is_day: Int
    let weather_code: Int
    let wind_speed_10m: Double
}
