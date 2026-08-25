import Foundation
import LyricXCore
import LyricXMac
@testable import LyricXApp

struct TestFailure: Error, CustomStringConvertible {
    let message: String
    let file: String
    let line: UInt

    var description: String {
        "\(file):\(line): \(message)"
    }
}

struct FailingLyricTranslationService: LyricTranslationService {
    func translationTimeline(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationTimeline {
        throw FailingLyricTranslationError()
    }
}

struct ConfiguredLyricTranslationService: LyricTranslationService {
    let translatedText: String

    func translationTimeline(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationTimeline {
        LyricTranslationTimeline(
            targetLanguage: targetLanguage,
            lines: sourceTimeline.lines.map { line in
                LyricTranslationLine(sourceLineID: line.id, time: line.time, translatedText: translatedText, romajiText: nil)
            }
        )
    }
}

struct FailingLyricTranslationError: LocalizedError {
    var errorDescription: String? { "translation unavailable" }
}

actor RecordingTranslationProvider: LyricTranslationProvider {
    let kind: TranslationProviderKind
    let result: LyricTranslationProviderResult?
    private(set) var callCount = 0

    init(kind: TranslationProviderKind, result: LyricTranslationProviderResult?) {
        self.kind = kind
        self.result = result
    }

    func translation(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationProviderResult? {
        callCount += 1
        return result
    }
}

struct ControlledLyricTranslationService: LyricTranslationService {
    let requests: ControlledTranslationRequests

    func translationTimeline(
        for track: PlaybackTrack,
        sourceTimeline: LyricTimeline,
        targetLanguage: TranslationLanguage,
        options: LyricTranslationProviderOptions
    ) async throws -> LyricTranslationTimeline {
        await requests.append(targetLanguage: targetLanguage, includeRomaji: options.includeRomaji)
    }
}

actor ControlledTranslationRequests {
    private struct Request {
        let targetLanguage: TranslationLanguage
        let includeRomaji: Bool
        let continuation: CheckedContinuation<LyricTranslationTimeline, Never>
    }

    private var requests: [Request] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func append(targetLanguage: TranslationLanguage, includeRomaji: Bool) async -> LyricTranslationTimeline {
        await withCheckedContinuation { continuation in
            requests.append(Request(targetLanguage: targetLanguage, includeRomaji: includeRomaji, continuation: continuation))
            resumeReadyWaiters()
        }
    }

    func waitForRequestCount(_ count: Int) async throws {
        if requests.count >= count {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append((count, continuation))
        }
    }

    func completeRequest(at index: Int, with timeline: LyricTranslationTimeline) {
        requests[index].continuation.resume(returning: timeline)
    }

    private func resumeReadyWaiters() {
        var remaining: [(Int, CheckedContinuation<Void, Never>)] = []
        for waiter in waiters {
            if requests.count >= waiter.0 {
                waiter.1.resume()
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
    }
}


final class ScriptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedScripts: [String] = []

    var scripts: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedScripts
    }

    func run(_ script: String) throws -> String {
        lock.lock()
        recordedScripts.append(script)
        lock.unlock()
        return ""
    }
}
