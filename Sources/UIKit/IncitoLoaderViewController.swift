//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

public protocol IncitoLoaderViewControllerDelegate: IncitoViewControllerDelegate {
    func errorViewController(for error: Error, in viewController: IncitoLoaderViewController) -> UIViewController
    func loadingViewController(in viewController: IncitoLoaderViewController) -> UIViewController
    
    func transitionIncitoLoaderChildViewController(
        from fromViewController: UIViewController?,
        to toViewController: UIViewController,
        in containerView: UIView,
        for viewController: IncitoLoaderViewController
    )
}

public extension IncitoLoaderViewControllerDelegate {
    func errorViewController(for error: Error, in viewController: IncitoLoaderViewController) -> UIViewController {
        return buildDefaultErrorViewController(for: error, backgroundColor: viewController.view.backgroundColor ?? .white) { [weak viewController] in
            guard let loader = viewController?.lastLoader else { return }
            viewController?.reload(loader, completion: viewController?.lastReloadCompletion)
        }
    }
    
    func loadingViewController(in viewController: IncitoLoaderViewController) -> UIViewController {
         return DefaultLoadingViewController.build(backgroundColor: viewController.view.backgroundColor ?? .white)
    }
    
    func transitionIncitoLoaderChildViewController(
        from fromViewController: UIViewController?,
        to toViewController: UIViewController,
        in containerView: UIView,
        for viewController: IncitoLoaderViewController
        ) {
        
        viewController.cycleFromViewController(
            oldViewController: fromViewController,
            toViewController: toViewController,
            in: containerView
        )
    }
}

/**
 A utility view controller that allows for an incito to be loaded asyncronously, using an IncitoLoader. It shows loading/error views depending on the loading process.
 */
open class IncitoLoaderViewController: UIViewController {
    
    fileprivate enum State {
        case loading
        case success(IncitoViewController)
        case error(Error)
    }
    
    fileprivate var reloadId: Int = 0
    fileprivate var lastLoader: IncitoLoader?
    fileprivate var lastReloadCompletion: ((Result<IncitoViewController>) -> Void)?
    fileprivate var loaderQueue = DispatchQueue(label: "IncitoLoaderQueue", qos: .userInitiated)
    
    fileprivate var currentStateViewController: UIViewController?
    fileprivate var stateContainerView = UIView()
    fileprivate var state: State = .loading {
        didSet {
            updateViewState()
        }
    }

    
    
    public weak var delegate: IncitoLoaderViewControllerDelegate?
    
    public var incitoViewController: IncitoViewController? {
        guard case let .success(incitoVC) = self.state else {
            return nil
        }
        return incitoVC
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        stateContainerView.frame = self.view.bounds
        stateContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stateContainerView)
        
        updateViewState()
    }
    
    /**
     Given an IncitoLoader, we will start reloading the IncitoViewController.
     */
    public func reload(_ loader: IncitoLoader, completion: ((Result<IncitoViewController>) -> Void)? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.state = .loading
            self.lastLoader = loader
            self.lastReloadCompletion = completion
            
            self.reloadId += 1
            let currReloadId = self.reloadId
            
            loader
                .async(on: self.loaderQueue, completesOn: .main)
                .run({ [weak self] renderableDocResult in
                    guard let self = self else { return }
                    guard self.reloadId == currReloadId else { return }
                    
                    switch renderableDocResult {
                    case let .error(err):
                        self.state = .error(err)                        
                        completion?(.error(err))
                    case let .success(renderableDocument):
                        
                        let incitoVC = IncitoViewController()
                        incitoVC.delegate = self.delegate
                        incitoVC.update(renderableDocument: renderableDocument)
                        
                        self.state = .success(incitoVC)
                        
                        completion?(.success(incitoVC))
                    }
                })
        }
    }
    
    private func updateViewState() {
        
        class DefaultDelegate: IncitoLoaderViewControllerDelegate {}
        let delegate: IncitoLoaderViewControllerDelegate = self.delegate ?? DefaultDelegate()
        
        let oldVC = currentStateViewController
        
        let newVC: UIViewController
        switch state {
        case .loading:
            newVC = delegate.loadingViewController(in: self)
        case .error(let error):
            newVC = delegate.errorViewController(for: error, in: self)
        case .success(let incitoVC):
            newVC = incitoVC
        }
        
        self.currentStateViewController = newVC
        delegate.transitionIncitoLoaderChildViewController(
            from: oldVC,
            to: newVC,
            in: stateContainerView,
            for: self
        )
    }
}

extension UIViewController {
    func cycleFromViewController(oldViewController: UIViewController?, toViewController newViewController: UIViewController, in container: UIView? = nil) {
        
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
