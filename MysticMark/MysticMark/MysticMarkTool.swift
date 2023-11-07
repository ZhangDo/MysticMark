import UIKit

//MARK: 隐写
func stegoImage(_ originalImage: UIImage, message: String) -> UIImage {
    let data = message.data(using: .utf8)!
    let bits = data.flatMap { byte in (0..<8).reversed().map { (byte >> $0) & 1 } }

    let width = Int(originalImage.size.width)
    let height = Int(originalImage.size.height)
    
    let paddingCount = width * height * 3 - bits.count // 计算需要填充数量
    let paddingBits = Array(repeating: UInt8(0), count: paddingCount)
    let paddedBits = bits + paddingBits // 填充数组

    let bitsPerComponent = 8
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    let context = CGContext(data: nil,
                            width: width,
                            height: height,
                            bitsPerComponent: bitsPerComponent,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                            
    let cgImage = originalImage.cgImage!
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var index = 0
    for y in 0..<height {
        for x in 0..<width {
            var pixel = context.data!.advanced(by: y * bytesPerRow + x * bytesPerPixel).load(as: UInt32.self)
            pixel &= 0xFFFFFFFE // 将最后一位清零
            pixel |= UInt32(paddedBits[index]) // 将最后一位设置为要插入的位
            context.data!.advanced(by: y * bytesPerRow + x * bytesPerPixel).storeBytes(of: pixel, as: UInt32.self)
            index += 1
        }
    }
    let stegoImage = UIImage(cgImage: context.makeImage()!)
    return stegoImage
}

//MARK: 获取被隐写的文字
func extractedChinese(_ image: UIImage) -> String? {
    let width = Int(image.size.width)
    let height = Int(image.size.height)
    
    ///bitsPerCom 8 位
    let bitsPerComponent = 8
    let bytesPerPixel = 4
    let _ = bytesPerPixel * bitsPerComponent
    let bytesPerRow = bytesPerPixel * width
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    let context = CGContext(data: nil,
                            width: width,
                            height: height,
                            bitsPerComponent: bitsPerComponent,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                            
    let cgImage = image.cgImage!
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
    
    let extractedBits = (0..<(width * height)).map { index in
        let x = index % width
        let y = index / width
        let pixel = context.data!.advanced(by: y * bytesPerRow + x * bytesPerPixel).load(as: UInt32.self)
        return Int(pixel & 1)
    }

    let extractedData = Data(extractedBits.chunked(into: 8).map { bytes in
        var byte: UInt8 = 0
        for (index, bit) in bytes.enumerated() {
            byte |= UInt8(bit << (7 - index))
        }
        return byte
    })

    let extractedChinese = String(data: extractedData, encoding: .utf8)
    return extractedChinese
}

//将一个数组切分为多个指定大小的子数组。在这里，它被用来将提取出的数组分成了 8 个一组，以便将它们转换为字节。
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}


// 获取像素颜色
extension CGContext {
    
    func pixelColor(x: Int, y: Int) -> UIColor {
        let data = self.data!.assumingMemoryBound(to: UInt8.self)
        let offset = 4 * (x + y * Int(self.width))
        let alpha = CGFloat(data[offset]) / 255.0
        let red = CGFloat(data[offset+1]) / 255.0
        let green = CGFloat(data[offset+2]) / 255.0
        let blue = CGFloat(data[offset+3]) / 255.0
        
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    func setPixelColor(_ color: UIColor, x: Int, y: Int) {
        var alpha: CGFloat = 0
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let data = self.data!.assumingMemoryBound(to: UInt8.self)
        let offset = 4 * (x + y * Int(self.width))
        
        data[offset] = UInt8(alpha * 255.0)
        data[offset+1] = UInt8(red * 255.0)
        data[offset+2] = UInt8(green * 255.0)
        data[offset+3] = UInt8(blue * 255.0)
    }
}
