//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import RRFPSBar

class DemoViewController: UIViewController {
    var selectedIndex: Int = 999
    let availableIncitos: [(json: String, refImg: String?)] = [
        ("incito-fakta-375.json", "fakta-incito-375-reference"),
        ("incito-superbrugsen-375.json", nil),
        
        //"incito-fakta-1200.json",
        //"incito-superbrugsen-1200.json",
    ]
    
    var incitoController: IncitoViewController?
    var refImageView = UIImageView()
    
    @objc
    func loadNextIncito() {
        selectedIndex += 1
        if selectedIndex >= availableIncitos.count {
            selectedIndex = 0
        }
        
        let incitoInfo = availableIncitos[selectedIndex]
        
        var image: UIImage? = nil
        if let imgName = incitoInfo.refImg {
            image = UIImage(named: imgName)
        }
        
        loadIncito(named: availableIncitos[selectedIndex].json, refImage: image)
    }
    
    func loadIncito(named filename: String, refImage: UIImage?) {
        
        print("\n-----------------")
        print("🌈 Loading '\(filename)'…")
        
        self.title = filename
        
        DispatchQueue.global().async {
            
            let incito: Incito = decodeIncito(filename)
            
            DispatchQueue.main.async {
                let oldIncitoVC = self.incitoController
                let newIncitoVC = IncitoViewController(incito: incito)
                
                self.refImageView.removeFromSuperview()
                newIncitoVC.scrollView.addSubview(self.refImageView)
                
                self.refImageView.image = refImage
                self.refImageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    self.refImageView.centerXAnchor.constraint(equalTo: newIncitoVC.scrollView.centerXAnchor),
                    self.refImageView.topAnchor.constraint(equalTo: newIncitoVC.scrollView.topAnchor)
                    ])
                self.refImageView.alpha = 0
                self.navigationItem.leftBarButtonItem?.tintColor = UIColor.orange.withAlphaComponent(0.75)
                self.navigationItem.leftBarButtonItem?.isEnabled = (refImage != nil)
                
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
        
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "fps", style: .plain, target: self, action: #selector(toggleFPS)),
            UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(toggleReferenceImage)),
            ]
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .fastForward, target: self, action: #selector(loadNextIncito))

        loadNextIncito()
    }
    
    @objc
    func toggleReferenceImage() {
        switch refImageView.alpha {
        case 0:
            refImageView.alpha = 0.5
            self.navigationItem.leftBarButtonItem?.tintColor = UIColor.orange.withAlphaComponent(1)
        case 0.5:
            refImageView.alpha = 1
            self.navigationItem.leftBarButtonItem?.tintColor = UIColor.orange.withAlphaComponent(0.3)
        default:
            refImageView.alpha = 0
            self.navigationItem.leftBarButtonItem?.tintColor = UIColor.orange.withAlphaComponent(0.75)
        }
    }
    
    @objc
    func toggleFPS() {
        RRFPSBar.sharedInstance()?.isHidden.toggle()
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
