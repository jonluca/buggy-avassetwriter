//
// Created by JonLuca De Caro on 1/31/23.
// Copyright (c) 2023 Apple. All rights reserved.
//

import Foundation
import ScreenCaptureKit
import Combine
import OSLog
class MeetingController: ObservableObject {
    private let captureEngine = CaptureEngine()
    var meetingRecorder: MeetingRecorder = MeetingRecorder()
    let logger = Logger()
    var startTime = Date()
    var isRunning = false
    private var availableApps = [SCRunningApplication]()
    private(set) var availableDisplays = [SCDisplay]()
    private(set) var availableWindows = [SCWindow]()
    private var isSetup = false

    static let shared = MeetingController()
    private init() {
        Task {
            await monitorAvailableContent()
        }
    }

    @Published var selectedDisplay: SCDisplay? {
        didSet {
            updateEngine()
        }
    }

    var canRecord: Bool {
        get async {
            do {
                // If the app doesn't have Screen Recording permission, this call generates an exception.
                try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                return true
            } catch {
                return false
            }
        }
    }

    private func updateEngine() {
        guard isRunning else {
            return
        }
        Task {
            await captureEngine.update(configuration: streamConfiguration, filter: contentFilter)
        }
    }

    func monitorAvailableContent() async {
        guard !isSetup else {
            return
        }
        // Refresh the lists of capturable content.
        await self.refreshAvailableContent()
    }

    private var contentFilter: SCContentFilter {
        let excludedApps = availableApps.filter { app in
            !Constants.excludedApps.contains(app.bundleIdentifier)
        }
        let filter: SCContentFilter = SCContentFilter(display: availableDisplays.first!,
                                                      excludingApplications: excludedApps,
                                                      exceptingWindows: [])
        return filter
    }

    private func refreshAvailableContent() async {
        do {
            // Retrieve the available screen content to capture.
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false,
                                                                                        onScreenWindowsOnly: true)
            availableDisplays = availableContent.displays
            availableWindows = availableContent.windows
            availableApps = availableContent.applications

        } catch {
            logger.error("Failed to get the shareable content: \(error.localizedDescription)")
        }
    }

    private var scaleFactor: Int {
        Int(NSScreen.main?.backingScaleFactor ?? 2)
    }

    private var streamConfiguration: SCStreamConfiguration {

        let streamConfig = SCStreamConfiguration()

        // Configure audio capture.
        streamConfig.capturesAudio = true
        streamConfig.excludesCurrentProcessAudio = true

        // Configure the display content width and height.
        if let display = selectedDisplay {
            streamConfig.width = display.width * scaleFactor
            streamConfig.height = display.height * scaleFactor
        }

        // Set the capture interval at 60 fps.
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)

        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        streamConfig.queueDepth = 5

        return streamConfig
    }

    /// Starts capturing screen content.
    func start(displayId: CGDirectDisplayID) async {
        // Exit early if already running.
        guard !isRunning else {
            return
        }
        startTime = Date()

        if !isSetup {
            // Starting polling for available screen content.
            await monitorAvailableContent()
            isSetup = true
        }

        selectedDisplay = availableDisplays.filter { display in
                    display.displayID == displayId
                }
                .first ?? availableDisplays.first
        let config = streamConfiguration
        let filter = contentFilter
        isRunning = true
        captureEngine.startCapture(configuration: config, filter: filter, meetingRecorder: meetingRecorder)
    }

    /// Stops capturing screen content.
    func stop() async {
        guard isRunning else {
            return
        }
        await captureEngine.stopCapture()
        isRunning = false
    }
}

/// An object that wraps an instance of `SCStream`, and returns its results as an `AsyncThrowingStream`.
class CaptureEngine: NSObject, @unchecked Sendable {

    var meetingRecorder: MeetingRecorder?

    private var stream: SCStream?
    private let videoSampleBufferQueue = DispatchQueue(label: "com.example.apple-samplecode.VideoSampleBufferQueue")
    private let audioSampleBufferQueue = DispatchQueue(label: "com.example.apple-samplecode.AudioSampleBufferQueue")

    private var startTime = Date()

    /// - Tag: StartCapture
    func startCapture(configuration: SCStreamConfiguration, filter: SCContentFilter, meetingRecorder: MeetingRecorder) {
        // The stream output object.
        let streamOutput = CaptureEngineStreamOutput()
        streamOutput.recorder = meetingRecorder
        self.meetingRecorder = streamOutput.recorder!
        self.startTime = Date()
        self.meetingRecorder!.startRecording(height: Int(configuration.height), width: Int(configuration.width))

        do {
            stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput)

            // Add a stream output to capture screen content.
            try stream?.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
            try stream?.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)

            stream?.startCapture()
        } catch {
            logger.error("Failed to start the stream session: \(String(describing: error))")
        }
    }

    @discardableResult func stopCapture() async -> URL? {
        do {
            try await stream?.stopCapture()
        } catch {
            logger.error("Failed to stop the stream session: \(String(describing: error))")
        }
        return await meetingRecorder!.stopRecording()
    }
    
    let logger = Logger()

    /// - Tag: UpdateStreamConfiguration
    func update(configuration: SCStreamConfiguration, filter: SCContentFilter) async {
        do {
            try await stream?.updateConfiguration(configuration)
            try await stream?.updateContentFilter(filter)
        } catch {
            logger.error("Failed to update the stream session: \(String(describing: error))")
        }
    }
}

/// A class that handles output from an SCStream, and handles stream errors.
private class CaptureEngineStreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
    var recorder: MeetingRecorder?

    /// - Tag: DidOutputSampleBuffer
    func stream(_ stream: SCStream,
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                of outputType: SCStreamOutputType) {

        // Return early if the sample buffer is invalid.
        guard sampleBuffer.isValid else {
            return
        }
        switch outputType {
        case .screen:
            recorder?.recordVideo(sampleBuffer: sampleBuffer)
        case .audio:
            recorder?.recordAudio(sampleBuffer: sampleBuffer)
        @unknown default:
            fatalError("Encountered unknown stream output type: \(outputType)")
        }
    }
    let logger = Logger()

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        logger.error("Encountered an error while capturing: \(error)")
    }
}
