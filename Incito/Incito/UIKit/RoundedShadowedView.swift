//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

/**
 A UIView subclass that allows for shadows and rounded corners. If there is a shadow all of the contents of the view, and the rounding of the corners, will be applied to a `contents` subview. When adding subviews to this view, you must use the `childContainer` property, which either refers to self or the contents, depening on if there is a shadow or not.
 */
class RoundedShadowedView: UIView {
    
    private var contents: UIView?
    private var layerMask: CALayer? // used as a store if we disable/re-enable clipping
    
    init(frame: CGRect, shadow: Shadow? = nil, cornerRadius: Corners<Double> = .zero) {
        super.init(frame: frame)
        
        if let shadow = shadow {
            let contents = UIView(frame: self.bounds)
            contents.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            contents.clipsToBounds = true
            
            self.addSubview(contents)
            self.contents = contents
            self.clipsToBounds = false
            
            // apply shadow to self
            self.layer.applyShadow(shadow)
        }
        
        // apply cornerRadius
        if cornerRadius != Corners<Double>.zero {
            let contentsView = contents ?? self
            
            if cornerRadius.isUniform {
                contentsView.layer.cornerRadius = CGFloat(cornerRadius.topLeft)
            } else {
                
                let cornerMaskPath = UIBezierPath(
                    roundedRect: self.bounds,
                    topLeft: CGFloat(cornerRadius.topLeft),
                    topRight: CGFloat(cornerRadius.topRight),
                    bottomLeft: CGFloat(cornerRadius.bottomLeft),
                    bottomRight: CGFloat(cornerRadius.bottomRight)
                    ).cgPath
                
                let shape = CAShapeLayer()
                shape.frame = self.bounds
                shape.path = cornerMaskPath
                contentsView.layer.mask = shape
                self.layerMask = contentsView.layer.mask
                
                if shadow != nil {
                    self.layer.shadowPath = cornerMaskPath
                }
            }
        }
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var clipsToBounds: Bool {
        get { return contents?.clipsToBounds ?? super.clipsToBounds }
        set {
            if let c = contents { c.clipsToBounds = newValue }
            else { super.clipsToBounds = newValue }
            
            // annoyingly if clipping is disabled && there is a background color, the corners will stop being rounded
            if newValue == false {
                childContainer.layer.mask = nil
            } else {
                childContainer.layer.mask = self.layerMask
            }
        }
    }
    
    override var backgroundColor: UIColor? {
        get { return contents?.backgroundColor ?? super.backgroundColor }
        set {
            if let c = contents { c.backgroundColor = newValue }
            else { super.backgroundColor = newValue }
        }
    }
    
    var childContainer: UIView {
        return contents ?? self
    }
}

extension RoundedShadowedView {
    convenience init(renderableView: RenderableView) {
        let dimensions = renderableView.dimensions
        let rect = CGRect(origin: renderableView.localPosition.cgPoint,
                          size: dimensions.size.cgSize)
        
        let style = renderableView.viewProperties.style
        let cornerRadius = style.cornerRadius.absolute(in: min(dimensions.size.width, dimensions.size.height) / 2)
        
        self.init(
            frame: rect,
            shadow: style.shadow,
            cornerRadius: cornerRadius
        )
    }
}
