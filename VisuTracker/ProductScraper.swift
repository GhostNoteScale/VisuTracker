import Foundation
import SwiftUI
import CoreData

// ZOZOTOWN商品情報取得クラス
class ZOZOProductScraper {
    
    struct ProductInfo {
        let name: String?
        let price: String?
        let imageURL: String?
        let brand: String?
        let originalURL: String
        let size: String?           // 新規追加
        let description: String?    // 新規追加
        let color: String?          // 新規追加
        let salePrice: String?      // 新規追加
        let originalPrice: String?  // 新規追加
    }
    
    // メイン取得関数
    static func fetchProductInfo(from urlString: String) async -> ProductInfo? {
        guard let url = URL(string: urlString),
              url.host?.contains("zozo.jp") == true else {
            print("Invalid ZOZO URL: \(urlString)")
            return ProductInfo(
                name: nil,
                price: nil,
                imageURL: nil,
                brand: nil,
                originalURL: urlString,
                size: nil,
                description: nil,
                color: nil,
                salePrice: nil,
                originalPrice: nil
            )
        }
        
        // 複数の方法を試行
        var productInfo: ProductInfo?
        
        // 方法1: 通常のHTTPリクエスト
        productInfo = await fetchViaHTTP(url: url, originalURL: urlString)
        if productInfo?.name != nil { return productInfo }
        
        // 方法2: モバイル版URL
        productInfo = await fetchViaMobile(url: url, originalURL: urlString)
        if productInfo?.name != nil { return productInfo }
        
        // 方法3: URLから商品IDを抽出して構築
        productInfo = await fetchViaProductID(url: url, originalURL: urlString)
        if productInfo?.name != nil { return productInfo }
        
        print("すべての方法で取得に失敗しました")
        return ProductInfo(
            name: nil,
            price: nil,
            imageURL: nil,
            brand: nil,
            originalURL: urlString,
            size: nil,
            description: nil,
            color: nil,
            salePrice: nil,
            originalPrice: nil
        )
    }
    
    // 方法1: 通常のHTTPリクエスト（改良版）
    private static func fetchViaHTTP(url: URL, originalURL: String) async -> ProductInfo? {
        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("ja-JP,ja;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
            request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
            request.setValue("navigate", forHTTPHeaderField: "Sec-Fetch-Mode")
            request.setValue("document", forHTTPHeaderField: "Sec-Fetch-Dest")
            request.setValue("?1", forHTTPHeaderField: "Sec-Fetch-User")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Method 1 - HTTP Status: \(httpResponse.statusCode)")
            }
            
            let html = String(data: data, encoding: .utf8) ?? ""
            print("Method 1 - HTML取得成功、サイズ: \(html.count)文字")
            
            if html.count > 1000 {
                return parseZOZOHTML(html: html, originalURL: originalURL)
            }
            
        } catch {
            print("Method 1 - エラー: \(error)")
        }
        
