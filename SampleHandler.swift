import ReplayKit
import VideoToolbox
import UIKit

/// System-wide screen capture. This runs in a separate process with a hard
/// 50 MB memory cap, so everything here is deliberately lightweight:
/// we throttle hard, downscale aggressively, and never retain buffers.
class SampleHandler: RPBroadcastSampleHandler {

    private var lastWrite: TimeInterval = 0
    /// Seconds between kept frames. The app decides when to actually call the API;
    /// this just keeps a reasonably fresh frame on disk.
    private let minInterval: TimeInterval = 1.0

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        FrameBridge.setBroadcasting(true)
    }

    override func broadcastPaused() {
        FrameBridge.setBroadcasting(false)
    }

    override func broadcastResumed() {
        FrameBridge.setBroadcasting(true)
    }

    override func broadcastFinished() {
        FrameBridge.setBroadcasting(false)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer,
                                      with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }

        let now = Date().timeIntervalSince1970
        guard now - lastWrite >= minInterval else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        autoreleasepool {
            let ci = CIImage(cvPixelBuffer: pixelBuffer)

            // Downscale to ~900px on the long edge. Keeps text legible for OCR
            // while staying far under the extension's memory ceiling.
            let extent = ci.extent
            let longEdge = max(extent.width, extent.height)
            let target: CGFloat = 900
            let scale = longEdge > target ? target / longEdge : 1.0

            let scaled = scale < 1.0
                ? ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                : ci

            guard let cg = ciContext.createCGImage(scaled, from: scaled.extent) else { return }
            let image = UIImage(cgImage: cg)

            guard let jpeg = image.jpegData(compressionQuality: 0.6) else { return }

            FrameBridge.writeFrame(jpeg)
            lastWrite = now

            // Keep broadcast state fresh so the app knows we're alive
            FrameBridge.setBroadcasting(true)
        }
    }
}
