//
//  ViewController.swift
//  Incito
//
//  Created by Laurie Hufford on 14/11/2018.
//  Copyright © 2018 ShopGun. All rights reserved.
//

import UIKit

class IncitoViewController: UIViewController {
    
    var incito: Incito = decodeIncito("superbrugsen.json")
//    var incito: Incito = decodeIncito("simple-incito-absolute.json")
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

//        let scrollView = UIScrollView()
//        view.addSubview(scrollView)
//
//        scrollView.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
//            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
//            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
//            ])
        
//        layoutRelative(incito.rootView, prevSiblingRect: nil, padding: .zero, parentWidth: .px(view.frame.size.width))
//
//
//        let incitoView = render(incito)
        let incito = self.incito
        
        let start = Date.timeIntervalSinceReferenceDate
        render(incito, into: self.view)
        let end = Date.timeIntervalSinceReferenceDate
        print("Building Views \(round((end - start) * 1_000))ms")

//        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "IncitoCell")
    }

//    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return 10
//    }
//    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "IncitoCell", for: indexPath)
//        cell.backgroundColor = .orange
//        return cell
//    }
}


//extension Incito {
//    var numberOfSections: Int {
//        return self.rootView.viewProperties.childViews.count
//    }
//}

// parse(JSON) -> Incito
// render(Incito, Config) -> IncitoUIView + fontloader + datasource + eventHandler


//func render(_ incito: Incito) -> UIView {
//
//    // Depending on the rootView type, we might need different ViewController types. (always linear layout?)
//
//    let containerView = UIView()
//    containerView.backgroundColor = incito.theme?.bgColor?.uiColor
//
//    render(incito.rootView, into: containerView)
//
//    return containerView
//}
//
//func render(_ view: IncitoViewType, into parentView: UIView) {
//
//    // TODO: pass font-assets further. or just rebuild properties+theme+assets+... into something the renderer can use (to be passed to the children)
//    switch view {
//    case let .absoluteLayout(properties): renderAbsoluteLayout(properties, into: parentView)
//    case let .flexLayout(flex, properties): renderFlexLayout(flex, properties: properties, into: parentView)
//
//    case let .view(properties): renderView(properties, into: parentView)
//    case let .textView(text, properties): renderTextView(text, properties: properties, into: parentView)
//    case let .fragView(properties): renderFragView(properties, into: parentView)
//    case let .imageView(image, properties): renderImageView(image, properties: properties, into: parentView)
//    case let .videoEmbedView(src, properties): renderVideoEmbedView(src, properties: properties, into: parentView)
//    case let .videoView(video, properties): renderVideoView(video, properties: properties, into: parentView)
//    }
//}
//
//func renderAbsoluteLayout(_ properties: ViewProperties, into parentView: UIView) {
//
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//}
//
//func renderFlexLayout(_ flex: FlexLayoutProperties, properties: ViewProperties, into parentView: UIView) {
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//
//}
//
//func renderView(_ properties: ViewProperties, into parentView: UIView) {
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//}
//
//func renderFragView(_ properties: ViewProperties, into parentView: UIView) {
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//
//}
//
//func renderTextView(_ text: TextViewProperties, properties: ViewProperties, into parentView: UIView) {
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//}
//
//func renderImageView(_ image: ImageViewProperties, properties: ViewProperties, into parentView: UIView) {
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//}
//
//func renderVideoView(_ video: VideoViewProperties, properties: ViewProperties, into parentView: UIView) {
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//
//}
//
//func renderVideoEmbedView(_ src: String, properties: ViewProperties, into parentView: UIView) {
//    let view = UIView()
//    parentView.addSubview(view)
//
//    // build 'tap' payload
//
//    properties.apply(to: view)
//    parentView.bottomAnchor.constraint(greaterThanOrEqualTo: view.bottomAnchor).isActive = true
//
//}

