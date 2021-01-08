///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import UIKit

private extension Error {
    var errorViewContents: DefaultErrorViewController.Contents {
        return DefaultErrorViewController.Contents(
            image: nil,
            title: Assets.ErrorView.defaultTitle.withoutWidows,
            message: Assets.ErrorView.defaultMessage.withoutWidows,
            errorDetails: "\(self.localizedDescription)\n\(self)",
            isRetryable: true
        )
    }
}

class DefaultErrorViewController: UIViewController {
    
    struct Contents {
        var image: UIImage?
        var title: String?
        var message: String?
        var errorDetails: String?
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
        
        button.setTitle(Assets.ErrorView.retryButton, for: .normal)

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        
        view.addSubview(stackView)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: self.view.layoutMarginsGuide.centerYAnchor),
            stackView.centerXAnchor.constraint(equalTo: self.view.layoutMarginsGuide.centerXAnchor),
            
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: self.view.readableContentGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: self.view.readableContentGuide.trailingAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
            
            stackView.topAnchor.constraint(greaterThanOrEqualTo: self.view.layoutMarginsGuide.topAnchor)
            ])
    }
    
    func update(_ errorContents: Contents) {
        
        iconImageView.image = errorContents.image
        titleLabel.text = errorContents.title
        
        errorDescriptionLabel.text = errorContents.errorDetails
        messageLabel.text = errorContents.message
        retryButton.isHidden = !errorContents.isRetryable
        
        self.view.setNeedsLayout()
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
extension DefaultErrorViewController: ColorableChildVC {
    func parentBackgroundColorDidChange(to parentBackgroundColor: UIColor?) {
        let bgColor = parentBackgroundColor ?? .white
        var isBGDark: Bool {
            var whiteComponent: CGFloat = 1.0
            bgColor.getWhite(&whiteComponent, alpha: nil)
            
            return whiteComponent <= 0.6
        }

        self.view.backgroundColor = bgColor
        
        let tint: UIColor = isBGDark ? UIColor.white : UIColor(white: 0, alpha: 0.6)
        
        iconImageView.tintColor = tint
        titleLabel.textColor = tint
        messageLabel.textColor = tint
        errorDescriptionLabel.textColor = tint.withAlphaComponent(0.8)
        
        retryButton.setTitleColor(tint, for: .normal)
        retryButton.backgroundColor = tint.withAlphaComponent(0.05)
        retryButton.layer.borderColor = tint.cgColor
    }
}

extension DefaultErrorViewController {
    static func build(
        for error: Error,
        backgroundColor: UIColor,
        retryCallback: @escaping () -> Void
        ) -> DefaultErrorViewController {
        
        let errorVC = DefaultErrorViewController()
        errorVC.didTapRetryCallback = retryCallback
        errorVC.update(error.errorViewContents)
        
        errorVC.parentBackgroundColorDidChange(to: backgroundColor)
        
        return errorVC
    }
}
