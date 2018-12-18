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
    let value: T
    
    private(set) weak var parent: TreeNode? = nil
    private(set) var children: [TreeNode<T>] = []
    
    required init(value: T) {
        self.value = value
    }
    
    func add(child: TreeNode<T>) {
        children.append(child)
        child.parent = self
    }
    
    func remove(child: TreeNode<T>) {
        self.children.removeAll { $0 === self }
    }
    
    var isLeaf: Bool { return children.isEmpty }
    var isRoot: Bool { return parent == nil }
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
    func mapValues<B>(_ transform: (T, _ parent: TreeNode<B>?) -> B) -> TreeNode<B> {
        return _mapValues(parent: nil, transform)
    }
    
    private func _mapValues<B>(parent: TreeNode<B>? = nil, _ transform: (T, _ parent: TreeNode<B>?) -> B) -> TreeNode<B> {
        let newNode = TreeNode<B>(value: transform(self.value, parent))
        
        self.children.forEach {
            newNode.add(child: $0._mapValues(parent: newNode, transform))
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
    func first(where predicate: (TreeNode<T>) -> Bool) -> TreeNode? {
        if predicate(self) {
            return self
        }
        
        for child in children {
            if let found = child.first(where: predicate) {
                return found
            }
        }
        return nil
    }
}

extension TreeNode where T: Equatable {
    func search(_ value: T) -> TreeNode? {
        return first { $0.value == value }
    }
}

extension TreeNode {
    /// Walk the node and all it's children. If `rootFirst` is set to false (the default) then the closure will called on all the leaf nodes first, then their parents etc, until finally the rootNode (the object we are calling this on) is passed. if `rootFirst` is true, we start with the current node.
    func forEachNode(rootFirst: Bool = false, _ body: (TreeNode<T>, _ depth: Int) throws -> Void) rethrows {
        try _forEachNode(rootFirst: rootFirst, depth: 0, body)
    }
    
    private func _forEachNode(rootFirst: Bool, depth: Int, _ body: (TreeNode<T>, _ depth: Int) throws -> Void) rethrows {
        
        if rootFirst {
            try body(self, depth)
            try self.children.forEach { try $0._forEachNode(rootFirst: rootFirst, depth: depth + 1, body) }
        } else {
            try self.children.forEach { try $0._forEachNode(rootFirst: rootFirst, depth: depth + 1, body) }
            try body(self, depth)
        }
    }
}
