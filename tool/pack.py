"""Pack the locally authored sources into a single tarball for upload."""
import os
import tarfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
APP = os.path.join(ROOT, 'UptimeKumaAPP')
OUT = os.path.join(ROOT, '.workbuddy', 'tools', 'src.tar.gz')

INCLUDE_DIRS = ['lib', 'assets', 'tool', 'test']
INCLUDE_FILES = [
    'pubspec.yaml',
    'README.md',
    'dart_test.yaml',
    'android/app/build.gradle.kts',
    'android/app/src/main/AndroidManifest.xml',
    'android/app/src/main/kotlin/com/zakoflare/uptime_kuma_app/MainActivity.kt',
    'android/app/src/main/kotlin/com/zakoflare/uptime_kuma_app/MonitorForegroundService.kt',
    'android/app/src/main/res/values/strings.xml',
]
for density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']:
    INCLUDE_DIRS.append('android/app/src/main/res/mipmap-' + density)
INCLUDE_DIRS.append('android/app/src/main/res/drawable')
INCLUDE_DIRS.append('android/app/src/main/res/drawable-nodpi')
INCLUDE_DIRS.append('android/app/src/main/res/mipmap-anydpi-v26')
for name, ext in [('chime', 'wav'), ('pulse', 'wav'), ('radar', 'wav'),
                  ('marimba', 'wav'), ('siren', 'wav'), ('ice', 'mp3')]:
    INCLUDE_FILES.append('android/app/src/main/res/raw/alert_%s.%s' % (name, ext))

SKIP_EXT = {'.iml', '.lock'}


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with tarfile.open(OUT, 'w:gz') as tar:
        for d in INCLUDE_DIRS:
            full = os.path.join(APP, d)
            for dirpath, _, files in os.walk(full):
                for f in files:
                    if os.path.splitext(f)[1] in SKIP_EXT:
                        continue
                    path = os.path.join(dirpath, f)
                    tar.add(path, arcname=os.path.relpath(path, APP))
        for f in INCLUDE_FILES:
            path = os.path.join(APP, f)
            if not os.path.exists(path):
                print('MISSING', f)
                continue
            tar.add(path, arcname=os.path.relpath(path, APP))
    print(OUT, round(os.path.getsize(OUT) / 1024 / 1024, 2), 'MB')


if __name__ == '__main__':
    main()
