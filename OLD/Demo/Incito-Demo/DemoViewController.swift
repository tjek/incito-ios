///
///  Copyright (c) 2018 Tjek. All rights reserved.
///

import UIKit
import Incito

class DemoViewController: IncitoLoaderViewController {
    
    var selectedIndex: Int = 999
    let availableIncitos: [String] = [
        "elgiganten-nov19-375.json",
        "ica-aug19-375.json",
        "incito-irma-375.json",
        "incito-kvickly-feb2019-375.json",
        "elgiganten-mar19-375.json",
        "incito-elgiganten-feb19-375.json",
        "incito-superbrugsen-mar18-375.json",
        "incito-videotest-375.json",
        "incito-elgiganten-375.json",
        "incito-elgiganten-legacy-375.json",
        "incito-superbrugsen-375.json",
        "incito-fakta-375.json",
        "incito-elgiganten-small-375.json",
        "incito-fakta-small-375.json",
        "incito-superbrugsen-small-375.json",
        "incito-blocktest-375.json",
        "incito-transformtest-375.json",
        "incito-flextest-375.json",
        "incito-imagetest-375.json",
        "incito-texttest-375.json",
        
        
        //"incito-superbrugsen-mar18-768.json",
        //"incito-elgiganten-768.json",
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
        
        loadNextIncito()
        
        if #available(iOS 11.0, *) {
            let searchController = UISearchController(searchResultsController: self.searchResultsController)
            searchController.searchResultsUpdater = searchResultsController
            definesPresentationContext = true
            navigationItem.hidesSearchBarWhenScrolling = false
            navigationItem.searchController = searchController
            
            searchResultsController.didSelectOffer = { [weak self] offer in
                self?.navigationItem.searchController?.isActive = false
                self?.incitoViewController?.scrollToElement(withId: offer.id, animated: false)
            }
        }
    }
    
    @objc
    func loadNextIncito() {
        selectedIndex += 1
        if selectedIndex >= availableIncitos.count {
            selectedIndex = 0
        }
        
        let incitoFilename = availableIncitos[selectedIndex]
        
        loadIncito(named: incitoFilename)
    }
    
    func loadIncito(named filename: String) {
        
        print("\n-----------------")
        print("🌈 Loading '\(filename)'…")
        
        self.title = filename
        
        self.searchResultsController.offers = []
        
        let loader = IncitoJSONFileLoader(
            filename: filename
        )
        
        let start = Date.timeIntervalSinceReferenceDate
        self.load(loader) { result in
            let end = Date.timeIntervalSinceReferenceDate
            switch result {
            case .success:
                print("   ✅ in \(round((end - start) * 1000) / 1000)s")
            case .failure(let error):
                print("   ❌ in \(round((end - start) * 1000) / 1000)s: \(error)")
            }
            print("-----------------")
            
            guard case .success(let vc) = result else { return }
            
            // add an example custom gesture recognizer to the incito's view
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(DemoViewController.didLongPress))
            vc.addGesture(longPress)
        }
    }
    
    @objc
    func didLongPress(_ longPress: UILongPressGestureRecognizer) {
        guard longPress.state == .began else { return }
        
        guard let incitoVC = self.incitoViewController else { return }
        let point = longPress.location(in: incitoVC.view)
        
        // An example of how to get the offer that was tapped.
        self.incitoViewController?.getFirstElement(at: point, where: { $0.isOffer }) {
            guard let firstOffer = $0 else { return }
            
            print("⏱👉 [Offer long-press] '\(firstOffer.tjekMeta["title"]?.stringValue ?? "")': '\(firstOffer.tjekMeta["description"]?.stringValue ?? "")'")
            
            self.incitoViewController?.scrollToElement(withId: firstOffer.id, position: .top, animated: true)
        }
    }
}

extension IncitoDocument.Element {
    var isOffer: Bool {
        return self.role == "offer"
    }
    
    var tjekMeta: [String: JSONValue] {
        return self.meta["tjek.offer.v1"]?.objectValue ?? [:]
    }
}

import SafariServices

extension DemoViewController: IncitoLoaderViewControllerDelegate {
    
    func incitoDocumentLoaded(document: IncitoDocument, in viewController: IncitoViewController) {
        
        self.searchResultsController.offers = document.elements
            .compactMap({
                guard $0.isOffer else { return nil }
                guard let title = $0.title ?? $0.tjekMeta["title"]?.stringValue else {
                    return nil
                }
                return (
                    title: title,
                    desc: $0.tjekMeta["description"]?.stringValue,
                    id: $0.id
                )
            })
    }
    
    func incitoDidTapLink(_ url: URL, in viewController: IncitoViewController) {
        
        print("👉 [Link] '\(url)'")
        
        // An example of how to present an in-app view of the link.
        let sfVC = SFSafariViewController(url: url)
        viewController.present(sfVC, animated: true, completion: nil)
    }
    
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController) {
        // An example of how to get the offer that was tapped.
        viewController.getFirstElement(at: point, where: { $0.isOffer }) {
            guard let firstOffer = $0 else { return }
            print("👉 [Offer] '\(firstOffer.tjekMeta["title"]?.stringValue ?? "")': '\(firstOffer.tjekMeta["description"]?.stringValue ?? "")'")
            
            viewController.scrollToElement(withId: firstOffer.id, position: .top, animated: true)
        }
    }
}

// MARK: - Search

class SearchResultsViewController: UITableViewController {
    
    typealias OfferProperties = (title: String, desc: String?, id: IncitoDocument.Element.Identifier)
    
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
