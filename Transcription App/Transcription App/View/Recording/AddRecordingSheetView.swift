import SwiftUI

struct AddRecordingSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var onRecordAudio: () -> Void
    var onUploadFile: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                
                VStack(spacing: 1) {
                    Button {
                        dismiss()
                        onRecordAudio()
                    } label: {
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.title2)
                                .frame(width: 30)
                            Text("Record audio")
                                .font(.body)
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                    }
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    Button {
                        dismiss()
                        onUploadFile()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.title2)
                                .frame(width: 30)
                            Text("Upload file")
                                .font(.body)
                            Spacer()
                        }
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(UIColor.systemBackground))
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .padding()
            }
            .background(Color.black.opacity(0.0001)) // Invisible but tappable
        }
        .background(
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }
        )
    }
}
