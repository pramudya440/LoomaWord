import Foundation
import Darwin

let frameworksDir = (Bundle.main.bundlePath as NSString)
    .appendingPathComponent("Contents/Frameworks")
let dylibPath = (frameworksDir as NSString)
    .appendingPathComponent("libReaDeepLLib.dylib")

guard FileManager.default.fileExists(atPath: dylibPath) else {
    FileHandle.standardError.write("launcher: dylib not found at \(dylibPath)\n".data(using: .utf8)!)
    exit(1)
}

guard let handle = dlopen(dylibPath, RTLD_NOW | RTLD_GLOBAL) else {
    let err = dlerror().map { String(cString: $0) } ?? "unknown"
    FileHandle.standardError.write("launcher: dlopen failed: \(err)\n".data(using: .utf8)!)
    exit(1)
}

guard let sym = dlsym(handle, "reaDeepLMain") else {
    FileHandle.standardError.write("launcher: symbol reaDeepLMain not found\n".data(using: .utf8)!)
    exit(1)
}

typealias MainFn = @convention(c) () -> Void
let fn = unsafeBitCast(sym, to: MainFn.self)
fn()
