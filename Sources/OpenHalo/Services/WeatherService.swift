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
        temperature: 22.0,
        apparentTemperature: 24.0,
        humidity: 60,
        windSpeed: 8.0,
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
    @Published public var cityName: String = "Locating..."

    // User coordinates (auto-detected via IP, or set via city search)
    @Published public var latitude: Double = 12.9716
    @Published public var longitude: Double = 77.5946

    private let userDefaultsCityKey = "openhalo.weather.cityName"
    private let userDefaultsLatKey = "openhalo.weather.latitude"
    private let userDefaultsLonKey = "openhalo.weather.longitude"

    private let cacheTTL: TimeInterval = 1200 // 20 minutes
    private var lastFetchTime: Date? = nil

    public init() {
        if let savedCity = UserDefaults.standard.string(forKey: userDefaultsCityKey),
           savedCity != "San Francisco" && !savedCity.isEmpty {
            self.cityName = savedCity
            self.latitude = UserDefaults.standard.double(forKey: userDefaultsLatKey)
            self.longitude = UserDefaults.standard.double(forKey: userDefaultsLonKey)
            Task {
                await fetchWeather()
            }
        } else {
            Task {
                await autoDetectLocation()
            }
        }
    }

    public func autoDetectLocation() async {
        isLoading = true
        errorMessage = nil

        // 1. Primary: ip-api.com
        if let url = URL(string: "http://ip-api.com/json/"),
           let (data, response) = try? await URLSession.shared.data(from: url),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let json = try? JSONDecoder().decode(IPLocationResponse.self, from: data),
           json.status.lowercased() == "success" {
            self.cityName = json.city
            self.latitude = json.lat
            self.longitude = json.lon
            saveLocation(name: json.city, lat: json.lat, lon: json.lon)
            await fetchWeather(force: true)
            return
        }

        // 2. Fallback: freeipapi.com
        if let fallbackURL = URL(string: "https://freeipapi.com/api/json"),
           let (data, response) = try? await URLSession.shared.data(from: fallbackURL),
           let http = response as? HTTPURLResponse, http.statusCode == 200,
           let json = try? JSONDecoder().decode(FreeIPLocationResponse.self, from: data) {
            let name = json.cityName.isEmpty ? "Current Location" : json.cityName
            self.cityName = name
            self.latitude = json.latitude
            self.longitude = json.longitude
            saveLocation(name: name, lat: json.latitude, lon: json.longitude)
            await fetchWeather(force: true)
            return
        }

        // 3. Fallback to existing or Bengaluru
        if self.cityName == "Locating..." {
            self.cityName = "Bengaluru"
            self.latitude = 12.9716
            self.longitude = 77.5946
        }
        await fetchWeather(force: true)
    }

    public func searchAndSetCity(_ query: String) async -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                isLoading = false
                return false
            }

            let geo = try JSONDecoder().decode(OpenMeteoGeoResponse.self, from: data)
            if let first = geo.results?.first {
                self.cityName = first.name
                self.latitude = first.latitude
                self.longitude = first.longitude
                saveLocation(name: first.name, lat: first.latitude, lon: first.longitude)
                await fetchWeather(force: true)
                return true
            }
        } catch {
            self.errorMessage = "City not found"
            self.isLoading = false
        }
        return false
    }

    private func saveLocation(name: String, lat: Double, lon: Double) {
        UserDefaults.standard.set(name, forKey: userDefaultsCityKey)
        UserDefaults.standard.set(lat, forKey: userDefaultsLatKey)
        UserDefaults.standard.set(lon, forKey: userDefaultsLonKey)
    }

    public func setLocation(name: String, lat: Double, lon: Double) {
        self.cityName = name
        self.latitude = lat
        self.longitude = lon
        saveLocation(name: name, lat: lat, lon: lon)
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

// Schemas
private struct IPLocationResponse: Codable {
    let status: String
    let city: String
    let lat: Double
    let lon: Double
}

private struct FreeIPLocationResponse: Codable {
    let cityName: String
    let latitude: Double
    let longitude: Double
}

private struct OpenMeteoGeoResponse: Codable {
    let results: [GeoCityResult]?
}

private struct GeoCityResult: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
}

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
