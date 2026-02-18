//
//  BlockedUsersView.swift
//  AR Haber
//
//  Created by Antigravity AI on 14.02.2026.
//

import SwiftUI

struct BlockedUsersView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var moderationManager = ContentModerationManager.shared
    @State private var blockedUsersList: [String] = []

    var body: some View {
        List {
            if blockedUsersList.isEmpty {
                Text("Engellenen kullanıcı yok")
                    .foregroundColor(.secondary)
            } else {
                ForEach(blockedUsersList, id: \.self) { username in
                    HStack {
                        Image(systemName: "person.slash.fill")
                            .foregroundColor(.red)
                        Text(username)
                            .font(.body)
                        Spacer()
                        Button("Engeli Kaldır") {
                            unblockUser(username)
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("Engellenen Kullanıcılar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshList()
        }
    }

    private func refreshList() {
        blockedUsersList = Array(moderationManager.blockedUsers).sorted()
    }

    private func unblockUser(_ username: String) {
        moderationManager.unblockUser(username)
        // Opt: Also call server API if needed, but for now local unblock + server sync on next load is fine
        // If strict server sync is needed:
        /*
        guard let currentUser = authViewModel.user?.username else { return }
        // Call a server API to unblock if implemented
        */
        refreshList()
    }
}

#Preview {
    NavigationView {
        BlockedUsersView()
            .environmentObject(AuthViewModel())
    }
}
