//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit

func buildDefaultErrorViewController(
    for error: Error,
    backgroundColor: UIColor,
    retryCallback: @escaping () -> Void
    ) -> UIViewController {
    
    let errorVC = UIViewController()
    errorVC.view.backgroundColor = backgroundColor
    
    let errorView = ErrorView()
    errorView.didTapRetryCallback = retryCallback
    
    errorVC.view.addSubview(errorView)
    errorView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        errorView.topAnchor.constraint(equalTo: errorVC.view.topAnchor),
        errorView.bottomAnchor.constraint(equalTo: errorVC.view.bottomAnchor),
        errorView.leadingAnchor.constraint(equalTo: errorVC.view.leadingAnchor),
        errorView.trailingAnchor.constraint(equalTo: errorVC.view.trailingAnchor),
        ])
    
    var isBGDark: Bool {
        var whiteComponent: CGFloat = 1.0
        backgroundColor.getWhite(&whiteComponent, alpha: nil)
        
        return whiteComponent <= 0.6
    }
    
    let tint: UIColor = isBGDark ? UIColor.white : UIColor(white: 0, alpha: 0.6)
    
    // TODO: different contents depending on the error
    errorView.update(ErrorView.Contents(
        image: nil,
        title: "😢 Unable to Load".withoutWidows,
        message: "Sorry, there was a problem. Please try again.".withoutWidows,
        errorDetails: "\(error.localizedDescription)\n\(error)",
        tint: tint,
        isRetryable: true
        )
    )
    
    return errorVC
}

class ErrorView: UIView {
    
    struct Contents {
        var image: UIImage?
        var title: String?
        var message: String?
        var errorDetails: String?
        var tint: UIColor?
        var isRetryable: Bool
    }

    var didTapRetryCallback: (() -> Void)?
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .title1)
        label.backgroundColor = .clear
        label.textAlignment = .center
        if #available(iOS 10.0, *) {
            label.adjustsFontForContentSizeCategory = true
        }
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let messageLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .title2)
        label.alpha = 0.7
        label.backgroundColor = .clear
        label.textAlignment = .center
        if #available(iOS 10.0, *) {
            label.adjustsFontForContentSizeCategory = true
        }
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.isUserInteractionEnabled = true
        return label
    }()
    
    let errorDescriptionLabel: CopyableLabel = {
        let label = CopyableLabel()
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.alpha = 0.7
        label.backgroundColor = .clear
        label.textAlignment = .center
        if #available(iOS 10.0, *) {
            label.adjustsFontForContentSizeCategory = true
        }
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()
    
    let retryButton: UIButton = {
        let button = UIButton()
        
        // TODO: localize
        button.setTitle(NSLocalizedString("Retry", comment: ""), for: .normal)

        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.titleLabel?.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setTitleColor(.darkGray, for: .normal)
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 4
        button.titleLabel?.textAlignment = .center
        if #available(iOS 10.0, *) {
            button.titleLabel?.adjustsFontForContentSizeCategory = true
        }
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        return button
    }()
    
    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        retryButton.addTarget(self, action: #selector(didTapRetry(_:)), for: .touchUpInside)
        errorDescriptionLabel.isHidden = true
        
        let stackView: UIStackView = {
            let stack = UIStackView(arrangedSubviews: [
                iconImageView,
                titleLabel,
                messageLabel,
                errorDescriptionLabel,
                retryButton
                ])
            stack.spacing = 16
            stack.distribution = .fill
            stack.alignment = .center
            stack.axis = .vertical
            return stack
        }()
        
        let tapGR = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGR.numberOfTapsRequired = 2
        stackView.addGestureRecognizer(tapGR)
        
        addSubview(stackView)
        
//        retryButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: self.layoutMarginsGuide.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: self.layoutMarginsGuide.centerXAnchor),
            
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: self.readableContentGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: self.readableContentGuide.trailingAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            
            stackView.topAnchor.constraint(greaterThanOrEqualTo: self.layoutMarginsGuide.topAnchor)
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ errorContents: Contents) {
        
        iconImageView.image = errorContents.image
        titleLabel.text = errorContents.title
        
        errorDescriptionLabel.text = errorContents.errorDetails
        
        messageLabel.text = errorContents.message
        iconImageView.tintColor = errorContents.tint
        titleLabel.textColor = errorContents.tint
        messageLabel.textColor = errorContents.tint
        errorDescriptionLabel.textColor = errorContents.tint?.withAlphaComponent(0.8)
        
        retryButton.setTitleColor(errorContents.tint, for: .normal)
        
        retryButton.backgroundColor = errorContents.tint?.withAlphaComponent(0.05)
        retryButton.layer.borderColor = errorContents.tint?.cgColor
        retryButton.isHidden = !errorContents.isRetryable
        
        self.setNeedsLayout()
    }
    
    @objc
    func didTapRetry(_ btn: UIButton) {
        self.didTapRetryCallback?()
    }
    
    @objc
    func handleTap(_ gesture: UITapGestureRecognizer) {
        errorDescriptionLabel.isHidden.toggle()
    }
}
