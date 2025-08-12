import UIKit

class ChartView: UIView {
    
    // MARK: - Properties
    
    private var dataPoints: [ChartDataPoint] = []
    private var chartType: ChartType = .line
    
    // MARK: - UI Components
    
    private let chartLayer = CAShapeLayer()
    private let gridLayer = CAShapeLayer()
    private let labelsLayer = CALayer()
    
    // MARK: - Chart Configuration
    
    private let padding: CGFloat = 40
    private let gridLineCount = 5
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupChart()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupChart()
    }
    
    // MARK: - Setup
    
    private func setupChart() {
        backgroundColor = .clear
        
        // Setup grid layer
        gridLayer.strokeColor = UIColor.systemGray5.cgColor
        gridLayer.lineWidth = 1
        gridLayer.fillColor = nil
        
        // Setup chart layer
        chartLayer.strokeColor = UIColor(named: "PrimaryBlue")?.cgColor ?? UIColor.systemBlue.cgColor
        chartLayer.lineWidth = 3
        chartLayer.fillColor = nil
        chartLayer.lineCap = .round
        chartLayer.lineJoin = .round
        
        layer.addSublayer(gridLayer)
        layer.addSublayer(chartLayer)
        layer.addSublayer(labelsLayer)
    }
    
    // MARK: - Public Methods
    
    func configure(with dataPoints: [ChartDataPoint], type: ChartType = .line) {
        self.dataPoints = dataPoints
        self.chartType = type
        setNeedsLayout()
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        drawGrid()
        drawChart()
        drawLabels()
    }
    
    // MARK: - Drawing Methods
    
    private func drawGrid() {
        let path = UIBezierPath()
        let chartRect = bounds.inset(by: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
        
        // Vertical grid lines
        for i in 0...gridLineCount {
            let x = chartRect.minX + (chartRect.width / CGFloat(gridLineCount)) * CGFloat(i)
            path.move(to: CGPoint(x: x, y: chartRect.minY))
            path.addLine(to: CGPoint(x: x, y: chartRect.maxY))
        }
        
        // Horizontal grid lines
        for i in 0...gridLineCount {
            let y = chartRect.minY + (chartRect.height / CGFloat(gridLineCount)) * CGFloat(i)
            path.move(to: CGPoint(x: chartRect.minX, y: y))
            path.addLine(to: CGPoint(x: chartRect.maxX, y: y))
        }
        
        gridLayer.path = path.cgPath
    }
    
    private func drawChart() {
        guard !dataPoints.isEmpty else { return }
        
        let chartRect = bounds.inset(by: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
        let path = UIBezierPath()
        
        let maxValue = dataPoints.map { $0.value }.max() ?? 1
        let minValue = dataPoints.map { $0.value }.min() ?? 0
        let valueRange = maxValue - minValue
        
        for (index, dataPoint) in dataPoints.enumerated() {
            let x = chartRect.minX + (chartRect.width / CGFloat(dataPoints.count - 1)) * CGFloat(index)
            let normalizedValue = valueRange > 0 ? (dataPoint.value - minValue) / valueRange : 0.5
            let y = chartRect.maxY - (chartRect.height * CGFloat(normalizedValue))
            
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        chartLayer.path = path.cgPath
        
        // Add animation
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = 1.0
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        chartLayer.add(animation, forKey: "strokeAnimation")
    }
    
    private func drawLabels() {
        labelsLayer.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        guard !dataPoints.isEmpty else { return }
        
        let chartRect = bounds.inset(by: UIEdgeInsets(top: padding, left: padding, bottom: padding, right: padding))
        
        // X-axis labels
        for (index, dataPoint) in dataPoints.enumerated() {
            let x = chartRect.minX + (chartRect.width / CGFloat(dataPoints.count - 1)) * CGFloat(index)
            let y = chartRect.maxY + 20
            
            let label = CATextLayer()
            label.string = dataPoint.label
            label.fontSize = 12
            label.foregroundColor = UIColor(named: "AccentLavender")?.cgColor ?? UIColor.darkGray.cgColor
            label.alignmentMode = .center
            
            let labelSize = (dataPoint.label as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)])
            label.frame = CGRect(x: x - labelSize.width / 2, y: y, width: labelSize.width, height: labelSize.height)
            
            labelsLayer.addSublayer(label)
        }
        
        // Y-axis labels
        let maxValue = dataPoints.map { $0.value }.max() ?? 1
        let minValue = dataPoints.map { $0.value }.min() ?? 0
        
        for i in 0...gridLineCount {
            let y = chartRect.minY + (chartRect.height / CGFloat(gridLineCount)) * CGFloat(i)
            let value = maxValue - (maxValue - minValue) * (CGFloat(i) / CGFloat(gridLineCount))
            
            let label = CATextLayer()
            label.string = formatValue(value)
            label.fontSize = 10
            label.foregroundColor = UIColor(named: "AccentLavender")?.cgColor ?? UIColor.darkGray.cgColor
            label.alignmentMode = .right
            
            let labelSize = (formatValue(value) as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
            label.frame = CGRect(x: 0, y: y - labelSize.height / 2, width: padding - 10, height: labelSize.height)
            
            labelsLayer.addSublayer(label)
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", value / 1_000)
        } else {
            return String(format: "%.0f", value)
        }
    }
}

// MARK: - Supporting Types

struct ChartDataPoint {
    let label: String
    let value: Double
}

enum ChartType {
    case line
    case bar
    case area
}
