// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SQLite3

enum DatabaseError: Error {
    case failed(Int, String)
    case databaseNotInitialized
}

extension DatabaseError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .failed(let resultCode, let message):
            return "❌ Code: \(resultCode) | \(message)"
        case .databaseNotInitialized:
            return "❌ Database not initialized"
        }
    }
}

typealias ResultCode = Int32

/// Result codes
extension ResultCode {
    static var ok: Int32 { SQLITE_OK }
    static var `internal`: Int32 { SQLITE_INTERNAL }
    static var perm: Int32 { SQLITE_PERM }
    static var abort: Int32 { SQLITE_ABORT }
    static var busy: Int32 { SQLITE_BUSY }
    static var locked: Int32 { SQLITE_LOCKED }
    static var noMem: Int32 { SQLITE_NOMEM }
    static var readOnly: Int32 { SQLITE_READONLY }
    static var interrupt: Int32 { SQLITE_INTERRUPT }
    static var ioErr: Int32 { SQLITE_IOERR }
    static var corrupt: Int32 { SQLITE_CORRUPT }
    static var notFound: Int32 { SQLITE_NOTFOUND }
    static var full: Int32 { SQLITE_FULL }
    static var cantOpen: Int32 { SQLITE_CANTOPEN }
    static var `protocol`: Int32 { SQLITE_PROTOCOL }
    static var empty: Int32 { SQLITE_EMPTY }
    static var schema: Int32 { SQLITE_SCHEMA }
    static var tooBig: Int32 { SQLITE_TOOBIG }
    static var constraint: Int32 { SQLITE_CONSTRAINT }
    static var mismatch: Int32 { SQLITE_MISMATCH }
    static var misuse: Int32 { SQLITE_MISUSE }
    static var noLFS: Int32 { SQLITE_NOLFS }
    static var auth: Int32 { SQLITE_AUTH }
    static var format: Int32 { SQLITE_FORMAT }
    static var range: Int32 { SQLITE_RANGE }
    static var notATB: Int32 { SQLITE_NOTADB }
    static var notice: Int32 { SQLITE_NOTICE }
    static var warning: Int32 { SQLITE_WARNING }
    static var row: Int32 { SQLITE_ROW }
    static var done: Int32 { SQLITE_DONE }
}

extension String {
    static var inMemory: String { ":memory:" }
    static func onDisk(_ path: String) -> String { path }
}

struct Database {
    
    class Statement {
        let pointer: OpaquePointer?
        
        init(pointer: OpaquePointer?) {
            self.pointer = pointer
        }
        
        deinit {
            sqlite3_finalize(pointer)
        }
    }
    
    typealias Connection = OpaquePointer
    
    typealias OpenHandler = (
        _ location: String,
        _ db: inout Connection?
    ) -> ResultCode
    
    typealias ResultCodeHandler = (
        _ resultCode: ResultCode,
        _ db: Connection
    ) throws -> Void
    
    typealias SingleParameterBinder = (
        _ statement: Statement,
        _ index: Int32,
        _ parameter: Any,
        _ db: Connection
    ) -> ResultCode
    
    typealias MultiParameterBinder = (
        _ statement: Statement,
        _ parameters: [Any],
        _ db: Connection,
        _ singleParameterBinder: SingleParameterBinder,
        _ resultCodeHandler: ResultCodeHandler
    ) throws -> Void
    
    typealias StatementPreparer = (
        _ sql: String,
        _ db: Connection,
        _ resultCodeHandler: ResultCodeHandler
    ) throws -> Statement
    
    typealias RowResultHandler = (
        _ row: [String: Any?]
    ) -> Void
    
    typealias RowValueExtractor = (
        _ statement: Statement,
        _ index: Int
    ) -> Any?
    
    typealias ColumnNameExtractor = (
        _ statement: Statement,
        _ index: Int
    ) -> String
    
    typealias ResultCountHandler = (
        _ count: Int
    ) -> Void
    
    typealias QueryExecutor = (
        _ query: String,
        _ parameters: [Any],
        _ db: Connection,
        _ singleParameterBinder: @escaping SingleParameterBinder,
        _ multiParameterBinder: @escaping MultiParameterBinder,
        _ statementPreparer: @escaping StatementPreparer,
        _ columnNameExtractor: @escaping ColumnNameExtractor,
        _ rowParser: @escaping RowValueExtractor,
        _ rowResultHandler: RowResultHandler?,
        _ resultCountHandler: ResultCountHandler?,
        _ resultCodeHandler: @escaping ResultCodeHandler
    ) throws -> Void
    
    var openHandler: OpenHandler = { location, db in
        return sqlite3_open(location, &db)
    }
    
    var resultCodeHandler: ResultCodeHandler = { resultCode, db in
        switch resultCode {
        case .ok, .done, .row:
            break
        default:
            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.failed(Int(resultCode), message)
        }
    }
    
