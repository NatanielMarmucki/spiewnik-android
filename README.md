# Spiewnik

## Testy

Testy korzystające z bazy ObjectBox potrzebują natywnej biblioteki ObjectBox w katalogu `lib/`
(`libobjectbox.dylib` na macOS, `libobjectbox.so` na Linuksie). Biblioteka nie jest w repozytorium,
więc po sklonowaniu i na CI trzeba ją najpierw pobrać:

```sh
tools/fetch_objectbox_lib.sh
flutter test
```

Skrypt pobiera `objectbox-c` w wersji zgodnej z pakietem `objectbox` z `pubspec.lock` i sprawdza sumę
kontrolną archiwum. Obsługuje macOS oraz Linux x64 i aarch64. Po aktualizacji pakietu `objectbox` skrypt
przerwie działanie i trzeba w nim podbić wersję biblioteki oraz sumy kontrolne.
