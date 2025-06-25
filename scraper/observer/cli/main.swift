import Foundation
import observer_lib
import SwiftRs

// Read token from environment variable
let token = ProcessInfo.processInfo.environment["TAURI_APP_TOKEN"] ?? "5a61fb62f5c9647396e592ac92441684"

setTokenAndUrl(
    token: SRString(token),
    url: SRString("http://localhost:5274"),
    appVersion: SRString("0.16.0")
)
run()

signal(SIGINT) { _ in
    print("\nReceived interrupt signal. Terminating...")
    exit(0)
}

while true {
    RunLoop.current.run(until: Date(timeIntervalSinceNow: 1))
}
