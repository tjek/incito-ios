//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

func render(_ incito: Incito, into containerView: UIView) {
    
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
    
    // build the view hierarchy
    let rootView = render(incito.rootView,
                          in: Size(cgSize: containerView.frame.size))
    wrapper.addSubview(rootView)
    
    print("Subviews: ", rootView.recursiveSubviewCount())
    
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

func render(_ rootView: View, in parentSize: Size) -> UIView {
    let start = Date.timeIntervalSinceReferenceDate
    
    // build the layout
    let rootNode = layout(view: rootView, parentLayout: .static, in: parentSize)
    
    let end = Date.timeIntervalSinceReferenceDate
    print("Building layout \(round((end - start) * 1_000))ms")
    
    // render the layout - build the UIViews etc
    let view = render(rootNode, maxKids: 2)
    
    return view
}

func render(_ layout: LayoutNode, maxKids: Int? = nil) -> UIView {
    let view: UIView
    
    switch layout.view.type {
    case let .text(textProperties):
        view = renderTextView(textProperties, styleProperties: layout.view.style)
    default:
        let dbgView = IncitoDebugView()
        dbgView.label.text = layout.view.id
        view = dbgView
    }
    
    view.frame = layout.rect.cgRect
    
    view.apply(styleProperties: layout.view.style)
    
    var children = layout.children
    if let kidLimit = maxKids {
        children = Array(children.prefix(kidLimit))
    }
    
    for childNode in children {
        let childView = render(childNode)
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
        
        addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: self.centerYAnchor)
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

func renderTextView(_ textProperties: TextViewProperties, styleProperties: StyleProperties) -> UIView {
    let label = UILabel()
    
    var string = textProperties.text
    if textProperties.allCaps {
        string = string.uppercased()
    }
    
    label.text = string
    label.numberOfLines = textProperties.maxLines
    label.textColor = textProperties.textColor?.uiColor ?? .black
    label.font = textProperties.font()
    label.textAlignment = .center
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
    func apply(styleProperties style: StyleProperties) {
        
        // apply the layout.view properties
        backgroundColor = style.backgroundColor?.uiColor ?? .clear
        clipsToBounds = style.clipsChildren
        
        // Use the smallest dimension when calculating relative corners.
        let cornerRadius = style.cornerRadius.absolute(in: Double(min(frame.size.width, frame.size.height) / 2))
        roundCorners(
            topLeft: CGFloat(cornerRadius.topLeft),
            topRight: CGFloat(cornerRadius.topRight),
            bottomLeft: CGFloat(cornerRadius.bottomLeft),
            bottomRight: CGFloat(cornerRadius.bottomRight)
        )
    }
}
