import UIKit

class ProgressRingView: UIView {
    
    // MARK: - Properties
    
    var progress: Double = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var ringColor: UIColor = .systemBlue {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var ringWidth: CGFloat = 8.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var showPercentage: Bool = true {
        didSet {
            setNeedsDisplay()
        }
    }
    
    // MARK: - Private Properties
    
    private let progressLayer = CAShapeLayer()
    private let backgroundLayer = CAShapeLayer()
    private let percentageLabel = UILabel()
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .clear
        
        // Setup percentage label
        percentageLabel.translatesAutoresizingMaskIntoConstraints = false
        percentageLabel.textAlignment = .center
        percentageLabel.font = UIFont(name: "Satoshi-Bold", size: 18) ?? UIFont.boldSystemFont(ofSize: 18)
        percentageLabel.textColor = .white
        addSubview(percentageLabel)
        
        NSLayoutConstraint.activate([
            percentageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            percentageLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Setup layers
        setupLayers()
    }
    
    private func setupLayers() {
        // Background layer
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        backgroundLayer.lineWidth = ringWidth
        backgroundLayer.lineCap = .round
        layer.addSublayer(backgroundLayer)
        
        // Progress layer
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = ringColor.cgColor
        progressLayer.lineWidth = ringWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0.0
        layer.addSublayer(progressLayer)
    }
    
    // MARK: - Drawing
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - ringWidth / 2
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi
        
        // Background circle
        let backgroundPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: true
        )
        backgroundLayer.path = backgroundPath.cgPath
        
        // Progress circle
        let progressEndAngle = startAngle + (2 * CGFloat.pi * CGFloat(progress))
        let progressPath = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: progressEndAngle,
            clockwise: true
        )
        progressLayer.path = progressPath.cgPath
        
        // Animate progress
        animateProgress()
        
        // Update percentage label
        if showPercentage {
            let percentage = Int(progress * 100)
            percentageLabel.text = "\(percentage)%"
        } else {
            percentageLabel.text = ""
        }
    }
    
    // MARK: - Animation
    
    private func animateProgress() {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = progressLayer.strokeEnd
        animation.toValue = progress
        animation.duration = 0.5
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        progressLayer.strokeEnd = CGFloat(progress)
        progressLayer.add(animation, forKey: "progressAnimation")
    }
    
    // MARK: - Public Methods
    
    func setProgress(_ progress: Double, animated: Bool = true) {
        self.progress = max(0.0, min(1.0, progress))
        
        if !animated {
            progressLayer.removeAllAnimations()
            progressLayer.strokeEnd = CGFloat(self.progress)
        }
    }
}
