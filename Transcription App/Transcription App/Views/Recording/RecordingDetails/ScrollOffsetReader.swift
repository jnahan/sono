import SwiftUI
import UIKit

struct ScrollOffsetReader: UIViewRepresentable {
    var onScrollViewFound: (UIScrollView) -> Void
    var onOffsetChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        context.coordinator.attach(to: view,
                                   onScrollViewFound: onScrollViewFound,
                                   onOffsetChange: onOffsetChange)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onScrollViewFound = onScrollViewFound
        context.coordinator.onOffsetChange = onOffsetChange
        context.coordinator.tryHookScrollView(from: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var onScrollViewFound: ((UIScrollView) -> Void)?
        var onOffsetChange: ((CGFloat) -> Void)?

        private weak var scrollView: UIScrollView?
        private var observation: NSKeyValueObservation?

        func attach(to view: UIView,
                    onScrollViewFound: @escaping (UIScrollView) -> Void,
                    onOffsetChange: @escaping (CGFloat) -> Void) {
            self.onScrollViewFound = onScrollViewFound
            self.onOffsetChange = onOffsetChange
        }

        func tryHookScrollView(from view: UIView) {
            guard scrollView == nil else { return }

            var v: UIView? = view
            while let current = v {
                if let sv = current as? UIScrollView {
                    hook(sv)
                    return
                }
                v = current.superview
            }

            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.tryHookScrollView(from: view)
            }
        }

        private func hook(_ sv: UIScrollView) {
            scrollView = sv
            onScrollViewFound?(sv)

            observation?.invalidate()
            observation = sv.observe(\.contentOffset, options: [.initial, .new]) { [weak self] sv, _ in
                self?.onOffsetChange?(max(0, sv.contentOffset.y))
            }
        }

        deinit { observation?.invalidate() }
    }
}
