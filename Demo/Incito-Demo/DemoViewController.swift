//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

import UIKit
import Incito

class DemoViewController: IncitoLoaderViewController {
    
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
    
    let searchResultsController = SearchResultsViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
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
        
        let searchController = UISearchController(searchResultsController: self.searchResultsController)
        searchController.searchResultsUpdater = searchResultsController
        definesPresentationContext = true
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
            navigationItem.searchController = searchController
        } else {
            navigationItem.titleView = searchController.searchBar
        }

        searchResultsController.didSelectOffer = { [weak self] offer in
            if #available(iOS 11.0, *) {
                self?.navigationItem.searchController?.isActive = false
            }
            self?.incitoViewController?.scrollToElement(withId: offer.id, animated: false)
        }
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
        
        self.searchResultsController.offers = []
        
        var size = self.view.frame.size
        size.width = min(size.width, size.height)
        
        let loader = IncitoJSONFileLoader(
            filename: filename,
            size: size,
            queue: DispatchQueue(label: "DemoLoaderQueue", qos: .userInitiated)
        )
        
        self.reload(loader)
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

extension ViewProperties {
    var isOffer: Bool {
        return self.style.role == "offer"
    }
}

extension DemoViewController: IncitoLoaderViewControllerDelegate {
    func viewDidRender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController) {
        
    }
    
    func viewDidUnrender(view: UIView, with viewProperties: ViewProperties, in viewController: IncitoViewController) {
        
    }
    
    func incitoDocumentLoaded(in viewController: IncitoViewController) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            var offers: [SearchResultsViewController.OfferProperties] = []
            
            // walk through all the view elements, indexing all the offers.
            viewController.iterateViewElements { viewProperties in
                guard viewProperties.isOffer else {
                    return
                }
                // or products instead...
                let metaTitle = viewProperties.style.meta["title"]?.stringValue
                let metaDesc = viewProperties.style.meta["description"]?.stringValue
                guard let title =  viewProperties.style.title ?? metaTitle else { return }
                
                //        print("'\(title)': '\(metaDesc ?? "")'")
                
                offers.append((title, metaDesc, viewProperties.id))
            }
            
            DispatchQueue.main.async { [weak self] in
                guard self?.incitoViewController == viewController else {
                    return
                }
                
                self?.searchResultsController.offers = offers
            }
        }
    }
}

class SearchResultsViewController: UITableViewController {
    
    typealias OfferProperties = (title: String, desc: String?, id: ViewProperties.Identifier)
    
    var didSelectOffer: ((OfferProperties) -> Void)?
    
    var offers: [OfferProperties] = [] {
        didSet {
            updateFilteredResults()
        }
    }
    var searchString: String = "" {
        didSet {
            updateFilteredResults()
        }
    }
    var filteredResults: [OfferProperties] = []
    
    func updateFilteredResults() {
        
        DispatchQueue.main.async {
            let normalizedSearch = self.searchString.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            self.filteredResults = self.offers.filter {
                $0.title.lowercased().contains(normalizedSearch) || ($0.desc?.lowercased().contains(normalizedSearch) ?? false)
            }
            self.tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredResults.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "offerCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "offerCell")
        
        let offer = filteredResults[indexPath.item]
        cell.textLabel?.text = offer.title
        cell.detailTextLabel?.text = offer.desc
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let offer = filteredResults[indexPath.item]
        
        didSelectOffer?(offer)
    }
}
extension SearchResultsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        self.searchString = searchController.searchBar.text ?? ""
    }
}
