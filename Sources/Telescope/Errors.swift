//
//  Errors.swift
//  
//
//  Created by Riccardo Persello on 06/03/21.
//

import Foundation

public enum RemoteImageError: Error {
    case invalidURL(stringURL: String)
    case notAnImage(url: URL)
    case editNotFound(remoteImage: RemoteImage, tag: String)
}

extension RemoteImageError: LocalizedError {
    public var failureReason: String? {
        switch self {
            case .invalidURL(let stringURL):
                return NSLocalizedString("\"\(stringURL)\" could not be converted to a valid URL.",
                                         comment: "RemoteImageError.invalidURL localized failure reason.")
            case .notAnImage(let url):
                return NSLocalizedString("\"\(url.absoluteString)\" points to a resource which is not an image.",
                                         comment: "RemoteImageError.notAnImage localized failure reason.")
            case .editNotFound(let remoteImage, let tag):
                return NSLocalizedString("The \"\(tag)\" tag does not exist in the specified RemoteImage. Existent tags are: \(remoteImage.editTags).",
                                         comment: "RemoteImageError.editNotFound localized failure reason.")
        }
    }
    
    public var errorDescription: String? {
        switch self {
            case .invalidURL:
                return NSLocalizedString("Invalid URL", comment: "RemoteImageError.invalidURL localized description.")
            case .notAnImage:
                return NSLocalizedString("Not an image", comment: "RemoteImageError.notAnImage localized description.")
            case .editNotFound:
                return NSLocalizedString("Edit not found", comment: "RemoteImageError.editNotFound localized description.")
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
            case .invalidURL:
                return NSLocalizedString("Check that the URL is in a correct format or use the `init(imageURL url: URL, isLazy lazy: Bool = true)` initializer.",
                                         comment: "RemoteImageError.invalidURL localized recovery suggestion.")
            case .notAnImage(let url):
                return NSLocalizedString("Check that the remote image is valid by navigating to \"\(url.absoluteString)\".",
                                         comment: "RemoteImageError.invalidURL localized recovery suggestion.")
                
            // TODO: Add function suggestion for adding tags
            case .editNotFound:
                return NSLocalizedString("Check that the tag has been created.",
                                         comment: "RemoteImageError.invalidURL localized recovery suggestion.")
        }
    }
}
