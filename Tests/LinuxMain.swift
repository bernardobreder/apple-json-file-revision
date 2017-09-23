//
//  JsonFileRevisionTests.swift
//  JsonFileRevision
//
//  Created by Bernardo Breder.
//
//

import XCTest
@testable import JsonFileRevisionTests

extension JsonFileRevisionTests {

	static var allTests : [(String, (JsonFileRevisionTests) -> () throws -> Void)] {
		return [
			("testCommit", testCommit),
			("testCommits", testCommits),
			("testCommitWrongRevision", testCommitWrongRevision),
		]
	}

}

extension JsonFileRevisionBranchTests {

	static var allTests : [(String, (JsonFileRevisionBranchTests) -> () throws -> Void)] {
		return [
			("testExample", testExample),
		]
	}

}

XCTMain([
	testCase(JsonFileRevisionTests.allTests),
	testCase(JsonFileRevisionBranchTests.allTests),
])

