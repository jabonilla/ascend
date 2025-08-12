import UIKit
import Lottie

class AnimationService {
    static let shared = AnimationService()
    
    private init() {}
    
    // MARK: - Loading Animations
    
    func showLoadingAnimation(in view: UIView, style: LoadingStyle = .default) -> LottieAnimationView? {
        let animationView = LottieAnimationView()
        
        switch style {
        case .default:
            if let animation = LottieAnimation.named("loading_spinner") {
                animationView.animation = animation
            }
        case .success:
            if let animation = LottieAnimation.named("success_check") {
                animationView.animation = animation
            }
        case .error:
            if let animation = LottieAnimation.named("error_x") {
                animationView.animation = animation
            }
        case .progress:
            if let animation = LottieAnimation.named("progress_bar") {
                animationView.animation = animation
            }
        }
        
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.play()
        
        view.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            animationView.widthAnchor.constraint(equalToConstant: 60),
            animationView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        return animationView
    }
    
    func hideLoadingAnimation(_ animationView: LottieAnimationView?) {
        UIView.animate(withDuration: 0.3, animations: {
            animationView?.alpha = 0
        }) { _ in
            animationView?.removeFromSuperview()
        }
    }
    
    // MARK: - Page Transitions
    
    func animatePageTransition(from fromView: UIView, to toView: UIView, direction: TransitionDirection = .right) {
        let screenWidth = UIScreen.main.bounds.width
        
        switch direction {
        case .right:
            toView.transform = CGAffineTransform(translationX: screenWidth, y: 0)
        case .left:
            toView.transform = CGAffineTransform(translationX: -screenWidth, y: 0)
        case .up:
            toView.transform = CGAffineTransform(translationX: 0, y: -UIScreen.main.bounds.height)
        case .down:
            toView.transform = CGAffineTransform(translationX: 0, y: UIScreen.main.bounds.height)
        }
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            fromView.transform = CGAffineTransform(translationX: -screenWidth, y: 0)
            toView.transform = .identity
        }
    }
    
    // MARK: - Card Animations
    
    func animateCardAppearance(_ card: UIView, delay: TimeInterval = 0) {
        card.alpha = 0
        card.transform = CGAffineTransform(translationX: 0, y: 50)
        
        UIView.animate(withDuration: 0.6, delay: delay, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            card.alpha = 1
            card.transform = .identity
        }
    }
    
    func animateCardTap(_ card: UIView, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.1, animations: {
            card.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                card.transform = .identity
            }) { _ in
                completion()
            }
        }
    }
    
    func animateCardHover(_ card: UIView, isHovered: Bool) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            if isHovered {
                card.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
                card.layer.shadowOpacity = 0.3
                card.layer.shadowRadius = 8
                card.layer.shadowOffset = CGSize(width: 0, height: 4)
            } else {
                card.transform = .identity
                card.layer.shadowOpacity = 0.1
                card.layer.shadowRadius = 4
                card.layer.shadowOffset = CGSize(width: 0, height: 2)
            }
        }
    }
    
    // MARK: - Button Animations
    
    func animateButtonPress(_ button: UIButton, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                button.transform = .identity
            }) { _ in
                completion()
            }
        }
    }
    
    func animateButtonSuccess(_ button: UIButton) {
        let originalTitle = button.title(for: .normal)
        let originalColor = button.backgroundColor
        
        button.setTitle("✓", for: .normal)
        button.backgroundColor = UIColor.systemGreen
        
        UIView.animate(withDuration: 0.3, delay: 1.0, options: [], animations: {
            button.alpha = 0.8
        }) { _ in
            button.setTitle(originalTitle, for: .normal)
            button.backgroundColor = originalColor
            UIView.animate(withDuration: 0.3) {
                button.alpha = 1.0
            }
        }
    }
    
    // MARK: - Progress Animations
    
    func animateProgressRing(_ progressView: ProgressRingView, to progress: Double, duration: TimeInterval = 1.0) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressView.progress
        animation.toValue = progress
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        progressView.progress = progress
        progressView.progressLayer.add(animation, forKey: "progressAnimation")
    }
    
    func animateProgressBar(_ progressBar: UIProgressView, to progress: Float, duration: TimeInterval = 1.0) {
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            progressBar.setProgress(progress, animated: false)
        }
    }
    
    // MARK: - List Animations
    
    func animateTableViewReload(_ tableView: UITableView) {
        tableView.reloadData()
        
        let cells = tableView.visibleCells
        for (index, cell) in cells.enumerated() {
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 50)
            
            UIView.animate(withDuration: 0.5, delay: Double(index) * 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                cell.alpha = 1
                cell.transform = .identity
            }
        }
    }
    
    func animateCollectionViewReload(_ collectionView: UICollectionView) {
        collectionView.reloadData()
        
        let cells = collectionView.visibleCells
        for (index, cell) in cells.enumerated() {
            cell.alpha = 0
            cell.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            
            UIView.animate(withDuration: 0.5, delay: Double(index) * 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                cell.alpha = 1
                cell.transform = .identity
            }
        }
    }
    
    // MARK: - Modal Animations
    
    func animateModalPresentation(_ modalView: UIView, from presentingView: UIView) {
        modalView.alpha = 0
        modalView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            modalView.alpha = 1
            modalView.transform = .identity
            presentingView.alpha = 0.3
        }
    }
    
    func animateModalDismissal(_ modalView: UIView, to presentingView: UIView, completion: @escaping () -> Void) {
        UIView.animate(withDuration: 0.3, animations: {
            modalView.alpha = 0
            modalView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            presentingView.alpha = 1.0
        }) { _ in
            completion()
        }
    }
    
    // MARK: - Shake Animation
    
    func animateShake(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.6
        animation.values = [-20.0, 20.0, -20.0, 20.0, -10.0, 10.0, -5.0, 5.0, 0.0]
        view.layer.add(animation, forKey: "shake")
    }
    
    // MARK: - Pulse Animation
    
    func animatePulse(_ view: UIView, duration: TimeInterval = 1.0) {
        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
        pulseAnimation.duration = duration
        pulseAnimation.fromValue = 1.0
        pulseAnimation.toValue = 1.1
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = Float.infinity
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        view.layer.add(pulseAnimation, forKey: "pulse")
    }
    
    func stopPulseAnimation(_ view: UIView) {
        view.layer.removeAnimation(forKey: "pulse")
    }
    
    // MARK: - Celebration Animations
    
    func animateCelebration(in view: UIView) {
        // Create confetti animation
        for _ in 0..<20 {
            let confetti = UIView()
            confetti.backgroundColor = [UIColor.systemRed, UIColor.systemBlue, UIColor.systemGreen, UIColor.systemYellow, UIColor.systemPurple].randomElement()
            confetti.frame = CGRect(x: CGFloat.random(in: 0...view.bounds.width), y: -20, width: 8, height: 8)
            confetti.layer.cornerRadius = 4
            view.addSubview(confetti)
            
            UIView.animate(withDuration: 3.0, delay: Double.random(in: 0...0.5), options: .curveEaseOut) {
                confetti.frame.origin.y = view.bounds.height + 20
                confetti.alpha = 0
            } completion: { _ in
                confetti.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Micro-interactions
    
    func animateTextFieldFocus(_ textField: UITextField, isFocused: Bool) {
        UIView.animate(withDuration: 0.2) {
            textField.layer.borderWidth = isFocused ? 2 : 1
            textField.layer.borderColor = isFocused ? UIColor.systemBlue.cgColor : UIColor.systemGray4.cgColor
        }
    }
    
    func animateSwitchToggle(_ switchView: UISwitch) {
        UIView.animate(withDuration: 0.1, animations: {
            switchView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                switchView.transform = .identity
            }
        }
    }
    
    func animateSegmentedControlChange(_ segmentedControl: UISegmentedControl) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            segmentedControl.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                segmentedControl.transform = .identity
            }
        }
    }
}

