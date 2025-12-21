import SwiftUI
import UIKit

// MARK: - Swipe Back Gesture Enabler
/// Enables swipe-to-go-back gesture for NavigationStack with hidden navigation bar
struct SwipeBackEnabled: UIViewControllerRepresentable {
    let onSwipeBack: () -> Void

    func makeUIViewController(context: Context) -> SwipeBackViewController {
        SwipeBackViewController(onSwipeBack: onSwipeBack)
    }

    func updateUIViewController(_ uiViewController: SwipeBackViewController, context: Context) {}

    class SwipeBackViewController: UIViewController, UIGestureRecognizerDelegate {
        let onSwipeBack: () -> Void

        init(onSwipeBack: @escaping () -> Void) {
            self.onSwipeBack = onSwipeBack
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableSwipeBack()
        }

        private func enableSwipeBack() {
            guard let navigationController = navigationController else { return }
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                              shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
    }
}

// MARK: - View Extension
extension View {
    /// Enables swipe-to-go-back gesture for views with hidden navigation bar
    func enableSwipeBack(onDismiss: @escaping () -> Void = {}) -> some View {
        background(
            SwipeBackEnabled(onSwipeBack: onDismiss)
                .frame(width: 0, height: 0)
        )
    }
}
