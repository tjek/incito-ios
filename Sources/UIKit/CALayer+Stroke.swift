//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

extension CALayer {
    /// Given some Stroke properties, and corner radii, will add sublayers to the reciever that draw the strokes. If stroke & cornerRadii are uniform, will resort to using simple borderWidth/color on the current layer. Note that cornerRadius is not actually applied to the layer - that must be done elsewhere.
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
        
        let borderLayer = CALayer()
        borderLayer.frame = self.bounds;
        
        let strokeWidths = stroke.width.withCGFloats
        
        let paths = pathsForRoundedRectEdges(
            Rect(cgRect: borderLayer.frame),
            cornerRadii: cornerRadius.withCGFloats,
            strokeWidths: strokeWidths
        )
        
        if let (path, _) = paths.top {
            let lineWidth = strokeWidths.top
            self.addSublayer(buildEdgeLayer(
                path: path,
                frame: self.bounds,
                color: stroke.color.top.uiColor,
                width: lineWidth,
                style: stroke.style,
                dashPhase: (lineWidth / 2)
            ))
        }
        
        if let (path, _) = paths.right {
            let lineWidth = strokeWidths.right
            self.addSublayer(buildEdgeLayer(
                path: path,
                frame: self.bounds,
                color: stroke.color.right.uiColor,
                width: lineWidth,
                style: stroke.style,
                dashPhase: (lineWidth / 2)
            ))
        }
        
        
        if let (path, _) = paths.bottom {
            let lineWidth = strokeWidths.bottom
            self.addSublayer(buildEdgeLayer(
                path: path,
                frame: self.bounds,
                color: stroke.color.bottom.uiColor,
                width: lineWidth,
                style: stroke.style,
                dashPhase: (lineWidth / 2)
            ))
        }
        
        if let (path, _) = paths.left {
            let lineWidth = strokeWidths.left
            self.addSublayer(buildEdgeLayer(
                path: path,
                frame: self.bounds,
                color: stroke.color.left.uiColor,
                width: lineWidth,
                style: stroke.style,
                dashPhase: (lineWidth / 2)
            ))
        }
    }
}

fileprivate func deg2rad<A: FloatingPoint>(_ number: A) -> A {
    return number * .pi / 180
}

extension Corners {
    /// clockwise order, so (topLeft, topRight), (bottomRight, bottomLeft) etc
    fileprivate func values(forEdge edge: CGRectEdge) -> (Value, Value) {
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
    fileprivate var next: CGRectEdge {
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
    fileprivate var previous: CGRectEdge {
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
    fileprivate func dashPattern(lineWidth: CGFloat) -> [CGFloat]? {
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

/// Returns a path/length pair for a specific edge.
fileprivate func buildStrokeablePath(
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
fileprivate func pathsForRoundedRectEdges(
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
    
    edgePaths.top = buildStrokeablePath(
        edge: .minYEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )
    edgePaths.right = buildStrokeablePath(
        edge: .maxXEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )
    edgePaths.bottom = buildStrokeablePath(
        edge: .maxYEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )
    edgePaths.left = buildStrokeablePath(
        edge: .minXEdge,
        cornerPoints: cornerPoints,
        cornerRadii: cornerRadii,
        lineWidths: strokeWidths
    )
    
    return edgePaths
}

/// Creates a CALayer that is strokes the the specified path with the required stroke properties
fileprivate func buildEdgeLayer(
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
    
    edgeLayer.fillColor = nil
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

