// © BCE Labs, 2024. All rights reserved.
//

import Foundation
import SQLite3

protocol DatabaseCodable: Codable {}

extension String: DatabaseCodable {}
extension Int: DatabaseCodable {}
extension Double: DatabaseCodable {}
extension Data: DatabaseCodable {}

extension Optional: DatabaseCodable where Wrapped: DatabaseCodable {}

struct AnyDatabaseCodable: Codable {
    private let value: DatabaseCodable
    
    init(_ value: DatabaseCodable) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let value = try? container.decode(Int.self) {
            self.value = value
        } else if let value = try? container.decode(Double.self) {
            self.value = value
        } else if let value = try? container.decode(String.self) {
            self.value = value
        } else if let value = try? container.decode(Data.self) {
            self.value = value
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode DatabaseCodable")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

enum DatabaseError: Error {
    case failed(Int, String)
    case failedToEncodeObject(Codable)
    case databaseNotInitialized
    case invalidObject(Codable)
}

extension DatabaseError: LocalizedError {
    
    var errorDescription: String? {
        switch self {
        case .failed(let resultCode, let message):
            return "❌ Code: \(resultCode) | \(message)"
        case .databaseNotInitialized:
            return "❌ Database not initialized"
        case .failedToEncodeObject(let object):
            return "❌ Failed to encode: \(object)"
        case .invalidObject(let object):
            return "❌ Invalid: \(object)"
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
        _ parameter: Any?,
        _ db: Connection
    ) -> ResultCode
    
    typealias MultiParameterBinder<T> = (
        _ statement: Statement,
        _ parameters: T,
        _ db: Connection,
        _ singleParameterBinder: SingleParameterBinder,
        _ resultCodeHandler: ResultCodeHandler
    ) throws -> Void
    
    typealias StatementPreparer = (
        _ sql: String,
        _ db: Connection,
        _ resultCodeHandler: ResultCodeHandler
    ) throws -> Statement
    
    typealias RowResultHandler<T: Codable> = (
        _ row: T
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
    
    typealias QueryExecutor<T: Codable> = (
        _ query: String,
        _ dataType: T?,
        _ db: Connection,
        _ singleParameterBinder: @escaping SingleParameterBinder,
        _ multiParameterBinder: @escaping MultiParameterBinder<T>,
        _ statementPreparer: @escaping StatementPreparer,
        _ columnNameExtractor: @escaping ColumnNameExtractor,
        _ rowValueExtractor: @escaping RowValueExtractor,
        _ rowResultHandler: RowResultHandler<T>?,
        _ resultCountHandler: ResultCountHandler?,
        _ resultCodeHandler: @escaping ResultCodeHandler
    ) throws -> Void
    
    static var openHandler: OpenHandler = { location, db in
        return sqlite3_open(location, &db)
    }
    
    static var resultCodeHandler: ResultCodeHandler = { resultCode, db in
        switch resultCode {
        case .ok, .done, .row:
            break
        default:
            let message = String(cString: sqlite3_errmsg(db))
            throw DatabaseError.failed(Int(resultCode), message)
        }
    }
    
    static var statementPreparer: StatementPreparer = { sql, db, resultCodeHandler in
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v3(db, sql, -1, 0, &statement, nil)
        try resultCodeHandler(result, db)
        return Statement(pointer: statement)
    }
    
    static var singleParameterBinder: SingleParameterBinder = { statement, index, parameter, db in
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
            return .format
        }
    }
    
    static func dataTypeBinder<T: Codable>(
        statement: Statement,
        dataType: T,
        db: Connection,
        singleParameterBinder: SingleParameterBinder,
        resultCodeHandler: ResultCodeHandler
    ) throws {
        // 1. We could extract this... but this is for a codable object binder.
        // We also need to have a binder for a single object, or array of objects, or dictionary of objects...
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(dataType)
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        
        if let dictionary = jsonObject as? [String: Any?] {
            for (index, parameter) in dictionary.enumerated() {
                let i = Int32(index + 1)
                let result = singleParameterBinder(statement, i, parameter.value, db)
                try resultCodeHandler(result, db)
            }
        } else if let array = jsonObject as? [Any?] {
            for (index, value) in array.enumerated() {
                let i = Int32(index + 1)
                let result = singleParameterBinder(statement, i, value, db)
                try resultCodeHandler(result, db)
            }
        } else {
            throw DatabaseError.invalidObject(dataType)
        }
    }
    
    static var columnNameExtractor: ColumnNameExtractor = { statement, index in
        String(cString: sqlite3_column_name(statement.pointer, Int32(index)))
    }
    
    static var rowValueExtractor: RowValueExtractor = { statement, index in
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
    
    static func queryExecutor<T: Codable>(
        query: String,
        dataType: T? = nil,
        db: Connection,
        singleParameterBinder: @escaping SingleParameterBinder,
        multiParameterBinder: @escaping MultiParameterBinder<T>,
        statementPreparer: @escaping StatementPreparer,
        columnNameExtractor: @escaping ColumnNameExtractor,
        rowValueExtractor: @escaping RowValueExtractor,
        rowResultHandler: RowResultHandler<T>?,
        resultCountHandler: ResultCountHandler?,
        resultCodeHandler: @escaping ResultCodeHandler
    ) throws {
        let statement = try statementPreparer(query, db, resultCodeHandler)
        
        // If there are no provided parameters, we don't need to bind anything to the SQL statement
        if let dataType {
            try multiParameterBinder(statement, dataType, db, singleParameterBinder, resultCodeHandler)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
                let data = try JSONSerialization.data(withJSONObject: row)
                let decodedRow = try decoder.decode(T.self, from: data)
                rowResultHandler(decodedRow)
            }
            stepResult = sqlite3_step(statement.pointer)
        }
        
        try resultCodeHandler(stepResult, db)
        
        if let resultCountHandler {
            let resultCount = Int(sqlite3_changes(db))
            resultCountHandler(resultCount)
        }
    }
    
    static func run<T: Codable>(
        type: T.Type = T.self,
        location: String = .inMemory,
        query: String,
        dataType: T? = nil,
        resultHandler: RowResultHandler<T>? = nil,
        resultCountHandler: ResultCountHandler? = nil
    ) throws {
        try run(
            type: T.self,
            location: location,
            query: query,
            dataType: dataType,
            openHandler: self.openHandler,
            singleBinder: self.singleParameterBinder,
            multiBinder: self.dataTypeBinder,
            statementPreparer: self.statementPreparer,
            columnNameExtractor: self.columnNameExtractor,
            rowValueExtractor: self.rowValueExtractor,
            queryExecutor: self.queryExecutor,
            rowResultHandler: resultHandler,
            resultCountHandler: resultCountHandler,
            resultCodeHandler: self.resultCodeHandler)
    }
    
    static func run<T: Codable>(
        type: T.Type = T.self,
        location: String = .inMemory,
        query: String,
        dataType: T? = nil,
        openHandler: @escaping OpenHandler,
        singleBinder: @escaping SingleParameterBinder,
        multiBinder: @escaping MultiParameterBinder<T>,
        statementPreparer: @escaping StatementPreparer,
        columnNameExtractor: @escaping ColumnNameExtractor,
        rowValueExtractor: @escaping RowValueExtractor,
        queryExecutor: @escaping QueryExecutor<T>,
        rowResultHandler: RowResultHandler<T>? = nil,
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
            dataType,
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

enum Order: String {
    case asc = "ASC"
    case desc = "DESC"
}

func buildWithJoin(_ join: String) -> ([Query]) -> Query {
    return { queries in
        let sql: String = queries.map { $0.sql }.joined(separator: join)
        let parameters: [Any] = queries.reduce([], { $0 + $1.parameters })
        
        return .init(sql: sql, parameters: parameters)
    }
}

@resultBuilder
struct Query {
    var sql: String
    var parameters: [Any] = []
    
    static func buildBlock(_ queries: Query...) -> Query {
        buildWithJoin("\n")(queries)
    }
}

@resultBuilder
struct And {
    static func buildBlock(_ queries: Query...) -> Query {
        buildWithJoin(" AND ")(queries)
    }
}

@resultBuilder
struct Or {
    static func buildBlock(_ queries: Query...) -> Query {
        buildWithJoin(" OR ")(queries)
    }
}

@resultBuilder
struct Set {
    static func buildBlock(_ queries: Query...) -> Query {
        buildWithJoin(", ")(queries)
    }
}

@resultBuilder
struct Parameters {
    static func buildBlock(_ parameters: String...) -> String {
        let string: String = parameters.map { $0 }.joined(separator: ",\n    ")
        return "(\n    \(string)\n)"
    }
}

@resultBuilder
struct Values {
    static func buildBlock(_ values: Any...) -> Query {
        let string: String = values.map { _ in "?" }.joined(separator: ", ")
        return .init(sql: "(\(string))", parameters: values)
    }
}

@resultBuilder
struct OrderBy {
    var column: String
    var order: Order
    
    static func buildBlock(_ orderBys: OrderBy...) -> Query {
        let columnsString = orderBys
            .map { "\($0.column) \($0.order.rawValue)" }
            .joined(separator: ", ")
        return .init(sql: "ORDER BY \(columnsString)")
    }
}

@resultBuilder
struct Select {
    static func buildBlock(_ columns: String...) -> Query {
        let columnsString = columns.isEmpty ? "*" : columns.joined(separator: ", ")
        return .init(sql: "SELECT \(columnsString)", parameters: [])
    }
}

func insert(
    into table: String,
    @Parameters _ parameters: () -> String
) -> Query {
    .init(sql: "INSERT INTO \(table) \(parameters())")
}

func values_(
    @Values _ values: () -> Query
) -> Query {
    let valuesQuery = values()
    return .init(sql: "VALUES \(valuesQuery.sql)", parameters: valuesQuery.parameters)
}
    
func update(_ table: String) -> Query {
    .init(sql: "UPDATE \(table)", parameters: [])
}

func where_(@Query _ condition: () -> Query) -> Query {
    let whereClause = condition()
    return .init(sql: "WHERE \(whereClause.sql)", parameters: whereClause.parameters)
}

func create(
    table: String,
    @Parameters _ parameters: () -> String
) -> Query {
    .init(sql: "CREATE TABLE IF NOT EXISTS \(table) \(parameters())")
}

func and(@And _ statements: () -> Query) -> Query {
    statements()
}

func or(@Or _ statements: () -> Query) -> Query {
    statements()
}

func orderBy(@OrderBy _ columns: () -> Query) -> Query {
    columns()
}

func select(@Select _ columns: () -> Query) -> Query {
    columns()
}

func from(_ table: String, _ alias: String? = nil) -> Query {
    var sql = "FROM \(table)"
    if let alias {
        sql += " \(alias)"
    }
    return .init(sql: sql)
}

func set(@Set _ values: () -> Query) -> Query {
    let values = values()
    return .init(
        sql: "SET \(values.sql)",
        parameters: values.parameters)
}

func query(@Query _ query: () -> Query) -> Query {
    var query = query()
    query.sql += ";"
    return query
}

extension String {
    
    func equal(to value: Any) -> Query {
        .init(sql: "\(self) = ?", parameters: [value])
    }
    
    func greater(than value: Any) -> Query {
        .init(sql: "\(self) > ?", parameters: [value])
    }

    func less(than value: Any) -> Query {
        .init(sql: "\(self) < ?", parameters: [value])
    }
    
    var ascending: OrderBy {
        .init(column: self, order: .asc)
    }
    
    var descending: OrderBy {
        .init(column: self, order: .desc)
    }
}

/*

 // MARK: - Usage Example

 // SELECT query
 let selectUsers = select("name", "age")
     => from("users")
     => where_(and(
         { greaterThan("age", 30) },
         { equal("name", "John") }
     ))
     => orderBy("age", direction: .descending)
     => limit(10)

 let selectResult = selectUsers(("", []))
 print("Select Query:", selectResult.sql)
 print("Select Parameters:", selectResult.parameters)

 // INSERT query
 let insertUser = insert(into: "users")
     => values(["name": "Alice", "age": 28, "email": "alice@example.com"])

 let insertResult = insertUser(("", []))
 print("Insert Query:", insertResult.sql)
 print("Insert Parameters:", insertResult.parameters)

 // UPDATE query
 let updateUser = update("users")
     => set(["age": 29, "email": "newemail@example.com"])
     => where_({ equal("name", "Alice") })

 let updateResult = updateUser(("", []))
 print("Update Query:", updateResult.sql)
 print("Update Parameters:", updateResult.parameters)

 // DELETE query
 let deleteUsers = delete(from: "users")
     => where_({ lessThan("age", 18) })

 let deleteResult = deleteUsers(("", []))
 print("Delete Query:", deleteResult.sql)
 print("Delete Parameters:", deleteResult.parameters)

 // Complex WHERE condition with OR
 let complexSelect = select("*")
     => from("users")
     => where_(or(
         { greaterThan("age", 30) },
         and(
             { equal("status", "VIP") },
             { greaterThan("purchase_amount", 1000) }
         )
     ))

 let complexResult = complexSelect(("", []))
 print("Complex Select Query:", complexResult.sql)
 print("Complex Select Parameters:", complexResult.parameters)
 */
