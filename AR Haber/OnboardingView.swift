//
//  OnboardingView.swift
//  AR Haber
//
//  Created by Aren Koş on 19.03.2026.
//

import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let gradientColors: [Color]
}

private let onboardingPages: [OnboardingPage] = [
    OnboardingPage(
        title: "AR Haber'e\nHoş Geldiniz",
        description: "Türkiye'nin en güncel haberlerine tek bir yerden ulaşın. Farklı kaynaklardan haberleri tek uygulamada takip edin.",
        iconName: "house.fill",
        gradientColors: [Color(red: 0.12, green: 0.53, blue: 0.90), Color(red: 0.08, green: 0.40, blue: 0.75)]
    ),
    OnboardingPage(
        title: "Kaynaklar &\nKategoriler",
        description: "Farklı haber kaynaklarını keşfedin ve kategorilere göre haberleri filtreleyin. Giriş yaptığınızda bu özelliklere erişebilirsiniz.",
        iconName: "newspaper.fill",
        gradientColors: [Color(red: 0.49, green: 0.30, blue: 1.0), Color(red: 0.40, green: 0.12, blue: 1.0)]
    ),
    OnboardingPage(
        title: "AI Asistan",
        description: "Haberleri AI ile özetletin, haber hakkında sorular sorun. Haber kartını sola kaydırarak AI özetine ulaşabilirsiniz.",
        iconName: "sparkles",
        gradientColors: [Color(red: 0.13, green: 0.59, blue: 0.95), Color(red: 0.61, green: 0.15, blue: 0.69)]
    ),
    OnboardingPage(
        title: "Kişisel\nDeneyim",
        description: "Giriş yaparak haberleri kaydedin, beğenin, yorum yapın ve diğer kullanıcılarla mesajlaşın. Profil sekmesinden giriş yapabilirsiniz.",
        iconName: "person.fill",
        gradientColors: [Color(red: 1.0, green: 0.42, blue: 0.21), Color(red: 0.90, green: 0.35, blue: 0.17)]
    )
]

struct OnboardingView: View {
    let onFinish: (Bool) -> Void
    
    @State private var currentPage = 0
    @State private var animateContent = false
    @State private var dontShowAgain = false
    
    var body: some View {
        ZStack {
            // Background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < onboardingPages.count - 1 {
                        Button(action: { onFinish(dontShowAgain) }) {
                            Text("Atla")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                    }
                }
                .frame(height: 44)
                .padding(.top, 8)
                
                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(onboardingPages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _ in
                    animateContent = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            animateContent = true
                        }
                    }
                }
                
                // Bottom controls
                VStack(spacing: 20) {
                    // Custom page indicators
                    HStack(spacing: 8) {
                        ForEach(0..<onboardingPages.count, id: \.self) { index in
                            Capsule()
                                .fill(
                                    index == currentPage
                                    ? LinearGradient(
                                        colors: onboardingPages[currentPage].gradientColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: index == currentPage ? 24 : 8, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: currentPage)
                        }
                    }
                    
                    // Main button
                    Button(action: {
                        if currentPage == onboardingPages.count - 1 {
                            onFinish(dontShowAgain)
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentPage += 1
                            }
                        }
                    }) {
                        Text(currentPage == onboardingPages.count - 1 ? "Hadi Başlayalım!" : "İleri")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: onboardingPages[currentPage].gradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .animation(.easeInOut(duration: 0.3), value: currentPage)
                    
                    // "Bir daha gösterme" checkbox - tüm sayfalarda görünür
                    Button(action: {
                        dontShowAgain.toggle()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(dontShowAgain ? onboardingPages[currentPage].gradientColors.first ?? .blue : .gray)
                            Text("Bir daha gösterme")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.5)) {
                    animateContent = true
                }
            }
        }
    }
}

// MARK: - Onboarding Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage
    
    @State private var iconScale: CGFloat = 0.8
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Icon with gradient circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)
                    .shadow(color: page.gradientColors.first?.opacity(0.4) ?? .clear, radius: 20, y: 10)
                
                Image(systemName: page.iconName)
                    .font(.system(size: 70, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(iconScale)
            
            Spacer()
                .frame(height: 48)
            
            // Title
            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.13, green: 0.13, blue: 0.13))
                .lineSpacing(4)
                .opacity(contentOpacity)
                .offset(y: contentOffset)
            
            Spacer()
                .frame(height: 16)
            
            // Description
            Text(page.description)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .foregroundColor(Color(red: 0.46, green: 0.46, blue: 0.46))
                .lineSpacing(4)
                .padding(.horizontal, 16)
                .opacity(contentOpacity)
                .offset(y: contentOffset)
            
            Spacer()
                .frame(height: 120)
        }
        .padding(.horizontal, 32)
        .onAppear {
            iconScale = 0.8
            contentOpacity = 0
            contentOffset = 30
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                iconScale = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
        }
    }
}

#Preview {
    OnboardingView(onFinish: { _ in })
}
