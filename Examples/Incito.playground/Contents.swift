///
///  Copyright (c) 2021 Tjek. All rights reserved.
///

import UIKit
import PlaygroundSupport
import Incito

class MyIncitoViewController: IncitoLoaderViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Use the IncitoLoaderViewControllerDelegate to respond to events and customize the error screen, for example.
        self.delegate = self
        
        // The `IncitoLoader` is used to asyncronously fetch the incito document. It's up to you how you fetch that data.
        let loader: IncitoLoader

        // This is simply a utility function that generates a loader using a local file.
        loader = IncitoJSONFileLoader(filename: "elgiganten-nov19-375.json")

        // … otherwise you could use the callback version to asyncrously fetch the document's json data
        //loader = IncitoLoader { loadedDocCallback in
        //    ... async work to fetch the data
        //    let result = .success(IncitoDocument(jsonData: data))
        //    loadedCallback(result)
        //}

        // Passing the loader to the load function starts the fetching & parsing of the IncitoDocument, and showing a spinner while loading, an error screen if it fails, and the rendered incito on success.
        self.load(loader)
    }
}

extension MyIncitoViewController: IncitoLoaderViewControllerDelegate {
    func stateDidChange(from oldState: IncitoLoaderViewController.State, to newState: IncitoLoaderViewController.State, in viewController: IncitoLoaderViewController) {
        // The state changes when the incito changes between loading, success, or error.

        switch newState {
        case .success(let incitoVC):
            // When an incito is successfully loaded, you get access to the underlying `IncitoViewController` that renders the incito here (or via the failable `incitoViewController` property on the `IncitoLoaderViewController`).

            // If you set yourself as delegate now, you can listen for interaction events etc.
            incitoVC.delegate = self
        case .loading:
            // The incito started loading
            break
        case .error(let error):
            // something bad happened while trying to load the incito
            print(error)
        }
    }
}

extension MyIncitoViewController: IncitoViewControllerDelegate {
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController) {
        // This event is triggered when the user taps on the incito content itself.
        // You can find out what is at the interaction location using a number of utility functions on the content viewcontroller itself.

        // for example, here we are getting the first element in the view hierarchy at the tap location that meets the `where` criteria. This is an async request, so has a completion handler.
        viewController.getFirstElement(
            at: point,
            where: { $0.role == "offer" },
            completion: { foundElement in
                // if an element matching the criteria it is returned here.
                print("Tapped on an offer @ \(point)")
            }
        )
    }
}

let incitoVC = MyIncitoViewController()
incitoVC.view.frame = CGRect(x: 0, y: 0, width: 375, height: 800)

PlaygroundPage.current.liveView = incitoVC
