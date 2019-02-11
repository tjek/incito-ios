import UIKit
import PlaygroundSupport

import Incito

func deg2rad<A: FloatingPoint>(_ number: A) -> A {
    return number * .pi / 180
}

extension Corners where Value == Double {
    var cgFloat: Corners<CGFloat> {
        return Corners<CGFloat>(
            topLeft: CGFloat(topLeft),
            topRight: CGFloat(topRight),
            bottomLeft: CGFloat(bottomLeft),
            bottomRight: CGFloat(bottomRight)
        )
    }
}

extension Edges where Value == Double {
    var cgFloat: Edges<CGFloat> {
        return Edges<CGFloat>(
            top: CGFloat(top),
            left: CGFloat(left),
            bottom: CGFloat(bottom),
            right: CGFloat(right)
        )
    }
}

func pathsForRoundedRectEdges(
    _ rect: CGRect,
    cornerRadii: Corners<CGFloat>,
    strokeWidths: Edges<CGFloat>
    ) -> Edges<UIBezierPath?> {
    
    let insetRect = rect.inset(by: UIEdgeInsets(
        top: strokeWidths.top / 2,
        left: strokeWidths.left / 2,
        bottom: strokeWidths.bottom / 2,
        right: strokeWidths.right / 2)
    )
    
    let topLeft = insetRect.origin
    let topRight = CGPoint(x: insetRect.maxX, y: insetRect.minY)
    let bottomRight = CGPoint(x: insetRect.maxX, y: insetRect.maxY)
    let bottomLeft = CGPoint(x: insetRect.minX, y: insetRect.maxY)
    
//    let topLeft = rect.origin
//    let topRight = CGPoint(x: rect.maxX, y: rect.minY)
//    let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
//    let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
    
    var edgePaths = Edges<UIBezierPath?>(nil)
    
    func buildPath(startCorner: CGPoint, endCorner: CGPoint, startCornerRadius: CGFloat, endCornerRadius: CGFloat, precedingLineWidth: CGFloat, followingLineWidth: CGFloat, startAngleDegs: CGFloat, edge: CGRectEdge) -> UIBezierPath {
        
        let startCornerRadius = max(0, startCornerRadius - (precedingLineWidth / 2))
        let endCornerRadius = max(0, endCornerRadius - (followingLineWidth / 2))
        
        let startPoint: CGPoint = {
            var pnt = startCorner
            
            switch edge {
            case .minXEdge: // left
                pnt.y -= startCornerRadius
                if startCornerRadius == 0 {
                    pnt.y += precedingLineWidth / 2
                }
            case .maxXEdge: // right
                pnt.y += startCornerRadius
                if startCornerRadius == 0 {
                    pnt.y -= precedingLineWidth / 2
                }
            case .minYEdge: // top
                pnt.x += startCornerRadius
                if startCornerRadius == 0 {
                    pnt.x -= precedingLineWidth / 2
                }
            case .maxYEdge: // bottom
                pnt.x -= startCornerRadius
                if startCornerRadius == 0 {
                    pnt.x += precedingLineWidth / 2
                }
            }
            
            return pnt
        }()
        
        let endPoint: CGPoint = {
            var pnt = endCorner
            
            switch edge {
            case .minXEdge: // left
                pnt.y += endCornerRadius
                if endCornerRadius == 0 {
                    pnt.y -= followingLineWidth / 2
                }
            case .maxXEdge: // right
                pnt.y -= endCornerRadius
                if endCornerRadius == 0 {
                    pnt.y += followingLineWidth / 2
                }
            case .minYEdge: // top
                pnt.x -= endCornerRadius
                if endCornerRadius == 0 {
                    pnt.x -= followingLineWidth / 2
                }
            case .maxYEdge: // bottom
                pnt.x += endCornerRadius
                if endCornerRadius == 0 {
                    pnt.x -= followingLineWidth / 2
                }
            }
            
            return pnt
        }()
        
        let startCornerCenter: CGPoint = {
            var centerPoint = startPoint
            
            switch edge {
            case .minXEdge: // left
                centerPoint.x += startCornerRadius
            case .maxXEdge: // right
                centerPoint.x -= startCornerRadius
            case .minYEdge: // top
                centerPoint.y += startCornerRadius
            case .maxYEdge: // bottom
                centerPoint.y -= startCornerRadius
            }
            
            return centerPoint
        }()
        
        let endCornerCenter: CGPoint = {
            var centerPoint = endPoint
            
            switch edge {
            case .minXEdge: // left
                centerPoint.x += endCornerRadius
            case .maxXEdge: // right
                centerPoint.x -= endCornerRadius
            case .minYEdge: // top
                centerPoint.y += endCornerRadius
            case .maxYEdge: // bottom
                centerPoint.y -= endCornerRadius
            }
            
            return centerPoint
        }()
        
        let path = CGMutablePath()
        
        path.move(to: startPoint)
        
        if startCornerRadius != 0 {
            
            path.addRelativeArc(
                center: startCornerCenter,
                radius: startCornerRadius,
                startAngle: deg2rad(startAngleDegs),
                delta: deg2rad(-45),
                transform: .identity
            )
            path.move(to: startPoint)
        }
        
        path.addLine(to: endPoint)
        
        if endCornerRadius != 0 {
            path.addRelativeArc(
                center: endCornerCenter,
                radius: endCornerRadius,
                startAngle: deg2rad(startAngleDegs),
                delta: deg2rad(45),
                transform: .identity
            )
        }
        
        return UIBezierPath(cgPath: path)
    }
    
    edgePaths.top = buildPath(
        startCorner: topLeft,
        endCorner: topRight,
        startCornerRadius: cornerRadii.topLeft,
        endCornerRadius: cornerRadii.topRight,
        precedingLineWidth: strokeWidths.left,
        followingLineWidth: strokeWidths.right,
        startAngleDegs: -90,
        edge: .minYEdge
    )
    
    edgePaths.right = buildPath(
        startCorner: topRight,
        endCorner: bottomRight,
        startCornerRadius: cornerRadii.topRight,
        endCornerRadius: cornerRadii.bottomRight,
        precedingLineWidth: strokeWidths.top,
        followingLineWidth: strokeWidths.bottom,
        startAngleDegs: 0,
        edge: .maxXEdge
    )
    
    edgePaths.bottom = buildPath(
        startCorner: bottomRight,
        endCorner: bottomLeft,
        startCornerRadius: cornerRadii.bottomRight,
        endCornerRadius: cornerRadii.bottomLeft,
        precedingLineWidth: strokeWidths.right,
        followingLineWidth: strokeWidths.left,
        startAngleDegs: 90,
        edge: .maxYEdge
    )

    edgePaths.left = buildPath(
        startCorner: bottomLeft,
        endCorner: topLeft,
        startCornerRadius: cornerRadii.bottomLeft,
        endCornerRadius: cornerRadii.topLeft,
        precedingLineWidth: strokeWidths.bottom,
        followingLineWidth: strokeWidths.top,
        startAngleDegs: 180,
        edge: .minXEdge
    )
    
    return edgePaths
}

