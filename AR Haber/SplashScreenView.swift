//
//  SplashScreenView.swift
//  AR Haber
//
//  Created by Aren Koş on 31.01.2026.
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var logoOpacity: Double = 0.0
    @State private var shimmerOffset: CGFloat = -1.0
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var newsViewModel = NewsViewModel()

    var body: some View {
        if isActive {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(newsViewModel)
        } else {
            ZStack {
                // Arka plan - koyu gradient
                LinearGradient(
                    colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Logo ve animasyon
                VStack {
                    Spacer()

                    // Logo görüntüsü
                    GeometryReader { geometry in
                        let logoWidth = geometry.size.width * 0.5

                        ZStack {
                            // Ana logo
                            Image("splash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: logoWidth)
                                .clipShape(RoundedRectangle(cornerRadius: 20))

                            // Shimmer efekti
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0),
                                            Color.gray.opacity(0.2),
                                            Color.white.opacity(0),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: logoWidth * 0.8, height: logoWidth * 0.6)
                                .offset(x: shimmerOffset * logoWidth)
                                .clipShape(RoundedRectangle(cornerRadius: 100))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(logoOpacity)
                    }
                    .frame(height: 200)

                    Spacer()

                    // Alt yazı
                    Text("AR Haber")
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .opacity(logoOpacity)

                    Text("Haberler yükleniyor...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                        .padding(.bottom, 50)
                        .opacity(logoOpacity)
                }
            }
            .onAppear {
                // Shimmer animasyonu (daha yavaş - 2 saniye)
                withAnimation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerOffset = 1.5
                }

                // Haberleri arka planda yükle
                newsViewModel.loadNews(resetPage: true, arama: "")

                // 0-1 saniye: Fade in (saydam → opak)
                withAnimation(.easeIn(duration: 1.0)) {
                    logoOpacity = 1.0
                }

                // 1-2 saniye: Fade out (opak → saydam)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 1.0)) {
                        logoOpacity = 0.0
                    }
                }

                // 2 saniye sonra ana ekrana geç
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashScreenView()
        .environmentObject(AuthViewModel())
}
