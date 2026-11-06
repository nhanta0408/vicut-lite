import AVKit
import SwiftUI

/// AVPlayerView without its own controls, so our keyboard shortcuts aren't swallowed.
struct PlayerView: NSViewRepresentable {
  let player: AVPlayer

  func makeNSView(context: Context) -> AVPlayerView {
    let view = AVPlayerView()
    view.controlsStyle = .none
    view.videoGravity = .resizeAspect
    view.player = player
    return view
  }

  func updateNSView(_ view: AVPlayerView, context: Context) {
    if view.player !== player {
      view.player = player
    }
  }
}
