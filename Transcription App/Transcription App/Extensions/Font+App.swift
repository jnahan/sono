import SwiftUI

extension Font {
    // Regular
    static func dmSansRegular(size: CGFloat) -> Font {
        .custom("DMSans-9ptRegular", size: size)
    }
    
    // Medium
    static func dmSansMedium(size: CGFloat) -> Font {
        .custom("DMSans-9ptRegular_Medium", size: size)
    }
    
    // SemiBold
    static func dmSansSemiBold(size: CGFloat) -> Font {
        .custom("DMSans-9ptRegular_SemiBold", size: size)
    }
    
    // Bold
    static func dmSansBold(size: CGFloat) -> Font {
        .custom("DMSans-9ptRegular_Bold", size: size)
    }
}
