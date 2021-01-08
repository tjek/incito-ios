///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

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
            activityIndicator.centerXAnchor.constraint(equalTo: view.layoutMarginsGuide.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.layoutMarginsGuide.centerYAnchor)
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

extension DefaultLoadingViewController: ColorableChildVC {
    func parentBackgroundColorDidChange(to parentBackgroundColor: UIColor?) {
        
        let bgColor = parentBackgroundColor ?? .white
        
        var isBGDark: Bool {
            var whiteComponent: CGFloat = 1.0
            bgColor.getWhite(&whiteComponent, alpha: nil)
            
            return whiteComponent <= 0.6
        }

        self.view.backgroundColor = bgColor

        self.activityIndicator.color = isBGDark ? UIColor.white : UIColor(white: 0, alpha: 0.7)
    }
}
extension DefaultLoadingViewController {
    static func build(backgroundColor: UIColor) -> DefaultLoadingViewController {
        let loadingVC = DefaultLoadingViewController()
        
        loadingVC.parentBackgroundColorDidChange(to: backgroundColor)
        
        return loadingVC
    }
}
