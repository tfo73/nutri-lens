@echo off
dart scripts/increment_version.dart --minor
flutter build apk
