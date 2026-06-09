#!/bin/bash
# Magma/OrcaSlicer Docker development helper
# All builds use Clang + lld (faster, less RAM than GCC)
# Run ./docker-dev.sh help for available commands

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCA_DIR="${SCRIPT_DIR}/orcaslicer"
IMAGE_NAME="orca-dev"
BUILD_DIR="build"

# Create config and cache directories if needed
mkdir -p "${SCRIPT_DIR}/.orcaslicer-config"
mkdir -p "${SCRIPT_DIR}/.orcaslicer-cache"

# Common docker run args (based on OrcaSlicer's scripts/DockerRun.sh)
DOCKER_ARGS=(
    --rm
    --net=host
    --ipc=host
    --privileged=true
    --user "$(id -u):$(id -g)"
    --group-add 44
    --group-add 109
    -e DISPLAY="$DISPLAY"
    -e HOME="$HOME"
    -e NO_AT_BRIDGE=1
    -e GSETTINGS_BACKEND=memory
    -e no_proxy="*"
    -e NO_PROXY="*"
    -e http_proxy=""
    -e https_proxy=""
    -e HTTP_PROXY=""
    -e HTTPS_PROXY=""
    -v /tmp/.X11-unix:/tmp/.X11-unix
    -v "$HOME:$HOME"
    -v "${ORCA_DIR}:/orcaslicer"
    -v "${SCRIPT_DIR}/.orcaslicer-config:$HOME/.config/OrcaSlicer"
    -v "${SCRIPT_DIR}/.orcaslicer-cache:$HOME/.cache"
    -w /orcaslicer
)

# Add -it only if we have a TTY
if [ -t 0 ]; then
    DOCKER_ARGS=(-it "${DOCKER_ARGS[@]}")
fi

# GPU passthrough for hardware OpenGL
if [ -e /dev/dri ]; then
    DOCKER_ARGS+=(--device /dev/dri)
fi

