import Foundation
import AVFoundation

protocol Transcriber: AnyObject {
    func startSession(format: AVAudioFormat) throws
    func process(buffer: AVAudioPCMBuffer)
    func finishSession() async throws -> String
}
