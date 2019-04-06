//
//  ParseNodeTests.swift
//  TypeCheckedAST
//
//  Created by Yuta Saito on 2019/04/05.
//

import XCTest
@testable import TypeCheckedAST

let rawASTString = """
(parameter_list (parameter "i" type='Int' interface type='Int') range=[foo.swift:1:17 - line:1:17])
"""

class ParseNodeTests: XCTestCase {

    func extractDecl(_ attr: Attribute) -> Decl {
        switch attr {
        case .decl(let decl): return decl
        default: fatalError()
        }
    }

    func testExample() {
        let (node, tail) = try! parseNode().parse(rawASTString)
    }

    func testParseDecl() throws {
        do {
            let content = "Swift.(file).Collection"
            let (node, _) = try parseDecl().parse(content)
            XCTAssertEqual(node.value, "Swift.(file).Collection")
        }
        do {
            let content = "Swift.(file).Int.init(_builtinIntegerLiteral:)"
            let (node, tail) = try parseDecl().parse(content)
            XCTAssertEqual(node.value, "Swift.(file).Int.init(_builtinIntegerLiteral:)")
            XCTAssertEqual(tail, "")
        }

        do {
            let content = "Swift.(file).Collection extension.map"
            let (node, tail) = try parseDecl().parse(content)
            XCTAssertEqual(node.value, "Swift.(file).Collection extension.map")
            XCTAssertEqual(tail, "")
        }

        do {
            let content = "(declref_expr decl=Swift.(file).Collection extension.map [with (substitution_map generic_signature=<Self, T where Self : Collection> (substitution Self -> [Int]) (substitution T -> String))])"
            let (node, _) = try! parseNode().parse(content)
            let decl = extractDecl(node.attributes[0])
            XCTAssertEqual(decl.value, "Swift.(file).Collection extension.map")
            XCTAssertEqual(decl.substitution, "[with (substitution_map generic_signature=<Self, T where Self : Collection>  (substitution Self -> [Int]) (substitution T -> String))]")
        }
    }

    func testParseChildren() throws {
        let content = """
        (source_file "foo.swift"
            (top_level_code_decl range=[foo.swift:1:1 - line:3:1] )
            (top_level_code_decl range=[foo.swift:1:1 - line:3:1] ))
        """
        let (node, _) = try parseNode().parse(content)
        XCTAssertEqual(node.children.count, 2)
    }

    func testParseValue() throws {
        let content = """
        (source_file "foo.swift" )
        """
        let (node, _) = try parseNode().parse(content)
        XCTAssertEqual(node.value, "foo.swift")
    }

    func testParseRange() throws {
        let content = "[foo.swift:1:1 - line:3:1]"
        let (node, _) = try parseRange()
            .parse(content)
        XCTAssertEqual(node.start.fileName, "foo.swift")
        XCTAssertEqual(node.start.line, 1)
        XCTAssertEqual(node.start.column, 1)
        XCTAssertEqual(node.end.fileName, "line")
        XCTAssertEqual(node.end.line, 3)
        XCTAssertEqual(node.end.column, 1)
    }

    func testParseType() throws {
        let content = "(call_expr type='[String]')"
        let (node, _) = try parseNode().parse(content)
        XCTAssertEqual(node.attributes.first, .type("[String]"))
    }

    func testParseMultipleAttributes() throws {
        let content = "(call_expr type='[String]' location=foo.swift:1:11 nothrow)"
        let (node, _) = try parseNode().parse(content)
        let location = Range.Point(
            fileName: "foo.swift",
            line: 1,
            column: 11
        )
        XCTAssertEqual(
            node.attributes,
            [
                .type("[String]"),
                .location(location),
                .nothrow
            ]
        )
    }

    func testParseNodeWithRange() throws {
        let content = "(top_level_code_decl range=[foo.swift:1:1 - line:3:1])"
        let (node, _) = try parseNode().parse(content)
        let range = Range(
            start: Range.Point(fileName: "foo.swift", line: 1, column: 1),
            end: Range.Point(fileName: "line", line: 3, column: 1)
        )
        let attribute = Attribute.range(range)
        let expectedNode = RawNode(
            name: "top_level_code_decl",
            value: nil,
            attributeOrNode: [.attribute(attribute)]
        )
        XCTAssertEqual(node, expectedNode)
    }
}
