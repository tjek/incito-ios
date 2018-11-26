//
//  ViewController.swift
//  Incito
//
//  Created by Laurie Hufford on 14/11/2018.
//  Copyright © 2018 ShopGun. All rights reserved.
//

import UIKit

class IncitoViewController: UIViewController {
    
    var incito: Incito = decodeIncito("incito-fakta.json")
//    var incito: Incito = decodeIncito("incito-superbrugsen.json")
//    var incito: Incito = decodeIncito("simple-incito-absolute.json")
    
    override func viewDidLoad() {
        super.viewDidLoad()
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
                
                let startRender = Date.timeIntervalSinceReferenceDate
                render(
                    incito,
                    fontLoader: {
                        loadedAssets.font(
                            forFamily: $0 + (incito.theme?.fontFamily ?? []),
                            size: $1)
                },
                    into: self.view
                )
                let endRender = Date.timeIntervalSinceReferenceDate
                print("Building Views \(round((endRender - startRender) * 1_000))ms")
                
                print(" -> Subviews: ", self.view.subviews.first(where: { $0 is UIScrollView })?.subviews.first?.recursiveSubviewCount() ?? 0)
        }
        
        

//        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "IncitoCell")
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
