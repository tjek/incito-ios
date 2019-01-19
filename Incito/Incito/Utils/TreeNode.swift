//
//  ┌────┬─┐         ┌─────┐
//  │  ──┤ └─┬───┬───┤  ┌──┼─┬─┬───┐
//  ├──  │ ╷ │ · │ · │  ╵  │ ╵ │ ╷ │
//  └────┴─┴─┴───┤ ┌─┴─────┴───┴─┴─┘
//               └─┘
//
//  Copyright (c) 2018 ShopGun. All rights reserved.

// TODO: maybe as struct - do we need a parent?
final class TreeNode<T> {
    var value: T
    
    private(set) weak var parent: TreeNode? = nil
    private(set) var children: [TreeNode<T>] = []
    
    required init(value: T) {
        self.value = value
    }
    
    func add(child: TreeNode<T>) {
        children.append(child)
        child.parent = self
    }
    
    func add(children: [TreeNode<T>]) {
        for child in children {
            self.children.append(child)
            child.parent = self
        }
    }
    
    func remove(child: TreeNode<T>) {
        self.children.removeAll { $0 === self }
    }
    
    var isLeaf: Bool { return children.isEmpty }
    var isRoot: Bool { return parent == nil }
    
    /// The node's siblings, excluding itself
    func siblings(excludeSelf: Bool = true) -> [TreeNode] {
        if excludeSelf {
            return self.parent?.children.filter({ $0 !== self }) ?? []
        } else {
            return self.parent?.children ?? []            
        }
    }
    
    /// The node's siblings, excluding itself
    func groupedSiblings() -> (prev: [TreeNode], next: [TreeNode]) {
        return mappedGroupedSiblings({ $0 })
    }
    
    func mappedGroupedSiblings<A>(_ transform: (TreeNode<T>) -> A) -> (prev: [A], next: [A]) {
        
        let allSiblings = siblings(excludeSelf: false)
        
        guard !allSiblings.isEmpty else {
            return ([], [])
        }
        
        guard let currIndex = allSiblings.index(where: { $0 === self}) else {
            fatalError("Current node MUST be a child of its parent")
        }
        
        let prevSiblings: [A] = {
            guard currIndex != allSiblings.startIndex else {
                return []
            }
            let prevIndex = allSiblings.index(before: currIndex)
            
            return Array(allSiblings[...prevIndex].map(transform))
        }()
        
        let nextSiblings: [A] = {
            guard currIndex != allSiblings.endIndex else {
                return []
            }
            let nextIndex = allSiblings.index(after: currIndex)
            return Array(allSiblings[nextIndex...].map(transform))
        }()
        
        return (prevSiblings, nextSiblings)
    }
}

extension TreeNode: CustomStringConvertible {
    public var description: String {
        return description(depth: 0)
    }
    
    private func description(depth: Int) -> String {
        var s = ""
        if depth > 0 {
            s += String(repeating: "   ", count: depth - 1) + " ‣ "
        }
        s += "\(value)"
        for child in children {
            s += "\n\(child.description(depth: depth + 1))"
        }
        return s
    }
}

extension TreeNode {
    // map root first
    func mapValues<B>(_ transform: (T, _ parent: TreeNode<B>?, _ index: Int) -> B) -> TreeNode<B> {
        return _mapValues(parent: nil, index: 0, transform)
    }
    
    private func _mapValues<B>(parent: TreeNode<B>? = nil, index: Int = 0, _ transform: (T, _ parent: TreeNode<B>?, _ index: Int) -> B) -> TreeNode<B> {
        let newNode = TreeNode<B>(value: transform(self.value, parent, index))
        
        for (idx, child) in children.enumerated() {
            newNode.add(child: child._mapValues(parent: newNode, index: idx, transform))
        }
        return newNode
    }
    
    func mapValuesLeafFirst<B>(_ transform: (T, _ children: [TreeNode<B>]) -> B) -> TreeNode<B> {
        // map the children
        let newChildren: [TreeNode<B>] = self.children.map {
            $0.mapValuesLeafFirst(transform)
        }
        // map the current node, providing the children as a parameter
        let newNode = TreeNode<B>(value: transform(self.value, newChildren))
        
        newChildren.forEach {
            newNode.add(child: $0)
        }
        return newNode
    }
    
    func mapTree<B>(_ transform: (TreeNode<T>, _ newParent: TreeNode<B>?) -> B) -> TreeNode<B> {
        return _mapTree(parent: nil, transform)
    }
    private func _mapTree<B>(parent: TreeNode<B>? = nil, _ transform: (TreeNode<T>, _ newParent: TreeNode<B>?) -> B) -> TreeNode<B> {
        let newNode = TreeNode<B>(value: transform(self, parent))

        self.children.forEach {
            let newChild = $0._mapTree(parent: newNode, transform)
            newNode.add(child: newChild)
        }
        return newNode
    }
}

extension TreeNode {
    var calculateNodeCount: Int {
        return children.reduce(1) { $0 + $1.calculateNodeCount }
    }
}

extension TreeNode {
    /**
     Traverse the tree, starting at the node this is called and, and recursively inspecting all its children.
     
     - parameter body: The closure executed for each node in the tree. The closure takes the following arguments:
     - parameter node: The current node being inspected
     - parameter depth: 0 for the first node, 1 for all that node's children etc.
     - parameter stopWalkingBranch: If you set this to true in the callback, it will not look at any of the children of the node we just inspected (but will continue to inspect the siblings and their children).
     - parameter completeStop: If you set this to true it will stop traversing the tree - including not inspecting the children or siblings of the current node.
     */
    func forEachNode(_ body: (_ node: TreeNode<T>, _ depth: Int, _ stopWalkingBranch: inout Bool, _ completeStop: inout Bool) throws -> Void) rethrows {
        try _forEachNode(depth: 0, body)
    }
    
    /// Returns true if we should completely stop walking the nodes.
    @discardableResult
    private func _forEachNode(depth: Int, _ body: (TreeNode<T>, _ depth: Int, _ stopWalkingBranch: inout Bool, _ completeStop: inout Bool) throws -> Void) rethrows -> Bool {
        
        var stopWalkingBranch: Bool = false
        var completeStop: Bool = false
        
        try body(self, depth, &stopWalkingBranch, &completeStop)
        
        guard completeStop == false, stopWalkingBranch == false else { return completeStop }
        
        for child in children {
            completeStop = try child._forEachNode(depth: depth + 1, body)
            
            if completeStop {
                return true
            }
        }
        return false
    }
}

extension TreeNode {
    /**
     Returns the first Node where the `predicate` returns true, or nil if predicate never returns true.
     
     - parameter predicate: The closure that is called for each node in the tree, to check if it is the node you are looking for. Return true to use that node, false to continue looking.
     - parameter node: The node that the predicate is checking.
     - parameter stopWalkingBranch: Allow the predicate to ignore entire branches by setting this to true. All children of the currently-inspected node will not be checked (but its siblings will be).
     */
    func first(where predicate: (_ node: TreeNode<T>, _ stopWalkingBranch: inout Bool) -> Bool) -> TreeNode? {
        
        var found: TreeNode? = nil
        self.forEachNode { (node, _, stopBranch, completeStop) in
            if predicate(node, &stopBranch) {
                found = node
                completeStop = true
                return
            }
        }
        return found
    }
}

extension TreeNode where T: Equatable {
    func search(_ value: T) -> TreeNode? {
        return first { node, _ in node.value == value }
    }
}
