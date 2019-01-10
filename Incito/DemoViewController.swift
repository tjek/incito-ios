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
//        ("incito-flextest-375.json", nil),
//        ("incito-fakta-small-375.json", "fakta-incito-375-reference"),
        ("incito-fakta-375.json", "fakta-incito-375-reference"),
        ("incito-superbrugsen-375.json", nil),
        
        //"incito-fakta-1200.json",
        //"incito-superbrugsen-1200.json",
    ]
    
    var incitoController: IncitoViewController?
    var refImageView = UIImageView()
    var refImageButton: UIBarButtonItem!
    
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
            
            let incito: IncitoDocument = decodeIncito(filename)
            
            DispatchQueue.main.async {
                let oldIncitoVC = self.incitoController
                let newIncitoVC = IncitoViewController(incito: incito)
                newIncitoVC.delegate = self
                
                self.refImageView.removeFromSuperview()
                newIncitoVC.scrollView.addSubview(self.refImageView)
                
                self.refImageView.image = refImage
                self.refImageView.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    self.refImageView.centerXAnchor.constraint(equalTo: newIncitoVC.scrollView.centerXAnchor),
                    self.refImageView.topAnchor.constraint(equalTo: newIncitoVC.scrollView.topAnchor)
                    ])
                self.refImageView.alpha = 0
                self.refImageButton.tintColor = UIColor.orange.withAlphaComponent(0.75)
                self.refImageButton.isEnabled = (refImage != nil)
                
                self.incitoController = newIncitoVC
                
                self.cycleFromViewController(
                    oldViewController: oldIncitoVC,
                    toViewController: newIncitoVC
                )
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.navigationBar.tintColor = .orange
        view.backgroundColor = .white
        
        self.registerForPreviewing(with: self, sourceView: view)
        
        refImageButton = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(toggleReferenceImage))
        
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "fps", style: .plain, target: self, action: #selector(toggleFPS)),
            refImageButton,
            ]
        navigationItem.rightBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: .fastForward, target: self, action: #selector(loadNextIncito))

        loadNextIncito()
    }
    
    @objc
    func toggleReferenceImage() {
        switch refImageView.alpha {
        case 0:
            refImageView.alpha = 0.5
            refImageButton.tintColor = UIColor.orange.withAlphaComponent(1)
        case 0.5:
            refImageView.alpha = 1
            refImageButton.tintColor = UIColor.orange.withAlphaComponent(0.3)
        default:
            refImageView.alpha = 0
            refImageButton.tintColor = UIColor.orange.withAlphaComponent(0.75)
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

extension ViewProperties {
    var isOffer: Bool {
        return self.style.role == "offer"
    }
}

extension DemoViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let incito = incitoController else { return nil }
        
        let incitoVCLocation = previewingContext.sourceView.convert(location, to: incito.view)
        
        let firstView = incito.firstView(at: incitoVCLocation) { $1.isOffer }
        
        guard let view = firstView?.0 else { return nil }
        
        previewingContext.sourceRect = view.convert(view.bounds, to: previewingContext.sourceView)
        
        // TODO: use the previewingContext.sourceView to include bgColor.
        
        let vc = OfferPreviewViewController()
        let screenImage = view.asImage()
        let imageView = UIImageView(image: screenImage)
        vc.addSnapshot(imageView)
        
        return vc
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
//        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

extension DemoViewController: IncitoViewControllerDelegate {
    func viewDidRender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController) {
        // view just rendered (may still be off the bottom of the screen)
    }
    
    func viewDidUnrender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController) {
        // view just disappeared
    }
}

extension UIView {
    
    // Using a function since `var image` might conflict with an existing variable
    // (like on `UIImageView`)
    func asImage() -> UIImage {
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { rendererContext in
                layer.render(in: rendererContext.cgContext)
            }
        } else {
            UIGraphicsBeginImageContext(self.frame.size)
            self.layer.render(in:UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return UIImage(cgImage: image!.cgImage!)
        }
    }
}

class OfferPreviewViewController: UIViewController {
    func addSnapshot(_ snapshot: UIView) {
        view.backgroundColor = .white
        view.addSubview(snapshot)
        
        self.preferredContentSize = snapshot.frame.size
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        let listsAction = UIPreviewAction(title: "Add to List", style: .default) { previewAction, viewController in
            print("Added to list!")
        }
        return [
            listsAction
        ]
    }
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
