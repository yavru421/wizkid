; --- Wizkid GUI Script ---
#SingleInstance Force
SetWorkingDir A_ScriptDir

; Global variables
global APP_MODE := "full" ; Default mode: full, screenshot, chat

; --- Parse command line arguments ---
ParseCommandLine() {
    Loop A_Args.Length {
        arg := A_Args[A_Index]
        if InStr(arg, "--mode=") {
            APP_MODE := StrSplit(arg, "=")[2]
        }
    }
    
    ; Validate mode
    if !InStr("full,screenshot,chat", APP_MODE) {
        APP_MODE := "full"
    }
    
    return APP_MODE
}

; --- GUI Setup ---
SetupGui() {
    global myGui, imgCtrl, questionEdit, modelDDL, screenshotBtn, sendBtn, chatModelDDL, chatHistoryEdit, chatInputEdit, chatSendBtn
    
    mode := ParseCommandLine()
    
    myGui := Gui()
    myGui.Opt('+Resize')
    myGui.SetFont('s10', 'Segoe UI')
    myGui.BackColor := 0xF0F0F0
    
    ; Set appropriate title based on mode
    title := "Wizkid - "
    if (mode = "full") {
        title .= "ScreenHelp (Screenshot + Chat)"
    } else if (mode = "screenshot") {
        title .= "Screenshot Analysis"
    } else if (mode = "chat") {
        title .= "Groq Chat"
    }
    
    myGui.AddText('w320 h30 Center cBlue BackgroundTrans', title)
    
    ; Show different controls based on mode
    if (mode = "full" || mode = "screenshot") {
        imgCtrl := myGui.AddPicture('x10 y50 w300 h180 vScreenshot Border')
        questionEdit := myGui.AddEdit('x10 y240 w300', 'What is happening in this screenshot?')
        modelDDL := myGui.AddDropDownList('x10 y280 w150 Choose1', ['Scout', 'Maverick'])
        screenshotBtn := myGui.AddButton('x10 y320 w140', 'Take Screenshot')
        sendBtn := myGui.AddButton('x160 y320 w140', 'Send to Groq Vision')
        
        screenshotBtn.OnEvent('Click', TakeScreenshot)
        sendBtn.OnEvent('Click', SendToGroq)
    }
    
    ; Add vertical separator if in full mode
    if (mode = "full") {
        myGui.AddText('x320 y10 w2 h380 0x10', '') ; vertical separator
    }
    
    ; Chat controls
    if (mode = "full" || mode = "chat") {
        xOffset := (mode = "full") ? 330 : 10
        width := (mode = "full") ? 400 : 600
        
        chatPanel := myGui.AddGroupBox(Format('x{} y10 w{} h380', xOffset, width), 'Groq API Chat')
        chatModelDDL := myGui.AddDropDownList(Format('x{} y40 w300 Choose1', xOffset+10), ['compound-beta', 'meta-llama/llama-3-maverick-8b-8192'])
        chatHistoryEdit := myGui.AddEdit(Format('x{} y70 w{} h200 ReadOnly', xOffset+10, width-20), '')
        chatInputEdit := myGui.AddEdit(Format('x{} y280 w{} h60', xOffset+10, width-20), '')
        chatSendBtn := myGui.AddButton(Format('x{} y350 w100', xOffset+10), 'Send')
        
        chatSendBtn.OnEvent('Click', SendGroqChat)
    }

    myGui.OnEvent('Close', (*) => ExitApp())

    ; Size the window appropriately based on mode
    screenW := A_ScreenWidth
    screenH := A_ScreenHeight
    
    if (mode = "full") {
        winW := screenW * 0.7  ; 70% of screen width for full mode
        winH := screenH * 0.6  ; 60% of screen height
    } else if (mode = "screenshot") {
        winW := screenW * 0.4  ; 40% of screen width for screenshot mode
        winH := screenH * 0.5  ; 50% of screen height
    } else {  ; chat mode
        winW := screenW * 0.5  ; 50% of screen width for chat mode
        winH := screenH * 0.5  ; 50% of screen height
    }
    
    myGui.Show(Format('w{} h{}', winW, winH))
}

