import Foundation
import WhisperBarCore
import WhisperBarEngine

// whisperbar-cli download            — fetch + compile Parakeet v3 into the cache
// whisperbar-cli transcribe <file>   — transcribe an audio file and print the text

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: whisperbar-cli download | transcribe <audio-file>")
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
    default:
        print("usage: whisperbar-cli download | transcribe <audio-file>")
        exit(2)
    }
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
