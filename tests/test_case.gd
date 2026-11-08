class_name TestCase
extends RefCounted
## Base class for the game's tests. Each method whose name starts with
## "test_" runs on a fresh instance. Checks record failures instead of
## stopping, so one run reports every broken expectation.

## The scene tree, for tests that need nodes in a running scene.
var tree: SceneTree
var failures: PackedStringArray = []
## Nodes added with add_node() are freed after the test.
var _nodes: Array[Node] = []


func expect(condition: bool, message: String = "expected true") -> void:
	if not condition:
		failures.append(message)


func expect_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%sexpected %s but got %s" % [_prefix(message), var_to_str(expected), var_to_str(actual)])


func expect_near(actual: float, expected: float, tolerance: float = 0.0001, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%sexpected %s ± %s but got %s" % [_prefix(message), expected, tolerance, actual])


func expect_between(actual: float, low: float, high: float, message: String = "") -> void:
	if actual < low or actual > high:
		failures.append("%sexpected %s to be between %s and %s" % [_prefix(message), actual, low, high])


## Adds a node to the running scene and frees it when the test ends.
func add_node(node: Node) -> Node:
	tree.root.add_child(node)
	_nodes.append(node)
	return node


func cleanup() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	_nodes.clear()


func _prefix(message: String) -> String:
	return "" if message.is_empty() else message + ": "