//    convenience init(roundedRect rect: CGRect, topLeftRadius: CGSize = .zero, topRightRadius: CGSize = .zero, bottomLeftRadius: CGSize = .zero, bottomRightRadius: CGSize = .zero) {
//
//        self.init()
//
//        let path = CGMutablePath()
//
//        let topLeft = rect.origin
//        let topRight = CGPoint(x: rect.maxX, y: rect.minY)
//        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
//        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
//
//        if topLeftRadius != .zero {
//            path.move(to: CGPoint(x: topLeft.x + topLeftRadius.width, y: topLeft.y))
//        } else {
//            path.move(to: topLeft)
//        }
//
//        if topRightRadius != .zero {
//            path.addLine(to: CGPoint(x: topRight.x - topRightRadius.width, y: topRight.y))
//            path.addCurve(
//                to: CGPoint(x: topRight.x, y: topRight.y + topRightRadius.height),
//                control1: CGPoint(x: topRight.x, y: topRight.y),
//                control2: CGPoint(x: topRight.x, y: topRight.y + topRightRadius.height)
//            )
//        } else {
//            path.addLine(to: topRight)
//        }
//
//        if bottomRightRadius != .zero{
//            path.addLine(to: CGPoint(x: bottomRight.x, y: bottomRight.y-bottomRightRadius.height))
//            path.addCurve(
//                to: CGPoint(x: bottomRight.x - bottomRightRadius.width, y: bottomRight.y),
//                control1: CGPoint(x: bottomRight.x, y: bottomRight.y),
//                control2: CGPoint(x: bottomRight.x - bottomRightRadius.width, y: bottomRight.y)
//            )
//        } else {
//            path.addLine(to: bottomRight)
//        }
//
//        if bottomLeftRadius != .zero {
//            path.addLine(to: CGPoint(x: bottomLeft.x + bottomLeftRadius.width, y: bottomLeft.y))
//            path.addCurve(
//                to: CGPoint(x: bottomLeft.x, y: bottomLeft.y - bottomLeftRadius.height),
//                control1: CGPoint(x: bottomLeft.x, y: bottomLeft.y),
//                control2: CGPoint(x: bottomLeft.x, y: bottomLeft.y-bottomLeftRadius.height)
//            )
//        } else {
//            path.addLine(to: bottomLeft)
//        }
//
//        if topLeftRadius != .zero{
//            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y+topLeftRadius.height))
//            path.addCurve(to: CGPoint(x: topLeft.x+topLeftRadius.width, y: topLeft.y) , control1: CGPoint(x: topLeft.x, y: topLeft.y) , control2: CGPoint(x: topLeft.x+topLeftRadius.width, y: topLeft.y))
//        } else {
//            path.addLine(to: CGPoint(x: topLeft.x, y: topLeft.y))
//        }
//
//        path.closeSubpath()
//        cgPath = path
//    }



