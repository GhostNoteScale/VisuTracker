//
//  ContentView.swift
//  VisuTracker
//
//  Created by Go Nakazawa on 2025/07/05.
//


import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \VisuItem.timestamp, ascending: false)],
        animation: .default)
    private var items: FetchedResults<VisuItem>
    
    @State private var showingAddView = false
    @State private var searchText = ""
    @State private var filterOption: FilterOption = .all
    
    enum FilterOption: String, CaseIterable {
        case all = "all"
        case amazon = "amazon"
        case rakuten = "rakuten"
        case zozo = "zozo"
        case sale = "sale"
        
        var displayName: String {
            switch self {
            case .all: return "すべて"
            case .amazon: return "Amazon"
            case .rakuten: return "楽天"
            case .zozo: return "ZOZOTOWN"
            case .sale: return "セール"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                VStack(spacing: 16) {
                    HStack {
                        Text("お気に入り")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddView = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                    
                    // フィルタータブ
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(FilterOption.allCases, id: \.self) { option in
                                Button(action: {
                                    filterOption = option
                                }) {
                                    Text(option.displayName)
                                        .font(.subheadline)
                                        .fontWeight(filterOption == option ? .semibold : .regular)
                                        .foregroundColor(filterOption == option ? .black : .gray)
                                        .padding(.bottom, 8)
                                        .overlay(
                                            Rectangle()
                                                .frame(height: 2)
                                                .foregroundColor(filterOption == option ? .black : .clear),
                                            alignment: .bottom
                                        )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // アイテム数
                    HStack {
                        Text("\(filteredItems.count) 件")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.top)
                .background(Color(.systemBackground))
                
                // 商品グリッド
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ], spacing: 16) {
                        ForEach(filteredItems, id: \.objectID) { item in
                            ICBProductCard(item: item)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                }
            }
            .navigationBarHidden(true)
            .searchable(text: $searchText, prompt: "商品を検索")
            .sheet(isPresented: $showingAddView) {
                Text("Add Item View - Coming Soon")
            }
        }
        .onAppear {
            checkForSharedURLs()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkForSharedURLs()
        }
    }
    
    private var filteredItems: [VisuItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                (item.productName?.localizedCaseInsensitiveContains(searchText) ?? false)
            
            let matchesFilter = filterOption == .all || {
                switch filterOption {
                case .sale:
                    return item.price?.contains("セール") ?? false
                case .zozo:
                    return item.pageURL?.contains("zozo.jp") ?? false
                case .amazon:
                    return item.pageURL?.contains("amazon") ?? false
                case .rakuten:
                    return item.pageURL?.contains("rakuten") ?? false
                default:
                    return true
                }
            }()
            
            return matchesSearch && matchesFilter
        }
    }
    
    private func checkForSharedURLs() {
        let userDefaults = UserDefaults(suiteName: "group.work.rockets.VisuTracker2")
        if let pendingURLs = userDefaults?.array(forKey: "pendingURLs") as? [String], !pendingURLs.isEmpty {
            for url in pendingURLs {
                let fetchRequest: NSFetchRequest<VisuItem> = VisuItem.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "pageURL == %@", url)
                
                do {
                    let existingItems = try viewContext.fetch(fetchRequest)
                    if existingItems.isEmpty {
                        let newItem = VisuItem(context: viewContext)
                        newItem.id = UUID()
                        newItem.pageURL = url
                        newItem.productName = "Share Extensionから追加"
                        newItem.imageURL = ""
                        newItem.price = ""
                        newItem.timestamp = Date()
                        
                        // 商品情報を非同期で取得（即座に開始）
                        Task {
                            print("📱 ShareExtensionで詳細取得開始: \(url)")
                            if let productInfo = await ZOZOProductScraper.fetchProductInfo(from: url) {
                                await MainActor.run {
                                    newItem.productName = productInfo.name ?? "商品名不明"
                                    newItem.price = productInfo.price ?? ""
                                    newItem.imageURL = productInfo.imageURL ?? ""
                                    print("📱 ShareExtensionで情報更新完了: \(productInfo.name ?? "不明")")
                                    try? viewContext.save()
                                }
                            }
                        }
                    }
                } catch {
                    print("Error checking for existing items: \(error)")
                }
            }
            
            do {
                try viewContext.save()
                userDefaults?.removeObject(forKey: "pendingURLs")
                userDefaults?.synchronize()
            } catch {
                print("Error saving shared URLs: \(error)")
            }
        }
    }
}

// ICBスタイルの商品カード
struct ICBProductCard: View {
    let item: VisuItem
    @State private var isLiked = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 商品画像
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: "https://img.icons8.com/color/300/clothes.png")) { image in
                    image
                        .resizable()
                        .aspectRatio(3/4, contentMode: .fill)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(3/4, contentMode: .fit)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .cornerRadius(8)
                
                // ハートボタン
                Button(action: {
                    isLiked.toggle()
                }) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundColor(isLiked ? .red : .white)
                        .font(.title3)
                        .padding(8)
                }
            }
            
            // ブランド名
            if let pageURL = item.pageURL {
                Text(siteName(for: pageURL))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
            }
            
            // 商品名
            if let productName = item.productName {
                Text(productName)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            // 価格
            if let price = item.price, !price.isEmpty {
                Text(price)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
            }
        }
        .onTapGesture {
            // 商品詳細画面への遷移
            print("商品タップ: \(item.productName ?? "不明")")
        }
    }
    
    private func siteName(for url: String) -> String {
        guard let urlObj = URL(string: url) else { return "BRAND" }
        let host = urlObj.host?.lowercased() ?? ""
        
        switch true {
        case host.contains("zozo"):
            return "ZOZOTOWN"
        case host.contains("amazon"):
            return "Amazon"
        case host.contains("rakuten"):
            return "楽天"
        default:
            return urlObj.host?.uppercased() ?? "BRAND"
        }
    }
}