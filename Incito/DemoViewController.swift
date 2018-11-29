//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

class DemoViewController: UIViewController {
    var selectedIndex: Int = 0
    let availableIncitos = [
        "incito-fakta-375.json",
        "incito-superbrugsen-375.json",
        
        //"incito-fakta-1200.json",
        //"incito-superbrugsen-1200.json",
    ]
    
    var incitoController: IncitoViewController?
    
    @objc
    func loadNextIncito() {
        selectedIndex += 1
        if selectedIndex >= availableIncitos.count {
            selectedIndex = 0
        }
        
        loadIncito(named: availableIncitos[selectedIndex])
    }
    
    func loadIncito(named filename: String) {
        
        print("\n-----------------")
        print("🌈 Loading '\(filename)'…")
        
        self.title = filename
        
        DispatchQueue.global().async {
            
            let incito: Incito = decodeIncito(filename)
            
            DispatchQueue.main.async {
                let oldIncitoVC = self.incitoController
                let newIncitoVC = IncitoViewController(incito: incito)
                self.incitoController = newIncitoVC
                
                self.cycleFromViewController(
                    oldViewController: oldIncitoVC,
                    toViewController: newIncitoVC
                )
            }
        }
        //        let startFontLoad = Date.timeIntervalSinceReferenceDate
        //
        //        FontAssetLoader.fontAssetLoader()
        //            .loadAndRegisterFontAssets(incito.fontAssets) { (loadedAssets) in
        //                let endFontLoad = Date.timeIntervalSinceReferenceDate
        //                print("\(loadedAssets.count) Fonts Loaded \(round((endFontLoad - startFontLoad) * 1_000))ms")
        //
        //                loadedAssets.forEach { asset in
        //                    print(" -> '\(asset.assetName)': \(asset.fontName)")
        //                }
        //
        //
        ////                controller.build()
        //
        ////                self.incitoController = controller
        //
        //
        //
        //                let renderer = IncitoRenderer(
        //                    fontProvider: loadedAssets.font(forFamily:size:),
        //                    imageLoader: loadImage(url:completion:),
        //                    theme: incito.theme
        //                )
        //
        //                let parentSize = Size(cgSize: self.view.frame.size)
        //
        //                let controller = IncitoController(
        //                    incito: incito,
        //                    renderer: renderer,
        //                    parentSize: parentSize
        //                )
        //
        ////                controller.view
        //
        //                controller.rootLayoutNode.rect
        //
        //                // build the layout
        ////                let rootNode = LayoutNode.build(
        ////                    for: incito.rootView,
        ////                    intrinsicSize: <#T##(View, Size) -> Size#>, parentLayout: <#T##LayoutType#>, in: <#T##Size#>)
        ////
        ////                    layout(
        ////                    view: incito.rootView,
        ////                    parentLayout: .static,
        ////                    with: renderer,
        ////                    in: parentSize)
        ////
        ////                rootNode.render()
        //
        //
        //                let startRender = Date.timeIntervalSinceReferenceDate
        //                render(
        //                    incito,
        //                    with: renderer,
        //                    into: self.view
        //                )
        //                let endRender = Date.timeIntervalSinceReferenceDate
        //                print("Building Views \(round((endRender - startRender) * 1_000))ms")
        //
        //                print(" -> Subviews: ", self.view.subviews.first(where: { $0 is UIScrollView })?.subviews.first?.recursiveSubviewCount() ?? 0)
        //
        //                self.title = filename
        ////                self.addBlurredStatusBar()
        //        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.tintColor = .orange
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonItem.SystemItem.fastForward, target: self, action: #selector(loadNextIncito))
        
        self.loadIncito(named: availableIncitos[selectedIndex])
    }
    
    //    func addBlurredStatusBar() {
    //
    //        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    //
    //        view.addSubview(blur)
    //
    //        blur.translatesAutoresizingMaskIntoConstraints = false
    //        NSLayoutConstraint.activate([
    //            blur.topAnchor.constraint(equalTo: view.topAnchor),
    //            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    //            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    //            blur.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor)
    //            ])
    //    }
}


extension UIViewController {
    public func cycleFromViewController(oldViewController: UIViewController?, toViewController newViewController: UIViewController, in container: UIView? = nil) {
        
        newViewController.view.translatesAutoresizingMaskIntoConstraints = false
        self.addChild(newViewController)
        self.addSubview(
            subView: newViewController.view,
            toView: container ?? self.view
        )
        
        newViewController.view.layoutIfNeeded()
        
        guard let oldVC = oldViewController else {
            newViewController.didMove(toParent: self)
            newViewController.view.alpha = 1
            return
        }
        
        oldVC.willMove(toParent: nil)
        newViewController.view.alpha = 0
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .transitionCrossDissolve, animations: {
            newViewController.view.alpha = 1
            oldVC.view.alpha = 0
        }) { (finished) in
            oldVC.view.removeFromSuperview()
            oldVC.removeFromParent()
            newViewController.didMove(toParent: self)
        }
    }
    
    private func addSubview(subView: UIView, toView parentView: UIView) {
        self.view.layoutIfNeeded()
        parentView.addSubview(subView)
        
        NSLayoutConstraint.activate([
            subView.topAnchor.constraint(equalTo: parentView.topAnchor),
            subView.bottomAnchor.constraint(equalTo: parentView.bottomAnchor),
            subView.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            subView.trailingAnchor.constraint(equalTo: parentView.trailingAnchor)
            ])
    }
}
