import SwiftUI

// MARK: - Inter Font Extension
extension Font {
    
    // Thin
    static func interThin(size: CGFloat) -> Font {
        .custom("Inter-Regular_Thin", size: size)
    }
    
    // ExtraLight
    static func interExtraLight(size: CGFloat) -> Font {
        .custom("Inter-Regular_ExtraLight", size: size)
    }
    
    // Light
    static func interLight(size: CGFloat) -> Font {
        .custom("Inter-Regular_Light", size: size)
    }
    
    // Regular
    static func interRegular(size: CGFloat) -> Font {
        .custom("Inter-Regular", size: size)
    }
    
    // Medium
    static func interMedium(size: CGFloat) -> Font {
        .custom("Inter-Regular_Medium", size: size)
    }
    
    // SemiBold
    static func interSemiBold(size: CGFloat) -> Font {
        .custom("Inter-Regular_SemiBold", size: size)
    }
    
    // Bold
    static func interBold(size: CGFloat) -> Font {
        .custom("Inter-Regular_Bold", size: size)
    }
    
    // ExtraBold
    static func interExtraBold(size: CGFloat) -> Font {
        .custom("Inter-Regular_ExtraBold", size: size)
    }
    
    // Black
    static func interBlack(size: CGFloat) -> Font {
        .custom("Inter-Regular_Black", size: size)
    }
}

// MARK: - Libre Baskerville Font Extension
extension Font {
    
    // Regular
    static func libreRegular(size: CGFloat) -> Font {
        .custom("LibreBaskerville-Regular", size: size)
    }
    
    // Medium
    static func libreMedium(size: CGFloat) -> Font {
        .custom("LibreBaskerville-Medium", size: size)
    }
    
    // SemiBold
    static func libreSemiBold(size: CGFloat) -> Font {
        .custom("LibreBaskerville-SemiBold", size: size)
    }
    
    // Bold
    static func libreBold(size: CGFloat) -> Font {
        .custom("LibreBaskerville-Bold", size: size)
    }
}
