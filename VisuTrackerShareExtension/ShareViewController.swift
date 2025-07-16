import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("VisuTracker: viewDidLoad called")
    }
    
    override func isContentValid() -> Bool {
        print("VisuTracker: isContentValid called")
        return true
    }
    
    override func didSelectPost() {
        print("VisuTracker: didSelectPost called")
        
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let itemProvider = extensionItem.attachments?.first else {
            print("VisuTracker: No extension item found")
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        
        if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                DispatchQueue.main.async {
                    if let url = item as? URL {
                        let urlString = url.absoluteString
                        print("VisuTracker: Got URL: \(urlString)")
                        
                        // UserDefaultsに保存
                        self?.saveURLToAppGroup(url: urlString)
                    } else {
                        print("VisuTracker: Failed to get URL")
                    }
                    
                    // 完了
                    self?.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                }
            }
        } else {
            print("VisuTracker: No URL type found")
            self.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    override func configurationItems() -> [Any]! {
        print("VisuTracker: configurationItems called")
        return []
    }
    
    private func saveURLToAppGroup(url: String) {
        let userDefaults = UserDefaults(suiteName: "group.work.rockets.VisuTracker2")
        
        var savedURLs = userDefaults?.array(forKey: "pendingURLs") as? [String] ?? []
        savedURLs.append(url)
        userDefaults?.set(savedURLs, forKey: "pendingURLs")
        userDefaults?.synchronize()
        
        print("VisuTracker: Saved to UserDefaults. Total URLs: \(savedURLs.count)")
    }
}
