import UIKit
import PlaygroundSupport

import Incito

func deg2rad<A: FloatingPoint>(_ number: A) -> A {
    return number * .pi / 180
}

extension Corners {
    
    /// clockwise order, so (topLeft, topRight), (bottomRight, bottomLeft) etc
    func values(forEdge edge: CGRectEdge) -> (Value, Value) {
        print(edge, self)
        switch edge {
        case .minYEdge: // top
            return (topLeft, topRight)
        case .maxXEdge: // right
            return (topRight, bottomRight)
        case .maxYEdge: // bottom
            return (bottomRight, bottomLeft)
        case .minXEdge: // left
            return (bottomLeft, topLeft)
        }
    }
}

extension CGRectEdge {
    
    /// In clockwise order
    var next: CGRectEdge {
        switch self {
        case .minYEdge: // top
            return .maxXEdge // -> right
        case .maxXEdge: // right
            return .maxYEdge // -> bottom
        case .maxYEdge: // bottom
            return .minXEdge // -> left
        case .minXEdge: // left
            return .minYEdge // -> top
        }
    }
    /// Next in anti-clockwise order
    var previous: CGRectEdge {
        switch self {
        case .minYEdge: // top
            return .minXEdge // -> left
        case .maxXEdge: // right
            return .minYEdge // -> top
        case .maxYEdge: // bottom
            return .maxXEdge // -> right
        case .minXEdge: // left
            return .maxYEdge // -> bottom
        }
    }
}

extension Stroke.Style {
    func dashPattern(lineWidth: CGFloat) -> [CGFloat]? {
        switch self {
        case .solid:
            return nil
        case .dashed:
            return [lineWidth * 2, lineWidth]
        case .dotted:
            return [0, lineWidth * 2]
        }
    }
}

func buildPath(
    edge: CGRectEdge,
    cornerPoints: Corners<CGPoint>,
    cornerRadii: Corners<CGFloat>,
    lineWidths: Edges<CGFloat>
    ) -> (UIBezierPath, CGFloat)? {
    
    let lineWidth = lineWidths.value(forEdge: edge)
    guard lineWidth > 0 else { return nil }

    let precedingLineWidth = lineWidths.value(forEdge: edge.previous)
    let followingLineWidth = lineWidths.value(forEdge: edge.next)

    let startAngleDegs: CGFloat = Edges(
        top: -90,
        left: 180,
        bottom: 90,
        right: 0)
        .value(forEdge: edge)
    
    let cornerRadiusPair: (CGFloat, CGFloat) = cornerRadii.values(forEdge: edge)
    
    let startCornerRadius = max(0, cornerRadiusPair.0 - (precedingLineWidth / 2))
    let endCornerRadius = max(0, cornerRadiusPair.1 - (followingLineWidth / 2))
    
    let cornerPointPair: (CGPoint, CGPoint) = cornerPoints.values(forEdge: edge)
    
    // start point of the straight part
    // takes into account the corner radius & neighbour line widths
    let startPoint: CGPoint = {
        var pnt = cornerPointPair.0
        
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
    
    // end point of the straight part
    // takes into account the corner radius & neighbour line widths
    let endPoint: CGPoint = {
        var pnt = cornerPointPair.1
        
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
                pnt.x += followingLineWidth / 2
            }
        case .maxYEdge: // bottom
            pnt.x += endCornerRadius
            if endCornerRadius == 0 {
                pnt.x -= followingLineWidth / 2
            }
        }
        
        return pnt
    }()
    
    // center of the first corner arc
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
    
    // center of the last corner arc
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
    
    // the path that will be built
    let path = UIBezierPath()
    // the total length of that path
    var length: CGFloat = 0
    
    // move to the start of the straight part
    path.move(to: startPoint)
    
    // if there is a corner radius, append a curve for the corner
    if startCornerRadius != 0 {
        
        let firstCornerPath = UIBezierPath()
        firstCornerPath.addArc(
            withCenter: startCornerCenter,
            radius: startCornerRadius,
            startAngle: deg2rad(startAngleDegs),
            endAngle: deg2rad(startAngleDegs - 45),
            clockwise: false
        )
        // we reverse it otherwise dash-phase gets weird
        path.append(firstCornerPath.reversing())
        // calculate the length of the arc
        length += (2 * .pi * startCornerRadius) / 8
    }
    
    // draw the straight part
    path.addLine(to: endPoint)
    
    // calculate the length of the edge
    switch edge {
    case .minXEdge, .maxXEdge: // left/right
        length += abs(startPoint.y - endPoint.y)
    case .minYEdge, .maxYEdge: // top/bottom
        length += abs(startPoint.x - endPoint.x)
    }
    
    // if the last corner is curved, append the arc
    if endCornerRadius != 0 {
        path.addArc(
            withCenter: endCornerCenter,
            radius: endCornerRadius,
            startAngle: deg2rad(startAngleDegs),
            endAngle: deg2rad(startAngleDegs + 45),
            clockwise: true
        )
        length += (2 * .pi * endCornerRadius) / 8
    }
    
    return (path, length)
}


