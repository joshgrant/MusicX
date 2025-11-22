// © BCE Labs, 2024. All rights reserved.
//

import XCTest
import ComposableArchitecture

@testable import MusicX

final class DatabaseTests: XCTestCase {
    
    struct Song: Codable {
        var id: UUID
        var songName: String
        var artistName: String
        var playCount: Int
        var trackDuration: Double
        var songUrl: String
    }
    
    func test_createTable() throws {
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
        
        try Database.run(
            type: Song.self,
            location: .onDisk("/Users/me/Desktop/test.db"),
            query: query,
            resultCountHandler: { count in
                XCTAssertEqual(count, 0)
            })
    }
    
    func test_createTable_query() throws {
        let query = query {
            create(table: "song") {
                "id TEXT PRIMARY KEY"
                "song_name TEXT NOT NULL"
                "artist_name TEXT NOT NULL"
                "play_count INTEGER DEFAULT 0"
                "track_duration REAL NOT NULL"
                "song_url TEXT"
            }
        }
        
        XCTAssertEqual(query.sql,
        """
        CREATE TABLE IF NOT EXISTS song (
            id TEXT PRIMARY KEY,
            song_name TEXT NOT NULL,
            artist_name TEXT NOT NULL,
            play_count INTEGER DEFAULT 0,
            track_duration REAL NOT NULL,
            song_url TEXT
        );
        """)
    }
    
    func test_insertRow() throws {
        let query =
        """
        INSERT INTO song (id, song_name, artist_name, play_count, track_duration, song_url)
        VALUES ( ?, ?, ?, ?, ?, ? );
        """
        
        try Database.run(
            location: .onDisk("/Users/me/Desktop/test.db"),
            query: query,
            dataType: Song(
                id: .init(),
                songName: "Imagine",
                artistName: "John Lennon",
                playCount: 14,
                trackDuration: 183.5,
                songUrl: "https://example.com/imagine.mp3"),
            resultHandler: { song in
                XCTAssertEqual(song.playCount, 14)
            },
            resultCountHandler: { count in
                XCTAssertEqual(count, 1)
            })
    }
    
    func test_query() throws {
        let query =
        """
        SELECT *
        FROM song
        WHERE artist_name = ?;
        """
        
        try Database.run(
            type: [String: AnyDatabaseCodable].self,
            location: .onDisk("/Users/me/Desktop/test.db"),
            query: query,
            resultHandler: { row in
                print(row)
            })
    }
    
    func test_buildQuery() {
        let result = query {
            update("songs")
            set {
                "artist_name".equal(to: "Poop")
                "play_count".equal(to: 0)
            }
            where_ {
                or {
                    "artist_name".equal(to: "John Lennon")
                    "play_count".greater(than: 5)
                }
            }
        }
        
        XCTAssertEqual(result.sql,
        """
        UPDATE songs
        SET artist_name = ?, play_count = ?
        WHERE artist_name = ? OR play_count > ?;
        """)
        
        XCTAssertEqual(result.parameters[0] as! String, "Poop")
        XCTAssertEqual(result.parameters[1] as! Int, 0)
        XCTAssertEqual(result.parameters[2] as! String, "John Lennon")
        XCTAssertEqual(result.parameters[3] as! Int, 5)
    }
    
    func test_selectQuery() {
        let query = query {
            select {}
            from("songs", "s")
            where_ {
                "artist_name".equal(to: "John Lennon")
            }
            orderBy {
                "artist_name".descending
                "play_count".ascending
            }
        }
        
        XCTAssertEqual(query.sql,
        """
        SELECT *
        FROM songs s
        WHERE artist_name = ?
        ORDER BY artist_name DESC, play_count ASC;
        """)
    }
    
    func test_insert() {
        let query = query {
            insert(into: "songs") {
                "artist_name"
                "play_count"
            }
            values_ {
                "Johnny"
                0
            }
        }
        
        XCTAssertEqual(query.sql,
        """
        INSERT INTO songs (
            artist_name,
            play_count
        )
        VALUES (?, ?);
        """)
        
        XCTAssertEqual(query.parameters[0] as! String, "Johnny")
        XCTAssertEqual(query.parameters[1] as! Int, 0)
    }
}

/*
 
 SELECT
 a.artist_name,
 COUNT(DISTINCT s.song_id) AS total_songs,
 AVG(s.duration) AS avg_song_duration,
 SUM(s.play_count) AS total_plays,
 g.genre_name
 FROM
 artists a
 JOIN
 songs s ON a.artist_id = s.artist_id
 LEFT JOIN
 genres g ON s.genre_id = g.genre_id
 WHERE
 s.release_year BETWEEN 2010 AND 2020
 AND s.play_count > 1000
 GROUP BY
 a.artist_id, g.genre_id
 HAVING
 COUNT(DISTINCT s.song_id) > 5
 ORDER BY
 total_plays DESC, avg_song_duration ASC
 LIMIT 10;
 */

/*
 INSERT INTO playlist_songs (playlist_id, song_id, position)
 SELECT
     p.playlist_id,
     s.song_id,
     (SELECT COALESCE(MAX(position), 0) + 1
      FROM playlist_songs
      WHERE playlist_id = p.playlist_id)
 FROM
     playlists p
 CROSS JOIN
     songs s
 WHERE
     p.playlist_name = 'My Favorites'
     AND s.artist_id IN (
         SELECT artist_id
         FROM artists
         WHERE country = 'Canada'
     )
     AND s.release_year > 2020
     AND s.song_id NOT IN (
         SELECT song_id
         FROM playlist_songs
         WHERE playlist_id = p.playlist_id
     )
 LIMIT 10;
 */

/*
 
 Pain #1:
 
 The result handler doesn't encode into a type. We should encode to a type!!!
 (Actually, !!! NO !!! this sucks... we want types to be better...)
 
 Pain #2:
 
 Building queries is painful.
 
 Pain #3:
 
 Inserting data should decode from a type
 
 */
