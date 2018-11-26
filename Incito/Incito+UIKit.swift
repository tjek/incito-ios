//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

//struct IncitoRenderer {
//    // given a font family and a size it returns a UIFont
//    var fontProvider: (FontFamily, CGFloat) -> UIFont
//}

func render(_ incito: Incito, fontLoader: (FontFamily, CGFloat) -> UIFont, into containerView: UIView) {
    
    let scroll = UIScrollView()
    
    containerView.addSubview(scroll)
    scroll.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        scroll.topAnchor.constraint(equalTo: containerView.topAnchor),
        scroll.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        scroll.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        scroll.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    
    
    // put inside a wrapper
    let wrapper = UIView()
    scroll.addSubview(wrapper)
    
    scroll.backgroundColor = incito.theme?.bgColor?.uiColor ?? .white
    wrapper.backgroundColor = incito.theme?.bgColor?.uiColor ?? .white
    
    // build the view hierarchy
    let rootView = render(incito.rootView,
                          fontLoader: fontLoader,
                          in: Size(cgSize: containerView.frame.size))
    wrapper.addSubview(rootView)
    
    wrapper.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        wrapper.topAnchor.constraint(equalTo: scroll.topAnchor),
        wrapper.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
        wrapper.leftAnchor.constraint(greaterThanOrEqualTo: scroll.leftAnchor),
        wrapper.rightAnchor.constraint(lessThanOrEqualTo: scroll.rightAnchor),
        wrapper.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
        
        wrapper.heightAnchor.constraint(equalToConstant: rootView.frame.size.height),
        wrapper.widthAnchor.constraint(equalToConstant: rootView.frame.size.width)
        ])
}

func render(_ rootView: View, fontLoader: (FontFamily, CGFloat) -> UIFont, in parentSize: Size) -> UIView {
    let start = Date.timeIntervalSinceReferenceDate
    
    // build the layout
    let rootNode = layout(view: rootView, parentLayout: .static, in: parentSize)
    
    let end = Date.timeIntervalSinceReferenceDate
    print("Building layout \(round((end - start) * 1_000))ms")
    
    // render the layout - build the UIViews etc
    let view = render(rootNode, fontLoader: fontLoader, maxKids: nil)
    
    return view
}

func render(_ layout: LayoutNode, fontLoader: (FontFamily, CGFloat) -> UIFont, maxKids: Int? = nil) -> UIView {
    let view: UIView
    
    switch layout.view.type {
    case let .text(textProperties):
        view = renderTextView(textProperties, styleProperties: layout.view.style, fontLoader: fontLoader, in: layout.rect)
    case .view:
        view = renderPassthruView(styleProperties: layout.view.style, in: layout.rect)
    case .absoluteLayout:
        view = renderPassthruView(styleProperties: layout.view.style, in: layout.rect)
    case .flexLayout:
        view = renderPassthruView(styleProperties: layout.view.style, in: layout.rect)
    default:
        let dbgView = IncitoDebugView()
        dbgView.isHidden = true
//        dbgView.label.text = layout.view.id
        view = dbgView
    }
    
    view.frame = layout.rect.cgRect
    
    // must be called after frame otherwise round-rect clipping path is not sized properly
    view.apply(styleProperties: layout.view.style, in: layout.rect)
    
    var children = layout.children
    if let kidLimit = maxKids {
        children = Array(children.prefix(kidLimit))
    }
    
    for childNode in children {
        let childView = render(childNode, fontLoader: fontLoader)
        view.addSubview(childView)
    }
    
    return view
}

extension UIView {
    func recursiveSubviewCount(where predicate: (UIView) -> Bool = { _ in true }) -> Int {
        return self.subviews.reduce(1) {
            if predicate($1) {
                return $0 + $1.recursiveSubviewCount(where: predicate)
            } else {
                return $0
            }
        }
    }
}

extension Color {
    var uiColor: UIColor {
        return UIColor(hex: self.hexVal) ?? .clear
    }
}

extension Point {
    init(cgPoint: CGPoint) {
        self.init(x: Double(cgPoint.x), y: Double(cgPoint.y))
    }
    var cgPoint: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

extension Size {
    init(cgSize: CGSize) {
        self.init(width: Double(cgSize.width), height: Double(cgSize.height))
    }
    var cgSize: CGSize {
        return CGSize(width: width, height: height)
    }
}
extension Rect {
    init(cgRect: CGRect) {
        self.init(origin: Point(cgPoint: cgRect.origin),
                  size: Size(cgSize: cgRect.size))
    }
    var cgRect: CGRect {
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
}

class IncitoDebugView: UIView {
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
//        addSubview(label)
//
//        label.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
//            label.centerYAnchor.constraint(equalTo: self.centerYAnchor)
//            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
func renderPassthruView(styleProperties: StyleProperties, in rect: Rect) -> UIView {
    let view = UIView()
    
    
    return view
}

func renderTextView(_ textProperties: TextViewProperties, styleProperties: StyleProperties, fontLoader: (FontFamily, CGFloat) -> UIFont, in rect: Rect) -> UIView {
    let label = UILabel()
    
    var string = textProperties.text
    if textProperties.allCaps {
        string = string.uppercased()
    }
    
    label.text = string
    label.numberOfLines = textProperties.maxLines
    label.textColor = textProperties.textColor?.uiColor ?? .black
    label.font = fontLoader(textProperties.fontFamily, CGFloat(ceil(textProperties.textSize ?? 16)))
    label.textAlignment = .center
    
    label.backgroundColor = .clear
    
    return label
}

extension TextViewProperties {
    func font() -> UIFont {
        // TODO: a font-provider (the using the webfont loader), from which a font can be selected using the fontFamilyName.

        // TODO: what is the default fontSize?
        let fontSize = CGFloat(ceil(self.textSize ?? 16))
        return UIFont.boldSystemFont(ofSize: fontSize)
    }
}

extension UIView {
    func apply(styleProperties style: StyleProperties, in rect: Rect) {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        clipsToBounds = style.clipsChildren
        
        // Use the smallest dimension when calculating relative corners.
        let cornerRadius = style.cornerRadius.absolute(in: min(rect.size.width, rect.size.height) / 2)
        
        if cornerRadius != Corners<Double>.zero {
            if cornerRadius.topLeft == cornerRadius.topRight && cornerRadius.bottomLeft == cornerRadius.bottomRight &&
                cornerRadius.topLeft == cornerRadius.bottomLeft {
                
                layer.cornerRadius = CGFloat(cornerRadius.topLeft)
            } else {
                roundCorners(
                    topLeft: CGFloat(cornerRadius.topLeft),
                    topRight: CGFloat(cornerRadius.topRight),
                    bottomLeft: CGFloat(cornerRadius.bottomLeft),
                    bottomRight: CGFloat(cornerRadius.bottomRight)
                )
            }
        }
    }
}
