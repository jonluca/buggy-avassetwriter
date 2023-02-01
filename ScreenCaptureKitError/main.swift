//
//  main.swift
//  ScreenCaptureKitError
//
//  Created by JonLuca De Caro on 1/31/23.
//

import Foundation
import Cocoa

print("Starting")
Task {
    await MeetingController.shared.start(displayId: CGMainDisplayID())
}
let sweepTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
sweepTimer.schedule(deadline: .now() + .seconds(10), leeway: .milliseconds(200))
sweepTimer.setEventHandler {
    Task {
        await MeetingController.shared.stop()
        await NSApplication.shared.terminate(_: nil)
    }
}
sweepTimer.resume()
RunLoop.main.run()
print("Started")