// MARK: - Supporting Types

enum LoadingStyle {
    case `default`
    case success
    case error
    case progress
}

enum TransitionDirection {
    case left
    case right
    case up
    case down
}

// MARK: - UIView Extensions

extension UIView {
    func animateAppearance(delay: TimeInterval = 0) {
        AnimationService.shared.animateCardAppearance(self, delay: delay)
    }
    
    func animateTap(completion: @escaping () -> Void) {
        AnimationService.shared.animateCardTap(self, completion: completion)
    }
    
    func animateHover(isHovered: Bool) {
        AnimationService.shared.animateCardHover(self, isHovered: isHovered)
    }
    
    func animateShake() {
        AnimationService.shared.animateShake(self)
    }
    
    func animatePulse(duration: TimeInterval = 1.0) {
        AnimationService.shared.animatePulse(self, duration: duration)
    }
    
    func stopPulse() {
        AnimationService.shared.stopPulseAnimation(self)
    }
}

extension UIButton {
    func animatePress(completion: @escaping () -> Void) {
        AnimationService.shared.animateButtonPress(self, completion: completion)
    }
    
    func animateSuccess() {
        AnimationService.shared.animateButtonSuccess(self)
    }
}

extension UITextField {
    func animateFocus(isFocused: Bool) {
        AnimationService.shared.animateTextFieldFocus(self, isFocused: isFocused)
    }
}

extension UISwitch {
    func animateToggle() {
        AnimationService.shared.animateSwitchToggle(self)
    }
}

extension UISegmentedControl {
    func animateChange() {
        AnimationService.shared.animateSegmentedControlChange(self)
    }
}
