// © BCE Labs, 2024. All rights reserved.
//

import XCTest
import ComposableArchitecture

@testable import MusicX

final class DatabaseTests: XCTestCase {
    
    func test_createTable() throws {
        let database = Database()
        
        let query =
            """
            CREATE TABLE IF NOT EXISTS song (
                id TEXT PRIMARY KEY,
                song_name TEXT NOT NULL,
                artist_name TEXT NOT NULL,
                play_count INTEGER DEFAULT 0,
                track_duration REAL NOT NULL,
                song_url TEXT
            );
            """
        
        try database.run(
            location: .onDisk("/Users/me/Desktop/test.db"),
            query: query,
            resultCountHandler: { count in
                XCTAssertEqual(count, 0)
            })
    }
    
    func test_insertRow() throws {
        let database = Database()
        let query =
        """
        INSERT INTO song (id, song_name, artist_name, play_count, track_duration, song_url)
        VALUES ( ?, ?, ?, ?, ?, ? );
        """
        
        try database.run(
            location: .onDisk("/Users/me/Desktop/test.db"),
            query: query,
            parameters: [
                UUID(),
                "Imagine",
                "John Lennon",
                14,
                183.5,
                "https://example.com/imagine.mp3"
            ],
            resultHandler: { row in
                XCTAssertEqual(row.count, 0)
            },
            resultCountHandler: { count in
                XCTAssertEqual(count, 1)
            })
    }
    
    func test_query() throws {
        let database = Database()
        let query =
        """
        SELECT *
        FROM song
        WHERE artist_name = ?;
        """
        
        try database.run(
            location: .onDisk("/Users/me/Desktop/test.db"),
            query: query,
            parameters: [
                "John Lennon"
            ],
            resultHandler: { row in
                switch row["play_count"] {
                case let v as Int64:
                    XCTAssertEqual(v, 14)
                default:
                    XCTFail("Failed to extract the play_count")
                }
            })
    }
}

/*
 
 Pain #1:
 
 The result handler doesn't encode into a type. We should encode to a type!!!
 
 Pain #2:
 
 Building queries is painful.
 
 Pain #3:
 
 Inserting data should decode from a type
 
 */
