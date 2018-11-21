//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

class IncitoWrapper: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        guard let root = self.subviews.first else { return }
        
        var frm = root.frame
        
        // center
        frm.origin.x = bounds.midX - (frm.width / 2)
        
        root.frame = frm
    }
}

func render(_ incito: Incito, into containerView: UIView) {
    
    // put inside a wrapper
    let wrapper = IncitoWrapper()
    containerView.addSubview(wrapper)
    
    wrapper.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        wrapper.topAnchor.constraint(equalTo: containerView.layoutMarginsGuide.topAnchor),
        wrapper.bottomAnchor.constraint(equalTo: containerView.layoutMarginsGuide.bottomAnchor),
        wrapper.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
        wrapper.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    
    // build the view hierarchy
    let rootView = render(incito.rootView.view, in: (width: Double(containerView.frame.size.width),
                                                     height: Double(containerView.frame.size.height)))
    
    wrapper.addSubview(rootView)
}

func render(_ rootView: View, in parentSize: Size) -> UIView {
    let start = Date.timeIntervalSinceReferenceDate
    // build the layout
    let rootNode = layout(view: rootView, in: parentSize)
    let end = Date.timeIntervalSinceReferenceDate
    print("Building layout \(round((end - start) * 1_000_000))μs")
    
    // render the layout - build the UIViews etc
    let view = render(rootNode)
    
    return view
}

func render(_ layout: LayoutNode) -> UIView {
    
    let view = IncitoDebugView()
    
    view.frame = layout.rect
    
    // apply the layout.view properties
    view.backgroundColor = layout.view.style.backgroundColor?.uiColor ?? UIColor.debug
    view.alpha = 0.8
    view.label.text = layout.view.id
    
    for childNode in layout.children {
        let childView = render(childNode)
        view.addSubview(childView)
    }
    return view
}

extension Color {
    var uiColor: UIColor {
        return UIColor(hex: self.hexVal) ?? .clear
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
