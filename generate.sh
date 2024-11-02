#!/bin/bash
# 脚本名: generate_scripting_bridge.sh

# 检查参数
if [ $# -ne 1 ]; then
    echo "Usage: $0 /path/to/application.app"
    exit 1
fi

APP_PATH="$1"
APP_NAME=$(basename "$APP_PATH" .app)
CURRENT_DIR=$(pwd)
ASSETS_DIR="$CURRENT_DIR/assets"
APP_ASSETS_DIR="$ASSETS_DIR/$APP_NAME"

# 检查应用是否存在
if [ ! -e "$APP_PATH" ]; then
    echo "Error: Application not found at $APP_PATH"
    exit 1
fi

# 创建资源目录
create_assets_directory() {
    if [ ! -d "$ASSETS_DIR" ]; then
        mkdir -p "$ASSETS_DIR"
    fi
    
    # 如果应用目录已存在，先清理
    if [ -d "$APP_ASSETS_DIR" ]; then
        rm -rf "$APP_ASSETS_DIR"
    fi
    
    mkdir -p "$APP_ASSETS_DIR"
    echo "Created directory: $APP_ASSETS_DIR"
}

# 检查必要工具
check_requirements() {
    local missing_tools=()
    
    if ! command -v sdef &> /dev/null; then
        missing_tools+=("sdef")
    fi
    if ! command -v sdp &> /dev/null; then
        missing_tools+=("sdp")
    fi
    if ! command -v ~/var/miniconda3/bin/python &> /dev/null; then
        missing_tools+=("~/var/miniconda3/bin/python")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        echo "Error: Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
}

# 检查 Python 脚本是否存在
check_python_scripts() {
    if [ ! -f "sbhc.py" ] || [ ! -f "sbsc.py" ]; then
        echo "Error: Required Python scripts (sbhc.py and sbsc.py) not found in current directory"
        exit 1
    fi
}

# 生成 ScriptingBridge 文件
generate_bridge_files() {
    echo "Generating ScriptingBridge files for $APP_NAME..."
    
    # 切换到应用资源目录
    cd "$APP_ASSETS_DIR"
    
    # 步骤 1: 生成 sdef 文件
    echo "Step 1: Generating sdef file..."
    sdef "$APP_PATH" > "$APP_NAME.sdef"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate sdef file"
        exit 1
    fi
    
    # 步骤 2: 生成头文件
    echo "Step 2: Generating header file..."
    sdp -fh --basename "$APP_NAME" "$APP_NAME.sdef"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate header file"
        exit 1
    fi
    
    # 步骤 3: 生成 Objective-C 桥接文件
    echo "Step 3: Generating Objective-C bridge file..."
    ~/var/miniconda3/bin/python "$CURRENT_DIR/sbhc.py" "$APP_NAME.h"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate Objective-C bridge file"
        exit 1
    fi
    
    # 步骤 4: 生成 Swift 桥接文件
    echo "Step 4: Generating Swift bridge file..."
    ~/var/miniconda3/bin/python "$CURRENT_DIR/sbsc.py" "$APP_NAME.sdef"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to generate Swift bridge file"
        exit 1
    fi
    
    # 返回原始目录
    cd "$CURRENT_DIR"
}

# 清理临时文件
cleanup() {
    local keep_files
    read -p "Do you want to keep the intermediate files? (y/n): " keep_files
    if [ "$keep_files" != "y" ]; then
        echo "Cleaning up temporary files..."
        rm -f "$APP_ASSETS_DIR/$APP_NAME.sdef"
        rm -f "$APP_ASSETS_DIR/$APP_NAME.h"
    fi
}

# 主程序
main() {
    check_requirements
    check_python_scripts
    create_assets_directory
    generate_bridge_files
    
    echo "Generated files in $APP_ASSETS_DIR:"
    echo "- $APP_NAME.sdef"
    echo "- $APP_NAME.h"
    echo "- ${APP_NAME}Bridge.h"
    echo "- ${APP_NAME}Bridge.swift"
    
    cleanup
    
    echo "ScriptingBridge generation completed successfully!"
}

main