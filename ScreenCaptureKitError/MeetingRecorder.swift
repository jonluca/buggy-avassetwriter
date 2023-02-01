//
// Created by JonLuca De Caro on 1/31/23.
// Copyright (c) 2023 Apple. All rights reserved.
//

import Foundation
import SwiftUI
import OSLog
import AVFoundation

class MeetingRecorder {

    private(set) var assetWriter: AVAssetWriter?

    private var assetWriterVideoInput: AVAssetWriterInput?

    private var assetWriterAudioInput: AVAssetWriterInput?

    private(set) var isRecording = false

    init() {}

    private func getNextAudioPath() -> URL {
        let now = Date()
        let formatter = Constants.dateFormatter
        let formatted = formatter.string(from: now).split(separator: "/")
        let dir = String(formatted[0])
        let file = String(formatted[1])
        let audioDir = Constants.audioDirectory()
        let directoryURL = audioDir.appendingPathComponent(dir)
        Constants.ensureDirectory(dir: directoryURL)
        return directoryURL.appendingPathComponent(file).appendingPathExtension("mov")
    }

    func startRecording(height: Int, width: Int) {
        // Create an asset writer that records to a temporary file
        let filePath = getNextAudioPath()
        guard let assetWriter = try? AVAssetWriter(url: filePath, fileType: .mov) else {
            return
        }

        // Add an audio input
        // Add an audio input
        let audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ] as [String: Any]

        let assetWriterAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        assetWriterAudioInput.expectsMediaDataInRealTime = true
        assetWriter.add(assetWriterAudioInput)

        let videoSettings = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ] as [String: Any]

        // Add a video input
        let assetWriterVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        assetWriterVideoInput.expectsMediaDataInRealTime = true
        assetWriter.add(assetWriterVideoInput)

        self.assetWriter = assetWriter
        self.assetWriterAudioInput = assetWriterAudioInput
        self.assetWriterVideoInput = assetWriterVideoInput
        isRecording = true
    }

    func stopRecording() async -> URL? {
        guard let assetWriter = assetWriter else {
            return nil
        }

        self.isRecording = false
        self.assetWriter = nil

        await assetWriter.finishWriting()
        return assetWriter.outputURL
    }

    func recordVideo(sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let assetWriter = assetWriter
        else {
            return
        }

        if assetWriter.status == .unknown {
            assetWriter.startWriting()
            assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        } else if assetWriter.status == .writing {
            if let input = assetWriterVideoInput,
               input.isReadyForMoreMediaData {
                input.append(sampleBuffer)
            }
        } else {
            logger.error("Error writing video - \(assetWriter.error?.localizedDescription ?? "Unknown error")")
        }
    }
    
    let logger = Logger()


    func recordAudio(sampleBuffer: CMSampleBuffer) {
        guard isRecording,
              let assetWriter = assetWriter,
              assetWriter.status == .writing,
              let input = assetWriterAudioInput,
              input.isReadyForMoreMediaData
        else {
            return
        }

        input.append(sampleBuffer)
    }
}
