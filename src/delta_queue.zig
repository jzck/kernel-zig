const std = @import("std");

/// DeltaQueue is a singly-linked list where each
/// node has a counter. Each counter is relative
/// to the previous.
///
/// Inspired by https://wiki.osdev.org/Blocking_Process
/// Based on std.SinglyLinkedList
pub fn DeltaQueue(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Node inside the linked list wrapping the actual data.
        pub const Node = struct {
            next: ?*Node,
            data: T,
            counter: u64,

            pub fn init(data: T, counter: u64) Node {
                return Node{
                    .next = null,
                    .data = data,
                    .counter = counter,
                };
            }

            /// Insert a new node after the current one.
            ///
            /// Arguments:
            ///     new_node: Pointer to the new node to insert.
            pub fn insertAfter(node: *Node, new_node: *Node) void {
                if (node.next) |after| {
                    std.debug.assert(new_node.counter <= after.counter); //sanity check
                    after.counter -= new_node.counter;
                }
                new_node.next = node.next;
                node.next = new_node;
            }
        };

        first: ?*Node,

        /// Initialize a delta queue.
        ///
        /// Returns:
        ///     An empty linked list.
        pub fn init() Self {
            return Self{
                .first = null,
            };
        }

        /// Insert a node in the list
        ///
        /// Arguments:
        ///     node: Pointer to a node in the list.
        ///     new_node: Pointer to the new node to insert.
        pub fn insert(list: *Self, node: *Node) void {
            var target: ?*Node = null;
            var next: ?*Node = list.first;
            while (true) {
                if (next == null or node.counter <= next.?.counter) {
                    if (target) |tg| return tg.insertAfter(node);
                    return list.prepend(node);
                }
                if (target) |tg| node.counter -= tg.counter;
                target = next;
                next = target.?.next;
            }
        }

        /// worst case is O(n)
        /// Could be better with a different data structure
        /// Example: case of large list with all counters at 0,
        /// we need to traverse the whole list.
        pub fn decrement(list: *Self, count: u64) void {
            var it = list.first;
            var i = count;
            while (it) |node| : (it = node.next) {
                if (node.counter >= i) {
                    node.counter -= i;
                    return;
                }
                i -= node.counter;
                node.counter = 0;
            }
        }

        /// Insert a new node at the head.
        ///
        /// Arguments:
        ///     new_node: Pointer to the new node to insert.
        fn prepend(list: *Self, new_node: *Node) void {
            if (list.first) |after| {
                std.debug.assert(new_node.counter <= after.counter); //sanity check
                after.counter -= new_node.counter;
            }
            new_node.next = list.first;
            list.first = new_node;
        }

        /// Remove and return the first node in the list
        /// if its counter is 0.
        ///
        /// Returns:
        ///     A pointer to the first node in the list.
        pub fn popZero(list: *Self) ?*Node {
            const first = list.first orelse return null;
            if (first.counter != 0) return null;
            list.first = first.next;
            return first;
        }

        /// Allocate a new node.
        ///
        /// Arguments:
        ///     allocator: Dynamic memory allocator.
        ///
        /// Returns:
        ///     A pointer to the new node.
        pub fn allocateNode(list: *Self, allocator: *Allocator) !*Node {
            return allocator.create(Node);
        }

        /// Deallocate a node.
        ///
        /// Arguments:
        ///     node: Pointer to the node to deallocate.
        ///     allocator: Dynamic memory allocator.
        pub fn destroyNode(list: *Self, node: *Node, allocator: *Allocator) void {
            allocator.destroy(node);
        }

        /// Allocate and initialize a node and its data.
        ///
        /// Arguments:
        ///     data: The data to put inside the node.
        ///     allocator: Dynamic memory allocator.
        ///
        /// Returns:
        ///     A pointer to the new node.
        pub fn createNode(list: *Self, data: T, counter: u64, allocator: *Allocator) !*Node {
            var node = try list.allocateNode(allocator);
            node.* = Node.init(data, counter);
            return node;
        }
    };
}
