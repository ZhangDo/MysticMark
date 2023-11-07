import UIKit

//MARK: 隐写
func stegoImage(_ originalImage: UIImage, message: String) -> UIImage {
    let data = message.data(using: .utf8)!// 将要隐藏的文本转换为 UTF-8 编码的数据
    //将数据转换为位数据
    let bits = data.flatMap { byte in (0..<8).reversed().map { (byte >> $0) & 1 } }

    let width = Int(originalImage.size.width)
    let height = Int(originalImage.size.height)
    // 计算需要填充的位数
    let paddingCount = width * height * 3 - bits.count
    // 创建填充数组
    let paddingBits = Array(repeating: UInt8(0), count: paddingCount)
    // 填充位数据数组
    let paddedBits = bits + paddingBits
    
    // 设置每个组件的位数和字节顺序
    let bitsPerComponent = 8
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    
    // 创建设备 RGB 颜色空间
    let colorSpace = CGColorSpaceCreateDeviceRGB()

    let context = CGContext(data: nil,
                            width: width,
                            height: height,
                            bitsPerComponent: bitsPerComponent,
                            bytesPerRow: bytesPerRow,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // 从原始图像绘制到上下文中
    let cgImage = originalImage.cgImage!
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    // 遍历每个像素，将最后一位替换为要插入的位
    var index = 0
    for y in 0..<height {
        for x in 0..<width {
            // 获取像素的颜色
            var pixel = context.data!.advanced(by: y * bytesPerRow + x * bytesPerPixel).load(as: UInt32.self)
            // 将最后一位清零
            pixel &= 0xFFFFFFFE
            // 将最后一位设置为要插入的位
            pixel |= UInt32(paddedBits[index])
            // 将修改后的像素存储回上下文中
            context.data!.advanced(by: y * bytesPerRow + x * bytesPerPixel).storeBytes(of: pixel, as: UInt32.self)
            index += 1
        }
    }
    // 创建包含隐藏文本的图像
    let stegoImage = UIImage(cgImage: context.makeImage()!)
    return stegoImage
}

//MARK: 获取被隐写的文字
func extractedChinese(_ image: UIImage) -> String? {
    // 获取图像的宽度和高度
    let width = Int(image.size.width)
    let height = Int(image.size.height)
    
    // 设置每个组件的位数和字节顺序
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
    
    // 提取每个像素的最后一位
    let extractedBits = (0..<(width * height)).map { index in
        let x = index % width
        let y = index / width
        let pixel = context.data!.advanced(by: y * bytesPerRow + x * bytesPerPixel).load(as: UInt32.self)
        return Int(pixel & 1)
    }

    // 将提取的位数据转换为字节
    let extractedData = Data(extractedBits.chunked(into: 8).map { bytes in
        var byte: UInt8 = 0
        for (index, bit) in bytes.enumerated() {
            byte |= UInt8(bit << (7 - index))
        }
        return byte
    })

    // 将提取的字节数据转换为文本
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
