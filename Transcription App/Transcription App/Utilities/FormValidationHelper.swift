import Foundation

/// Utility for form validation
struct FormValidationHelper {
    
    /// Validate that a text field is not empty
    /// - Parameters:
    ///   - text: The text to validate
    ///   - fieldName: Name of the field for error message
    /// - Returns: Error message if invalid, nil if valid
    static func validateNotEmpty(_ text: String, fieldName: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Use centralized error messages when possible
        if fieldName == "Title" {
            return trimmed.isEmpty ? ErrorMessages.Validation.titleRequired : nil
        } else if fieldName == "Collection name" {
            return trimmed.isEmpty ? ErrorMessages.Validation.collectionNameRequired : nil
        }
        return trimmed.isEmpty ? "\(fieldName) is required" : nil
    }
    
    /// Validate that text length is within maximum
    /// - Parameters:
    ///   - text: The text to validate
    ///   - max: Maximum allowed length
    ///   - fieldName: Name of the field for error message
    /// - Returns: Error message if invalid, nil if valid
    static func validateLength(_ text: String, max: Int, fieldName: String) -> String? {
        // Use centralized error messages when possible
        if fieldName == "Title" && max == AppConstants.Validation.maxTitleLength {
            return text.count > max ? ErrorMessages.format(ErrorMessages.Validation.titleTooLong, max) : nil
        } else if fieldName == "Collection name" && max == AppConstants.Validation.maxCollectionNameLength {
            return text.count > max ? ErrorMessages.format(ErrorMessages.Validation.collectionNameTooLong, max) : nil
        }
        return text.count > max ? "\(fieldName) must be less than \(max) characters" : nil
    }
    
    /// Validate that a name is unique (not a duplicate)
    /// - Parameters:
    ///   - name: The name to check
    ///   - existingNames: Array of existing names
    ///   - fieldName: Name of the field for error message
    ///   - ignoreCase: Whether to ignore case when comparing
    /// - Returns: Error message if duplicate found, nil if unique
    static func validateUnique(
        _ name: String,
        against existingNames: [String],
        fieldName: String,
        ignoreCase: Bool = true
    ) -> String? {
        let nameToCheck = ignoreCase ? name.lowercased() : name
        let isDuplicate = existingNames.contains { existing in
            ignoreCase ? existing.lowercased() == nameToCheck : existing == nameToCheck
        }
        
        // Use centralized error messages when possible
        if fieldName == "Collection" {
            return isDuplicate ? ErrorMessages.Validation.duplicateCollectionName : nil
        }
        
        return isDuplicate ? "A \(fieldName.lowercased()) with this name already exists" : nil
    }
}