case "${1:-help}" in
    build-image)
        echo "Building Docker image..."
        docker build -t "$IMAGE_NAME" -f "${SCRIPT_DIR}/Dockerfile.dev" "${SCRIPT_DIR}"
        echo "Done! Next run: ./docker-dev.sh build-deps"
        ;;

    build-deps)
        echo "Building dependencies with Clang + lld (this takes 30-60 min)..."
        # -l = clang, -L = lld, -Wno-error prevents warnings from failing build
        docker run "${DOCKER_ARGS[@]}" --user root "$IMAGE_NAME" \
            bash -c "cd /orcaslicer && CXXFLAGS='-Wno-error' CFLAGS='-Wno-error' ./build_linux.sh -dlLr"
        echo "Done! Next: ./docker-dev.sh configure"
        ;;

    configure)
        echo "Configuring build (Release with Clang + lld)..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "cd /orcaslicer/${BUILD_DIR} && cmake \
                -DCMAKE_C_COMPILER=/usr/bin/clang \
                -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
                -DCMAKE_EXE_LINKER_FLAGS='-fuse-ld=lld' \
                -DCMAKE_SHARED_LINKER_FLAGS='-fuse-ld=lld' \
                -DCMAKE_BUILD_TYPE=Release \
                ."
        echo "Done! Now use: ./docker-dev.sh ninja"
        ;;

    configure-asan)
        echo "Configuring with AddressSanitizer + UBSan (Clang + lld)..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "cd /orcaslicer/${BUILD_DIR} && cmake \
                -DCMAKE_C_COMPILER=/usr/bin/clang \
                -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
                -DCMAKE_EXE_LINKER_FLAGS='-fuse-ld=lld -fsanitize=address,undefined' \
                -DCMAKE_SHARED_LINKER_FLAGS='-fuse-ld=lld' \
                -DCMAKE_BUILD_TYPE=RelWithDebInfo \
                -DSLIC3R_ASAN=ON \
                -DCMAKE_CXX_FLAGS='-g -fno-omit-frame-pointer -fsanitize=address,undefined -DNDEBUG' \
                -DCMAKE_C_FLAGS='-g -fno-omit-frame-pointer -fsanitize=address,undefined -DNDEBUG' \
                ."
        echo "Done! Now use: ./docker-dev.sh ninja"
        echo "Run with: ./docker-dev.sh run-asan"
        ;;

    configure-tsan)
        echo "Configuring with ThreadSanitizer (Clang + lld)..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "cd /orcaslicer/${BUILD_DIR} && cmake \
                -DCMAKE_C_COMPILER=/usr/bin/clang \
                -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
                -DCMAKE_EXE_LINKER_FLAGS='-fuse-ld=lld -fsanitize=thread' \
                -DCMAKE_SHARED_LINKER_FLAGS='-fuse-ld=lld' \
                -DCMAKE_BUILD_TYPE=RelWithDebInfo \
                -DCMAKE_CXX_FLAGS='-g -fno-omit-frame-pointer -fsanitize=thread -DNDEBUG' \
                -DCMAKE_C_FLAGS='-g -fno-omit-frame-pointer -fsanitize=thread -DNDEBUG' \
                ."
        echo "Done! Now use: ./docker-dev.sh ninja"
        ;;

    ninja)
        echo "Building OrcaSlicer (Release)..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "cd /orcaslicer/${BUILD_DIR} && ninja -f build-Release.ninja OrcaSlicer"
        ;;

    ninja-reldbg)
        echo "Building OrcaSlicer (RelWithDebInfo)..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "cd /orcaslicer/${BUILD_DIR} && ninja -f build-RelWithDebInfo.ninja OrcaSlicer"
        ;;

    ninja-debug)
        echo "Building OrcaSlicer (Debug)..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "cd /orcaslicer/${BUILD_DIR} && ninja -f build-Debug.ninja OrcaSlicer"
        ;;

    test)
        echo "Running tests..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "cd /orcaslicer/${BUILD_DIR} && ninja -f build-Release.ninja test"
        ;;

    run)
        echo "Running OrcaSlicer (Release)..."
        xhost +local:docker 2>/dev/null || true
        docker run "${DOCKER_ARGS[@]}" \
            -e GDK_BACKEND=x11 \
            "$IMAGE_NAME" \
            /orcaslicer/${BUILD_DIR}/src/Release/orca-slicer
        ;;

    run-debug)
        echo "Running OrcaSlicer (Debug)..."
        xhost +local:docker 2>/dev/null || true
        docker run "${DOCKER_ARGS[@]}" \
            -e GDK_BACKEND=x11 \
            "$IMAGE_NAME" \
            /orcaslicer/${BUILD_DIR}/src/Debug/orca-slicer
        ;;

    run-gdb)
        echo "Running OrcaSlicer under GDB (RelWithDebInfo)..."
        xhost +local:docker 2>/dev/null || true
        docker run "${DOCKER_ARGS[@]}" \
            -e GDK_BACKEND=x11 \
            "$IMAGE_NAME" \
            gdb -ex run -ex 'bt full' -ex quit --args /orcaslicer/${BUILD_DIR}/src/RelWithDebInfo/orca-slicer
        ;;

    run-asan)
        echo "Running OrcaSlicer with AddressSanitizer..."
        xhost +local:docker 2>/dev/null || true
        docker run "${DOCKER_ARGS[@]}" \
            -e GDK_BACKEND=x11 \
            -e ASAN_OPTIONS="detect_leaks=0:halt_on_error=0:print_stats=1:color=always" \
            -e UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=0:color=always" \
            "$IMAGE_NAME" \
            /orcaslicer/${BUILD_DIR}/src/RelWithDebInfo/orca-slicer 2>&1 | tee asan_output.log
        echo "ASan output saved to asan_output.log"
        ;;

    shell)
        echo "Opening shell in container..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" bash
        ;;

    root-shell)
        echo "Opening root shell in container..."
        docker run "${DOCKER_ARGS[@]}" --user root "$IMAGE_NAME" bash
        ;;

    clean)
        echo "Cleaning build directory..."
        docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" \
            bash -c "rm -rf /orcaslicer/${BUILD_DIR}"
        ;;

    help|*)
        echo "Magma/OrcaSlicer Docker Dev (Clang + lld)"
        echo ""
        echo "First time setup:"
        echo "  ./docker-dev.sh build-image   # Build Docker image"
        echo "  ./docker-dev.sh build-deps    # Build dependencies (~30-60 min)"
        echo "  ./docker-dev.sh configure     # Configure Release build"
        echo ""
        echo "Daily workflow (Release - fast):"
        echo "  ./docker-dev.sh ninja         # Build Release"
        echo "  ./docker-dev.sh run           # Run Release"
        echo "  ./docker-dev.sh test          # Run unit tests"
        echo ""
        echo "Debug builds:"
        echo "  ./docker-dev.sh ninja-reldbg    # Build RelWithDebInfo (optimized + debug symbols)"
        echo "  ./docker-dev.sh run-gdb         # Run under GDB (RelWithDebInfo)"
        echo "  ./docker-dev.sh ninja-debug     # Build Debug (slow, full asserts)"
        echo "  ./docker-dev.sh run-debug       # Run Debug"
        echo ""
        echo "Sanitizers (for debugging memory/threading bugs):"
        echo "  ./docker-dev.sh configure-asan  # AddressSanitizer + UBSan"
        echo "  ./docker-dev.sh configure-tsan  # ThreadSanitizer"
        echo "  ./docker-dev.sh run-asan        # Run with ASan"
        echo ""
        echo "Utilities:"
        echo "  ./docker-dev.sh shell         # Interactive shell"
        echo "  ./docker-dev.sh root-shell    # Root shell"
        echo "  ./docker-dev.sh clean         # Clean build directory"
        ;;
esac
