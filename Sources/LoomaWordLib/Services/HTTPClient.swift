import Foundation

/// Minimal HTTP helper shared by all engines.
///
/// Provides an explicit timeout plus retry with exponential backoff for transient
/// failures (429 / 5xx). Client errors (400 / 401 / 403 / 404 / 456 …) are never retried.
public enum HTTPClient {

    public struct Response {
        public let data: Data
        public let statusCode: Int
        public let headers: [AnyHashable: Any]
    }

    public enum ClientError: Error, LocalizedError {
        case http(status: Int, body: String, retryAfter: TimeInterval?)
        case network(String)

        public var errorDescription: String? {
            switch self {
            case .http(let status, let body, _):
                return "HTTP \(status): \(body)"
            case .network(let message):
                return message
            }
        }
    }

    /// Perform a request, retrying transient failures.
    /// - Parameters:
    ///   - maxAttempts: total attempts including the first one.
    ///   - retryOnStatus: statuses considered transient (defaults to 429 and 5xx).
    public static func send(
        _ request: URLRequest,
        timeout: TimeInterval = 30,
        maxAttempts: Int = 3,
        retryOnStatus: Set<Int> = [429, 500, 502, 503, 504]
    ) async throws -> Response {
        var attempt = 0
        var lastError: Error = ClientError.network("no attempt made")

        while attempt < maxAttempts {
            attempt += 1
            var req = request
            req.timeoutInterval = timeout

            do {
                let (data, response) = try await URLSession.shared.data(for: req)
                guard let http = response as? HTTPURLResponse else {
                    throw ClientError.network("Respons jaringan tidak valid.")
                }
                if retryOnStatus.contains(http.statusCode) && attempt < maxAttempts {
                    let retryAfter = retryAfterSeconds(from: http.allHeaderFields)
                    lastError = ClientError.http(
                        status: http.statusCode,
                        body: truncate(data),
                        retryAfter: retryAfter
                    )
                    try await Task.sleep(nanoseconds: UInt64(backoffSeconds(attempt: attempt, retryAfter: retryAfter) * 1_000_000_000))
                    continue
                }
                return Response(data: data, statusCode: http.statusCode, headers: http.allHeaderFields)
            } catch let error as ClientError {
                lastError = error
                if case .http = error { throw error }
                guard attempt < maxAttempts else { throw error }
                try await Task.sleep(nanoseconds: UInt64(backoffSeconds(attempt: attempt, retryAfter: nil) * 1_000_000_000))
            } catch {
                // Transport-level failure (timeout, connection lost) — retry.
                lastError = ClientError.network(error.localizedDescription)
                guard attempt < maxAttempts else { throw lastError }
                try await Task.sleep(nanoseconds: UInt64(backoffSeconds(attempt: attempt, retryAfter: nil) * 1_000_000_000))
            }
        }
        throw lastError
    }

    static func backoffSeconds(attempt: Int, retryAfter: TimeInterval?) -> Double {
        if let retryAfter { return min(max(retryAfter, 0), 30) }
        // 0.5s, 1s, 2s … capped at 8s, with a little jitter.
        let base = min(0.5 * pow(2, Double(attempt - 1)), 8)
        return base + Double.random(in: 0...0.25)
    }

    static func retryAfterSeconds(from headers: [AnyHashable: Any]) -> TimeInterval? {
        guard let raw = headers["Retry-After"] as? String ?? headers["retry-after"] as? String else { return nil }
        return TimeInterval(raw.trimmingCharacters(in: .whitespaces))
    }

    /// Error bodies can be huge HTML/JSON blobs — keep messages readable.
    static func truncate(_ data: Data, limit: Int = 300) -> String {
        guard let text = String(data: data, encoding: .utf8) else { return "HTTP error" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= limit { return trimmed }
        return String(trimmed.prefix(limit)) + "…"
    }

    /// Build a GET URL with correct percent-encoding.
    ///
    /// `URLComponents.queryItems` leaves `+` and `?` literal, which corrupts queries
    /// (`+` is read as a space by servers). We encode manually with a set that excludes
    /// `&`, `+`, `=`, `?`, `#` and `%` so reserved characters are always escaped.
    public static func url(base: String, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(string: base) else { return nil }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#%")

        let encoded = queryItems.map { item -> String in
            let name = item.name.addingPercentEncoding(withAllowedCharacters: allowed) ?? item.name
            guard let value = item.value else { return name }
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(name)=\(v)"
        }
        components.percentEncodedQuery = encoded.joined(separator: "&")
        return components.url
    }
}
