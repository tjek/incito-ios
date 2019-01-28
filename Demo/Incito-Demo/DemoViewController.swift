//
//  ViewController.swift
//  Incito-Demo
//
//  Created by Laurie Hufford on 28/01/2019.
//  Copyright © 2019 ShopGun. All rights reserved.
//

import UIKit
import Incito

class DemoViewController: LoadedIncitoViewController {
    var selectedIndex: Int = 999
    let availableIncitos: [(json: String, refImg: String?)] = [
        ("incito-superbrugsen-mar18-375.json", nil),
        ("incito-videotest-375.json", nil),
        ("incito-elgiganten-375.json", nil),
        ("incito-elgiganten-legacy-375.json", nil),
        ("incito-superbrugsen-375.json", nil),
        ("incito-fakta-375.json", "fakta-incito-375-reference"),
        ("incito-elgiganten-small-375.json", nil),
        ("incito-fakta-small-375.json", "fakta-incito-375-reference"),
        ("incito-superbrugsen-small-375.json", nil),
        
        ("incito-blocktest-375.json", nil),
        ("incito-flextest-375.json", nil),
        ("incito-transformtest-375.json", nil),
        ("incito-imagetest-375.json", nil),
        
        //        ("incito-superbrugsen-mar18-768.json", nil),
        //        ("incito-elgiganten-768.json", nil),
        //"incito-fakta-1200.json",
        //"incito-superbrugsen-1200.json",
    ]
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = .orange
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem.init(barButtonSystemItem: .fastForward, target: self, action: #selector(loadNextIncito))
        ]
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem.init(title: "Debug", style: .plain, target: self, action: #selector(openDebugMenu))
        ]
        
        loadNextIncito()
        
//        self.registerForPreviewing(with: self, sourceView: view)
        
//        let searchController = UISearchController(searchResultsController: self.searchResultsController)
//        searchController.searchResultsUpdater = searchResultsController
//        definesPresentationContext = true
//        if #available(iOS 11.0, *) {
//            navigationItem.hidesSearchBarWhenScrolling = false
//            navigationItem.searchController = searchController
//        } else {
//            navigationItem.titleView = searchController.searchBar
//        }
//
//        searchResultsController.didSelectOffer = { [weak self] offer in
//            if #available(iOS 11.0, *) {
//                self?.navigationItem.searchController?.isActive = false
//            }
//            self?.incitoController?.scrollToElement(withId: offer.id, animated: false)
//        }
    }
    
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
        
        var size = self.view.frame.size
        size.width = min(size.width, size.height)
        
        let loader = IncitoJSONFileLoader(
            filename: filename,
            size: size,
            queue: DispatchQueue(label: "DemoLoaderQueue", qos: .userInitiated)
        )
        
        self.reload(loader)
        
//        { [weak self] in
//            guard let self = self,
//                let incitoVC = self.incitoViewController else { return }
            
//            self.refImageView.removeFromSuperview()
//
//            incitoVC.scrollView.addSubview(self.refImageView)
//
//            self.refImageView.image = refImage
//            self.refImageView.translatesAutoresizingMaskIntoConstraints = false
//            NSLayoutConstraint.activate([
//                self.refImageView.centerXAnchor.constraint(equalTo: newIncitoVC.scrollView.centerXAnchor),
//                self.refImageView.topAnchor.constraint(equalTo: newIncitoVC.scrollView.topAnchor)
//                ])
//            self.refImageView.alpha = 0
//            self.refImageButton.tintColor = UIColor.orange.withAlphaComponent(0.75)
//            self.refImageButton.isEnabled = (refImage != nil)
//        }
    }
    
    @objc
    func openDebugMenu() {
        
        guard let incitoVC = self.incitoViewController else { return }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(
            UIAlertAction(title: "\(incitoVC.debug.showOutlines ? "Disable" : "Enable") Outlines",
                          style: incitoVC.debug.showOutlines ? .destructive : .default,
                          handler: { _ in incitoVC.debug.showOutlines.toggle() })
        )
        
        alert.addAction(
            UIAlertAction(title: "\(incitoVC.debug.showRenderWindows ? "Disable" : "Enable") Render Window",
                style: incitoVC.debug.showRenderWindows ? .destructive : .default,
                handler: { _ in incitoVC.debug.showRenderWindows.toggle() })
        )
        
        alert.addAction(
            UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        )
        
        present(alert, animated: true)
    }
}
