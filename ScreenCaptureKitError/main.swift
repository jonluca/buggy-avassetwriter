//
//  main.swift
//  ScreenCaptureKitError
//
//  Created by JonLuca De Caro on 1/31/23.
//

import Foundation
import Cocoa

print("Starting")
await MeetingController.shared.start(displayId: CGMainDisplayID())
print("Started")
