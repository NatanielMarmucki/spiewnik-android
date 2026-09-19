# Fixtures: the old iOS app's Core Data database

Schema: `docs/SCHEMA-ZMYSONG.md`.

| File | Origin | Contents |
|---|---|---|
| `ios_with_data.sqlite` (+ `-wal`, `-shm`) | database from the simulator, **one row changed by hand** (below) | 2000 songs, favorites 5 and 12, one user song |
| `ios_fresh.sqlite` (+ `-wal`, `-shm`) | database from the simulator right after install | 2000 songs, no favorites and no user songs |
| `ios_no_mysong.sqlite` | template file from the iOS repository | 2000 songs, no `ZMYSONG` table |

The simulator databases are in WAL mode. The empty `-wal` files and the prepared `-shm` files are in the repository
on purpose, so the tests run on the same set of files as on a device.

## The manual change in `ios_with_data.sqlite`

The original row from the simulator had test gibberish. It was replaced; the rest of the data is unchanged
(a full dump of the database before and after the change differs only in this row):

```sql
-- before: INSERT INTO ZMYSONG VALUES(1,1,1,'Sdfdsfdsfdsfsdfds','Dsfdsfds');
UPDATE ZMYSONG SET ZTITLE = 'Pieśń poranna', ZCONTENT = '1. Dziękuję Ci, Panie, za nowy dzień.' WHERE Z_PK = 1;
```

The change was made in `sqlite3` with `.filectrl persist_wal 1`, so that closing the connection would not delete
the `-wal` and `-shm` files. After the change: `PRAGMA journal_mode` = `wal`, `PRAGMA integrity_check` = `ok`.

The tests never modify these files; synthetic cases are created on copies (`test/core_data_reader_test.dart`).
