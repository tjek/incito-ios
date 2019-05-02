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
    
    func prettyMuchEqual(_ other: TestLayoutRect) -> Bool {
        let epsilon = 0.001
        return abs(x - other.x) < epsilon
            && abs(y - other.y) < epsilon
            && abs(width - other.width) < epsilon
            && abs(height - other.height) < epsilon
    }
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
        ("incito-transformtest-350.json", "incito-transformtest-350.dimensions.json", 350),
        ("incito-flextest-375.json", "incito-flextest-375.dimensions.json", 375),
        ("incito-stroketest-375.json", "incito-stroketest-375.dimensions.json", 375),
    ]
    
    func testLayoutChecks() {
        testComparisons.forEach(self.compareLayoutFiles)
    }
    
    func compareLayoutFiles(filename: String, dimensionsFilename: String, width: Double) {
        
        let bundle = Bundle(for: LayoutComparisonTests.self)
        
        let dimensionsLoader = openFile(filename: dimensionsFilename, bundle: bundle)
            .flatMapResult(TestLayoutDimensions.decodeFutureJSON(from:))
            .mapResult { $0.treeify() }
        let incitoLoader = IncitoJSONFileLoader(filename: filename, bundle: bundle, width: width)
            .mapResult({ (renderableDoc: RenderableIncitoDocument) -> TreeNode<(String?, TestLayoutRect, RenderableView)> in
                // Incito's root view is a container, so we need to skip that
                renderableDoc.rootView.children[0].mapValues({ (renderableView: RenderableView, _, _) in
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
            .zippedResult(dimensionsLoader)
            .run {
                switch $0 {
                case let .failure(error):
                    XCTFail("Unable to render Incito \(error)")
                case let .success((incitoRectTree, dimensionsTree)):
                    
                    if let comparisonError = compareLayoutTrees(incitoRectTree, dimensionsTree) {
                        XCTFail("Incorrect Layout \(filename)\n\(comparisonError)")
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
    let actualRect = lhs.value.1
    let expectedRect = rhs.value.1
    guard actualRect.prettyMuchEqual(expectedRect) else {
        print("❌ Misaligned!", lhs.value.1, rhs.value.1)
        print("   ", lhs.value.2.layout.dimensions)
        
        return LayoutTestError.incorrectLayout(
            id: lhs.value.0 ?? rhs.value.0,
            expected: expectedRect,
            actual: actualRect
        )
    }
    
    for (lhsChild, rhsChild) in zip(lhs.children, rhs.children) {
        if let error = compareLayoutTrees(lhsChild, rhsChild) {
            return error
        }
    }
    return nil
}
