import AVFoundation
import Foundation
import MynahCore
import MynahEngine

// mynah-cli download            — fetch + compile Parakeet v3 into the cache
// mynah-cli transcribe <file>   — transcribe an audio file and print the text

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: mynah-cli download | transcribe <audio-file>")
    exit(2)
}

let engine = ParakeetEngine()
do {
    let t0 = Date()
    try await engine.load { p in
        FileHandle.standardError.write(Data(String(format: "\rdownload %.0f%%", p * 100).utf8))
    }
    FileHandle.standardError.write(Data(String(format: "\nmodel ready in %.1fs at %@\n",
        Date().timeIntervalSince(t0), ParakeetEngine.modelDirectory.path).utf8))

    switch args[1] {
    case "download":
        break
    case "transcribe" where args.count >= 3:
        let t1 = Date()
        let raw = try await engine.transcribe(file: URL(fileURLWithPath: args[2]))
        print(TranscriptCleaner.clean(raw) ?? "")
        FileHandle.standardError.write(Data(String(format: "transcribed in %.2fs\n", Date().timeIntervalSince(t1)).utf8))
    case "live" where args.count >= 3:
        // Feed the file in 100 ms chunks at real-time speed and print live updates.
        guard var factory = await engine.liveSessions else { exit(1) }
        // WB_LIVE="chunk,left,right" overrides the window layout for experiments.
        if let spec = ProcessInfo.processInfo.environment["WB_LIVE"]?.split(separator: ",").compactMap({ Double($0) }),
           spec.count == 3 {
            (factory.chunk, factory.left, factory.right) = (spec[0], spec[1], spec[2])
        }
        let t0 = Date()
        let session = factory.start { text in
            print(String(format: "[%5.2fs] %@", Date().timeIntervalSince(t0), text))
        }
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: args[2]))
        let chunk = AVAudioFrameCount(file.processingFormat.sampleRate / 10)
        while file.framePosition < file.length {
            guard let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunk) else { break }
            try file.read(into: buf, frameCount: chunk)
            session.feed(buf)
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 1_500_000_000)
        await session.stop()
    default:
        print("usage: mynah-cli download | transcribe <audio-file>")
        exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
