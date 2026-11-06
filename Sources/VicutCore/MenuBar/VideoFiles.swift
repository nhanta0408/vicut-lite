import Foundation

/// Which files ViCut Lite accepts, shared by the window, the menu bar icon and the floating drop zone.
public enum VideoFiles {
  public static let supportedExtensions: Set<String> = ["mov", "mp4", "m4v", "mkv", "webm", "avi"]

  public static func isSupported(_ url: URL) -> Bool {
    url.isFileURL && supportedExtensions.contains(url.pathExtension.lowercased())
  }

  public static func supported(in urls: [URL]) -> [URL] {
    urls.filter(isSupported)
  }
}
