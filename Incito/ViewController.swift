//
//  ViewController.swift
//  Incito
//
//  Created by Laurie Hufford on 14/11/2018.
//  Copyright © 2018 ShopGun. All rights reserved.
//

import UIKit

class IncitoViewController: UIViewController {
    
    var incito: Incito = decodeIncito("incito-fakta-375.json")
//    var incito: Incito = decodeIncito("incito-fakta-1200.json")
//    var incito: Incito = decodeIncito("incito-superbrugsen-375.json")
//    var incito: Incito = decodeIncito("incito-superbrugsen-1200.json")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.isNavigationBarHidden = true
        
        view.backgroundColor = .white
        
        let incito = self.incito
        
        let startFontLoad = Date.timeIntervalSinceReferenceDate

        FontAssetLoader.fontAssetLoader()
            .loadAndRegisterFontAssets(incito.fontAssets) { (loadedAssets) in
                let endFontLoad = Date.timeIntervalSinceReferenceDate
                print("\(loadedAssets.count) Fonts Loaded \(round((endFontLoad - startFontLoad) * 1_000))ms")

                loadedAssets.forEach { asset in
                    print(" -> '\(asset.assetName)': \(asset.fontName)")
                }
                
                let renderer = IncitoRenderer(
                    fontProvider: loadedAssets.font(forFamily:size:),
                    theme: incito.theme
                )
                
                let startRender = Date.timeIntervalSinceReferenceDate
                render(
                    incito,
                    with: renderer,
                    into: self.view
                )
                let endRender = Date.timeIntervalSinceReferenceDate
                print("Building Views \(round((endRender - startRender) * 1_000))ms")
                
                print(" -> Subviews: ", self.view.subviews.first(where: { $0 is UIScrollView })?.subviews.first?.recursiveSubviewCount() ?? 0)
                
                self.addBlurredStatusBar()
        }
        
        

//        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "IncitoCell")
    }

    func addBlurredStatusBar() {
        
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
        
        view.addSubview(blur)
        
        blur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor)
            ])
    }
    
//    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return 10
//    }
//    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "IncitoCell", for: indexPath)
//        cell.backgroundColor = .orange
//        return cell
//    }
}


//extension Incito {
//    var numberOfSections: Int {
//        return self.rootView.viewProperties.childViews.count
//    }
//}