        return ProductInfo(
            name: nil,
            price: nil,
            imageURL: nil,
            brand: nil,
            originalURL: originalURL,
            size: nil,
            description: nil,
            color: nil,
            salePrice: nil,
            originalPrice: nil
        )
    }
    
    // 方法2: モバイル版URLでアクセス
    private static func fetchViaMobile(url: URL, originalURL: String) async -> ProductInfo? {
        // モバイル版URLに変換
        var mobileURLString = url.absoluteString
        if !mobileURLString.contains("m.zozo.jp") {
            mobileURLString = mobileURLString.replacingOccurrences(of: "zozo.jp", with: "m.zozo.jp")
        }
        
        guard let mobileURL = URL(string: mobileURLString) else { return nil }
        
        do {
            var request = URLRequest(url: mobileURL)
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Method 2 - Mobile HTTP Status: \(httpResponse.statusCode)")
            }
            
            let html = String(data: data, encoding: .utf8) ?? ""
            print("Method 2 - Mobile HTML取得成功、サイズ: \(html.count)文字")
            
            if html.count > 1000 {
                return parseZOZOHTML(html: html, originalURL: originalURL)
            }
            
        } catch {
            print("Method 2 - Mobile エラー: \(error)")
        }
        
        return ProductInfo(
            name: nil,
            price: nil,
            imageURL: nil,
            brand: nil,
            originalURL: originalURL,
            size: nil,
            description: nil,
            color: nil,
            salePrice: nil,
            originalPrice: nil
        )
    }
    
    // 方法3: URLから商品情報を推測（改良版）
    private static func fetchViaProductID(url: URL, originalURL: String) async -> ProductInfo? {
        print("Method 3 - URLから商品情報を抽出中: \(url.absoluteString)")
        
        let urlString = url.absoluteString
        var productName: String?
        var productID: String?
        var shopName: String?
        var isOnSale = false
        
        // ショップ名を抽出
        if let shopMatch = urlString.range(of: #"/shop/([^/]+)"#, options: .regularExpression) {
            let match = String(urlString[shopMatch])
            if let nameRange = match.range(of: #"(?<=/shop/)[^/]+"#, options: .regularExpression) {
                shopName = String(match[nameRange])
            }
        }
        
        // 商品IDを抽出（複数パターン対応）
        let idPatterns = [
            #"/goods-sale/(\d+)"#,
            #"/goods/(\d+)"#,
            #"goods[^/]*/(\d+)"#
        ]
        
        for pattern in idPatterns {
            if let match = urlString.range(of: pattern, options: .regularExpression) {
                let matchString = String(urlString[match])
                if let idRange = matchString.range(of: #"\d+"#, options: .regularExpression) {
                    productID = String(matchString[idRange])
                    if pattern.contains("sale") {
                        isOnSale = true
                    }
                    break
                }
            }
        }
        
        // 商品名を構築
        if let shop = shopName, let id = productID {
            let saleText = isOnSale ? "【セール】" : ""
            let shopDisplayName = formatShopName(shop)
            productName = "\(saleText)\(shopDisplayName) - 商品ID: \(id)"
            
            print("Method 3 - 構築された商品名: \(productName!)")
            print("Method 3 - ショップ: \(shopDisplayName), ID: \(id), セール: \(isOnSale)")
            
            // 画像URLを検証して取得
            print("🔍 画像取得処理を開始します...")
            let validImageURL = await findValidImageURL(productID: id)
            print("🖼️ 最終的な画像URL: \(validImageURL ?? "nil")")
            
            let productInfo = ProductInfo(
                name: productName,
                price: isOnSale ? "セール価格" : nil,
                imageURL: validImageURL,
                brand: shopDisplayName,
                originalURL: originalURL,
                size: extractSizeFromURL(originalURL),
                description: nil,
                color: nil,
                salePrice: isOnSale ? "セール価格" : nil,
                originalPrice: nil
            )
            
            print("📦 作成されたProductInfo:")
            print("  - name: \(productInfo.name ?? "nil")")
            print("  - price: \(productInfo.price ?? "nil")")
            print("  - imageURL: \(productInfo.imageURL ?? "nil")")
            print("  - brand: \(productInfo.brand ?? "nil")")
            
            return productInfo
        }
        
        print("Method 3 - 商品情報の構築に失敗")
        return ProductInfo(
            name: nil,
            price: nil,
            imageURL: nil,
            brand: nil,
            originalURL: originalURL,
            size: nil,
            description: nil,
            color: nil,
            salePrice: nil,
            originalPrice: nil
        )
    }
    
    // 有効な画像URLを見つける（実画像対応強化版）
    private static func findValidImageURL(productID: String) async -> String? {
        let imageURLCandidates = [
            // パターン1: ZOZO公式CDN（最新形式）
            "https://c.imgz.jp/\(productID)/\(productID)_1_D_500.jpg",
            "https://c.imgz.jp/\(productID)/\(productID)_B_01_500.jpg",
            "https://c.imgz.jp/\(productID)/\(productID)_1_D_300.jpg",
            
            // パターン2: 従来のZOZO画像サーバー
            "https://img.zozo.jp/goodsimages/\(productID)/\(productID)_1_D_500.jpg",
            "https://img.zozo.jp/goodsimages/\(productID)/\(productID)_B_01_500.jpg",
            "https://img.zozo.jp/goodsimages/\(productID)/\(productID)_1_D_300.jpg",
            
            // パターン3: 商品ページから抽出
            "https://zozo.jp/shop/goods/\(productID)/image/\(productID)_1.jpg",
            
            // パターン4: フォールバック - 洋服アイコン
            "https://img.icons8.com/color/300/clothes.png",
            "https://img.icons8.com/color/300/t-shirt.png"
        ]
        
        print("画像URL検証開始（商品ID: \(productID)）")
        
        // 実際の商品画像を優先的にテスト
        for (index, imageURL) in imageURLCandidates.enumerated() {
            if index < imageURLCandidates.count - 2 { // 実画像をテスト
                print("🔍 商品画像テスト中 (パターン\(index + 1)): \(imageURL)")
                if await isImageURLValid(imageURL) {
                    print("✅ 商品画像発見! \(imageURL)")
                    return imageURL
                }
            } else { // フォールバック
                print("👕 洋服アイコンを使用: \(imageURL)")
                return imageURL
            }
        }
        
        return imageURLCandidates.last
    }
    
    // 画像URLが有効かチェック（統合版）
    private static func isImageURLValid(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 3.0 // 3秒タイムアウト
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
            request.setValue("image/webp,image/apng,image/jpeg,image/png,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
            request.setValue("https://zozo.jp", forHTTPHeaderField: "Referer")
            request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
            request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                let isValid = httpResponse.statusCode == 200
                print("📊 画像URL検証結果: \(httpResponse.statusCode) - \(isValid ? "有効" : "無効")")
                return isValid
            }
            
            return false
        } catch {
            print("❌ 画像URL検証エラー: \(error.localizedDescription)")
            return false
        }
    }
    
    // URLからサイズ情報を抽出
    private static func extractSizeFromURL(_ url: String) -> String? {
        // URLパラメータからサイズ情報を抽出
        if let sizeMatch = url.range(of: #"size=([^&]*)"#, options: .regularExpression) {
            let match = String(url[sizeMatch])
            if let valueRange = match.range(of: #"(?<=size=)[^&]*"#, options: .regularExpression) {
                return String(match[valueRange])
            }
        }
        return nil
    }
    
    // ショップ名を読みやすく整形
    private static func formatShopName(_ shopName: String) -> String {
        let shopDisplayNames: [String: String] = [
            "multisize": "MULTISIZE",
            "diavel": "Diavel",
            "bonjoursagan": "Bonjour Sagan",
            "uniqlo": "ユニクロ",
            "gu": "GU",
            "beams": "BEAMS",
            "ships": "SHIPS",
            "urbanresearch": "URBAN RESEARCH",
            "nanamica": "nanamica",
            "tomorrowland": "TOMORROWLAND",
            "studious": "STUDIOUS",
            "nano": "nano・universe",
            "journal": "JOURNAL STANDARD",
            "freak": "FREAK'S STORE"
        ]
        
        return shopDisplayNames[shopName.lowercased()] ?? shopName.uppercased()
    }
    
    // HTML解析関数
    private static func parseZOZOHTML(html: String, originalURL: String) -> ProductInfo {
        var productName: String?
        var price: String?
        var imageURL: String?
        var brand: String?
        
        // デバッグ用：HTMLの一部を出力
        print("HTML取得成功、サイズ: \(html.count)文字")
        
        // 商品名を抽出（複数のパターンに対応）
        productName = extractProductName(from: html)
        print("商品名抽出結果: \(productName ?? "nil")")
        
        // 価格を抽出
        price = extractPrice(from: html)
        print("価格抽出結果: \(price ?? "nil")")
        
        // 画像URLを抽出
        imageURL = extractImageURL(from: html)
        print("画像URL抽出結果: \(imageURL ?? "nil")")
        
        // ブランド名を抽出
        brand = extractBrand(from: html)
        
        return ProductInfo(
            name: productName,
            price: price,
            imageURL: imageURL,
            brand: brand,
            originalURL: originalURL,
            size: extractSizeFromURL(originalURL),
            description: nil,
            color: nil,
            salePrice: price,
            originalPrice: nil
        )
    }
    
    // 商品名抽出（ZOZOTOWNに特化）
    private static func extractProductName(from html: String) -> String? {
        // ZOZOTOWNの新しいパターンを追加
        let namePatterns = [
            // パターン1: og:title（最も確実）
            #"<meta\s+property=["\']og:title["\']\s+content=["\']([^"\']*)["\']"#,
            // パターン2: titleタグ
            #"<title>([^<]*?)\s*\|\s*ZOZOTOWN"#,
            #"<title>([^<]*)</title>"#,
            // パターン3: JSONのproductName
            #"["\']productName["\']\s*:\s*["\']([^"\']*)["\']"#,
            #"["\']name["\']\s*:\s*["\']([^"\']*)["\']"#,
            // パターン4: data属性
            #"data-product-name=["\']([^"\']*)["\']"#,
            // パターン5: クラス名から
            #"class=["\'][^"\']*product[^"\']*name[^"\']*["\'][^>]*>([^<]*)"#
        ]
        
        for pattern in namePatterns {
            if let match = extractFirstMatch(from: html, pattern: pattern) {
                let cleaned = cleanHTMLText(match)
                if !cleaned.isEmpty && cleaned != "ZOZOTOWN" && !cleaned.contains("ページが見つかりません") {
                    print("商品名パターンマッチ: \(cleaned)")
                    return cleaned
                }
            }
        }
        
        return nil
    }
    
    // 価格抽出（ZOZOTOWNに特化）
    private static func extractPrice(from html: String) -> String? {
        let pricePatterns = [
            // パターン1: 価格表示（¥マーク付き）
            #"[￥¥]\s*([0-9,]+)"#,
            // パターン2: JSON内の価格
            #"["\']price["\']\s*:\s*["\']?([0-9,]+)["\']?"#,
            #"["\']salePrice["\']\s*:\s*["\']?([0-9,]+)["\']?"#,
            // パターン3: data属性
            #"data-price=["\']([0-9,]+)["\']"#,
            // パターン4: 価格クラス
            #"class=["\'][^"\']*price[^"\']*["\'][^>]*>.*?([0-9,]+)"#
        ]
        
        for pattern in pricePatterns {
            if let match = extractFirstMatch(from: html, pattern: pattern) {
                let cleanPrice = match.replacingOccurrences(of: ",", with: "")
                if let priceNumber = Int(cleanPrice), priceNumber > 0 {
                    let formatter = NumberFormatter()
                    formatter.numberStyle = .decimal
                    if let formattedPrice = formatter.string(from: NSNumber(value: priceNumber)) {
                        print("価格パターンマッチ: ¥\(formattedPrice)")
                        return "¥\(formattedPrice)"
                    }
                }
            }
        }
        
        return nil
    }
    
    // 画像URL抽出（ZOZOTOWNに特化）
    private static func extractImageURL(from html: String) -> String? {
        let imagePatterns = [
            // パターン1: og:image（最も確実）
            #"<meta\s+property=["\']og:image["\']\s+content=["\']([^"\']*)["\']"#,
            // パターン2: 商品画像のsrc
            #"<img[^>]*src=["\']([^"\']*)["\'][^>]*(?:alt=["\'][^"\']*商品|class=["\'][^"\']*product)"#,
            // パターン3: data-src（遅延読み込み）
            #"<img[^>]*data-src=["\']([^"\']*)["\']"#,
            // パターン4: JSON内の画像
            #"["\']imageUrl["\']\s*:\s*["\']([^"\']*)["\']"#,
            #"["\']image["\']\s*:\s*["\']([^"\']*)["\']"#
        ]
        
        for pattern in imagePatterns {
            if let match = extractFirstMatch(from: html, pattern: pattern) {
                var imageURL = match
                
                // 相対URLを絶対URLに変換
                if imageURL.hasPrefix("//") {
                    imageURL = "https:" + imageURL
                } else if imageURL.hasPrefix("/") {
                    imageURL = "https://zozo.jp" + imageURL
                } else if !imageURL.hasPrefix("http") {
                    continue // 無効なURL
                }
                
                // 有効な画像URLかチェック
                if imageURL.contains("zozo") || imageURL.contains("img") {
                    print("画像URLパターンマッチ: \(imageURL)")
                    return imageURL
                }
            }
        }
        
        return nil
    }
    
    // 正規表現での最初のマッチを抽出
    private static func extractFirstMatch(from text: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let results = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
            
            if let match = results.first, match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: text) {
                    return String(text[swiftRange])
                }
            }
        } catch {
            print("正規表現エラー: \(error)")
        }
        
        return nil
    }
    
    // ブランド名抽出
    private static func extractBrand(from html: String) -> String? {
        // パターン1: ブランド名リンク
        if let brandMatch = html.range(of: #"<a[^>]*href="/brand/[^"]*"[^>]*>(.*?)</a>"#, options: .regularExpression) {
            let brandHTML = String(html[brandMatch])
            return cleanHTMLText(brandHTML)
        }
        
        return nil
    }
    
    // HTMLタグを除去してテキストをクリーンアップ
    private static func cleanHTMLText(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = withoutTags
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
        
        return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
