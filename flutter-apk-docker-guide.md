# Build a Flutter APK with Docker (No Android Studio)

A reusable guide for building a Flutter Android APK inside Docker without installing Android Studio, Android SDK, JDK, or Gradle on the host machine.

## 1. Prerequisites

You only need:

- Docker Desktop
- Your Flutter project
- A `Dockerfile`
- A `.dockerignore`

You do **not** need:

- Android Studio
- Android SDK installed on Windows
- JDK installed on Windows
- Gradle installed on Windows

---

## 2. Create a `.dockerignore`

Create `.dockerignore` in the root of the Flutter project, next to the `Dockerfile`.

```text
.git
.gitignore
.dart_tool
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache
build
android/.gradle
android/.idea
android/local.properties
.idea
.vscode
*.iml
```

### Why?

Docker sends the project directory as the **build context**. The `.dockerignore` prevents unnecessary files and generated folders from being sent to Docker.

This makes the build smaller and faster.

---

## 3. Create the `Dockerfile`

Create a file named exactly:

```text
Dockerfile
```

Use:

```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
```

### What this does

- `FROM` → uses an image containing Flutter and the Android build environment.
- `WORKDIR /app` → sets the working directory inside the container.
- `COPY pubspec.yaml pubspec.lock ./` → copies dependency files first.
- `RUN flutter pub get` → installs Flutter dependencies.
- `COPY . .` → copies the rest of the project.

Copying the dependency files separately allows Docker to cache `flutter pub get`. If you only change Dart code, Docker can reuse that layer.

---

## 4. Pull the Flutter Docker image

Before building your own image, pull the Flutter image:

```bash
docker pull ghcr.io/cirruslabs/flutter:stable
```

This image can be large, so the first download may take some time.

You can check that it was downloaded with:

```bash
docker images
```

---

## 5. Build your Docker image

Open a terminal in the Flutter project's root directory — the directory containing `Dockerfile`.

Run:

```bash
docker build -t my-flutter-app .
```

### Important

The `.` means:

> Use the current directory as the Docker build context.

If Docker reports:

```text
ERROR: failed to solve: error from sender: context canceled
```

try:

1. Make sure Docker Desktop is running.
2. Make sure `.dockerignore` exists.
3. Run the image pull again:

```bash
docker pull ghcr.io/cirruslabs/flutter:stable
```

4. Retry:

```bash
docker build -t my-flutter-app .
```

---

## 6. Build the APK

After the Docker image is built, run Flutter inside the container.

### PowerShell

```powershell
docker run --rm -v "${PWD}:/app" my-flutter-app flutter build apk --release
```

### Windows CMD

```cmd
docker run --rm -v "%cd%:/app" my-flutter-app flutter build apk --release
```

### What is happening?

The command:

```text
docker run
```

starts a container.

```text
--rm
```

automatically removes the container after the command finishes.

```text
-v "${PWD}:/app"
```

mounts your Windows project directory into `/app` inside the container.

```text
my-flutter-app
```

is the Docker image we built.

```text
flutter build apk --release
```

runs the Flutter APK build inside Docker.

---

## 7. Find the APK

After the build finishes, the APK will be created in your normal Flutter project:

```text
build/
└── app/
    └── outputs/
        └── flutter-apk/
            └── app-release.apk
```

On Windows:

```text
buildpp\outputslutter-apkpp-release.apk
```

The APK is on your Windows machine because the project directory was mounted into the container.

---

## 8. Complete project structure

Your project can look like:

```text
my_flutter_app/
│
├── android/
├── ios/
├── lib/
├── test/
├── pubspec.yaml
├── pubspec.lock
├── Dockerfile
├── .dockerignore
└── ...
```

---

## 9. Complete workflow to remember

For a new Flutter project:

### Step 1 — Create `.dockerignore`

```text
.git
.gitignore
.dart_tool
.flutter-plugins
.flutter-plugins-dependencies
.pub-cache
build
android/.gradle
android/.idea
android/local.properties
.idea
.vscode
*.iml
```

### Step 2 — Create `Dockerfile`

```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
```

### Step 3 — Pull the Flutter image

```bash
docker pull ghcr.io/cirruslabs/flutter:stable
```

### Step 4 — Build your Docker image

```bash
docker build -t my-flutter-app .
```

### Step 5 — Build the release APK

PowerShell:

```powershell
docker run --rm -v "${PWD}:/app" my-flutter-app flutter build apk --release
```

CMD:

```cmd
docker run --rm -v "%cd%:/app" my-flutter-app flutter build apk --release
```

### Step 6 — Get the APK

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 10. The idea behind the setup

Think of Docker as providing the Android build environment:

```text
Windows
│
├── VS Code
│   └── Develop Flutter application
│
└── Docker Desktop
    │
    └── Flutter Container
        ├── Flutter SDK
        ├── Android SDK
        ├── JDK
        ├── Gradle
        └── Build APK
              │
              ▼
        app-release.apk
```

So Android Studio is not required for the APK build.

---

## 11. Useful commands

Check Docker:

```bash
docker --version
```

Check available images:

```bash
docker images
```

Check running containers:

```bash
docker ps
```

Check all containers:

```bash
docker ps -a
```

Remove the image if needed:

```bash
docker rmi my-flutter-app
```

Rebuild without using Docker's cache:

```bash
docker build --no-cache -t my-flutter-app .
```

---

## 12. Development vs APK building

This setup is especially useful for **building APKs** and CI/CD.

You can still develop normally using VS Code:

```text
VS Code
   │
   └── Flutter project
          │
          └── Write/test code
                 │
                 ▼
             Docker
                 │
                 └── Build release APK
```

Docker is not necessarily the easiest way to run an Android emulator or use Flutter hot reload.

For normal development, use your preferred editor and emulator/device setup. Use Docker when you want a reproducible Android build environment without installing Android Studio.

---

## Quick cheat sheet

```bash
# 1. Pull Flutter image
docker pull ghcr.io/cirruslabs/flutter:stable

# 2. Build Docker image
docker build -t my-flutter-app .

# 3. Build APK (PowerShell)
docker run --rm -v "${PWD}:/app" my-flutter-app flutter build apk --release

# 4. APK location
build/app/outputs/flutter-apk/app-release.apk
```
