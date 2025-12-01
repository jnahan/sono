import SwiftUI

extension Color {
    // MARK: - Accent
    static let accent = Color(red: 240/255, green: 88/255, blue: 136/255)
    static let accentLight = Color(red: 250/255, green: 231/255, blue: 237/255)
    
    // MARK: - Warning
    static let warning = Color(red: 223/255, green: 0/255, blue: 33/255)
    
    // MARK: - Warm Gray Scale
    static let warmGray50 = Color(red: 250/255, green: 250/255, blue: 249/255)
    static let warmGray100 = Color(red: 245/255, green: 245/255, blue: 244/255)
    static let warmGray200 = Color(red: 231/255, green: 229/255, blue: 228/255)
    static let warmGray300 = Color(red: 214/255, green: 211/255, blue: 209/255)
    static let warmGray400 = Color(red: 168/255, green: 162/255, blue: 158/255)
    static let warmGray500 = Color(red: 120/255, green: 113/255, blue: 108/255)
    static let warmGray600 = Color(red: 87/255, green: 83/255, blue: 78/255)
    static let warmGray700 = Color(red: 68/255, green: 64/255, blue: 60/255)
    static let warmGray800 = Color(red: 41/255, green: 37/255, blue: 36/255)
    static let warmGray900 = Color(red: 28/255, green: 25/255, blue: 23/255)
    
    // MARK: - Base
    static let baseBlack = Color.black
    static let baseWhite = Color.white
}

extension View {
    func defaultShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 4)
    }
}