extension CALayer {
    
    func addStroke(_ stroke: Stroke, cornerRadius: Corners<Double>) {
        // if all stroke dimensions, and corner radii, are uniform, then dont do anything special
        if cornerRadius.isUniform,
            stroke.color.isUniform,
            stroke.width.isUniform {
            // use basic stroke
            self.borderWidth = CGFloat(stroke.width.top)
            self.borderColor = stroke.color.top.uiColor.cgColor
        }
    
        let borderLayer = CALayer()
        borderLayer.frame = self.bounds;
        
        let paths = pathsForRoundedRectEdges(
            borderLayer.frame,
            cornerRadii: cornerRadius.cgFloat,
            strokeWidths: stroke.width.cgFloat
        )
        
        let pathProperties: [(UIBezierPath?, CGColor, CGFloat, Stroke.Style)] = [
            (paths.top, stroke.color.top.uiColor.cgColor, CGFloat(stroke.width.top), stroke.style),
            (paths.right, stroke.color.right.uiColor.cgColor, CGFloat(stroke.width.right), stroke.style),
            (paths.bottom, stroke.color.bottom.uiColor.cgColor, CGFloat(stroke.width.bottom), stroke.style),
            (paths.left, stroke.color.left.uiColor.cgColor, CGFloat(stroke.width.left), stroke.style),
        ]
        
        
        for (possiblePath, color, width, style) in pathProperties {
            guard let path = possiblePath else { continue }
            
            let edgeLayer = CAShapeLayer()
            edgeLayer.frame = self.bounds
            
            edgeLayer.fillColor = nil
            edgeLayer.strokeColor = color
            edgeLayer.lineWidth = width
            switch style {
            case .dotted:
                edgeLayer.lineDashPattern = [0, width * 2] as [NSNumber]
                edgeLayer.lineCap = .round
            case .solid:
                edgeLayer.lineDashPattern = nil
                edgeLayer.lineCap = .butt
            case .dashed:
                edgeLayer.lineDashPattern = [width * 2, width] as [NSNumber]
                edgeLayer.lineCap = .butt
                edgeLayer.lineDashPhase = 0
            }
            
            edgeLayer.path = path.cgPath
            
            self.addSublayer(edgeLayer)
        }
        
//        if let topPath = paths.top {
//            topPath.copy
//
//            let topLayer = CAShapeLayer()
//            topLayer.frame = self.bounds
//
//            topLayer.fillColor = nil
//            topLayer.strokeColor = stroke.color.top.uiColor.cgColor
//            topLayer.lineWidth = CGFloat(stroke.width.top)
//
//            switch stroke.style {
//            case .dotted:
//                topLayer.lineDashPattern = [0, stroke.width.top * 2] as [NSNumber]
//                topLayer.lineCap = .round
//            case .solid:
//                topLayer.lineDashPattern = nil
//                topLayer.lineCap = .butt
//            case .dashed:
//                topLayer.lineDashPattern = [stroke.width.top * 2, stroke.width.top] as [NSNumber]
//                topLayer.lineCap = .butt
//            }
//            // dotted
//
//            topLayer.path = topPath.cgPath
//
////            topLayer.path = topPath.cgPath.copy(
////                strokingWithWidth: CGFloat(stroke.width.top),
////                lineCap: .butt,
////                lineJoin: CGLineJoin.miter,
////                miterLimit: 0
////            )
//
//            self.addSublayer(topLayer)
//        }
        
    }
}

let view = UIView()
view.backgroundColor = UIColor(white: 0.8, alpha: 1)
view.frame = CGRect(x: 50, y: 50, width: 200, height: 200)

let stroke = Stroke.init(
    style: .dashed,
    width: Edges<Double>(top: 20, left: 10, bottom: 20, right: 10),
    color: Edges<Color>(
        top: Color(string: "#960911")!,
        left: Color(string: "#000911")!,
        bottom: Color(string: "#ff0900")!,
        right: Color(string: "#00ffaa")!
    )
)

//view.layer.cornerRadius = 40
//view.roundCorners(topLeft: 40, topRight: 0, bottomLeft: 20, bottomRight: 30)
view.layer.addStroke(
    stroke,
    cornerRadius: Corners(topLeft: 50, topRight: 100, bottomLeft: 100, bottomRight: 100)
)


let sizeMarker = UIView()
sizeMarker.backgroundColor = UIColor.red.withAlphaComponent(0.2)
sizeMarker.frame = view.frame


let c = UIView()
c.frame = CGRect(x: 0, y: 0, width: 500, height: 500)
c.backgroundColor = .white
c.addSubview(sizeMarker)
c.addSubview(view)

PlaygroundPage.current.liveView = c
