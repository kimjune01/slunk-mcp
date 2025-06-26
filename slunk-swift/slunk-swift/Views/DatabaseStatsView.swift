import SwiftUI

/// View showing database statistics
struct DatabaseStatsView: View {
    let stats: DatabaseStats?
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Database Stats")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button("Refresh") {
                    onRefresh()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            if let stats = stats {
                StatsContentView(stats: stats)
            } else {
                LoadingStatsView()
            }
        }
    }
}

private struct StatsContentView: View {
    let stats: DatabaseStats
    
    var body: some View {
        HStack(spacing: 15) {
            StatItem(label: "Messages", value: "\(stats.messageCount)")
            
            Divider()
                .frame(height: 12)
            
            StatItem(label: "Workspaces", value: "\(stats.workspaceCount)")
            
            Divider()
                .frame(height: 12)
            
            StatItem(label: "Size", value: stats.databaseSize)
            
            Spacer()
            
            Text(formatTimestamp(stats.lastUpdated))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(6)
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct StatItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

private struct LoadingStatsView: View {
    var body: some View {
        HStack {
            Text("Loading stats...")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}