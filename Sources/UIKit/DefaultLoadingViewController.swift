//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

class DefaultLoadingViewController: UIViewController {
    fileprivate lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .whiteLarge)
        view.color = UIColor(white: 0, alpha: 0.7)
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // We use a 0.5 second delay to not show an activity indicator
        // in case our data loads very quickly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.activityIndicator.startAnimating()
        }
    }
}

extension DefaultLoadingViewController {
    static func build(backgroundColor: UIColor) -> DefaultLoadingViewController {
        let loadingVC = DefaultLoadingViewController()
        loadingVC.view.backgroundColor = backgroundColor
        
        var isBGDark: Bool {
            var whiteComponent: CGFloat = 1.0
            backgroundColor.getWhite(&whiteComponent, alpha: nil)

            return whiteComponent <= 0.6
        }
        
        loadingVC.activityIndicator.color = isBGDark ? UIColor.white : UIColor(white: 0, alpha: 0.7)

        return loadingVC
    }
}
