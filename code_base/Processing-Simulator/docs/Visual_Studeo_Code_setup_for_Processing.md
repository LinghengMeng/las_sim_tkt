# Visual Studio Code setup (optional)
Processing IDE is not well designed for large project management, so Visual Studio Code can be used for this purpose by the following instructions given in here.

## Setup Visual Studio Code for Processing Edit
1. Download [Visual Studio Code](https://code.visualstudio.com/download)
2. Install [Processing for Visual Studio Code](https://marketplace.visualstudio.com/items?itemName=Tobiah.language-pde&ssr=false#overview)
3. Create a hidden `.vscode/tasks.json` file within the root directory
4. Edit `tasks.json`:
    ```
    {
        "version": "2.0.0",
        "tasks": [
        {
            "label": "Run Sketch",
            "type": "shell",
            "group": {
            "kind": "build",
            "isDefault": true
            },
            "command": "${config:processing.path}",
            "presentation": {
            "echo": true,
            "reveal": "always",
            "focus": false,
            "panel": "dedicated"
            },
            "args": [
            "--force",
            "--sketch=${workspaceRoot}\\Control_World",
            "--output=${workspaceRoot}\\out",
            "--run"
            ],
            "windows": {
            "args": [
                "--force",
                "--sketch=${workspaceRoot}\\Control_World",
                "--output=${workspaceRoot}\\out",
                "--run"
            ]
            }
        }
        ]
    }
    ```
5. Run `Terminal->Run build task` to run the simulator.