; --- Screenshot Functionality ---
TakeScreenshot(*) {
    global imgCtrl
    
    ; Create assets dir if it doesn't exist
    assetsDir := A_ScriptDir "\..\assets"
    if !DirExist(assetsDir) {
        DirCreate(assetsDir)
    }
    
    File := assetsDir "\wizkid_screenshot.png" 
    Send('{PrintScreen}')
    Sleep(500) ; Give time for the screenshot to be taken
    
    ; Use Python script to save clipboard image
    Cmd := Format('python "{}\save_clipboard_image.py" "{}"', A_ScriptDir, File)
    ExitCode := RunWait(Cmd, , 'Hide')
    if (ExitCode != 0) {
        MsgBox(Format('Failed to save screenshot. Python script exited with code {}.', ExitCode))
    } else if FileExist(File) {
        imgCtrl.Value := File
        MsgBox('Screenshot saved successfully!')
    } else {
        MsgBox('Failed to save screenshot. No image in clipboard or error occurred.')
    }
}

; --- Python Integration ---
SendToGroq(*) {
    global questionEdit, modelDDL, chatHistoryEdit
    
    ; Create assets dir if it doesn't exist
    assetsDir := A_ScriptDir "\..\assets"
    if !DirExist(assetsDir) {
        DirCreate(assetsDir)
    }
    
    File := assetsDir "\wizkid_screenshot.png"
    if !FileExist(File) {
        MsgBox('Take a screenshot first.')
        return
    }
    
    question := questionEdit.Value
    model := modelDDL.Text
    
    ; Show user that we're processing
    chatHistoryEdit.Value := "Sending to Groq Vision API, please wait..."
    
    ; Run the Python script to analyze the image
    Cmd := Format('python "{}\wizkid_groq.py" "{}" "{}" "{}"', A_ScriptDir, File, question, model)
    RunWait(Cmd, , 'Hide')
    
    ; Check for response
    respFile := assetsDir "\wizkid_response.txt"
    if FileExist(respFile) {
        resp := FileRead(respFile, 'UTF-8')
        chatHistoryEdit.Value := "📝 ANALYSIS RESULT:\n\n" resp
    } else {
        chatHistoryEdit.Value := 'No response from Groq API. Please check the Python script.'
    }
}

SendGroqChat(*) {
    global chatInputEdit, chatHistoryEdit, chatModelDDL
    
    ; Create assets dir if it doesn't exist
    assetsDir := A_ScriptDir "\..\assets"
    if !DirExist(assetsDir) {
        DirCreate(assetsDir)
    }
    
    userMsg := chatInputEdit.Value
    model := chatModelDDL.Text
    
    if !userMsg {
        MsgBox('Please enter a message.')
        return
    }
    
    ; Add the user's message to the chat history immediately
    chatHistoryEdit.Value .= 'You: ' userMsg '\n'
    chatHistoryEdit.Value .= 'Groq: Thinking...\n'
    
    ; Run the Python script for chat
    Cmd := Format('python "{}\wizkid_groq_chat.py" "{}" "{}"', A_ScriptDir, userMsg, model)
    RunWait(Cmd, , 'Hide')
    
    ; Get the response
    respFile := assetsDir "\wizkid_chat_response.txt"
    if FileExist(respFile) {
        resp := FileRead(respFile, 'UTF-8')
        
        ; Replace the "thinking" line with the actual response
        current := chatHistoryEdit.Value
        chatHistoryEdit.Value := RegExReplace(current, "Groq: Thinking...\R", "Groq: " resp "\n\n")
        
        ; Clear the input field
        chatInputEdit.Value := ''
    } else {
        ; Replace the "thinking" line with an error message
        current := chatHistoryEdit.Value
        chatHistoryEdit.Value := RegExReplace(current, "Groq: Thinking...\R", "Groq: [Error: No response received]\n\n")
    }
}

; --- Utility Functions ---
EscapeForDisplay(text) {
    ; Replace any characters that might cause issues in the display
    text := StrReplace(text, '\', '\\')
    text := StrReplace(text, '`r', '')
    text := StrReplace(text, '`n', '\n')
    return text
}

SetupGui()
