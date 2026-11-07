// Generates the synthetic "field" video used as the mock glasses feed.
// Usage: swift scripts/make-mock-feed.swift out.mp4
// MockDeviceKit only accepts H.265/HEVC video, so the feed is encoded as HEVC.
import AVFoundation
import CoreGraphics
import Foundation
let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.removeItem(at: out)
let w = 504, h = 896, fps: Int32 = 30, seconds = 20
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: w, AVVideoHeightKey: h])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)
for i in 0..<(Int(fps) * seconds) {
  while !input.isReadyForMoreMediaData { usleep(1000) }
  var pb: CVPixelBuffer?; CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
  CVPixelBufferLockBaseAddress(pb!, [])
  let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb!), width: w, height: h, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
  ctx.setFillColor(CGColor(red: 0.1, green: 0.45, blue: 0.15, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
  ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
  for y in stride(from: 60, to: h, by: 120) { ctx.fill(CGRect(x: 0, y: y, width: w, height: 4)) }
  let x = CGFloat((i * 6) % w); ctx.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1)); ctx.fillEllipse(in: CGRect(x: x, y: CGFloat(h/2), width: 40, height: 40))
  CVPixelBufferUnlockBaseAddress(pb!, [])
  adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
}
input.markAsFinished(); let sem = DispatchSemaphore(value: 0); writer.finishWriting { sem.signal() }; sem.wait()
print(writer.status == .completed ? "ok" : "fail \(String(describing: writer.error))")
