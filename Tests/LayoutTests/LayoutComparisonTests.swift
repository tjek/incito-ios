//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2019 ShopGun. All rights reserved.

import XCTest
@testable import Incito

typealias TestLayoutTree = TreeNode<(String?, TestLayoutRect)>

struct TestLayoutRect: Decodable, Equatable {
    var x: Double, y: Double, width: Double, height: Double
}

struct TestLayoutDimensions: Decodable {
    var id: String?
    var rect: TestLayoutRect
    var children: [TestLayoutDimensions]
    
    func treeify() -> TestLayoutTree {
        let node = TestLayoutTree(value: (self.id, self.rect))
        node.add(children: self.children.map { $0.treeify() })
        return node
    }
}

class LayoutComparisonTests: XCTestCase {
    let testComparisons: [(filename: String, dimensionsFilename: String, width: Double)] = [
        ("incito-blocktest-375.json", "incito-blocktest-375.dimensions.json", 375),
        ("incito-transformtest-375.json", "incito-transformtest-375.dimensions.json", 375)
    ]
    
    func testLayoutChecks() {
        testComparisons.forEach(self.compareLayoutFiles)
    }
    
    func compareLayoutFiles(filename: String, dimensionsFilename: String, width: Double) {
        
        let bundle = Bundle(for: LayoutComparisonTests.self)
        
        let dimensionsLoader = openFile(filename: dimensionsFilename, bundle: bundle)
            .flatMap(TestLayoutDimensions.decode(from:))
            .map { $0.treeify() }
        let incitoLoader = IncitoJSONFileLoader(filename: filename, bundle: bundle, width: width)
            .map({ (renderableDoc: RenderableIncitoDocument) -> TreeNode<(String?, TestLayoutRect, RenderableView)> in
                renderableDoc.rootView.mapValues({ (renderableView: RenderableView, _, _) in
                    let absRect = renderableView.absoluteRect
                    return (
                        renderableView.layout.viewProperties.name,
                        TestLayoutRect(x: Double(absRect.origin.x), y: Double(absRect.origin.y), width: Double(absRect.size.width), height: Double(absRect.size.height)),
                        renderableView
                    )
                })
            })
        
        let expect = self.expectation(description: "IncitoLoaded")
        
        incitoLoader
            .zip(dimensionsLoader)
            .run {
                switch $0 {
                case let .error(error):
                    XCTFail("Unable to render Incito \(error)")
                case let .success((incitoRectTree, dimensionsTree)):
                    
                    if let comparisonError = compareLayoutTrees(incitoRectTree, dimensionsTree) {
                        XCTFail("Incorrect Layout \(comparisonError)")
                    }
                }
                expect.fulfill()
        }
        self.wait(for: [expect], timeout: 10)
    }
}
enum LayoutTestError: Error {
    case incorrectLayout(id: String?, expected: TestLayoutRect, actual: TestLayoutRect)
}

func compareLayoutTrees(_ lhs: TreeNode<(String?, TestLayoutRect, RenderableView)>, _ rhs: TestLayoutTree) -> Error? {
    guard lhs.value.1 == rhs.value.1 else {
        print("❌ Misaligned!", lhs.value.1, rhs.value.1)
        print("   ", lhs.value.2.layout.dimensions)
        
        return LayoutTestError.incorrectLayout(
            id: lhs.value.0 ?? rhs.value.0,
            expected: lhs.value.1,
            actual: rhs.value.1
        )
    }
    
    for (lhsChild, rhsChild) in zip(lhs.children, rhs.children) {
        if let error = compareLayoutTrees(lhsChild, rhsChild) {
            return error
        }
    }
    return nil
}
