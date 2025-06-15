# WizKid by John D Dondlinger

A user-friendly, AI-powered self-help tool for Windows, powered by Groq's Compound Beta and Vision models. WizKid helps you analyze screenshots, review code, summarize text, organize files, and more—all from a simple menu, with no technical jargon required.

---

## 🚀 Quick Start

1. **Download and extract the ZIP** from the [GitHub Releases](https://github.com/yavru421/wizkid/releases) page.
2. **Add your Groq API key:**
   - Copy `.env.example` to `.env` and paste your key (get one at https://console.groq.com/).
3. **Launch WizKid:**
   - Double-click `WizKidLauncher.bat` (recommended) or run `ScreenHelp.ps1` in PowerShell.

---

## 🧙‍♂️ Features

- **Screenshot Analysis:** Instantly analyze your screen with AI.
- **Clipboard Image Analysis:** Paste any image and get insights.
- **Groq Chat:** Ask questions, get help, or brainstorm ideas.
- **Smart Contextual Q&A:** Get thoughtful answers to complex scenarios.
- **Code Review:** Select a code file for instant review and suggestions.
- **Summarize Text:** Paste any text for a simple summary.
- **Explain Error Message:** Paste an error and get a plain-English explanation.
- **File Organization:** Clean up your Desktop, Downloads, and Temp folders.
- **Personalization:** Set your name and style for a tailored experience.
- **Voice Input (Experimental):** Dictate questions using Windows Speech Recognition.
- **Feedback:** Send feedback to help improve WizKid.

---

## 🖥️ Requirements
- Windows 10/11
- PowerShell 5.1+
- Internet connection (for Groq API)

---

## 🛠️ Setup Details

1. **Clone or Download**
   - Download the ZIP from GitHub and extract it anywhere (e.g., Desktop).
2. **API Key**
   - Copy `.env.example` to `.env` and add your Groq API key.
3. **Run**
   - Double-click `WizKidLauncher.bat` (or right-click > Run as Administrator if needed).
   - Or, open PowerShell in the folder and run: `./ScreenHelp.ps1`

---

## 📦 What’s in the ZIP?
- `ScreenHelp.ps1`, `WizKid.ps1` — Main scripts
- `modules/` — All required PowerShell modules
- `assets/` — App images (no personal data)
- `WizKidLauncher.bat` — Easy launcher
- `.env.example` — Template for your API key
- `README.md` — This file

**Not included:**
- Your `.env` (keep your API key private!)
- Log files, user preferences, and feedback logs

---

## 🔒 Security & Privacy
- Your API key and personal data are never uploaded or shared.
- All logs and preferences are stored locally.

---

## 🆘 Troubleshooting
- If you see errors, check your `.env` file and internet connection.
- For PowerShell script execution errors, run: `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
- If you need help, open an issue on GitHub or email the author.

---

## 🤖 Updating
- Download the latest ZIP from GitHub Releases and overwrite your files (keep your `.env`).

---

## 📝 License
MIT License. See LICENSE file for details.

---

## 💡 Contributing
Pull requests and feedback are welcome! See CONTRIBUTING.md for guidelines.

---

## 📦 Packaging for Distribution
- Exclude `.env`, logs, and user data from your ZIP.
- Include all scripts, modules, assets, `.env.example`, and this README.
- Distribute via GitHub Releases or your preferred method.

---

## 🛠️ Advanced: GitHub Actions (Optional)
You can automate ZIP packaging and release uploads using GitHub Actions. See `.github/workflows/release.yml` for an example (not included by default).

---

Enjoy using WizKid! If you have questions or ideas, let us know!
