//
//  NewsSummaryView.swift
//  AR Haber
//
//  Created by AI Assistant on 25.01.2026.
//

import SwiftUI

// MARK: - Haber Özeti Görüntüleme Ekranı
struct HaberOzetiView: View {
    @Environment(\.dismiss) var dismiss
    let news: NewsItem
    let summary: String?
    let isLoading: Bool
    let mapSource: (String) -> String
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Haber Görseli
                    if let uiImage = UIImage(contentsOfFile: news.resim_url) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        AsyncImage(url: URL(string: news.resim_url)) { image in
                            image.resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } placeholder: {
                            ProgressView()
                                .frame(height: 200)
                        }
                    }
                    
                    // Kaynak Logosu
                    HStack {
                        let kaynak = mapSource(news.kaynak)
                        Image(kaynak)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                        
                        Text(news.kaynak)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        Text(news.tarih)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    // Haber Başlığı
                    Text(news.baslik)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Divider()
                    
                    // Özet Başlığı
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("AI Özeti")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    // Özet İçeriği
                    if isLoading {
                        HStack {
                            ProgressView()
                            Text("Özet oluşturuluyor...")
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if let summary = summary {
                        Text(summary)
                            .font(.body)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("Özet yüklenemedi. Lütfen tekrar deneyin.")
                            .foregroundColor(.red)
                            .italic()
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Haber Özeti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }
}
