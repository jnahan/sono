//
//  IconButton.swift
//  Transcription App
//
//  Created by Jenna Han on 12/6/25.
//

import SwiftUI

struct IconButton: View {
    let icon: String
    var iconSize: CGFloat = 28
    var frameSize: CGFloat = 40
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(.warmGray500)
                .frame(width: frameSize, height: frameSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
