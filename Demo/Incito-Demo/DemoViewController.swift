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
        ("incito-irma-375.json", nil),
        ("incito-kvickly-feb2019-375.json", nil),
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
        ("incito-transformtest-375.json", nil),
        ("incito-flextest-375.json", nil),
        ("incito-imagetest-375.json", nil),
        
        //        ("incito-superbrugsen-mar18-768.json", nil),
        //        ("incito-elgiganten-768.json", nil),
        //"incito-fakta-1200.json",
        //"incito-superbrugsen-1200.json",
    ]
    
    let searchResultsController = SearchResultsViewController()
    
    var refImageView = UIImageView()
    var refImageButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.delegate = self
        self.navigationController?.navigationBar.tintColor = .orange
        view.backgroundColor = .white
        
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem.init(barButtonSystemItem: .fastForward, target: self, action: #selector(loadNextIncito))
        ]
        
        refImageButton = UIBarButtonItem(barButtonSystemItem: .camera, target: self, action: #selector(toggleReferenceImage))
        
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem.init(title: "∙∙∙", style: .plain, target: self, action: #selector(openDebugMenu)),
            refImageButton
        ]
        
        loadNextIncito()
        
        self.registerForPreviewing(with: self, sourceView: view)
        
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
        self.refImageView.removeFromSuperview()
        self.refImageView.image = nil
        self.refImageButton.isEnabled = false
        
        self.searchResultsController.offers = []
        
        let size = self.view.frame.size
        
        let loader = IncitoJSONFileLoader(
            filename: filename,
            width: Double(min(size.width, size.height))
        )
        
        let start = Date.timeIntervalSinceReferenceDate
        self.reload(loader) { result in
            let end = Date.timeIntervalSinceReferenceDate
            switch result {
            case .success:
                print("   ✅ in \(round((end - start) * 1000) / 1000)s")
            case .error(let error):
                print("   ❌ in \(round((end - start) * 1000) / 1000)s: \(error)")
            }
            print("-----------------")
            
            guard case .success(let vc) = result else { return }
            
            // add an example custom gesture recognizer to the incito's view
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(DemoViewController.didLongPress))
            vc.view.addGestureRecognizer(longPress)
            
            if let refImage = refImage {
                self.refImageView.image = refImage
                self.refImageView.translatesAutoresizingMaskIntoConstraints = false
                
                vc.configureScrollView { (scrollView) in
                    // add the refImageView
                    scrollView.addSubview(self.refImageView)
                    
                    NSLayoutConstraint.activate([
                        self.refImageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
                        self.refImageView.topAnchor.constraint(equalTo: scrollView.topAnchor)
                        ])
                }
                
                self.refImageView.alpha = 0
                self.refImageButton.tintColor = UIColor.orange.withAlphaComponent(0.75)
                self.refImageButton.isEnabled = true
            }
        }
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
    
    @objc
    func toggleReferenceImage() {
        switch refImageView.alpha {
        case 0:
            refImageView.alpha = 0.5
            refImageButton.tintColor = UIColor.orange.withAlphaComponent(1)
        case 0.5:
            refImageView.alpha = 1
            refImageButton.tintColor = UIColor.orange.withAlphaComponent(0.3)
        default:
            refImageView.alpha = 0
            refImageButton.tintColor = UIColor.orange.withAlphaComponent(0.75)
        }
    }
    
    @objc
    func didLongPress(_ longPress: UILongPressGestureRecognizer) {
        guard longPress.state == .began else { return }
        
        guard let incitoVC = self.incitoViewController else { return }
        let point = longPress.location(in: incitoVC.view)
        
        guard let firstOffer = incitoVC.firstView(at: point, where: { $1.isOffer }) else { return }
        
        let properties = firstOffer.properties
        
        print("👉 [Offer long-press] '\(properties.style.meta["title"]?.stringValue ?? "")': '\(properties.style.meta["description"]?.stringValue ?? "")'")
    }
}

extension ViewProperties {
    var isOffer: Bool {
        return self.style.role == "offer"
    }
}

import SafariServices

extension DemoViewController: IncitoLoaderViewControllerDelegate {
    
    func incitoDocumentLoaded(in viewController: IncitoViewController) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            var offers: [SearchResultsViewController.OfferProperties] = []
            
            // walk through all the view elements, indexing all the offers.
            viewController.iterateViewElements { viewProperties, _ in
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
    
    func incitoDidTapLink(_ url: URL, at point: CGPoint, in viewController: IncitoViewController) {
        
        print("👉 [Link] '\(url)'")
        
        // An example of how to present an in-app view of the link.
        let sfVC = SFSafariViewController(url: url)
        viewController.present(sfVC, animated: true, completion: nil)
    }
    
    func incitoDidReceiveTap(at point: CGPoint, in viewController: IncitoViewController) {
        
        // An example of how to get the offer that was tapped.
        guard let firstOffer = viewController.firstView(at: point, where: { $1.isOffer }) else { return }
        
        let properties = firstOffer.properties
        
        print("👉 [Offer] '\(properties.style.meta["title"]?.stringValue ?? "")': '\(properties.style.meta["description"]?.stringValue ?? "")'")
        
        viewController.scrollToElement(withId: properties.id, position: .top, animated: true)
    }
}

// MARK: - Previewing

extension DemoViewController: UIViewControllerPreviewingDelegate {
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        
        guard let incito = incitoViewController else { return nil }
        
        let incitoVCLocation = previewingContext.sourceView.convert(location, to: incito.view)
        
        // get first offer view
        let firstView = incito.firstView(at: incitoVCLocation) { $1.isOffer }
        
        guard let view = firstView?.0 else { return nil }
        
        previewingContext.sourceRect = view.convert(view.bounds, to: previewingContext.sourceView)
        
        // TODO: use the previewingContext.sourceView to include bgColor.
        
        let vc = OfferPreviewViewController()
        let screenImage = view.asImage()
        let imageView = UIImageView(image: screenImage)
        vc.addSnapshot(imageView)
        
        return vc
    }
    
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        //        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}

extension UIView {
    
    // Using a function since `var image` might conflict with an existing variable
    // (like on `UIImageView`)
    func asImage() -> UIImage {
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { rendererContext in
                layer.render(in: rendererContext.cgContext)
            }
        } else {
            UIGraphicsBeginImageContext(self.frame.size)
            self.layer.render(in:UIGraphicsGetCurrentContext()!)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return UIImage(cgImage: image!.cgImage!)
        }
    }
}

class OfferPreviewViewController: UIViewController {
    func addSnapshot(_ snapshot: UIView) {
        view.backgroundColor = .white
        view.addSubview(snapshot)
        
        self.preferredContentSize = snapshot.frame.size
    }
    
    override var previewActionItems: [UIPreviewActionItem] {
        let listsAction = UIPreviewAction(title: "Add to List", style: .default) { previewAction, viewController in
            print("Added to list!")
        }
        return [
            listsAction
        ]
    }
}

// MARK: - Search

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
