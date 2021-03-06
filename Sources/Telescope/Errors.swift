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
    case httpError(url: URL, code: Int?)
    case unknown
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
            case .httpError(let url, let code):
                return NSLocalizedString("The HTTP response code for \"\(url.absoluteString)\" was \(code?.description ?? "empty").",
                                         comment: "RemoteImageError.httpError localized failure reason.")
            case .unknown:
                return NSLocalizedString("An unknown error has happened",
                                         comment: "RemoteImageError.unknown failure reason.")
        }
    }
    
    public var errorDescription: String? {
        switch self {
            case .invalidURL:
                return NSLocalizedString("Invalid URL",
                                         comment: "RemoteImageError.invalidURL localized description.")
            case .notAnImage:
                return NSLocalizedString("Not an image",
                                         comment: "RemoteImageError.notAnImage localized description.")
            case .editNotFound:
                return NSLocalizedString("Edit not found",
                                         comment: "RemoteImageError.editNotFound localized description.")
            case .httpError(_ , let code):
                return NSLocalizedString("HTTP error \(code?.description ?? "unknown").",
                                         comment: "RemoteImageError.httpError localized description.")
            case .unknown:
                return NSLocalizedString("Unknown error",
                                         comment: "RemoteImageError.unknown localized description.")
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
            case .httpError:
                return NSLocalizedString("Check that you have the correct URL and can have the right to access it.",
                                         comment: "RemoteImageError.httpError localized recovery suggestion.")
            case .unknown:
                return NSLocalizedString("Try to debug this issue step by step or open an issue on this package's repository.",
                                         comment: "RemoteImageError.unknown localized recovery suggestion.")
        }
    }
}
