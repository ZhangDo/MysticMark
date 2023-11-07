import UIKit
import UniformTypeIdentifiers
import Photos

class ViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var activityView: UIActivityIndicatorView!
    @IBOutlet weak var resultView: UITextView!
    @IBOutlet weak var rightImageView: UIImageView!
    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var imageButton: UIButton!
    @IBOutlet weak var segment: UISegmentedControl!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let menuActions: [UIAction] = [UIAction(title: "选择照片", image: UIImage(systemName: "photo.fill"), handler: { [self] action in
            selectPhoto()
        }),UIAction(title: "拍照", image: UIImage(systemName: "camera.on.rectangle.fill"), handler: { [self] action in
            takePhoto()
        }),UIAction(title: "文件", image: UIImage(systemName: "camera.on.rectangle.fill"), handler: { [self] action in
            selectFile()
        })]
        imageButton.showsMenuAsPrimaryAction = true
        imageButton.menu = UIMenu(children: menuActions)
        
        
        segment.setAction(UIAction(title: "加密", handler: { [self] action in
            saveButton.isHidden = false
            textView.isHidden = false
            leftImageView.image = nil
            rightImageView.image = nil
            resultView.text = ""
        }), forSegmentAt: 0)
        segment.setAction(UIAction(title: "解密", handler: { [self] action in
            saveButton.isHidden = true
            textView.isHidden = true
            leftImageView.image = nil
            rightImageView.image = nil
            resultView.text = ""
        }), forSegmentAt: 1)
        
        
        let saveMenuActions: [UIAction] = [UIAction(title: "保存到相册", image: UIImage(systemName: "photo.fill"), handler: { [self] action in
            guard let image = self.rightImageView?.image else { return}
            PHPhotoLibrary.shared().performChanges({ [] in
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: image.pngData()!, options: nil)
            }, completionHandler: { success, error in
                if success {
                    print("图片保存成功！")
                } else {
                    print("图片保存失败：\(error!.localizedDescription)")
                }
            })
            
            
        }),UIAction(title: "保存到文件", image: UIImage(systemName: "camera.on.rectangle.fill"), handler: { [self] action in
            guard let image = self.rightImageView?.image else { return}
            export(image: image)
        })]
        saveButton.showsMenuAsPrimaryAction = true
        saveButton.menu = UIMenu(children: saveMenuActions)
    }
    
    func export(image: UIImage) {
        guard let imageData = image.pngData() else {
            return
        }
        
        let fileManager = FileManager.default

        do {
            let fileURL = fileManager.temporaryDirectory.appendingPathComponent("temp.png") // 3
            
            try imageData.write(to: fileURL)
                        
            if #available(iOS 14, *) {
                let controller = UIDocumentPickerViewController(forExporting: [fileURL]) // 5
                present(controller, animated: true)
            } else {
                let controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService) // 6
                present(controller, animated: true)
            }
        } catch {
            print("Error creating file")
        }
    }
    
    
    // MARK: - 选择照片
    func selectPhoto() {
        let picker = UIImagePickerController()
        picker.modalPresentationStyle = .overFullScreen
        picker.delegate = self
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            picker.sourceType = .photoLibrary
            self.present(picker, animated: true, completion: nil)
        } else {
            print("无权限")
        }
    }
    // MARK: - 拍照
    func takePhoto() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        imagePicker.allowsEditing = true
        present(imagePicker, animated: true, completion: nil)
    }
    
    // MARK: - 打开文件应用
    func selectFile() {
        let supportedTypes: [UTType] = [UTType.item]
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        self.present(documentPicker, animated: true, completion: nil)
    }


}

extension ViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) { [self] in
            let originalImage = info[UIImagePickerController.InfoKey.originalImage] as! UIImage
            leftImageView.image = originalImage
            activityView.startAnimating()
            if saveButton.isHidden {
                DispatchQueue.main.async { [self] in
                    let message = extractedChinese(originalImage) //获取被隐藏的文字
                    resultView.text = message
                    activityView.stopAnimating()
                }
            } else {
                DispatchQueue.main.async { [self] in
                    rightImageView.image = stegoImage(originalImage, message: textView.text)//写入文字
                    activityView.stopAnimating()
                }
            }
            
            
        }
        
    }
}

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(readingItemAt: urls.first!, error: nil) { newURL in
            do {
                let imageData = try Data(contentsOf: newURL)
                let originalImage = UIImage(data: imageData)
                
                leftImageView.image = originalImage
                if saveButton.isHidden {
                    DispatchQueue.main.async { [self] in
                        let message = extractedChinese(originalImage!) //获取被隐藏的文字
                        resultView.text = message
                        activityView.stopAnimating()
                    }
                } else {
                    DispatchQueue.main.async { [self] in
                        rightImageView.image = stegoImage(originalImage!, message: textView.text)//写入文字
                        activityView.stopAnimating()
                    }
                }
            } catch {
                print(error)
            }
        }
    }
    
    // UIDocumentPickerDelegate 方法，用户取消时调用
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        dismiss(animated: true, completion: nil)
    }
}