    var statementPreparer: StatementPreparer = { sql, db, resultCodeHandler in
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v3(db, sql, -1, 0, &statement, nil)
        try resultCodeHandler(result, db)
        return Statement(pointer: statement)
    }
    
    var singleParameterBinder: SingleParameterBinder = { statement, index, parameter, db in
        let index = Int32(index)
        switch parameter {
        case let value as Int:
            return sqlite3_bind_int64(statement.pointer, index, Int64(value))
        case let value as Double:
            return sqlite3_bind_double(statement.pointer, index, value)
        case let value as String:
            return sqlite3_bind_text(statement.pointer, index, (value as NSString).utf8String, -1, nil)
        case let value as UUID:
            return sqlite3_bind_text(statement.pointer, index, (value.uuidString as NSString).utf8String, -1, nil)
        case is NSNull:
            return sqlite3_bind_null(statement.pointer, index)
        default:
            return .mismatch
        }
    }
    
    var multiParameterBinder: MultiParameterBinder = { statement, parameters, db, singleParameterBinder, resultCodeHandler in
        for (index, parameter) in parameters.enumerated() {
            let i = Int32(index + 1)
            let result = singleParameterBinder(statement, i, parameter, db)
            try resultCodeHandler(result, db)
        }
    }
    
    var columnNameExtractor: ColumnNameExtractor = { statement, index in
        String(cString: sqlite3_column_name(statement.pointer, Int32(index)))
    }
    
    var rowValueExtractor: RowValueExtractor = { statement, index in
        let i = Int32(index)
        
        switch sqlite3_column_type(statement.pointer, i) {
        case SQLITE_INTEGER:
            return sqlite3_column_int64(statement.pointer, i)
        case SQLITE_FLOAT:
            return sqlite3_column_double(statement.pointer, i)
        case SQLITE_NULL:
            return nil
        default:
            return String(cString: sqlite3_column_text(statement.pointer, i))
        }
    }
    
    var queryExecutor: QueryExecutor = {
        query,
        parameters,
        db,
        singleBinder,
        multiBinder,
        statementPreparer,
        columnNameExtractor,
        rowValueExtractor,
        rowResultHandler,
        resultCountHandler,
        resultCodeHandler in
        
        let statement = try statementPreparer(query, db, resultCodeHandler)
        try multiBinder(statement, parameters, db, singleBinder, resultCodeHandler)
        
        let columnCount = sqlite3_column_count(statement.pointer)
        var stepResult = sqlite3_step(statement.pointer)
        
        while stepResult == .row {
            if let rowResultHandler {
                var row: [String: Any?] = [:]
                for i in 0 ..< columnCount {
                    let index = Int(i)
                    let columnName = columnNameExtractor(statement, index)
                    let value = rowValueExtractor(statement, index)
                    row[columnName] = value
                }
                rowResultHandler(row)
            }
            stepResult = sqlite3_step(statement.pointer)
        }
        
        try resultCodeHandler(stepResult, db)
        
        if let resultCountHandler {
            let resultCount = Int(sqlite3_changes(db))
            resultCountHandler(resultCount)
        }
    }
    
    func run(
        location: String = .inMemory,
        query: String,
        parameters: [Any] = [],
        resultHandler: RowResultHandler? = nil,
        resultCountHandler: ResultCountHandler? = nil
    ) throws {
        try run(
            location: location,
            query: query,
            parameters: parameters,
            openHandler: self.openHandler,
            singleBinder: self.singleParameterBinder,
            multiBinder: self.multiParameterBinder,
            statementPreparer: self.statementPreparer,
            columnNameExtractor: self.columnNameExtractor,
            rowValueExtractor: self.rowValueExtractor,
            queryExecutor: self.queryExecutor,
            rowResultHandler: resultHandler,
            resultCountHandler: resultCountHandler,
            resultCodeHandler: self.resultCodeHandler)
    }
    
    func run(
        location: String = .inMemory,
        query: String,
        parameters: [Any],
        openHandler: @escaping OpenHandler,
        singleBinder: @escaping SingleParameterBinder,
        multiBinder: @escaping MultiParameterBinder,
        statementPreparer: @escaping StatementPreparer,
        columnNameExtractor: @escaping ColumnNameExtractor,
        rowValueExtractor: @escaping RowValueExtractor,
        queryExecutor: @escaping QueryExecutor,
        rowResultHandler: RowResultHandler? = nil,
        resultCountHandler: ResultCountHandler? = nil,
        resultCodeHandler: @escaping ResultCodeHandler
    ) throws {
        var db: Connection?
        defer { sqlite3_close(db) }
        
        let result = openHandler(location, &db)
        guard let db else {
            throw DatabaseError.databaseNotInitialized
        }
        
        try resultCodeHandler(result, db)
        
        try queryExecutor(
            query,
            parameters,
            db,
            singleBinder,
            multiBinder,
            statementPreparer,
            columnNameExtractor,
            rowValueExtractor,
            rowResultHandler,
            resultCountHandler,
            resultCodeHandler)
    }
}
