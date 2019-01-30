import UIKit
import PlaygroundSupport

extension CALayer {
    
    func addBorder(edge: UIRectEdge, color: UIColor, thickness: CGFloat) {
        
        let border = CALayer()
        
        switch edge {
        case .top:
            border.frame = CGRect(x: 0, y: 0, width: frame.width, height: thickness)
        case .bottom:
            border.frame = CGRect(x: 0, y: frame.height - thickness, width: frame.width, height: thickness)
        case .left:
            border.frame = CGRect(x: 0, y: 0, width: thickness, height: frame.height)
        case .right:
            border.frame = CGRect(x: frame.width - thickness, y: 0, width: thickness, height: frame.height)
        default:
            break
        }
        
        border.backgroundColor = color.cgColor;
        
        addSublayer(border)
    }
}

let view = UIView()
view.backgroundColor = .red
view.frame = CGRect(x: 10, y: 10, width: 10, height: 20)
view.layer.addBorder(edge: UIRectEdge.top, color: .clear, thickness: 10)
view.layer.addBorder(edge: UIRectEdge.bottom, color: .clear, thickness: 10)
view.layer.addBorder(edge: UIRectEdge.left, color: .clear, thickness: 10)

let c = UIView()
c.frame = CGRect(x: 0, y: 0, width: 500, height: 500)
c.backgroundColor = .white
c.addSubview(view)

PlaygroundPage.current.liveView = c
