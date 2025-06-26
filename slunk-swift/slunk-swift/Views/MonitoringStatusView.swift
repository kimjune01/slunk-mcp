import SwiftUI

/// A simple view showing the current Slack monitoring status
struct MonitoringStatusView: View {
    @ObservedObject var monitoringService = SlackMonitoringService.shared
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: monitoringService.isMonitoring ? "eye.fill" : "eye.slash")
                .foregroundColor(monitoringService.isMonitoring ? .green : .gray)
                .font(.caption)
            
            Text(monitoringService.isMonitoring ? "Monitoring Active" : "Monitoring Stopped")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let conversation = monitoringService.lastExtractedConversation {
                Divider()
                    .frame(height: 12)
                
                Text("\(conversation.messages.count) messages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
}