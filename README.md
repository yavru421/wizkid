# ScreenHelp (Wizkid) Application

A tool that integrates with the Groq API to provide screenshot analysis and chat functionality.

## Quick Start

1. Simply run `run_screenhelp.bat` to install dependencies and launch the application
2. If anything doesn't work, run `test_components.bat` to diagnose issues

## Features

- **Screenshot Analysis**: Capture screenshots and analyze them using Groq Vision API
- **Chat Interface**: Text-based communication with Groq AI models
- **Flexible Modes**: Run in full mode, screenshot-only mode, or chat-only mode

## Setup Instructions

### Prerequisites

- Windows OS
- Python 3.8 or higher
- AutoHotkey v2.0 or higher

### Installation

1. Clone or download this repository
2. Set up the Python environment:

```powershell
cd scripts
.\setup_python_env.ps1
```

3. Activate the virtual environment:

```powershell
..\venv\Scripts\Activate.ps1
```

4. Set your GROQ API key (optional, a default key is included but may expire):

```powershell
$env:GROQ_API_KEY = "your-groq-api-key"
```

### Running the Application

To run the application in full mode (both screenshot and chat):

```
cd scripts
AutoHotkey.exe wizkid_gui.ahk
```

To run in screenshot-only mode:

```
AutoHotkey.exe wizkid_gui.ahk --mode=screenshot
```

To run in chat-only mode:

```
AutoHotkey.exe wizkid_gui.ahk --mode=chat
```

## Usage

### Screenshot Analysis

1. Click "Take Screenshot" to capture your screen
2. Enter a question about the screenshot in the text field
3. Select a model (Scout or Maverick)
4. Click "Send to Groq Vision" to analyze the image

### Chat Interface

1. Select a model from the dropdown
2. Enter your message in the text field
3. Click "Send" to receive a response

## Troubleshooting

- If screenshots aren't being saved, ensure Python is in your PATH and Pillow is installed
- If responses aren't working, check your internet connection and Groq API key
- Check the assets folder for response files if the UI doesn't show results

## Project Structure

- **scripts/**: Contains the code files
- **assets/**: Stores screenshots and response files
- **archive/**: Contains older versions of the codebase
- **venv/**: Python virtual environment
