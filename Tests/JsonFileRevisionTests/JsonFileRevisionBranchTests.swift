//
//  JsonFileRevisionBranchTests.swift
//  JsonFileRevision
//
//  Created by Bernardo Breder on 02/02/17.
//
//

import XCTest
@testable import DataStore
@testable import JsonFileRevision
@testable import JsonFileRevisionClient
@testable import JsonFileRevisionServer
@testable import JsonFileChange
@testable import Json
@testable import Literal
@testable import IndexLiteral

class JsonFileRevisionBranchTests: XCTestCase {
    
    let cfs = MemoryFileSystem()
    
    let sfs = MemoryFileSystem()
    
    var cdb: DataStore!
    
    var sdb: DataStore!
    
    var client: JsonFileRevisionClient!
    
    var server: JsonFileRevisionServer!
    
    override func setUp() {
        sdb = try! DataStore(fileSystem: DataStoreFileSystem(folder: sfs.home()))
        cdb = try! DataStore(fileSystem: DataStoreFileSystem(folder: cfs.home()))
        client = try! cdb.read { reader in try JsonFileRevisionClient(reader: reader) }
        server = try! sdb.read { reader in try JsonFileRevisionServer(reader: reader) }
    }
    
    func testExample() throws {
        try createFolder(parents: [], name: "a")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a"], try listFolders())
        
        try createBranch(name: "A"); try switchBranch(name: "A")
        try createFolder(parents: [], name: "z")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a"], try listFolders())
        try switchBranch(name: "A"); XCTAssertEqual(["a", "z"], try listFolders())
     
        try switchBranch(name: "master")
        try createFolder(parents: [], name: "b")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a", "b"], try listFolders())
        try switchBranch(name: "A"); XCTAssertEqual(["a", "z"], try listFolders())
        
        try switchBranch(name: "A")
        try createFolder(parents: [], name: "y")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a", "b"], try listFolders())
        try switchBranch(name: "A"); XCTAssertEqual(["a", "y", "z"], try listFolders())
        
        try createBranch(name: "B");  try switchBranch(name: "B")
        try createFolder(parents: [], name: "x")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a", "b"], try listFolders())
        try switchBranch(name: "A"); XCTAssertEqual(["a", "y", "z"], try listFolders())
        try switchBranch(name: "B"); XCTAssertEqual(["a", "b", "x"], try listFolders())
        
        try switchBranch(name: "master")
        try createFolder(parents: [], name: "c")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a", "b", "c"], try listFolders())
        try switchBranch(name: "A"); XCTAssertEqual(["a", "y", "z"], try listFolders())
        try switchBranch(name: "B"); XCTAssertEqual(["a", "b", "x"], try listFolders())
        
        try switchBranch(name: "A")
        try createFolder(parents: [], name: "m")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a", "b", "c"], try listFolders())
        try switchBranch(name: "A"); XCTAssertEqual(["a", "m", "y", "z"], try listFolders())
        try switchBranch(name: "B"); XCTAssertEqual(["a", "b", "x"], try listFolders())
        
        try switchBranch(name: "B")
        try createFolder(parents: [], name: "n")
        try commit()
        
        try switchBranch(name: "master"); XCTAssertEqual(["a", "b", "c"], try listFolders())
        try switchBranch(name: "A"); XCTAssertEqual(["a", "m", "y", "z"], try listFolders())
        try switchBranch(name: "B"); XCTAssertEqual(["a", "b", "n", "x"], try listFolders())
    }
    
    func listFolders() throws -> [String] {
        return try cdb.read { reader in try client.read(reader: reader) { r in try r.list() }.folders.sorted() }
    }
    
    func switchBranch(name: String) throws {
        try cdb.write { writer in
            try client.switchBranch(writer: writer, branch: name)
        }
    }
    
    func createBranch(name: String) throws {
        try cdb.write { writer in
            try sdb.write { writer in try server.createBranch(writer: writer, revisionId: client.revisionId, name: name) }
            try client.createdBranch(writer: writer, name: name)
        }
    }
    
    func createFolder(parents: [String], name: String) throws {
        try cdb.write { writer in try client.write(writer: writer) { w in try w.createFolder(parents, name: name) } }
    }
    
    func commit() throws {
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: client.revisionId, branch: client.branch, changes: client.changes) });
        try cdb.write { writer in try client.commitChanges(writer: writer) }
    }
    
}