/// Given cornerRadii, and strokeWidths, will return optional path/length tuples for each edge. If an edge's strokeWidth is zero that edge's result is nil. Path is inset from the bounding rect by the stroke widths
func pathsForRoundedRectEdges(
    _ rect: Rect<CGFloat>,
    cornerRadii: Corners<CGFloat>,
    strokeWidths: Edges<CGFloat>
    ) -> Edges<(path: UIBezierPath, length: CGFloat)?> {
    
    // inset rect by half the strokeWidths (so when stroked they are just inside the rect
    let insetRect = rect.inset(
        by: strokeWidths.map({ $0 / 2 })
    )
    
    let cornerPoints: Corners<CGPoint> = insetRect.cornerPoints.map { $0.cgPoint }
    
    var edgePaths = Edges<(path: UIBezierPath, length: CGFloat)?>(nil)

    edgePaths.top = buildPath(
        edge: .minYEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )
    edgePaths.right = buildPath(
        edge: .maxXEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )
    edgePaths.bottom = buildPath(
        edge: .maxYEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )
    edgePaths.left = buildPath(
        edge: .minXEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )

    return edgePaths
}

func buildEdgeLayer(
    path: UIBezierPath,
    frame: CGRect,
    color: UIColor,
    width: CGFloat,
    style: Stroke.Style,
    dashPhase: CGFloat
    ) -> CAShapeLayer {
    
    let edgeLayer = CAShapeLayer()
    edgeLayer.frame = frame
    edgeLayer.masksToBounds = true
    
    edgeLayer.fillColor = UIColor.red.withAlphaComponent(0.2).cgColor // nil
    edgeLayer.strokeColor = color.cgColor
    edgeLayer.lineWidth = width
    
    edgeLayer.lineDashPhase = dashPhase
    edgeLayer.lineDashPattern = style.dashPattern(lineWidth: width) as [NSNumber]?
    
    switch style {
    case .dotted:
        edgeLayer.lineCap = .round
    case .solid:
        edgeLayer.lineDashPattern = nil
        edgeLayer.lineCap = .butt
    case .dashed:
        edgeLayer.lineCap = .butt
    }
    
    edgeLayer.path = path.cgPath
    return edgeLayer
}


extension CALayer {
    
    func addStroke(_ stroke: Stroke, cornerRadius: Corners<Double>) {
        // if all stroke dimensions, and corner radii, are uniform, then dont do anything special
        if cornerRadius.isUniform,
            stroke.color.isUniform,
            stroke.width.isUniform {
            // use basic stroke. applying cornerRadius needs to be handled elsewhere
            self.borderWidth = CGFloat(stroke.width.top)
            self.borderColor = stroke.color.top.uiColor.cgColor
            return
        }
    
        let shapeLayer = CAShapeLayer()
        shapeLayer.frame = self.bounds
        shapeLayer.fillColor = UIColor.red.withAlphaComponent(0.3).cgColor
        shapeLayer.strokeColor = UIColor.blue.withAlphaComponent(0.3).cgColor
        shapeLayer.lineWidth = 1
        
        let outerPath = UIBezierPath(roundedRect: shapeLayer.bounds, cornerRadius: 50)
        
        let innerPath = UIBezierPath(roundedRect: shapeLayer.bounds.insetBy(dx: 30, dy: 10), cornerRadius: 30)
        
        let strokePath = outerPath
        strokePath.append(innerPath.reversing())
        
        UIGraphicsBeginImageContext(self.bounds.size)
        let ctx = UIGraphicsGetCurrentContext()!

        ctx.setLineWidth(100)

        ctx.setLineDash(phase: 0, lengths: [40, 20])
        ctx.setLineCap(CGLineCap.butt)

        ctx.addPath(innerPath.cgPath)

        ctx.replacePathWithStrokedPath()
        let dashedPath = UIBezierPath(cgPath: ctx.path!)

        UIGraphicsEndImageContext()

        let maskLayer = CAShapeLayer()
        maskLayer.frame = shapeLayer.bounds
        maskLayer.path = dashedPath.cgPath
        
//        shapeLayer.fillRule = .evenOdd
        shapeLayer.path = strokePath.cgPath
        shapeLayer.mask = maskLayer
        self.addSublayer(shapeLayer)
    }
}

let view = UIView()
view.backgroundColor = UIColor(white: 0.8, alpha: 1)
view.frame = CGRect(x: 50, y: 50, width: 400, height: 400)

//view.layer.cornerRadius = 40
//view.roundCorners(topLeft: 40, topRight: 0, bottomLeft: 20, bottomRight: 30)

//view.layer.addStroke(
//    Stroke(
//        style: .dashed,
//        width: Edges<Double>(top: 10, left: 10, bottom: 24, right: 50),
//        color: Edges<Color>(
//            top: Color(string: "#960911aa")!,
//            left: Color(string: "#000911aa")!,
//            bottom: Color(string: "#ff0900aa")!,
//            right: Color(string: "#00ffaaaa")!
//        )
//    ),
//    cornerRadius: Corners(topLeft: 20, topRight: 200, bottomLeft: 100, bottomRight: 200)
//)

view.backgroundColor = Color(string: "rgba(90%, 90%, 90%, 100%)")?.uiColor

view.layer.addStroke(
    Stroke(
        style: .solid,
        width: Edges<Double>(top: 10, left: 10, bottom: 20, right: 10),
        color: Edges<Color>(Color(string: "#960911")!)
    ),
    cornerRadius: Corners(20)
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
