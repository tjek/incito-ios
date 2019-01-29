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
    func errorViewController(for error: Error, in viewController: IncitoLoaderViewController) -> UIViewController?
    func loadingViewController(in viewController: IncitoLoaderViewController) -> UIViewController?
}

extension IncitoLoaderViewControllerDelegate {
    public func errorViewController(for error: Error, in viewController: IncitoLoaderViewController) -> UIViewController? {
        return nil
    }
    public func loadingViewController(in viewController: IncitoLoaderViewController) -> UIViewController? {
        return nil
    }
}

/**
 A utility view controller that allows for an incito to be loaded asyncronously, using an IncitoLoader. It shows loading/error views depending on the loading process.
 */
open class IncitoLoaderViewController: UIViewController {
    
    enum State {
        case loading
        case success(IncitoViewController)
        case error(Error)
    }
    
    public weak var delegate: IncitoLoaderViewControllerDelegate?
    
    public var incitoViewController: IncitoViewController? {
        guard case let .success(incitoVC) = self.state else {
            return nil
        }
        return incitoVC
    }
    
    private(set) var state: State = .loading {
        didSet {
            updateViewState()
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        stateContainerView.frame = self.view.bounds
        stateContainerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stateContainerView)
        
        updateViewState()
    }
    
    private var reloadId: Int = 0
    private var lastLoader: IncitoLoader?
    
    /// Given an IncitoLoader, we will start reloading the IncitoViewController.
    public func reload(_ loader: IncitoLoader, completion: @escaping (Result<IncitoViewController>) -> Void = { _ in }) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.state = .loading
            self.lastLoader = loader
            
            self.reloadId += 1
            let currReloadId = self.reloadId
            
            loader.load { renderableDocResult in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    guard self.reloadId == currReloadId else { return }
                    
                    switch renderableDocResult {
                    case let .error(err):
                        self.state = .error(err)                        
                        completion(.error(err))
                    case let .success(renderableDocument):
                        
                        let incitoVC = IncitoViewController()
                        incitoVC.delegate = self.delegate
                        incitoVC.update(renderableDocument: renderableDocument)
                        
                        self.state = .success(incitoVC)
                        
                        completion(.success(incitoVC))
                    }
                }
            }
        }
    }
    
    private var currentStateViewController: UIViewController?
    private var stateContainerView = UIView()
    
    private func updateViewState() {
        
        let oldVC = currentStateViewController
        
        let newVC: UIViewController
        switch state {
        case .loading:
            newVC = delegate?.loadingViewController(in: self) ?? DefaultLoadingViewController.build(backgroundColor: view.backgroundColor ?? .white)
        case .error(let error):
            if let delegateVC = delegate?.errorViewController(for: error, in: self) {
                newVC = delegateVC
            } else {
                newVC = buildDefaultErrorViewController(for: error, backgroundColor: view.backgroundColor ?? .white) { [weak self] in
                    guard let loader = self?.lastLoader else { return }
                    self?.reload(loader)
                }
            }
        case .success(let incitoVC):
            newVC = incitoVC
        }
        
        self.currentStateViewController = newVC
        self.cycleFromViewController(
            oldViewController: oldVC,
            toViewController: newVC,
            in: stateContainerView
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
