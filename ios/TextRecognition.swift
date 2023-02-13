import Vision

extension String {
    func stripPrefix(_ prefix: String) -> String {
        guard hasPrefix(prefix) else { return self }
        return String(dropFirst(prefix.count))
    }
}

@objc(TextRecognition)
class TextRecognition: NSObject {
    @objc(recognize:withOptions:withResolver:withRejecter:)
    func recognize(imgPath: String, options: [String: Float], resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard !imgPath.isEmpty else { reject("ERR", "You must include the image path", nil); return }
        
        let formattedImgPath = imgPath.stripPrefix("file://")
        var threshold: Float = 0.0
        
        if !(options["visionIgnoreThreshold"]?.isZero ?? true) {
            threshold = options["visionIgnoreThreshold"] ?? 0.0
        }
        
        do {
            let imgData = try Data(contentsOf: URL(fileURLWithPath: formattedImgPath))
            let image = UIImage(data: imgData)?.fixedOrientation();
            
            guard let cgImage = image?.cgImage else { return }
            let imgWidth = Double(cgImage.width)
            let imgHeight = Double(cgImage.height)
            
            let left:Double = 2.5 / 100.0 * imgWidth
            let top:Double = 40 / 100.0 * imgHeight
            let width:Double = 95 / 100.0 * imgWidth
            let height:Double = 15 / 100.0 * imgHeight
            
            let cropRect = CGRect(
                x: left,
                y: top,
                width: width,
                height: height
            ).integral
            
            let cropped = cgImage.cropping(
                to: cropRect
            )!
            
            let newImage = UIImage(cgImage: cropped);
            guard let newcgImage = newImage.cgImage else { return }
            
            let requestHandler = VNImageRequestHandler(cgImage: newcgImage)
            
            let ocrRequest = VNRecognizeTextRequest { (request: VNRequest, error: Error?) in
                self.recognizeTextHandler(request: request, threshold: threshold, error: error, resolve: resolve, reject: reject)
            }
            
            try requestHandler.perform([ocrRequest])
        } catch {
            print(error)
            reject("ERR", error.localizedDescription, nil)
        }
    }
    
    func recognizeTextHandler(request: VNRequest, threshold: Float, error _: Error?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        guard let observations = request.results as? [VNRecognizedTextObservation] else { reject("ERR", "No text recognized.", nil); return }
        
        let recognizedStrings = observations.compactMap { observation -> String? in
            if observation.topCandidates(1).first?.confidence ?? 0 >= threshold {
                return observation.topCandidates(1).first?.string
            } else {
                return nil
            }
        }
        
        resolve(recognizedStrings)
    }
}

extension UIImage {
    
    func fixedOrientation() -> UIImage? {
        
        guard imageOrientation != UIImage.Orientation.up else {
            //This is default orientation, don't need to do anything
            return self.copy() as? UIImage
        }
        
        guard let cgImage = self.cgImage else {
            //CGImage is not available
            return nil
        }
        
        guard let colorSpace = cgImage.colorSpace, let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil //Not able to create CGContext
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
            break
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
            break
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
            break
        case .up, .upMirrored:
            break
        }
        
        //Flip image one more time if needed to, this is to prevent flipped image
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            break
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        }
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(self.cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        guard let newCGImage = ctx.makeImage() else { return nil }
        let newImageToReturn = UIImage.init(cgImage: newCGImage, scale: 1, orientation: .up)
        return newImageToReturn
    }
}
