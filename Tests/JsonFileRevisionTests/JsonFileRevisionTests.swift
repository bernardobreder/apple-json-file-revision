//
//  JsonFileRevisionTests.swift
//  FileStore
//
//  Created by Bernardo Breder on 05/01/17.
//
//

import XCTest
import Foundation
@testable import JsonFileRevision
@testable import JsonFileRevisionClient
@testable import JsonFileRevisionServer
@testable import JsonFileChange
@testable import DataStore
@testable import FileSystem

class JsonFileRevisionTests: XCTestCase {
    
    func testCommit() throws {
        let cfs = MemoryFileSystem(), sfs = MemoryFileSystem()
        let cdb = try DataStore(fileSystem: DataStoreFileSystem(folder: cfs.home()))
        let sdb = try DataStore(fileSystem: DataStoreFileSystem(folder: sfs.home()))
        let client = try cdb.read { reader in try JsonFileRevisionClient(reader: reader) }
        let server = try sdb.read { reader in try JsonFileRevisionServer(reader: reader) }
        
        try cdb.write { writer in try client.write(writer: writer) { w in
            try w.createFile([], name: "a.txt")
            try w.write([], name: "a.txt", { jw in jw.apply(["a", "b"], value: 1) })
            } }
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: 0, branch: client.branch, changes: client.changes) })
    }
    
    func testCommitWrongRevision() throws {
        let cfs = MemoryFileSystem(), sfs = MemoryFileSystem()
        let cdb = try DataStore(fileSystem: DataStoreFileSystem(folder: cfs.home()))
        let sdb = try DataStore(fileSystem: DataStoreFileSystem(folder: sfs.home()))
        let client = try cdb.read { reader in try JsonFileRevisionClient(reader: reader) }
        let server = try sdb.read { reader in try JsonFileRevisionServer(reader: reader) }
        
        try cdb.write { writer in try client.write(writer: writer) { w in
            try w.createFile([], name: "a.txt")
            } }
        XCTAssertFalse(try sdb.write { writer in try server.commit(writer: writer, revisionId: 1, branch: client.branch, changes: client.changes) })
        XCTAssertFalse(try sdb.write { writer in try server.commit(writer: writer, revisionId: -1, branch: client.branch, changes: client.changes) })
    }
    
    func testCommits() throws {
        let cafs = MemoryFileSystem(), cbfs = MemoryFileSystem(), ccfs = MemoryFileSystem(), sfs = MemoryFileSystem()
        let cadb = try DataStore(fileSystem: DataStoreFileSystem(folder: cafs.home()))
        let cbdb = try DataStore(fileSystem: DataStoreFileSystem(folder: cbfs.home()))
        let ccdb = try DataStore(fileSystem: DataStoreFileSystem(folder: ccfs.home()))
        let sdb = try DataStore(fileSystem: DataStoreFileSystem(folder: sfs.home()))
        let clientA = try cadb.read { reader in try JsonFileRevisionClient(reader: reader) }
        let clientB = try cbdb.read { reader in try JsonFileRevisionClient(reader: reader) }
        let clientC = try ccdb.read { reader in try JsonFileRevisionClient(reader: reader) }
        let server = try sdb.read { reader in try JsonFileRevisionServer(reader: reader) }
        
        try cadb.write { writer in try clientA.write(writer: writer) { w in
            try w.createFile([], name: "a.txt")
            try w.write([], name: "a.txt", { jw in jw.apply(["a", "b"], value: 1) })
            } }
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: clientA.revisionId, branch: clientA.branch, changes: clientA.changes) })
        try cadb.write { writer in try clientA.commitChanges(writer: writer) }
        
        try cadb.write { writer in try clientA.write(writer: writer) { w in
            try w.createFile([], name: "b.txt")
            try w.write([], name: "b.txt", { jw in jw.apply(["a", "b"], value: 2) })
            } }
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: clientA.revisionId, branch: clientA.branch, changes: clientA.changes) })
        try cadb.write { writer in try clientA.commitChanges(writer: writer) }
        
        try cadb.write { writer in try clientA.write(writer: writer) { w in
            try w.write([], name: "a.txt", { jw in jw.apply(["a", "b"], value: 3) })
            try w.write([], name: "a.txt", { jw in jw.apply(["a", "c"], value: 4) })
            } }
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: clientA.revisionId, branch: clientA.branch, changes: clientA.changes) })
        try cadb.write { writer in try clientA.commitChanges(writer: writer) }
        
        XCTAssertEqual(["a.txt", "b.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual([], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.folders.sorted() })
        
        try cbdb.write { writer in try clientB.applyChanges(writer: writer, revisions: sdb.read { reader in try server.update(reader: reader, revisionId: clientB.revisionId) }) }
        
        XCTAssertEqual(["a.txt", "b.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["a.txt", "b.txt"], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.files.sorted() })
        
        XCTAssertEqual(3, try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.read([], name: "a.txt", { jr in jr[["a", "b"]]?.int }) } })
        XCTAssertEqual(4, try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.read([], name: "a.txt", { jr in jr[["a", "c"]]?.int }) } })
        XCTAssertEqual(2, try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.read([], name: "b.txt", { jr in jr[["a", "b"]]?.int }) } })
        
        try cbdb.write { writer in try clientB.write(writer: writer) { w in
            try w.createFile([], name: "c.txt")
            } }
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: clientB.revisionId, branch: clientB.branch, changes: clientB.changes) })
        try cbdb.write { writer in try clientB.commitChanges(writer: writer) }
        
        XCTAssertEqual(["a.txt", "b.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["a.txt", "b.txt", "c.txt"], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.files.sorted() })
        
        try cadb.write { writer in try clientA.applyChanges(writer: writer, revisions: sdb.read { reader in try server.update(reader: reader, revisionId: clientA.revisionId) }) }
        
        XCTAssertEqual(["a.txt", "b.txt", "c.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["a.txt", "b.txt", "c.txt"], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.files.sorted() })
        
        try cbdb.write { writer in try clientB.write(writer: writer) { w in
            try w.deleteFile([], name: "c.txt")
            } }
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: clientB.revisionId, branch: clientB.branch, changes: clientB.changes) })
        try cbdb.write { writer in try clientB.commitChanges(writer: writer) }
        
        XCTAssertEqual(["a.txt", "b.txt", "c.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["a.txt", "b.txt"], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.files.sorted() })
        
        try cadb.write { writer in try clientA.applyChanges(writer: writer, revisions: sdb.read { reader in try server.update(reader: reader, revisionId: clientA.revisionId) }) }
        
        XCTAssertEqual(["a.txt", "b.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["a.txt", "b.txt"], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.files.sorted() })
        
        try cbdb.write { writer in try clientB.write(writer: writer) { w in
            try w.deleteFile([], name: "a.txt")
            try w.renameFile([], oldName: "b.txt", newName: "z.txt")
            } }
        XCTAssertTrue(try sdb.write { writer in try server.commit(writer: writer, revisionId: clientB.revisionId, branch: clientB.branch, changes: clientB.changes) })
        try cbdb.write { writer in try clientB.commitChanges(writer: writer) }
        
        XCTAssertEqual(["a.txt", "b.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["z.txt"], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.files.sorted() })
        
        try cadb.write { writer in try clientA.applyChanges(writer: writer, revisions: sdb.read { reader in try server.update(reader: reader, revisionId: clientA.revisionId) }) }
        try ccdb.write { writer in try clientC.applyChanges(writer: writer, revisions: sdb.read { reader in try server.update(reader: reader, revisionId: clientC.revisionId) }) }
        
        XCTAssertEqual(["z.txt"], try cadb.read { reader in try clientA.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["z.txt"], try cbdb.read { reader in try clientB.read(reader: reader) { r in try r.list() }.files.sorted() })
        XCTAssertEqual(["z.txt"], try ccdb.read { reader in try clientC.read(reader: reader) { r in try r.list() }.files.sorted() })
    }
    
}
