@echo off
setlocal
cd /d c:\Users\Dell\Projects\no_smoke
set APK_NAME=no_smoke-main-3d72f62-r10.apk
copy /Y build\app\outputs\flutter-apk\app-release.apk apk\%APK_NAME%
git add .
git add -f apk\%APK_NAME%
git commit -m "chore: release r10 icon and reason updates"
git push origin main
git log --oneline -n 2
git ls-remote origin refs/heads/main
echo APK_NAME=%APK_NAME%
endlocal
