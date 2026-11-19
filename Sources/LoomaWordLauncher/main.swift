import Foundation
import Cocoa
import LoomaWordLib

@MainActor
func main() {
    let app = NSApplication.shared
    let delegate = AppDelegate.shared
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}

main()
