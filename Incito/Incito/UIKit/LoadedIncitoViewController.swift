//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit


struct IncitoLoader<A> {
    let load: (A, @escaping (Result<RenderableIncitoDocument>) -> Void) -> Void
}

/**
 A utility view controller that allows for an incito to be loaded asyncronously, using an IncitoLoader. It shows loading/error views depending on the loading process.
 */
class LoadedIncitoViewController<A>: UIViewController {
    
    enum State {
        case loading
        case success(IncitoViewController)
        case error(Error)
    }
    
    private let loader: IncitoLoader<A>
    private(set) var state: State = .loading
    
    init(loader: IncitoLoader<A>) {
        self.loader = loader
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reload(_ input: A) {
        self.state = .loading
        loader.load(input) {
            switch $0 {
            case let .error(err):
                self.state = .error(err)
            case let .success(renderableDocument):
                
                let incitoVC = IncitoViewController(document: renderableDocument)
                self.state = .success(incitoVC)
            }
        }
    }
}
