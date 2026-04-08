pragma Singleton
import QtQuick
import QtQuick.LocalStorage
import ".."

QtObject {
    id: db

    property var _db: null
    property bool ready: false

    Component.onCompleted: {
        _db = LocalStorage.openDatabaseSync("skwd-wall", "1.0", "skwd-wall cache", 5000000)
        try { _db.transaction(function(tx) { tx.executeSql("PRAGMA busy_timeout=5000") }) } catch(e) {}
        _db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY,tags TEXT,colors TEXT,matugen TEXT,favourite INTEGER DEFAULT 0,type TEXT,name TEXT,thumb TEXT,thumb_sm TEXT,video_file TEXT,we_id TEXT,mtime INTEGER,hue INTEGER DEFAULT 99,sat INTEGER DEFAULT 0,analyzed_by TEXT,filesize INTEGER,width INTEGER,height INTEGER)")
            tx.executeSql("CREATE INDEX IF NOT EXISTS idx_meta_favourite ON meta(favourite)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS image_optimize(src TEXT PRIMARY KEY,dest TEXT NOT NULL,preset TEXT NOT NULL,format TEXT,width INTEGER,height INTEGER,orig_size INTEGER,new_size INTEGER,optimized_at INTEGER)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS video_convert(src TEXT PRIMARY KEY,dest TEXT NOT NULL,preset TEXT NOT NULL,codec TEXT,width INTEGER,height INTEGER,orig_size INTEGER,new_size INTEGER,converted_at INTEGER)")
            tx.executeSql("CREATE TABLE IF NOT EXISTS state(key TEXT PRIMARY KEY, val TEXT)")
        })
        ready = true
    }

    function exec(sql) {
        _db.transaction(function(tx) { tx.executeSql(sql) })
    }

    function execBatch(sqlArray) {
        _db.transaction(function(tx) {
            for (var i = 0; i < sqlArray.length; i++)
                tx.executeSql(sqlArray[i])
        })
    }

    function query(sql) {
        var results = []
        _db.readTransaction(function(tx) {
            var rs = tx.executeSql(sql)
            for (var i = 0; i < rs.rows.length; i++)
                results.push(rs.rows.item(i))
        })
        return results
    }

    function sqlStr(s) {
        return "'" + String(s).replace(/'/g, "''") + "'"
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function cacheKey(path) {
        var filename = path.split("/").pop()
        var dot = filename.lastIndexOf(".")
        return dot > 0 ? filename.substring(0, dot) : filename
    }
}
