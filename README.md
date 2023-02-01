# ScreenCaptureKit and AVAssetWriter

This repo is being used as a demonstration of a bug with AVAssetWriter when used in conjunction with ScreenCaptureKit. I could be doing something wrong here, but this code looks pretty similar to the code that is published by apple as their walkthrough https://developer.apple.com/documentation/screencapturekit/capturing_screen_content_in_macos


## The Error


If the error shows up on your machine, you should see about a thousand `Error writing video - The operation could not be completed` within seconds. 

Digging into the error gets you this, which is not particularly useful.

"Optional(Error Domain=AVFoundationErrorDomain Code=-11800 \"The operation could not be completed\" UserInfo={NSLocalizedFailureReason=An unknown error occurred (-12785), NSLocalizedDescription=The operation could not be completed, NSUnderlyingError=0x600000c066d0 {Error Domain=NSOSStatusErrorDomain Code=-12785 \"(null)\"}})"

Whats even weirder is that this code works here! https://github.com/garethpaul/ScreenRecorderMacOS - if you run this repo, it should work perfectly.
