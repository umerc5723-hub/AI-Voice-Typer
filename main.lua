require "import"
import "android.widget.*"
import "android.content.Intent"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.speech.RecognizerIntent"
import "java.io.*"
import "android.graphics.Typeface"
import "android.net.Uri"
import "android.app.AlertDialog"
import "android.content.DialogInterface"
import "android.os.Bundle"
import "android.view.accessibility.AccessibilityNodeInfo"
import "java.util.Timer"
import "java.util.TimerTask"
import "android.os.Handler"
import "android.os.Looper"
import "android.media.MediaPlayer"
import "java.net.HttpURLConnection"
import "java.net.URL"
import "android.util.Base64"
import "android.util.TypedValue"
import "android.widget.SeekBar"
import "android.view.View"
import "android.content.Context"
import "com.androlua.Http"
import "cjson"

-------------------------------------------------
-- AUTO UPDATE SETTINGS
-------------------------------------------------
local UPDATE_PREF_NAME = "UpdatePref"
local updatePref = service.getSharedPreferences(UPDATE_PREF_NAME, Context.MODE_PRIVATE)
local updateEditor = updatePref.edit()

-- CHANGE THESE VALUES ACCORDING TO YOUR GITHUB REPO
local GITHUB_USERNAME = "SmartTechSabir"
local GITHUB_REPO = "AI-Voice-Typer"
local CURRENT_VERSION = "2.0"

function getLatestVersionFromGitHub()
    local url = "https://api.github.com/repos/" .. GITHUB_USERNAME .. "/" .. GITHUB_REPO .. "/releases/latest"
    local result = ""
    local success = false
    
    local conn = nil
    pcall(function()
        local httpURL = URL(url)
        conn = httpURL.openConnection()
        conn.setRequestMethod("GET")
        conn.setConnectTimeout(5000)
        conn.setReadTimeout(5000)
        conn.connect()
        
        local responseCode = conn.getResponseCode()
        if responseCode == 200 then
            local reader = BufferedReader(InputStreamReader(conn.getInputStream()))
            local line = ""
            while true do
                line = reader.readLine()
                if line == nil then break end
                result = result .. line
            end
            reader.close()
            success = true
        end
        conn.disconnect()
    end)
    
    if success and result ~= "" then
        local ok, data = pcall(cjson.decode, result)
        if ok and data then
            local latestVersion = data.tag_name
            if latestVersion then
                latestVersion = latestVersion:gsub("^v", "")
                return latestVersion, data.body or ""
            end
        end
    end
    return nil, nil
end

function compareVersions(v1, v2)
    local function splitVersion(v)
        local parts = {}
        for num in v:gmatch("%d+") do
            table.insert(parts, tonumber(num))
        end
        return parts
    end
    
    local parts1 = splitVersion(v1)
    local parts2 = splitVersion(v2)
    
    for i = 1, math.max(#parts1, #parts2) do
        local p1 = parts1[i] or 0
        local p2 = parts2[i] or 0
        if p1 > p2 then return 1
        elseif p1 < p2 then return -1 end
    end
    return 0
end

function checkForUpdate(showNoUpdateMessage)
    local latestVersion, changelog = getLatestVersionFromGitHub()
    
    if latestVersion and compareVersions(latestVersion, CURRENT_VERSION) > 0 then
        showUpdateDialog(latestVersion, changelog)
        return true
    else
        if showNoUpdateMessage then
            service.speak("You are using the latest version: " .. CURRENT_VERSION)
        end
        return false
    end
end

function showUpdateDialog(latestVersion, changelog)
    local builder = AlertDialog.Builder(service)
    builder.setTitle("📱 Update Available!")
    builder.setMessage("Current Version: " .. CURRENT_VERSION .. "\nNew Version: " .. latestVersion .. "\n\nWhat's New:\n" .. (changelog or "Bug fixes and improvements") .. "\n\nDo you want to update?")
    
    builder.setPositiveButton("Update", DialogInterface.OnClickListener({
        onClick = function(dialog, which)
            local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://github.com/" .. GITHUB_USERNAME .. "/" .. GITHUB_REPO .. "/releases/latest"))
            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            service.startActivity(intent)
            dialog.dismiss()
        end
    }))
    
    builder.setNegativeButton("Later", DialogInterface.OnClickListener({
        onClick = function(dialog, which)
            dialog.dismiss()
        end
    }))
    
    builder.setCancelable(true)
    service.runOnUiThread(function()
        builder.show()
    end)
end

-------------------------------------------------
-- AI ENGINE PREFERENCES
-------------------------------------------------
local AI_PREFS = "AITyper"
local aiPrefs = service.getSharedPreferences(AI_PREFS, Context.MODE_PRIVATE)
local aiEditor = aiPrefs.edit()

local AI_PROVIDERS = {
    "OpenAI",
    "OpenRouter",
    "Gemini",
    "Groq"
}

-- ==================== TYPING MODES ====================
local TYPING_MODES = {
    "Conversion Mode",
    "Intelligent Writer Mode",
    "Only Selected Language Mode"
}

function getSelectedTypingMode()
    return aiPrefs.getString("selected_typing_mode", "Conversion Mode")
end

function saveSelectedTypingMode(mode)
    aiEditor.putString("selected_typing_mode", mode)
    aiEditor.commit()
end

function getSelectedAIProvider()
    return aiPrefs.getString("selected_ai_provider", "Groq")
end

function saveSelectedAIProvider(provider)
    aiEditor.putString("selected_ai_provider", provider)
    aiEditor.commit()
end

-- OpenAI Settings
local OPENAI_MODELS = {
    "gpt-4o-mini (Fast - Recommended)",
    "gpt-3.5-turbo (Fast)",
    "gpt-4o (Best Quality)",
    "gpt-4-turbo (Slow - Best Quality)",
    "gpt-4"
}

local OPENAI_MODEL_NAMES = {
    "gpt-4o-mini",
    "gpt-3.5-turbo",
    "gpt-4o",
    "gpt-4-turbo",
    "gpt-4"
}

function getOpenAIApiKey()
    return aiPrefs.getString("openai_apiKey", "")
end

function saveOpenAIApiKey(key)
    aiEditor.putString("openai_apiKey", key)
    aiEditor.commit()
end

function getOpenAIModel()
    local saved = aiPrefs.getString("openai_model", "gpt-4o-mini")
    return saved
end

function saveOpenAIModel(model)
    aiEditor.putString("openai_model", model)
    aiEditor.commit()
end

-- OpenRouter Settings
local OPENROUTER_MODELS = {
    "google/gemini-2.0-flash-001",
    "meta-llama/llama-3.3-70b-instruct",
    "microsoft/phi-3-mini-128k",
    "anthropic/claude-3-haiku",
    "mistralai/mistral-7b-instruct"
}

function getOpenRouterApiKey()
    return aiPrefs.getString("openrouter_apiKey", "")
end

function saveOpenRouterApiKey(key)
    aiEditor.putString("openrouter_apiKey", key)
    aiEditor.commit()
end

function getOpenRouterModel()
    return aiPrefs.getString("openrouter_model", "google/gemini-2.0-flash-001")
end

function saveOpenRouterModel(model)
    aiEditor.putString("openrouter_model", model)
    aiEditor.commit()
end

-- Gemini Settings
local GEMINI_MODELS = {
    "Gemini 2.5 Flash",
    "Gemini 2.5 Pro",
    "Gemini 2.0 Flash"
}

local geminiApiDetails = {
    ["Gemini 2.5 Flash"] = { id = "models/gemini-2.5-flash", version = "v1beta" },
    ["Gemini 2.5 Pro"] = { id = "models/gemini-2.5-pro", version = "v1beta" },
    ["Gemini 2.0 Flash"] = { id = "models/gemini-2.0-flash", version = "v1beta" }
}

function getGeminiApiKey()
    return aiPrefs.getString("gemini_apiKey", "")
end

function saveGeminiApiKey(key)
    aiEditor.putString("gemini_apiKey", key)
    aiEditor.commit()
end

function getGeminiModel()
    return aiPrefs.getString("gemini_model", "Gemini 2.5 Flash")
end

function saveGeminiModel(model)
    aiEditor.putString("gemini_model", model)
    aiEditor.commit()
end

-- Groq Settings
local GROQ_MODELS = {
    "llama-3.3-70b-versatile (Best Quality)",
    "llama-3.1-8b-instant (Fast)",
    "mixtral-8x7b-32768",
    "gemma2-9b-it",
    "llama-guard-3-8b"
}

local GROQ_MODEL_NAMES = {
    "llama-3.3-70b-versatile",
    "llama-3.1-8b-instant",
    "mixtral-8x7b-32768",
    "gemma2-9b-it",
    "llama-guard-3-8b"
}

function getGroqApiKey()
    return aiPrefs.getString("groq_apiKey", "")
end

function saveGroqApiKey(key)
    aiEditor.putString("groq_apiKey", key)
    aiEditor.commit()
end

function getGroqModel()
    return aiPrefs.getString("groq_model", "llama-3.3-70b-versatile")
end

function saveGroqModel(model)
    aiEditor.putString("groq_model", model)
    aiEditor.commit()
end

-- Translation Settings
local TRANSLATION_LANGUAGES = {
    "Afrikaans", "Albanian", "Amharic", "Arabic", "Armenian", "Assamese", "Aymara", "Azerbaijani",
    "Bambara", "Basque", "Belarusian", "Bengali", "Bhojpuri", "Bosnian", "Bulgarian", "Catalan",
    "Cebuano", "Chinese (Simplified)", "Chinese (Traditional)", "Corsican", "Croatian", "Czech",
    "Danish", "Dhivehi", "Dogri", "Dutch", "English", "Esperanto", "Estonian", "Ewe",
    "Filipino (Tagalog)", "Finnish", "French", "Frisian", "Galician", "Georgian", "German", "Greek",
    "Guarani", "Gujarati", "Haitian Creole", "Hausa", "Hawaiian", "Hebrew", "Hindi", "Hmong",
    "Hungarian", "Icelandic", "Igbo", "Ilocano", "Indonesian", "Irish", "Italian", "Japanese",
    "Javanese", "Kannada", "Kazakh", "Khmer", "Kinyarwanda", "Konkani", "Korean", "Krio",
    "Kurdish", "Kurdish (Sorani)", "Kyrgyz", "Lao", "Latin", "Latvian", "Lingala", "Lithuanian",
    "Luganda", "Luxembourgish", "Macedonian", "Maithili", "Malagasy", "Malay", "Malayalam",
    "Maltese", "Maori", "Marathi", "Meiteilon (Manipuri)", "Mongolian", "Myanmar (Burmese)",
    "Nepali", "Norwegian", "Nyanja (Chichewa)", "Odia (Oriya)", "Oromo", "Pashto", "Persian",
    "Polish", "Portuguese", "Punjabi", "Quechua", "Romanian", "Russian", "Samoan", "Sanskrit",
    "Scots Gaelic", "Sepedi", "Serbian", "Sesotho", "Shona", "Sindhi", "Sinhala (Sinhalese)",
    "Slovak", "Slovenian", "Somali", "Spanish", "Sundanese", "Swahili", "Swedish", "Tagalog (Filipino)",
    "Tajik", "Tamil", "Tatar", "Telugu", "Thai", "Tigrinya", "Tsonga", "Turkish", "Turkmen",
    "Twi (Akan)", "Ukrainian", "Urdu", "Uyghur", "Uzbek", "Vietnamese", "Welsh", "Xhosa",
    "Yiddish", "Yoruba", "Zulu"
}

local TRANSLATION_CODES = {
    "af", "sq", "am", "ar", "hy", "as", "ay", "az", "bm", "eu", "be", "bn", "bho", "bs", "bg", "ca",
    "ceb", "zh-CN", "zh-TW", "co", "hr", "cs", "da", "dv", "doi", "nl", "en", "eo", "et", "ee",
    "fil", "fi", "fr", "fy", "gl", "ka", "de", "el", "gn", "gu", "ht", "ha", "haw", "iw", "hi", "hmn",
    "hu", "is", "ig", "ilo", "id", "ga", "it", "ja", "jv", "kn", "kk", "km", "rw", "gom", "ko", "kri",
    "ku", "ckb", "ky", "lo", "la", "lv", "ln", "lt", "lg", "lb", "mk", "mai", "mg", "ms", "ml",
    "mt", "mi", "mr", "mni-Mtei", "mn", "my", "ne", "no", "ny", "or", "om", "ps", "fa", "pl",
    "pt", "pa", "qu", "ro", "ru", "sm", "sa", "gd", "nso", "sr", "st", "sn", "sd", "si", "sk", "sl",
    "so", "es", "su", "sw", "sv", "tl", "tg", "ta", "tt", "te", "th", "ti", "ts", "tr", "tk",
    "ak", "uk", "ur", "ug", "uz", "vi", "cy", "xh", "yi", "yo", "zu"
}

function isTranslationEnabled()
    return aiPrefs.getBoolean("translationEnabled", false)
end

function setTranslationEnabled(enabled)
    aiEditor.putBoolean("translationEnabled", enabled)
    aiEditor.commit()
end

function getTargetLanguage()
    return aiPrefs.getString("targetLanguage", "en")
end

function saveTargetLanguage(langCode)
    aiEditor.putString("targetLanguage", langCode)
    aiEditor.commit()
end

function getTargetLanguageName()
    return aiPrefs.getString("targetLanguageName", "English")
end

function saveTargetLanguageName(langName)
    aiEditor.putString("targetLanguageName", langName)
    aiEditor.commit()
end

function isEmojiEnabled()
    return aiPrefs.getBoolean("emojiEnabled", false)
end

function setEmojiEnabled(enabled)
    aiEditor.putBoolean("emojiEnabled", enabled)
    aiEditor.commit()
end

-- ==================== PUNCTUATION SETTINGS ====================
function isPunctuationEnabled()
    return aiPrefs.getBoolean("punctuationEnabled", true)
end

function setPunctuationEnabled(enabled)
    aiEditor.putBoolean("punctuationEnabled", enabled)
    aiEditor.commit()
end

-- ==================== CHECK IF ANY API KEY IS SET ====================
function isAnyApiKeySet()
    local provider = getSelectedAIProvider()
    if provider == "OpenAI" then
        local key = getOpenAIApiKey()
        return key ~= nil and key ~= ""
    elseif provider == "OpenRouter" then
        local key = getOpenRouterApiKey()
        return key ~= nil and key ~= ""
    elseif provider == "Gemini" then
        local key = getGeminiApiKey()
        return key ~= nil and key ~= ""
    else
        local key = getGroqApiKey()
        return key ~= nil and key ~= ""
    end
end

-- ==================== CHECK IF ANY TEXT BOX IS FOCUSED ====================
function isAnyTextBoxFocused()
    local rootNode = service.getRootInActiveWindow()
    if rootNode == nil then return false end
    
    local function findFocused(node)
        if node.isEditable() and node.isFocused() then
            return true
        end
        for i = 0, node.getChildCount() - 1 do
            local child = node.getChild(i)
            if child ~= nil then
                if findFocused(child) then return true end
            end
        end
        return false
    end
    
    return findFocused(rootNode)
end

-- ==================== CONVERSION MODE PROMPT ====================
function getConversionModePrompt()
    return [[You are a multilingual text processor. Follow these rules strictly:

RULE 1: Convert ONLY the following to English:
- Country names (e.g., پاکستان → Pakistan)
- Proper nouns (names of people, cities, brands)
- Technical terms and English loanwords

RULE 2: Keep ALL other words in their original Urdu script.
- Common words like "میں", "تم", "وہ", "ہے", "تھا", "کر", "سے", "پر", "اور" MUST remain in Urdu.

RULE 3: Add country flag emoji AFTER each country name when you convert it.
- Example: Pakistan → Pakistan 🇵🇰

RULE 4: Return ONLY the converted text. Do NOT add any extra text or explanations. Do NOT add any words that were not spoken.

Now process the following text:]]
end

-- ==================== ONLY SELECTED LANGUAGE MODE PROMPT ====================
function getOnlySelectedLanguagePrompt(targetLanguage, punctuationEnabled, emojiEnabled)
    local prompt = "You are a translator. Convert the following speech into " .. targetLanguage .. " language only. "
    
    if punctuationEnabled then
        prompt = prompt .. "Add proper punctuation at the end of each sentence: period (.) for statements, question mark (?) for questions, exclamation (!) for excitement. Add commas where needed. "
    else
        prompt = prompt .. "Do NOT add any punctuation marks. "
    end
    
    if emojiEnabled then
        prompt = prompt .. "Add ONE relevant emoji at the end of each sentence. "
    else
        prompt = prompt .. "Do NOT add any emojis. "
    end
    
    prompt = prompt .. "Return ONLY the translated text. Do NOT add any extra words or explanations.\n\nText: "
    
    return prompt
end

-- ==================== INTELLIGENT WRITER MODE PROMPT ====================
function getIntelligentWriterPrompt(punctuationEnabled, emojiEnabled)
    local prompt = [[You are an AI Writing Assistant. Follow these rules strictly:

GOAL: ONLY fix grammar and spelling mistakes. Do NOT change the meaning. Do NOT add new words. Do NOT rephrase the sentence unnecessarily.

INSTRUCTIONS:
1. Fix obvious spelling errors.
2. Correct grammatical mistakes.
3. Keep the exact same meaning.
4. Do NOT add any words that were not spoken by the user.
5. Do NOT make the text longer than necessary.
6. Return ONLY the corrected text.
]]
    
    if punctuationEnabled then
        prompt = prompt .. [[
7. Add proper punctuation at the end of each sentence ONLY if missing:
   - Add period (.) for statements
   - Add question mark (?) for questions
   - Add exclamation mark (!) for excitement/strong emotions
8. Add commas (,) where needed for proper sentence structure.
9. If punctuation already exists at the end, do NOT add extra punctuation. Do NOT double punctuate.
10. For sentences that already have punctuation, keep it as is and do not add more.
]]
    else
        prompt = prompt .. [[
7. Do NOT add any punctuation. Keep the text exactly as is in terms of punctuation.
8. Do NOT remove any existing punctuation, just do not add new punctuation.
]]
    end
    
    if emojiEnabled then
        prompt = prompt .. [[
11. Add ONE relevant emoji at the end of each sentence AFTER any existing punctuation.
12. The emoji should come AFTER the punctuation mark, not before.
13. Example: "How are you? 😊" (correct), not "How are you 😊?" (incorrect)
14. Use DIFFERENT emojis for different sentences based on their meaning.
]]
    else
        prompt = prompt .. [[
11. Do NOT add any emojis.
]]
    end
    
    prompt = prompt .. [[

IMPORTANT: Check the end of each sentence carefully. If a sentence already ends with . or ? or !, do NOT add another one. Only add punctuation if completely missing.

Examples:
Input: how are you doing today
Output: How are you doing today? 😊

Input: i am fine thank you.
Output: I am fine, thank you. 😊

Input: what is your name?
Output: What is your name? ❓

Input: that is great news!!
Output: That is great news!! 🎉

Now process the following text:]]
    
    return prompt
end-- ==================== API FUNCTIONS ====================
function testOpenAIAPI(apiKey, model, callback)
    local url = "https://api.openai.com/v1/models"
    local headers = { ["Authorization"] = "Bearer " .. apiKey }
    Http.get(url, headers, function(status, data)
        if status == 200 then
            callback(true, "API key is valid!")
        elseif status == 401 then
            callback(false, "Invalid API key")
        elseif status == 429 then
            callback(true, "API key is valid (Rate limit may apply)")
        else
            callback(false, "Error: " .. status)
        end
    end)
end

function testOpenRouterAPI(apiKey, model, callback)
    local url = "https://openrouter.ai/api/v1/auth/key"
    local headers = { ["Authorization"] = "Bearer " .. apiKey }
    Http.get(url, headers, function(status, data)
        if status == 200 then
            callback(true, "API key is valid!")
        elseif status == 401 then
            callback(false, "Invalid API key")
        else
            callback(false, "Error: " .. status)
        end
    end)
end

function testGeminiAPI(apiKey, model, callback)
    local url = "https://generativelanguage.googleapis.com/v1beta/models?key=" .. apiKey
    Http.get(url, {}, function(status, data)
        if status == 200 then
            callback(true, "API key is valid!")
        else
            callback(false, "Invalid API key or error: " .. status)
        end
    end)
end

function testGroqAPI(apiKey, model, callback)
    local url = "https://api.groq.com/openai/v1/models"
    local headers = { ["Authorization"] = "Bearer " .. apiKey }
    Http.get(url, headers, function(status, data)
        if status == 200 then
            callback(true, "API key is valid!")
        elseif status == 401 then
            callback(false, "Invalid API key")
        else
            callback(false, "Error: " .. status)
        end
    end)
end

function callOpenAIAPI(apiKey, model, prompt, callback)
    local url = "https://api.openai.com/v1/chat/completions"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. apiKey
    }
    local payload = {
        model = model,
        messages = {{role = "user", content = prompt}},
        max_tokens = 1024,
        temperature = 0.2
    }
    Http.post(url, cjson.encode(payload), headers, function(status, data)
        if status == 200 then
            local ok, decoded = pcall(cjson.decode, data)
            if ok and decoded and decoded.choices and decoded.choices[1] then
                local text = decoded.choices[1].message.content
                if text then callback(text, nil) else callback(nil, "Invalid response") end
            else
                callback(nil, "Failed to parse response")
            end
        else
            callback(nil, "OpenAI Error: " .. status)
        end
    end)
end

function callOpenRouterAPI(apiKey, model, prompt, callback)
    local url = "https://openrouter.ai/api/v1/chat/completions"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. apiKey,
        ["HTTP-Referer"] = "https://github.com/SmartTechSabir",
        ["X-Title"] = "AI Voice Typer"
    }
    local payload = {
        model = model,
        messages = {{role = "user", content = prompt}},
        max_tokens = 1024,
        temperature = 0.2
    }
    Http.post(url, cjson.encode(payload), headers, function(status, data)
        if status == 200 then
            local ok, decoded = pcall(cjson.decode, data)
            if ok and decoded and decoded.choices and decoded.choices[1] then
                local text = decoded.choices[1].message.content
                if text then callback(text, nil) else callback(nil, "Invalid response") end
            else
                callback(nil, "Failed to parse response")
            end
        else
            callback(nil, "OpenRouter Error: " .. status)
        end
    end)
end

function callGeminiAPI(apiKey, model, prompt, callback)
    local modelInfo = geminiApiDetails[model]
    if not modelInfo then
        callback(nil, "Error: Model not found")
        return
    end
    local url = "https://generativelanguage.googleapis.com/" .. modelInfo.version .. "/" .. modelInfo.id .. ":generateContent?key=" .. apiKey
    local payload = { contents = {{ parts = {{ text = prompt }} }} }
    local headers = { ["Content-Type"] = "application/json" }
    Http.post(url, cjson.encode(payload), headers, function(status, data)
        if status == 200 then
            local ok, decoded = pcall(cjson.decode, data)
            if ok and decoded and decoded.candidates and decoded.candidates[1] then
                local text = decoded.candidates[1].content and decoded.candidates[1].content.parts and decoded.candidates[1].content.parts[1] and decoded.candidates[1].content.parts[1].text
                if text then callback(text, nil) else callback(nil, "Invalid response") end
            else
                callback(nil, "Failed to parse response")
            end
        else
            callback(nil, "Gemini Error: " .. status)
        end
    end)
end

function callGroqAPI(apiKey, model, prompt, callback)
    local url = "https://api.groq.com/openai/v1/chat/completions"
    local headers = {
        ["Content-Type"] = "application/json",
        ["Authorization"] = "Bearer " .. apiKey,
    }
    local payload = {
        model = model,
        messages = {{role = "user", content = prompt}},
        max_tokens = 1024,
        temperature = 0.2
    }
    Http.post(url, cjson.encode(payload), headers, function(status, data)
        if status == 200 then
            local ok, decoded = pcall(cjson.decode, data)
            if ok and decoded and decoded.choices and decoded.choices[1] then
                local text = decoded.choices[1].message.content
                if text then callback(text, nil) else callback(nil, "Invalid response") end
            else
                callback(nil, "Failed to parse response")
            end
        elseif status == 401 then
            callback(nil, "Invalid API key")
        elseif status == 429 then
            callback(nil, "Rate limit exceeded")
        else
            callback(nil, "Groq Error: " .. status)
        end
    end)
end

-- ==================== MAIN PROCESS FUNCTION ====================
function processWithAI(spokenText, callback)
    local provider = getSelectedAIProvider()
    local typingMode = getSelectedTypingMode()
    local translationEnabled = isTranslationEnabled()
    local targetLang = getTargetLanguageName()
    local emojiEnabled = isEmojiEnabled()
    local punctuationEnabled = isPunctuationEnabled()
    
    local prompt = ""
    
    if translationEnabled then
        if punctuationEnabled and emojiEnabled then
            prompt = "Translate this text to " .. targetLang .. " language. Add proper punctuation at the end of each sentence (. ? !) ONLY if missing. Add commas where needed. Add ONE relevant emoji AFTER the punctuation. Return ONLY the translation.\n\nText: " .. spokenText
        elseif punctuationEnabled and not emojiEnabled then
            prompt = "Translate this text to " .. targetLang .. " language. Add proper punctuation at the end of each sentence (. ? !) ONLY if missing. Add commas where needed. Do NOT add emojis. Return ONLY the translation.\n\nText: " .. spokenText
        elseif not punctuationEnabled and emojiEnabled then
            prompt = "Translate this text to " .. targetLang .. " language. Do NOT add any punctuation. Add ONE relevant emoji at the end. Return ONLY the translation.\n\nText: " .. spokenText
        else
            prompt = "Translate this text to " .. targetLang .. " language. Do NOT add any punctuation or emojis. Return ONLY the translation.\n\nText: " .. spokenText
        end
    else
        if typingMode == "Conversion Mode" then
            if emojiEnabled then
                prompt = getConversionModePrompt() .. "\n\nAdd ONE relevant emoji at the end of the text.\n\nText: " .. spokenText
            else
                prompt = getConversionModePrompt() .. "\n\nText: " .. spokenText
            end
        elseif typingMode == "Only Selected Language Mode" then
            local selectedLang = getLanguageNameFromCode(savedLang)
            if punctuationEnabled and emojiEnabled then
                prompt = "Convert the following speech to " .. selectedLang .. " language only. Add proper punctuation at the end of each sentence (. ? !) ONLY if missing. Add commas where needed. Add ONE relevant emoji AFTER the punctuation. Return ONLY the converted text.\n\nText: " .. spokenText
            elseif punctuationEnabled and not emojiEnabled then
                prompt = "Convert the following speech to " .. selectedLang .. " language only. Add proper punctuation at the end of each sentence (. ? !) ONLY if missing. Add commas where needed. Do NOT add emojis. Return ONLY the converted text.\n\nText: " .. spokenText
            elseif not punctuationEnabled and emojiEnabled then
                prompt = "Convert the following speech to " .. selectedLang .. " language only. Do NOT add any punctuation. Add ONE relevant emoji at the end. Return ONLY the converted text.\n\nText: " .. spokenText
            else
                prompt = "Convert the following speech to " .. selectedLang .. " language only. Do NOT add any punctuation or emojis. Return ONLY the converted text.\n\nText: " .. spokenText
            end
        else
            prompt = getIntelligentWriterPrompt(punctuationEnabled, emojiEnabled) .. "\n\nText: " .. spokenText
        end
    end
    
    if provider == "OpenAI" then
        local apiKey = getOpenAIApiKey()
        if not apiKey or apiKey == "" then callback(spokenText) return end
        local model = getOpenAIModel()
        callOpenAIAPI(apiKey, model, prompt, function(result, error)
            if error then callback(spokenText) else callback(result) end
        end)
    elseif provider == "OpenRouter" then
        local apiKey = getOpenRouterApiKey()
        if not apiKey or apiKey == "" then callback(spokenText) return end
        local model = getOpenRouterModel()
        callOpenRouterAPI(apiKey, model, prompt, function(result, error)
            if error then callback(spokenText) else callback(result) end
        end)
    elseif provider == "Gemini" then
        local apiKey = getGeminiApiKey()
        if not apiKey or apiKey == "" then callback(spokenText) return end
        local model = getGeminiModel()
        callGeminiAPI(apiKey, model, prompt, function(result, error)
            if error then callback(spokenText) else callback(result) end
        end)
    else
        local apiKey = getGroqApiKey()
        if not apiKey or apiKey == "" then callback(spokenText) return end
        local model = getGroqModel()
        callGroqAPI(apiKey, model, prompt, function(result, error)
            if error then callback(spokenText) else callback(result) end
        end)
    end
end

-- ==================== SOUND PREFERENCES ====================
local soundPref = service.getSharedPreferences("sound_pref", 0)
local soundEnabled = soundPref.getBoolean("sound_enabled", true)
local bgMusicEnabled = soundPref.getBoolean("bg_music_enabled", false)
local bgMusicVolume = soundPref.getInt("bg_music_volume", 50)
local soundEffectsVolume = soundPref.getInt("sound_effects_volume", 70)

local baseSoundPath = "/storage/emulated/0/解说/Plugins/AI Voice Typer/Audios/"
local openSoundPath = baseSoundPath .. "jim.m4a"
local exitSoundPath = baseSoundPath .. "jjq.ogg"
local backgroundMusicPath = baseSoundPath .. "sad background emotional music __ no copyright sad music ___sad _viral _sadflute _bgm _instrumental(MP3_160K).mp3"
local clickSoundPath = baseSoundPath .. "Focus1_7.mp3"

local backgroundMediaPlayer = nil

function playClickSound()
    if not soundEnabled then return end
    local file = File(clickSoundPath)
    if file.exists() then
        pcall(function()
            local mp = MediaPlayer()
            mp.setDataSource(clickSoundPath)
            local volume = soundEffectsVolume / 100.0
            mp.setVolume(volume, volume)
            mp.prepare()
            mp.start()
            mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{ onCompletion = function(m) m.release() end })
        end)
    end
end

function playSound(filePath)
    if not soundEnabled then return end
    if filePath == nil or filePath == "" then return end
    local file = File(filePath)
    if file.exists() then
        pcall(function()
            local mp = MediaPlayer()
            mp.setDataSource(filePath)
            local volume = soundEffectsVolume / 100.0
            mp.setVolume(volume, volume)
            mp.prepare()
            mp.start()
            mp.setOnCompletionListener(MediaPlayer.OnCompletionListener{ onCompletion = function(m) m.release() end })
        end)
    end
end

function startBackgroundMusic()
    if not bgMusicEnabled then return end
    if backgroundMediaPlayer ~= nil then
        pcall(function()
            if backgroundMediaPlayer.isPlaying() then backgroundMediaPlayer.stop() end
            backgroundMediaPlayer.release()
        end)
        backgroundMediaPlayer = nil
    end
    local file = File(backgroundMusicPath)
    if file.exists() then
        pcall(function()
            backgroundMediaPlayer = MediaPlayer()
            backgroundMediaPlayer.setDataSource(backgroundMusicPath)
            local volume = bgMusicVolume / 100.0
            backgroundMediaPlayer.setVolume(volume, volume)
            backgroundMediaPlayer.prepare()
            backgroundMediaPlayer.setLooping(true)
            backgroundMediaPlayer.start()
        end)
    end
end

function stopBackgroundMusic()
    if backgroundMediaPlayer ~= nil then
        pcall(function()
            if backgroundMediaPlayer.isPlaying() then backgroundMediaPlayer.stop() end
            backgroundMediaPlayer.release()
        end)
        backgroundMediaPlayer = nil
    end
end

function setBackgroundMusicVolume(volume)
    bgMusicVolume = volume
    soundPref.edit().putInt("bg_music_volume", volume).apply()
    if backgroundMediaPlayer ~= nil then
        pcall(function() backgroundMediaPlayer.setVolume(volume / 100.0, volume / 100.0) end)
    end
end

function setSoundEffectsVolume(volume)
    soundEffectsVolume = volume
    soundPref.edit().putInt("sound_effects_volume", volume).apply()
end

-- ==================== COMPLETE 148 LANGUAGES FOR VOICE TYPING ====================
local languages = {
    "Afrikaans (South Africa)=af-ZA", "Azerbaijani (Azerbaijan)=az-AZ", "Indonesian (Indonesia)=id-ID",
    "Malay (Malaysia)=ms-MY", "Javanese (Indonesia)=jv-ID", "Sundanese (Indonesia)=su-ID",
    "Catalan (Spain)=ca-ES", "Czech (Czech Republic)=cs-CZ", "Danish (Denmark)=da-DK",
    "German (Belgium)=de-BE", "German (Germany)=de-DE", "German (Austria)=de-AT",
    "German (Switzerland)=de-CH", "Estonian (Estonia)=et-EE", "English (Australia)=en-AU",
    "English (Canada)=en-CA", "English (Generic)=en", "English (Ghana)=en-GH",
    "English (India)=en-IN", "English (Indonesia)=en-ID", "English (Ireland)=en-IE",
    "English (Kenya)=en-KE", "English (New Zealand)=en-NZ", "English (Nigeria)=en-NG",
    "English (Philippines)=en-PH", "English (Singapore)=en-SG", "English (South Africa)=en-ZA",
    "English (Tanzania)=en-TZ", "English (Thailand)=en-TH", "English (UK)=en-GB",
    "English (US)=en-US", "Spanish (Argentina)=es-AR", "Spanish (Bolivia)=es-BO",
    "Spanish (Chile)=es-CL", "Spanish (Colombia)=es-CO", "Spanish (Costa Rica)=es-CR",
    "Spanish (Ecuador)=es-EC", "Spanish (USA)=es-US", "Spanish (El Salvador)=es-SV",
    "Spanish (Spain)=es-ES", "Spanish (Guatemala)=es-GT", "Spanish (Honduras)=es-HN",
    "Spanish (Mexico)=es-MX", "Spanish (Nicaragua)=es-NI", "Spanish (Panama)=es-PA",
    "Spanish (Paraguay)=es-PY", "Spanish (Peru)=es-PE", "Spanish (Puerto Rico)=es-PR",
    "Spanish (Dominican Republic)=es-DO", "Spanish (Uruguay)=es-UY", "Spanish (Venezuela)=es-VE",
    "Basque (Spain)=eu-ES", "Filipino (Philippines)=fil-PH", "French (Belgium)=fr-BE",
    "French (France)=fr-FR", "French (Canada)=fr-CA", "French (Switzerland)=fr-CH",
    "Galician (Spain)=gl-ES", "Croatian (Croatia)=hr-HR", "Kinyarwanda (Rwanda)=rw-RW",
    "Southern Ndebele (South Africa)=nr-ZA", "Xhosa (South Africa)=xh-ZA", "Zulu (South Africa)=zu-ZA",
    "Icelandic (Iceland)=is-IS", "Italian (Switzerland)=it-CH", "Italian (Italy)=it-IT",
    "Lithuanian (Lithuania)=lt-LT", "Swahili (Kenya)=sw-KE", "Swahili (Tanzania)=sw-TZ",
    "Latvian (Latvia)=lv-LV", "Hungarian (Hungary)=hu-HU", "Dutch (Netherlands)=nl-NL",
    "Norwegian Bokmål (Norway)=nb-NO", "Uzbek (Uzbekistan)=uz-UZ", "Polish (Poland)=pl-PL",
    "Portuguese (Brazil)=pt-BR", "Portuguese (Portugal)=pt-PT", "Romanian (Romania)=ro-RO",
    "Sotho (South Africa)=st-ZA", "Sotho (Lesotho)=st-LS", "Northern Sotho (South Africa)=nso-ZA",
    "Tswana (South Africa)=tn-ZA", "Tswana (Botswana)=tn-BW", "Albanian (Albania)=sq-AL",
    "Swati (eSwatini)=ss-SZ", "Swati (South Africa)=ss-ZA", "Slovenian (Slovenia)=sl-SI",
    "Slovak (Slovakia)=sk-SK", "Finnish (Finland)=fi-FI", "Swedish (Sweden)=sv-SE",
    "Vietnamese (Vietnam)=vi-VN", "Venda (South Africa)=ve-ZA", "Turkish (Turkey)=tr-TR",
    "Tsonga (South Africa)=ts-ZA", "Greek (Greece)=el-GR", "Bulgarian (Bulgaria)=bg-BG",
    "Macedonian (North Macedonia)=mk-MK", "Mongolian (Mongolia)=mn-MN", "Russian (Russia)=ru-RU",
    "Serbian (Serbia)=sr-RS", "Ukrainian (Ukraine)=uk-UA", "Kazakh (Kazakhstan)=kk-KZ",
    "Georgian (Georgia)=ka-GE", "Armenian (Armenia)=hy-AM", "Hebrew (Israel)=iw-IL",
    "Arabic (Israel)=ar-IL", "Arabic (Jordan)=ar-JO", "Arabic (UAE)=ar-AE",
    "Arabic (Bahrain)=ar-BH", "Arabic (Algeria)=ar-DZ", "Arabic (Saudi Arabia)=ar-SA",
    "Arabic (Kuwait)=ar-KW", "Arabic (Morocco)=ar-MA", "Arabic (Tunisia)=ar-TN",
    "Arabic (Oman)=ar-OM", "Arabic (Palestine)=ar-PS", "Arabic (Egypt)=ar-EG",
    "Persian (Iran)=fa-IR", "Arabic (Qatar)=ar-QA", "Arabic (Lebanon)=ar-LB",
    "Urdu (Pakistan)=ur-PK", "Urdu (India)=ur-IN", "Sindhi (Pakistan)=sd-PK",
    "Sindhi (India)=sd-IN", "Amharic (Ethiopia)=am-ET", "Hindi (India)=hi-IN",
    "Punjabi (India)=pa-IN", "Tamil (India)=ta-IN", "Tamil (Sri Lanka)=ta-LK",
    "Tamil (Singapore)=ta-SG", "Tamil (Malaysia)=ta-MY", "Bengali (Bangladesh)=bn-BD",
    "Bengali (India)=bn-IN", "Khmer (Cambodia)=km-KH", "Kannada (India)=kn-IN",
    "Marathi (India)=mr-IN", "Gujarati (India)=gu-IN", "Sinhala (Sri Lanka)=si-LK",
    "Telugu (India)=te-IN", "Malayalam (India)=ml-IN", "Nepali (Nepal)=ne-NP",
    "Lao (Laos)=lo-LA", "Thai (Thailand)=th-TH", "Mandarin Chinese (Taiwan)=zh-TW",
    "Burmese (Myanmar)=my-MM", "Korean (South Korea)=ko-KR", "Mandarin Chinese (Mainland China)=zh-CN",
    "Mandarin Chinese (Hong Kong)=zh-HK", "Cantonese (Hong Kong)=yue-Hant-HK", "Japanese (Japan)=ja-JP"
}

function getLanguageNameFromCode(code)
    if code == nil then return "Urdu (Pakistan)" end
    for i=1,#languages do
        local langCode = languages[i]:match("=(.+)")
        if langCode == code then
            local name = languages[i]:match("(.+)=")
            if name then return name end
        end
    end
    return code
end

-- ==================== ORIGINAL CODE VARIABLES ====================
local prefs = service.getSharedPreferences("lang_settings", 0)
local savedLang = prefs.getString("lang", "ur-PK")

local dictFilePath = service.getFilesDir().toString() .. "/dictionary.txt"
local endTextPref = service.getSharedPreferences("end_text_pref", 0)
local savedEndText = endTextPref.getString("end_text", "")

local namePref = service.getSharedPreferences("user_name_pref", 0)
local userName = namePref.getString("user_name", "")
local hasName = namePref.getBoolean("has_name", false)

local extLangPref = service.getSharedPreferences("ext_lang_pref", 0)
local extLang = extLangPref.getString("ext_lang", "urdu")

local romanPref = service.getSharedPreferences("roman_mode_pref", 0)
local romanModeEnabled = romanPref.getBoolean("roman_mode", false)

-- Extension language list (5 languages)
local extensionLangList = {
    {name="English", code="english", display="English"},
    {name="اردو", code="urdu", display="اردو"},
    {name="हिन्दी", code="hindi", display="हिन्दी"},
    {name="پنجابی", code="punjabi", display="پنجابی"},
    {name="سنڌي", code="sindhi", display="سنڌي"}
}

-- Roman Urdu conversion map
local romanUrduMap = {
    ["السلام"] = "assalam", ["علیکم"] = "alaikum", ["السلام علیکم"] = "assalam o alaikum",
    ["وعلیکم السلام"] = "wa alaikum assalam", ["کیسے"] = "kaise", ["ہیں"] = "hain",
    ["آپ"] = "aap", ["میں"] = "main", ["تم"] = "tum", ["وہ"] = "woh", ["یہ"] = "yeh",
    ["ہے"] = "hai", ["ہوں"] = "hoon", ["تھا"] = "tha", ["تھی"] = "thi", ["تھے"] = "thay",
    ["کر"] = "kar", ["کرنا"] = "karna", ["کرو"] = "karo", ["کیا"] = "kia", ["کی"] = "ki",
    ["کے"] = "ke", ["سے"] = "se", ["پر"] = "par", ["کو"] = "ko", ["نے"] = "ne",
    ["اور"] = "aur", ["تو"] = "to", ["بھی"] = "bhi", ["تک"] = "tak", ["لئے"] = "liye",
    ["ہی"] = "hi", ["اب"] = "ab", ["پھر"] = "phir", ["اگر"] = "agar", ["ورنہ"] = "warna",
    ["لیکن"] = "lekin", ["کیونکے"] = "kyunke", ["اس"] = "is", ["اسے"] = "isay",
    ["ان"] = "in", ["انہیں"] = "inhain", ["آج"] = "aaj", ["کل"] = "kal", ["آج کل"] = "aaj kal",
    ["صبح"] = "subah", ["شام"] = "shaam", ["رات"] = "raat", ["دن"] = "din", ["ہفتہ"] = "hafta",
    ["مہینہ"] = "maheena", ["سال"] = "saal", ["بہت"] = "bohat", ["تھوڑا"] = "thora",
    ["زیادہ"] = "zyada", ["کم"] = "kam", ["اچھا"] = "acha", ["برا"] = "bura",
    ["ٹھیک"] = "theek", ["غلط"] = "ghalat", ["نیا"] = "naya", ["پرانا"] = "purana",
    ["بڑا"] = "bara", ["چھوٹا"] = "chota", ["پاس"] = "paas", ["دور"] = "door",
    ["اندر"] = "andar", ["باہر"] = "bahar", ["اوپر"] = "oopar", ["نیچے"] = "neeche",
    ["دائیں"] = "dayen", ["بائیں"] = "bayen", ["سامنے"] = "samnay", ["پیچھے"] = "peechay",
    ["میرا"] = "mera", ["تیرا"] = "tera", ["اس کا"] = "us ka", ["ہمارا"] = "hamara",
    ["تمہارا"] = "tumhara", ["ان کا"] = "un ka", ["جا"] = "ja", ["آ"] = "aa", ["دے"] = "de",
    ["لے"] = "le", ["رکھ"] = "rakh", ["لکھ"] = "likh", ["پڑھ"] = "parh", ["سن"] = "sun",
    ["بول"] = "bol", ["دیکھ"] = "dekh", ["چل"] = "chal", ["بیٹھ"] = "baith", ["اٹھ"] = "uth",
    ["سو"] = "so", ["کھا"] = "kha", ["پی"] = "pee", ["خوش"] = "khush", ["غمگین"] = "ghamgeen",
    ["پیار"] = "pyaar", ["محبت"] = "mohabbat", ["دوستی"] = "dosti", ["دشمنی"] = "dushmani",
    ["بھائی"] = "bhai", ["بہن"] = "behan", ["ماں"] = "maa", ["باپ"] = "baap", ["بیٹا"] = "beta",
    ["بیٹی"] = "beti", ["دادا"] = "dada", ["دادی"] = "dadi", ["نانا"] = "nana", ["نانی"] = "nani",
    ["چچا"] = "chacha", ["چچی"] = "chachi", ["خالہ"] = "khala", ["خالو"] = "khalu",
    ["ماموں"] = "mamoon", ["پھوپھی"] = "phophi", ["انکل"] = "uncle", ["آنٹی"] = "aunty",
    ["سکول"] = "school", ["کالج"] = "college", ["یونیورسٹی"] = "university",
    ["پاکستان"] = "Pakistan", ["انڈیا"] = "India", ["امریکہ"] = "America",
    ["انگلینڈ"] = "England", ["چین"] = "China", ["جاپان"] = "Japan", ["دبئی"] = "Dubai",
}

function urduToRoman(text)
    if text == nil then return "" end
    local result = text
    for urdu, roman in pairs(romanUrduMap) do
        if #urdu > 1 then result = result:gsub(urdu, roman) end
    end
    for urdu, roman in pairs(romanUrduMap) do
        if #urdu == 1 then result = result:gsub(urdu, roman) end
    end
    return result
end

local selectedLangName = getLanguageNameFromCode(savedLang)

-- Language texts (5 languages) with Developer: Friends Star
local texts = {
    english = {
        app_title = "AI Voice Typer", developer = "Developer: Friends Star",
        select_lang = "Select Voice Language (148 Languages)", current_lang = "Current Language",
        add_dict = "Add Dictionary", view_dict = "View Dictionary", set_end = "Set End of Text",
        ext_lang = "Extension Language", roman_mode = "Roman Typing",
        roman_on = "Roman Typing: ON", roman_off = "Roman Typing: OFF",
        about = "About", exit = "Exit", ext_settings = "Extension Settings",
        sound_effects = "Sound Effects", sound_on = "Sound: ON", sound_off = "Sound: OFF",
        bg_music = "Background Music", bg_music_on = "BG Music: ON", bg_music_off = "BG Music: OFF",
        volume_control = "Volume Control", bg_music_volume = "Background Music Volume",
        sfx_volume = "Sound Effects Volume", ai_engine = "AI Engine Settings",
        follow_tiktok = "Follow TikTok Account", send_feedback = "Send Feedback",
        welcome_title = "Welcome to AI Voice Typer", enter_name = "Please enter your name:",
        your_name = "Your Name", ok = "OK", cancel = "Cancel", error = "Error",
        both_required = "Both fields are required!", saved = "Saved",
        nothing_added = "Nothing will be added at the end.", space_added = "A space will be added at the end.",
        period_added = "A period (.) will be added at the end.", newline_added = "A new line will be added at the end.",
        current = "Current", nothing = "Nothing", space = "Space", period = "Period", newline = "New Line",
        what_end = "What should appear at the end of each typed text?", save = "Save",
        dict_empty = "Dictionary is empty!\n\nAdd some words using 'Add Dictionary' button.",
        view_dict_title = "View Dictionary (Tap to Edit/Delete)", edit_delete = "Edit / Delete: ",
        wrong_word = "Wrong Word:", correct_word = "Correct Word:", update = "Update", delete = "Delete",
        about_title = "About AI Voice Typer", close = "Close", select_ext_lang = "Select Extension Language",
        welcome_msg = "is ready to use.", version = "Version: 2.0",
        no_textbox_title = "No Text Box Found",
        no_textbox_msg = "No text box is currently focused on screen.",
        about_text = "AI Voice Typer\nDeveloper: Friends Star\nVersion: 2.0\nFeatures:\n• Voice to text in 148 languages\n• Roman Typing Mode\n• Dictionary for word replacements\n• AI Engine with 4 providers\n• Translation to 133 languages\n• Emoji support\n• Punctuation ON/OFF\n• Sound Effects & Background Music",
        whatsapp_community = "Join WhatsApp Community", subscribe_youtube = "Subscribe YouTube Channel",
        follow_telegram = "Join Telegram Channel", check_update = "Check for Updates", goodbye = "Goodbye! Please remember us in your prayers."
    },
    urdu = {
        app_title = "AI وائس ٹائپر", developer = "ڈویلپر: Friends Star",
        select_lang = "انتخاب زبان (148 زبانیں)", current_lang = "موجودہ زبان",
        add_dict = "ڈکشنری شامل کریں", view_dict = "ڈکشنری دیکھیں",
        set_end = "متن کے آخر میں شامل کریں", ext_lang = "ایکسٹینشن زبان",
        roman_mode = "رومن ٹائپنگ", roman_on = "رومن ٹائپنگ: آن", roman_off = "رومن ٹائپنگ: آف",
        about = "تعارف", exit = "خارج", ext_settings = "ایکسٹینشن سیٹنگز",
        sound_effects = "صوتی اثرات", sound_on = "آواز: آن", sound_off = "آواز: آف",
        bg_music = "پس منظر موسیقی", bg_music_on = "پس منظر موسیقی: آن", bg_music_off = "پس منظر موسیقی: آف",
        volume_control = "والیوم کنٹرول", bg_music_volume = "پس منظر موسیقی والیوم",
        sfx_volume = "صوتی اثرات والیوم", ai_engine = "AI انجن سیٹنگز",
        follow_tiktok = "ٹک ٹاک اکاؤنٹ فالو کریں", send_feedback = "فیڈبیک بھیجیں",
        welcome_title = "AI وائس ٹائپر میں خوش آمدید", enter_name = "براہ کرم اپنا نام درج کریں:",
        your_name = "آپ کا نام", ok = "ٹھیک ہے", cancel = "منسوخ",
        error = "خرابی", both_required = "دونوں فیلڈز کی ضرورت ہے!", saved = "محفوظ",
        nothing_added = "آخر میں کچھ شامل نہیں کیا جائے گا۔", space_added = "آخر میں اسپیس شامل کیا جائے گا۔",
        period_added = "آخر میں فل اسٹاپ (.) شامل کیا جائے گا۔", newline_added = "آخر میں نئی لائن شامل کی جائے گی۔",
        current = "موجودہ", nothing = "کچھ نہیں", space = "اسپیس", period = "فل اسٹاپ", newline = "نئی لائن",
        what_end = "ٹائپ کردہ متن کے آخر میں کیا شامل ہو؟", save = "محفوظ",
        dict_empty = "ڈکشنری خالی ہے!", view_dict_title = "ڈکشنری دیکھیں",
        edit_delete = "ترمیم / حذف:", wrong_word = "غلط لفظ:",
        correct_word = "صحیح لفظ:", update = "اپ ڈیٹ کریں", delete = "حذف کریں",
        about_title = "AI وائس ٹائپر کے بارے میں", close = "بند کریں",
        select_ext_lang = "ایکسٹینشن زبان منتخب کریں",
        welcome_msg = "استعمال کے لیے تیار ہے۔",
        version = "ورژن: 2.0",
        about_text = "AI وائس ٹائپر\nڈویلپر: Friends Star\nورژن: 2.0\nفیچرز:\n• 148 زبانوں میں وائس ٹو ٹیکسٹ\n• رومن ٹائپنگ موڈ\n• ڈکشنری برائے الفاظ کی تبدیلی\n• AI انجن - 4 پرووائیڈرز\n• 133 زبانوں میں ترجمہ\n• ایموجی سپورٹ\n• پنکچویشن آن/آف\n• صوتی اثرات اور پس منظر موسیقی",
        whatsapp_community = "WhatsApp کمیونٹی جوائن کریں", subscribe_youtube = "YouTube چینل سبسکرائب کریں",
        follow_telegram = "ٹیلیگرام چینل جوائن کریں", check_update = "اپ ڈیٹ چیک کریں", goodbye = "خدا حافظ! ہمیں اپنی دعاؤں میں یاد رکھیں۔"
    },
    hindi = {
        app_title = "AI वॉइस टाइपर", developer = "डेवलपर: Friends Star",
        select_lang = "भाषा चुनें (148 भाषाएं)", current_lang = "वर्तमान भाषा",
        add_dict = "शब्दकोश जोड़ें", view_dict = "शब्दकोश देखें", set_end = "अंत में जोड़ें",
        ext_lang = "एक्सटेंशन भाषा", roman_mode = "रोमन टाइपिंग",
        roman_on = "रोमन टाइपिंग: चालू", roman_off = "रोमन टाइपिंग: बंद",
        about = "परिचय", exit = "बाहर जाएं", ext_settings = "एक्सटेंशन सेटिंग्स",
        sound_effects = "ध्वनि प्रभाव", sound_on = "ध्वनि: चालू", sound_off = "ध्वनि: बंद",
        bg_music = "पृष्ठभूमि संगीत", bg_music_on = "पृष्ठभूमि संगीत: चालू", bg_music_off = "पृष्ठभूमि संगीत: बंद",
        volume_control = "वॉल्यूम नियंत्रण", bg_music_volume = "पृष्ठभूमि संगीत वॉल्यूम",
        sfx_volume = "ध्वनि प्रभाव वॉल्यूम", ai_engine = "AI इंजन सेटिंग्स",
        follow_tiktok = "TikTok अकाउंट फॉलो करें", send_feedback = "फीडबैक भेजें",
        welcome_title = "AI वॉइस टाइपर में आपका स्वागत है", enter_name = "कृपया अपना नाम दर्ज करें:",
        your_name = "आपका नाम", ok = "ठीक है", cancel = "रद्द करें",
        error = "त्रुटि", both_required = "दोनों फ़ील्ड आवश्यक हैं!", saved = "सहेजा गया",
        nothing_added = "अंत में कुछ नहीं जोड़ा जाएगा।", space_added = "अंत में स्पेस जोड़ा जाएगा।",
        period_added = "अंत में पूर्ण विराम (.) जोड़ा जाएगा।", newline_added = "अंत में नई लाइन जोड़ी जाएगी।",
        current = "वर्तमान", nothing = "कुछ नहीं", space = "स्पेस", period = "पूर्ण विराम", newline = "नई लाइन",
        what_end = "टाइप किए गए टेक्सट के अंत में क्या होना चाहिए?", save = "सहेजें",
        dict_empty = "शब्दकोश खाली है!", view_dict_title = "शब्दकोश देखें",
        edit_delete = "संपादित करें / हटाएं:", wrong_word = "गलत शब्द:",
        correct_word = "सही शब्द:", update = "अपडेट करें", delete = "हटाएं",
        about_title = "AI वॉइस टाइपर के बारे में", close = "बंद करें",
        select_ext_lang = "एक्सटेंशन भाषा चुनें",
        welcome_msg = "उपयोग के लिए तैयार है।",
        version = "संस्करण: 2.0",
        about_text = "AI वॉइस टाइपर\nडेवलपर: Friends Star\nसंस्करण: 2.0\nविशेषताएं:\n• 148 भाषाओं में वॉइस टू टेक्स्ट\n• रोमन टाइपिंग मोड\n• शब्दकोश\n• AI इंजन - 4 प्रोवाइडर्स\n• 133 भाषाओं में अनुवाद\n• इमोजी समर्थन\n• विराम चिह्न चालू/बंद\n• ध्वनि प्रभाव और पृष्ठभूमि संगीत",
        whatsapp_community = "WhatsApp समुदाय से जुड़ें", subscribe_youtube = "YouTube चैनल सब्सक्राइब करें",
        follow_telegram = "टेलीग्राम चैनल ज्वाइन करें", check_update = "अपडेट जांचें", goodbye = "अलविदा! हमें अपनी दुआओं में याद रखना।"
    },
    punjabi = {
        app_title = "AI ਵੌਇਸ ਟਾਈਪਰ", developer = "ਡਿਵੈਲਪਰ: Friends Star",
        select_lang = "ਭਾਸ਼ਾ ਚੁਣੋ (148 ਭਾਸ਼ਾਵਾਂ)", current_lang = "ਮੌਜੂਦਾ ਭਾਸ਼ਾ",
        add_dict = "ਸ਼ਬਦਕੋਸ਼ ਸ਼ਾਮਲ ਕਰੋ", view_dict = "ਸ਼ਬਦਕੋਸ਼ ਦੇਖੋ", set_end = "ਅੰਤ ਵਿੱਚ ਸ਼ਾਮਲ ਕਰੋ",
        ext_lang = "ਐਕਸਟੈਂਸ਼ਨ ਭਾਸ਼ਾ", roman_mode = "ਰੋਮਨ ਟਾਈਪਿੰਗ",
        roman_on = "ਰੋਮਨ ਟਾਈਪਿੰਗ: ਚਾਲੂ", roman_off = "ਰੋਮਨ ਟਾਈਪਿੰਗ: ਬੰਦ",
        about = "ਜਾਣਕਾਰੀ", exit = "ਬਾਹਰ ਜਾਓ", ext_settings = "ਐਕਸਟੈਂਸ਼ਨ ਸੈਟਿੰਗਾਂ",
        sound_effects = "ਆਵਾਜ਼ ਪ੍ਰਭਾਵ", sound_on = "ਆਵਾਜ਼: ਚਾਲੂ", sound_off = "ਆਵਾਜ਼: ਬੰਦ",
        bg_music = "ਪਿਛੋਕੜ ਸੰਗੀਤ", bg_music_on = "ਪਿਛੋਕੜ ਸੰਗੀਤ: ਚਾਲੂ", bg_music_off = "ਪਿਛੋਕੜ ਸੰਗੀਤ: ਬੰਦ",
        volume_control = "ਵਾਲੀਅਮ ਕੰਟਰੋਲ", bg_music_volume = "ਪਿਛੋਕੜ ਸੰਗੀਤ ਵਾਲੀਅਮ",
        sfx_volume = "ਆਵਾਜ਼ ਪ੍ਰਭਾਵ ਵਾਲੀਅਮ", ai_engine = "AI ਇੰਜਣ ਸੈਟਿੰਗਾਂ",
        follow_tiktok = "TikTok ਅਕਾਊਂਟ ਫਾਲੋ ਕਰੋ", send_feedback = "ਫੀਡਬੈਕ ਭੇਜੋ",
        welcome_title = "AI ਵੌਇਸ ਟਾਈਪਰ ਵਿੱਚ ਤੁਹਾਡਾ ਸੁਆਗਤ ਹੈ", enter_name = "ਕਿਰਪਾ ਕਰਕੇ ਆਪਣਾ ਨਾਮ ਦਰਜ ਕਰੋ:",
        your_name = "ਤੁਹਾਡਾ ਨਾਮ", ok = "ਠੀਕ ਹੈ", cancel = "ਰੱਦ ਕਰੋ",
        error = "ਗਲਤੀ", both_required = "ਦੋਵੇਂ ਫ਼ੀਲਡਾਂ ਦੀ ਲੋੜ ਹੈ!", saved = "ਸੇਵ ਹੋਇਆ",
        nothing_added = "ਅੰਤ ਵਿੱਚ ਕੁਝ ਨਹੀਂ ਜੋੜਿਆ ਜਾਵੇਗਾ।", space_added = "ਅੰਤ ਵਿੱਚ ਸਪੇਸ ਜੋੜੀ ਜਾਵੇਗੀ।",
        period_added = "ਅੰਤ ਵਿੱਚ ਪੀਰੀਅਡ (.) ਜੋੜਿਆ ਜਾਵੇਗਾ।", newline_added = "ਅੰਤ ਵਿੱਚ ਨਵੀਂ ਲਾਈਨ ਜੋੜੀ ਜਾਵੇਗੀ।",
        current = "ਮੌਜੂਦਾ", nothing = "ਕੁਝ ਨਹੀਂ", space = "ਸਪੇਸ", period = "ਪੀਰੀਅਡ", newline = "ਨਵੀਂ ਲਾਈਨ",
        what_end = "ਟਾਈਪ ਕੀਤੇ ਟੈਕਸਟ ਦੇ ਅੰਤ ਵਿੱਚ ਕੀ ਹੋਣਾ ਚਾਹੀਦਾ ਹੈ?", save = "ਸੇਵ ਕਰੋ",
        dict_empty = "ਸ਼ਬਦਕੋਸ਼ ਖਾਲੀ ਹੈ!", view_dict_title = "ਸ਼ਬਦਕੋਸ਼ ਦੇਖੋ",
        edit_delete = "ਸੰਪਾਦਿਤ / ਹਟਾਓ:", wrong_word = "ਗਲਤ ਸ਼ਬਦ:",
        correct_word = "ਸਹੀ ਸ਼ਬਦ:", update = "ਅੱਪਡੇਟ ਕਰੋ", delete = "ਹਟਾਓ",
        about_title = "AI ਵੌਇਸ ਟਾਈਪਰ ਬਾਰੇ", close = "ਬੰਦ ਕਰੋ",
        select_ext_lang = "ਐਕਸਟੈਂਸ਼ਨ ਭਾਸ਼ਾ ਚੁਣੋ",
        welcome_msg = "ਵਰਤੋਂ ਲਈ ਤਿਆਰ ਹੈ।",
        version = "ਵਰਜਨ: 2.0",
        about_text = "AI ਵੌਇਸ ਟਾਈਪਰ\nਡਿਵੈਲਪਰ: Friends Star\nਵਰਜਨ: 2.0\nਫੀਚਰ:\n• 148 ਭਾਸ਼ਾਵਾਂ ਵਿੱਚ ਵੌਇਸ ਟੂ ਟੈਕਸਟ\n• ਰੋਮਨ ਟਾਈਪਿੰਗ ਮੋਡ\n• ਸ਼ਬਦਕੋਸ਼\n• AI ਇੰਜਣ - 4 ਪ੍ਰੋਵਾਈਡਰ\n• 133 ਭਾਸ਼ਾਵਾਂ ਵਿੱਚ ਅਨੁਵਾਦ\n• ਇਮੋਜੀ ਸਹਾਇਤਾ\n• ਵਿਰਾਮ ਚਿੰਨ੍ਹ ਚਾਲੂ/ਬੰਦ\n• ਆਵਾਜ਼ ਪ੍ਰਭਾਵ ਅਤੇ ਪਿਛੋਕੜ ਸੰਗੀਤ",
        whatsapp_community = "WhatsApp ਕਮਿਊਨਿਟੀ ਵਿੱਚ ਸ਼ਾਮਲ ਹੋਵੋ", subscribe_youtube = "YouTube ਚੈਨਲ ਸਬਸਕ੍ਰਾਈਬ ਕਰੋ",
        follow_telegram = "ਟੈਲੀਗ੍ਰਾਮ ਚੈਨਲ ਜੁਆਇਨ ਕਰੋ", check_update = "ਅੱਪਡੇਟ ਚੈੱਕ ਕਰੋ", goodbye = "ਅਲਵਿਦਾ! ਸਾਨੂੰ ਆਪਣੀਆਂ ਦੁਆਵਾਂ ਵਿੱਚ ਯਾਦ ਰੱਖਣਾ।"
    },
    sindhi = {
        app_title = "AI وائس ٽائپر", developer = "ڊولپر: Friends Star",
        select_lang = "ٻولي چونڊيو (148 ٻوليون)", current_lang = "موجوده ٻولي",
        add_dict = "لغت شامل ڪريو", view_dict = "لغت ڏسو", set_end = "آخر ۾ شامل ڪريو",
        ext_lang = "ايڪسٽينشن ٻولي", roman_mode = "رومن ٽائپنگ",
        roman_on = "رومن ٽائپنگ: آن", roman_off = "رومن ٽائپنگ: آف",
        about = "تعارف", exit = "ٻاهر نڪرو", ext_settings = "ايڪسٽينشن سيٽنگون",
        sound_effects = "آواز جا اثر", sound_on = "آواز: آن", sound_off = "آواز: آف",
        bg_music = "پس منظر موسيقي", bg_music_on = "پس منظر موسيقي: آن", bg_music_off = "پس منظر موسيقي: آف",
        volume_control = "وڌاءَ ڪنٽرول", bg_music_volume = "پس منظر موسيقي وڌاءَ",
        sfx_volume = "آواز جا اثر وڌاءَ", ai_engine = "AI انجڻ سيٽنگون",
        follow_tiktok = "TikTok اڪائونٽ فالو ڪريو", send_feedback = "راءِ موڪليو",
        welcome_title = "AI وائس ٽائپر ۾ ڀليڪار", enter_name = "مهرباني ڪري پنهنجو نالو داخل ڪريو:",
        your_name = "توهان جو نالو", ok = "ٺيڪ", cancel = "منسوخ",
        error = "غلطي", both_required = "ٻنهي فيلڊن جي ضرورت آهي!", saved = "محفوظ",
        nothing_added = "آخر ۾ ڪجهه شامل نه ڪيو ويندو.", space_added = "آخر ۾ اسپيس شامل ڪيو ويندو.",
        period_added = "آخر ۾ فل اسٽاپ (.) شامل ڪيو ويندو.", newline_added = "آخر ۾ نئين لائن شامل ڪئي ويندي.",
        current = "موجوده", nothing = "ڪجهه نه", space = "اسپيس", period = "فل اسٽاپ", newline = "نئين لائن",
        what_end = "ٽائپ ڪيل متن جي آخر ۾ ڪهڙو هجي؟", save = "محفوظ",
        dict_empty = "لغت خالي آهي!", view_dict_title = "لغت ڏسو",
        edit_delete = "ترميم / حذف:", wrong_word = "غلط لفظ:",
        correct_word = "صحيح لفظ:", update = "اپڊيٽ ڪريو", delete = "حذف ڪريو",
        about_title = "AI وائس ٽائپر بابت", close = "بند ڪريو",
        select_ext_lang = "ايڪسٽينشن ٻولي چونڊيو",
        welcome_msg = "استعمال لاءِ تيار آهي.",
        version = "ورزن: 2.0",
        about_text = "AI وائس ٽائپر\nڊولپر: Friends Star\nورزن: 2.0\nفيچرز:\n• 148 ٻولين ۾ وائس ٽو ٽيڪسٽ\n• رومن ٽائپنگ موڊ\n• لغت\n• AI انجڻ - 4 پرووائڊرز\n• 133 ٻولين ۾ ترجمو\n• ايموجي سپورٽ\n• پنڪچويشن آن/آف\n• آواز جا اثر ۽ پس منظر موسيقي",
        whatsapp_community = "WhatsApp ڪميونٽي ۾ شامل ٿيو", subscribe_youtube = "YouTube چينل سبسڪرائب ڪريو",
        follow_telegram = "ٽيليگرام چينل جوائن ڪريو", check_update = "اپڊيٽ چيڪ ڪريو", goodbye = "الله حافظ! اسان کي پنهنجين دعائن ۾ ياد رکو."
    }
}

function getText(key)
    if texts[extLang] and texts[extLang][key] then
        return texts[extLang][key]
    elseif texts.urdu[key] then
        return texts.urdu[key]
    else
        return key
    end
end

-- ==================== UPDATE EXTENSION LANGUAGE ====================
function updateExtensionLanguage(newLang)
    extLang = newLang
    extLangPref.edit().putString("ext_lang", newLang).apply()
    if mainDialog ~= nil and mainDialog.isShowing() then
        mainDialog.dismiss()
        showMainDialog()
    end
end

-- Dictionary functions
function loadDictionary()
    local dict = {}
    local file = File(dictFilePath)
    if file.exists() then
        local br = BufferedReader(FileReader(file))
        while true do
            local line = br.readLine()
            if line == nil then break end
            local k,v = line:match("(.+)=(.+)")
            if k and v then dict[k] = v end
        end
        br.close()
    end
    return dict
end

function saveWord(wrong, correct)
    if wrong == nil or wrong == "" or correct == nil or correct == "" then return end
    local fw = FileWriter(dictFilePath, true)
    fw.write(wrong .. "=" .. correct .. "\n")
    fw.close()
end

function saveDictionary(dict)
    local fw = FileWriter(dictFilePath, false)
    for k,v in pairs(dict) do
        fw.write(k .. "=" .. v .. "\n")
    end
    fw.close()
end

function deleteWord(key)
    if key == nil then return end
    local dict = loadDictionary()
    dict[key] = nil
    saveDictionary(dict)
end

function applyDictionaryReplacements(text)
    local dict = loadDictionary()
    local result = text
    for wrongWord, correctWord in pairs(dict) do
        result = result:gsub(wrongWord, correctWord)
    end
    return result
end

local changeTable = loadDictionary()

-- ==================== TYPING FUNCTION ====================
local lastSpokenText = ""

function insertTextIntoAnyTextBox(text)
    local rootNode = service.getRootInActiveWindow()
    if rootNode == nil then return false end
    
    local focusedNode = nil
    local currentText = ""
    
    local function findFocusedNode(node)
        if node.isEditable() and node.isFocused() then
            focusedNode = node
            local nodeText = node.getText()
            if nodeText ~= nil then currentText = tostring(nodeText) end
            return true
        end
        for i = 0, node.getChildCount() - 1 do
            local child = node.getChild(i)
            if child ~= nil then
                if findFocusedNode(child) then return true end
            end
        end
        return false
    end
    
    findFocusedNode(rootNode)
    
    if focusedNode == nil then return false end
    
    local placeholderPatterns = {
        "Add a reply", "Add reply", "Reply", "Write a reply", "Type a reply",
        "Search YouTube", "Search", "Type to search", "Search...",
        "Add description...", "Add description", "Description", "Type description",
        "Add comment...", "Add comment", "Comment", "Write a comment", "Type a comment",
        "Type a message", "Message", "Write a message", "Type message", "Enter message",
        "Aa", "Type here", "ٹائپ کریں", "Search or type URL", "Enter name", "Enter text"
    }
    
    local isPlaceholder = false
    local currentTextTrimmed = currentText:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    
    for _, placeholder in ipairs(placeholderPatterns) do
        if currentTextTrimmed == placeholder or currentTextTrimmed == placeholder .. "..." or currentText:find(placeholder) then
            isPlaceholder = true
            break
        end
    end
    
    if #currentTextTrimmed <= 3 and currentTextTrimmed ~= "" then isPlaceholder = true end
    
    local finalText = text
    if currentText == nil or currentText == "" or isPlaceholder then
        finalText = text
    else
        if not currentText:match("%s$") then finalText = currentText .. " " .. text
        else finalText = currentText .. text end
    end
    
    local success = false
    success = pcall(function()
        local args = Bundle()
        args.putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, finalText)
        focusedNode.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
    end)
    
    if not success then
        success = pcall(function() focusedNode.setText(finalText) end)
    end
    
    if success and text ~= nil and text ~= "" then
        pcall(function() service.speak(text) end)
    end
    
    return success
end

function toggleRomanMode()
    romanModeEnabled = not romanModeEnabled
    romanPref.edit().putBoolean("roman_mode", romanModeEnabled).apply()
    Toast.makeText(service, romanModeEnabled and "Roman Typing Mode: ON" or "Roman Typing Mode: OFF", Toast.LENGTH_SHORT).show()
end

function startTyping()
    if not isAnyApiKeySet() then
        service.speak("Please set your API key in AI Engine Settings first")
        return
    end
    
    playClickSound()
    
    local speechRecTemp = SpeechRecognizer.createSpeechRecognizer(service)
    local tempListener = RecognitionListener{
        onResults = function(r)
            local arr = r.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if arr and arr.size() > 0 then
                local txt = arr.get(0)
                txt = applyDictionaryReplacements(txt)
                if romanModeEnabled then txt = urduToRoman(txt) end
                if savedEndText ~= "" then txt = txt .. savedEndText end
                
                local provider = getSelectedAIProvider()
                local hasApiKey = false
                if provider == "OpenAI" then hasApiKey = getOpenAIApiKey() ~= ""
                elseif provider == "OpenRouter" then hasApiKey = getOpenRouterApiKey() ~= ""
                elseif provider == "Gemini" then hasApiKey = getGeminiApiKey() ~= ""
                else hasApiKey = getGroqApiKey() ~= "" end
                
                if hasApiKey then
                    service.speak("Processing...")
                    processWithAI(txt, function(enhancedText)
                        local finalText = enhancedText
                        if savedEndText ~= "" and not finalText:find(savedEndText) then
                            finalText = finalText .. savedEndText
                        end
                        insertTextIntoAnyTextBox(finalText)
                    end)
                else
                    insertTextIntoAnyTextBox(txt)
                end
            end
            speechRecTemp.destroy()
        end,
        onError = function(err)
            service.speak("Please speak again")
            speechRecTemp.destroy()
        end
    }
    local intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, savedLang)
    intent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
    speechRecTemp.setRecognitionListener(tempListener)
    speechRecTemp.startListening(intent)
end

-- ==================== DIALOG FUNCTIONS ====================
function dp(n)
    local scale = service.getResources().getDisplayMetrics().density
    return math.floor(n * scale + 0.5)
end

function showDictionary()
    playClickSound()
    local dict = loadDictionary()
    local listData = {}
    for k, v in pairs(dict) do
        table.insert(listData, k .. " => " .. v)
    end
    if #listData == 0 then
        local d = LuaDialog()
        d.setTitle(getText("view_dict"))
        local tv = TextView(service)
        tv.setText(getText("dict_empty"))
        tv.setTextSize(14)
        tv.setPadding(40, 40, 40, 40)
        d.setView(tv)
        d.show()
        return
    end
    local d = LuaDialog()
    d.setTitle(getText("view_dict_title"))
    local list = ListView(service)
    list.setAdapter(ArrayAdapter(service, android.R.layout.simple_list_item_1, listData))
    list.onItemClick = function(l, v, p, i)
        playClickSound()
        local itemText = listData[i + 1]
        local key, val = itemText:match("(.+) => (.+)")
        local ed = LuaDialog()
        ed.setTitle(getText("edit_delete") .. key)
        local lay = {
            LinearLayout; orientation = "vertical"; padding = "20dp";
            {TextView; text = getText("wrong_word");};
            {EditText; id = "wrongWord"; text = key;};
            {TextView; text = getText("correct_word");};
            {EditText; id = "correctWord"; text = val;};
            {LinearLayout; orientation = "horizontal";
                {Button; text = getText("update"); onClick = function()
                    local newWrong = wrongWord.getText().toString()
                    local newCorrect = correctWord.getText().toString()
                    if newWrong ~= "" and newCorrect ~= "" then
                        local dict2 = loadDictionary()
                        dict2[key] = nil
                        dict2[newWrong] = newCorrect
                        saveDictionary(dict2)
                        ed.dismiss()
                        d.dismiss()
                        showDictionary()
                    end
                end};
                {Button; text = getText("delete"); onClick = function()
                    deleteWord(key)
                    ed.dismiss()
                    d.dismiss()
                    showDictionary()
                end};
                {Button; text = getText("cancel"); onClick = function() ed.dismiss() end};
            };
        }
        ed.setView(loadlayout(lay))
        ed.show()
    end
    d.setView(list)
    d.show()
end

function showVolumeControl()
    playClickSound()
    local d = LuaDialog()
    d.setTitle(getText("volume_control"))
    local mainLayout = LinearLayout(service)
    mainLayout.setOrientation(1)
    mainLayout.setPadding(dp(20), dp(20), dp(20), dp(20))
    
    local bgMusicLabel = TextView(service)
    bgMusicLabel.setText(getText("bg_music_volume"))
    mainLayout.addView(bgMusicLabel)
    
    local bgSeekBar = SeekBar(service)
    bgSeekBar.setMax(100)
    bgSeekBar.setProgress(bgMusicVolume)
    bgSeekBar.setOnSeekBarChangeListener({
        onProgressChanged = function(seekbar, progress, fromUser)
            if fromUser then setBackgroundMusicVolume(progress) end
        end
    })
    mainLayout.addView(bgSeekBar)
    
    local sfxLabel = TextView(service)
    sfxLabel.setText(getText("sfx_volume"))
    mainLayout.addView(sfxLabel)
    
    local sfxSeekBar = SeekBar(service)
    sfxSeekBar.setMax(100)
    sfxSeekBar.setProgress(soundEffectsVolume)
    sfxSeekBar.setOnSeekBarChangeListener({
        onProgressChanged = function(seekbar, progress, fromUser)
            if fromUser then setSoundEffectsVolume(progress) end
        end
    })
    mainLayout.addView(sfxSeekBar)
    
    local closeBtn = Button(service)
    closeBtn.setText("Close")
    closeBtn.onClick = function() d.dismiss() end
    mainLayout.addView(closeBtn)
    
    d.setView(mainLayout)
    d.show()
end

function showSoundEffectsDialog()
    playClickSound()
    local d = LuaDialog()
    d.setTitle(getText("sound_effects"))
    local mainLayout = LinearLayout(service)
    mainLayout.setOrientation(1)
    mainLayout.setPadding(dp(20), dp(20), dp(20), dp(20))
    
    local bgMusicBtn = Button(service)
    bgMusicBtn.setText(bgMusicEnabled and getText("bg_music_on") or getText("bg_music_off"))
    bgMusicBtn.onClick = function()
        playClickSound()
        bgMusicEnabled = not bgMusicEnabled
        soundPref.edit().putBoolean("bg_music_enabled", bgMusicEnabled).apply()
        if bgMusicEnabled then startBackgroundMusic() else stopBackgroundMusic() end
        bgMusicBtn.setText(bgMusicEnabled and getText("bg_music_on") or getText("bg_music_off"))
    end
    mainLayout.addView(bgMusicBtn)
    
    local soundBtn = Button(service)
    soundBtn.setText(soundEnabled and getText("sound_on") or getText("sound_off"))
    soundBtn.onClick = function()
        playClickSound()
        soundEnabled = not soundEnabled
        soundPref.edit().putBoolean("sound_enabled", soundEnabled).apply()
        soundBtn.setText(soundEnabled and getText("sound_on") or getText("sound_off"))
    end
    mainLayout.addView(soundBtn)
    
    local volumeBtn = Button(service)
    volumeBtn.setText(getText("volume_control"))
    volumeBtn.onClick = function() showVolumeControl() end
    mainLayout.addView(volumeBtn)
    
    local backBtn = Button(service)
    backBtn.setText("Back")
    backBtn.onClick = function() d.dismiss() end
    mainLayout.addView(backBtn)
    
    d.setView(mainLayout)
    d.show()
end

function filterLangs(q)
    local res = {}
    for i = 1, #languages do
        if string.find(string.lower(languages[i]), string.lower(q), 1, true) then
            table.insert(res, languages[i])
        end
    end
    return res
end

-- ==================== SHOW EXTENSION SETTINGS ====================
function showExtensionSettings()
    playClickSound()
    local d = LuaDialog()
    d.setTitle(getText("ext_settings"))
    local mainLayout = LinearLayout(service)
    mainLayout.setOrientation(1)
    mainLayout.setPadding(dp(20), dp(20), dp(20), dp(20))
    
    local romanBtn = Button(service)
    romanBtn.setText(romanModeEnabled and getText("roman_on") or getText("roman_off"))
    romanBtn.setTextSize(14)
    romanBtn.setBackgroundColor(romanModeEnabled and 0xFF4CAF50 or 0xFFF44336)
    romanBtn.setPadding(0, 15, 0, 15)
    local romanParams = LinearLayout.LayoutParams(-1, -2)
    romanParams.setMargins(0, 0, 0, 10)
    romanBtn.setLayoutParams(romanParams)
    romanBtn.onClick = function()
        playClickSound()
        toggleRomanMode()
        d.dismiss()
        showExtensionSettings()
    end
    mainLayout.addView(romanBtn)
    
    local modesBtn = Button(service)
    modesBtn.setText("Select Typing Mode")
    modesBtn.setTextSize(14)
    modesBtn.setBackgroundColor(0xFF2196F3)
    modesBtn.setPadding(0, 15, 0, 15)
    local modesParams = LinearLayout.LayoutParams(-1, -2)
    modesParams.setMargins(0, 0, 0, 10)
    modesBtn.setLayoutParams(modesParams)
    modesBtn.onClick = function()
        playClickSound()
        d.dismiss()
        showTypingModesDialog(function() showExtensionSettings() end)
    end
    mainLayout.addView(modesBtn)
    
    local currentMode = getSelectedTypingMode()
    local modeStatus = TextView(service)
    modeStatus.setText("Current Mode: " .. currentMode)
    modeStatus.setTextSize(12)
    modeStatus.setTextColor(0xFF4CAF50)
    modeStatus.setPadding(5, 5, 5, 15)
    mainLayout.addView(modeStatus)
    
    local addDictBtn = Button(service)
    addDictBtn.setText(getText("add_dict"))
    addDictBtn.setTextSize(14)
    addDictBtn.setBackgroundColor(0xFF2196F3)
    addDictBtn.setPadding(0, 15, 0, 15)
    local addDictParams = LinearLayout.LayoutParams(-1, -2)
    addDictParams.setMargins(0, 0, 0, 10)
    addDictBtn.setLayoutParams(addDictParams)
    addDictBtn.onClick = function()
        playClickSound()
        local addD = LuaDialog()
        local addLay = { LinearLayout; orientation="vertical"; padding="20dp";
            {EditText; id="w"; hint=getText("wrong_word");};
            {EditText; id="c"; hint=getText("correct_word");};
            {Button; text=getText("save"); onClick=function()
                playClickSound()
                local wrong = w.getText().toString()
                local correct = c.getText().toString()
                if wrong ~= "" and correct ~= "" then
                    saveWord(wrong, correct)
                    changeTable = loadDictionary()
                    addD.dismiss()
                    Toast.makeText(service, getText("saved"), Toast.LENGTH_SHORT).show()
                else
                    local err = LuaDialog()
                    err.setTitle(getText("error"))
                    err.setMessage(getText("both_required"))
                    err.show()
                end
            end};
        }
        addD.setView(loadlayout(addLay))
        addD.show()
    end
    mainLayout.addView(addDictBtn)
    
    local viewDictBtn = Button(service)
    viewDictBtn.setText(getText("view_dict"))
    viewDictBtn.setTextSize(14)
    viewDictBtn.setBackgroundColor(0xFF2196F3)
    viewDictBtn.setPadding(0, 15, 0, 15)
    local viewDictParams = LinearLayout.LayoutParams(-1, -2)
    viewDictParams.setMargins(0, 0, 0, 10)
    viewDictBtn.setLayoutParams(viewDictParams)
    viewDictBtn.onClick = function()
        playClickSound()
        d.dismiss()
        showDictionary()
    end
    mainLayout.addView(viewDictBtn)
    
    local setEndBtn = Button(service)
    setEndBtn.setText(getText("set_end"))
    setEndBtn.setTextSize(14)
    setEndBtn.setBackgroundColor(0xFF2196F3)
    setEndBtn.setPadding(0, 15, 0, 15)
    local setEndParams = LinearLayout.LayoutParams(-1, -2)
    setEndParams.setMargins(0, 0, 0, 10)
    setEndBtn.setLayoutParams(setEndParams)
    setEndBtn.onClick = function()
        playClickSound()
        local endD = LuaDialog()
        local currentDisplay = getText("current") .. ": "
        if savedEndText == "" then currentDisplay = currentDisplay .. getText("nothing")
        elseif savedEndText == " " then currentDisplay = currentDisplay .. getText("space")
        elseif savedEndText == "." then currentDisplay = currentDisplay .. getText("period")
        elseif savedEndText == "\n" then currentDisplay = currentDisplay .. getText("newline")
        else currentDisplay = currentDisplay .. savedEndText end
        local endLay = { LinearLayout; orientation="vertical"; padding="20dp";
            {TextView; text=getText("what_end");};
            {TextView; text=currentDisplay;};
            {LinearLayout; orientation="horizontal";
                {Button; text=getText("nothing"); onClick=function()
                    savedEndText = ""; endTextPref.edit().putString("end_text", "").apply(); endD.dismiss();
                end};
                {Button; text=getText("space"); onClick=function()
                    savedEndText = " "; endTextPref.edit().putString("end_text", " ").apply(); endD.dismiss();
                end};
                {Button; text=getText("period"); onClick=function()
                    savedEndText = "."; endTextPref.edit().putString("end_text", ".").apply(); endD.dismiss();
                end};
                {Button; text=getText("newline"); onClick=function()
                    savedEndText = "\n"; endTextPref.edit().putString("end_text", "\n").apply(); endD.dismiss();
                end};
            };
            {Button; text=getText("cancel"); onClick=function() endD.dismiss() end};
        }
        endD.setView(loadlayout(endLay))
        endD.show()
    end
    mainLayout.addView(setEndBtn)
    
    local extLangBtn = Button(service)
    extLangBtn.setText(getText("ext_lang"))
    extLangBtn.setTextSize(14)
    extLangBtn.setBackgroundColor(0xFF2196F3)
    extLangBtn.setPadding(0, 15, 0, 15)
    local extLangParams = LinearLayout.LayoutParams(-1, -2)
    extLangParams.setMargins(0, 0, 0, 10)
    extLangBtn.setLayoutParams(extLangParams)
    extLangBtn.onClick = function()
        playClickSound()
        local langD = LuaDialog()
        local langButtons = LinearLayout(service)
        langButtons.setOrientation(1)
        langButtons.setPadding(20, 20, 20, 20)
        
        for i, lang in ipairs(extensionLangList) do
            local btn = Button(service)
            btn.setText(lang.display)
            btn.setTextSize(14)
            btn.setPadding(0, 15, 0, 15)
            btn.setBackgroundColor(lang.code == extLang and 0xFF4CAF50 or 0xFF2196F3)
            local params = LinearLayout.LayoutParams(-1, -2)
            params.setMargins(0, 0, 0, 10)
            btn.setLayoutParams(params)
            btn.onClick = function()
                playClickSound()
                updateExtensionLanguage(lang.code)
                langD.dismiss()
                d.dismiss()
                showExtensionSettings()
            end
            langButtons.addView(btn)
        end
        
        local cancelBtn = Button(service)
        cancelBtn.setText(getText("cancel"))
        cancelBtn.setTextSize(14)
        cancelBtn.setBackgroundColor(0xFFF44336)
        cancelBtn.setPadding(0, 15, 0, 15)
        cancelBtn.onClick = function()
            playClickSound()
            langD.dismiss()
        end
        langButtons.addView(cancelBtn)
        
        langD.setView(langButtons)
        langD.show()
    end
    mainLayout.addView(extLangBtn)
    
    local aiBtn = Button(service)
    aiBtn.setText(getText("ai_engine"))
    aiBtn.setTextSize(14)
    aiBtn.setBackgroundColor(0xFF2196F3)
    aiBtn.setPadding(0, 15, 0, 15)
    local aiParams = LinearLayout.LayoutParams(-1, -2)
    aiParams.setMargins(0, 0, 0, 10)
    aiBtn.setLayoutParams(aiParams)
    aiBtn.onClick = function()
        playClickSound()
        d.dismiss()
        showAISettingsDialog(function() showExtensionSettings() end)
    end
    mainLayout.addView(aiBtn)
    
    local punctuationState = isPunctuationEnabled()
    local punctuationBtn = Button(service)
    punctuationBtn.setText(punctuationState and "Punctuation: ON (. ? ! ,)" or "Punctuation: OFF")
    punctuationBtn.setTextSize(14)
    punctuationBtn.setBackgroundColor(punctuationState and 0xFF4CAF50 or 0xFFF44336)
    punctuationBtn.setPadding(0, 15, 0, 15)
    local punctParams = LinearLayout.LayoutParams(-1, -2)
    punctParams.setMargins(0, 0, 0, 10)
    punctuationBtn.setLayoutParams(punctParams)
    punctuationBtn.onClick = function()
        playClickSound()
        local newState = not isPunctuationEnabled()
        setPunctuationEnabled(newState)
        punctuationBtn.setText(newState and "Punctuation: ON (. ? ! ,)" or "Punctuation: OFF")
        punctuationBtn.setBackgroundColor(newState and 0xFF4CAF50 or 0xFFF44336)
        service.speak("Punctuation " .. (newState and "enabled" or "disabled"))
    end
    mainLayout.addView(punctuationBtn)
    
    local emojiState = isEmojiEnabled()
    local emojiBtn = Button(service)
    emojiBtn.setText(emojiState and "Emoji: ON 😊" or "Emoji: OFF")
    emojiBtn.setTextSize(14)
    emojiBtn.setBackgroundColor(emojiState and 0xFF4CAF50 or 0xFFF44336)
    emojiBtn.setPadding(0, 15, 0, 15)
    local emojiParams = LinearLayout.LayoutParams(-1, -2)
    emojiParams.setMargins(0, 0, 0, 10)
    emojiBtn.setLayoutParams(emojiParams)
    emojiBtn.onClick = function()
        playClickSound()
        local newState = not isEmojiEnabled()
        setEmojiEnabled(newState)
        emojiBtn.setText(newState and "Emoji: ON 😊" or "Emoji: OFF")
        emojiBtn.setBackgroundColor(newState and 0xFF4CAF50 or 0xFFF44336)
        service.speak("Emoji " .. (newState and "enabled" or "disabled"))
    end
    mainLayout.addView(emojiBtn)
    
    -- Check for Updates Button (NEW)
    local updateBtn = Button(service)
    updateBtn.setText(getText("check_update"))
    updateBtn.setTextSize(14)
    updateBtn.setBackgroundColor(0xFFFF9800)
    updateBtn.setPadding(0, 15, 0, 15)
    local updateParams = LinearLayout.LayoutParams(-1, -2)
    updateParams.setMargins(0, 0, 0, 10)
    updateBtn.setLayoutParams(updateParams)
    updateBtn.onClick = function()
        playClickSound()
        service.speak("Checking for updates...")
        checkForUpdate(true)
    end
    mainLayout.addView(updateBtn)
    
    local soundEffectsBtn = Button(service)
    soundEffectsBtn.setText(getText("sound_effects"))
    soundEffectsBtn.setTextSize(14)
    soundEffectsBtn.setBackgroundColor(0xFF2196F3)
    soundEffectsBtn.setPadding(0, 15, 0, 15)
    local soundParams = LinearLayout.LayoutParams(-1, -2)
    soundParams.setMargins(0, 0, 0, 10)
    soundEffectsBtn.setLayoutParams(soundParams)
    soundEffectsBtn.onClick = function()
        playClickSound()
        showSoundEffectsDialog()
    end
    mainLayout.addView(soundEffectsBtn)
    
    local backToMenuBtn = Button(service)
    backToMenuBtn.setText("🔘 Back to Main Menu")
    backToMenuBtn.setTextSize(14)
    backToMenuBtn.setBackgroundColor(0xFFF44336)
    backToMenuBtn.setPadding(0, 15, 0, 15)
    backToMenuBtn.onClick = function()
        playClickSound()
        d.dismiss()
        showMainDialog()
    end
    mainLayout.addView(backToMenuBtn)
    
    d.setView(mainLayout)
    d.show()
end

function showTypingModesDialog(parentDlg)
    local dlg = LuaDialog(service)
    dlg.setTitle("Select Typing Mode")
    dlg.setCancelable(true)
    
    local layout = LinearLayout(service)
    layout.setOrientation(1)
    layout.setPadding(20, 20, 20, 20)
    
    local currentMode = getSelectedTypingMode()
    
    -- Mode 1: Conversion Mode
    local convBtn = Button(service)
    if currentMode == "Conversion Mode" then
        convBtn.setText("✓ Conversion Mode (Active)")
        convBtn.setBackgroundColor(0xFF4CAF50)
    else
        convBtn.setText("Conversion Mode")
        convBtn.setBackgroundColor(0xFF2196F3)
    end
    convBtn.setTextSize(14)
    convBtn.setPadding(0, 15, 0, 15)
    local convParams = LinearLayout.LayoutParams(-1, -2)
    convParams.setMargins(0, 0, 0, 10)
    convBtn.setLayoutParams(convParams)
    convBtn.onClick = function()
        playClickSound()
        saveSelectedTypingMode("Conversion Mode")
        service.speak("Conversion Mode selected - Country names to English with flags")
        dlg.dismiss()
        if parentDlg and type(parentDlg) == "function" then
            parentDlg()
        end
    end
    layout.addView(convBtn)
    
    local convDesc = TextView(service)
    convDesc.setText("Converts country names to English with flags 🇵🇰🇮🇳🇺🇸")
    convDesc.setTextSize(11)
    convDesc.setTextColor(0xFFAAAAAA)
    convDesc.setPadding(5, 0, 5, 15)
    layout.addView(convDesc)
    
    -- Mode 2: Intelligent Writer Mode
    local intBtn = Button(service)
    if currentMode == "Intelligent Writer Mode" then
        intBtn.setText("✓ Intelligent Writer Mode (Active)")
        intBtn.setBackgroundColor(0xFF4CAF50)
    else
        intBtn.setText("Intelligent Writer Mode")
        intBtn.setBackgroundColor(0xFF2196F3)
    end
    intBtn.setTextSize(14)
    intBtn.setPadding(0, 15, 0, 15)
    local intParams = LinearLayout.LayoutParams(-1, -2)
    intParams.setMargins(0, 0, 0, 10)
    intBtn.setLayoutParams(intParams)
    intBtn.onClick = function()
        playClickSound()
        saveSelectedTypingMode("Intelligent Writer Mode")
        service.speak("Intelligent Writer Mode selected - Text enhancement with punctuation")
        dlg.dismiss()
        if parentDlg and type(parentDlg) == "function" then
            parentDlg()
        end
    end
    layout.addView(intBtn)
    
    local intDesc = TextView(service)
    intDesc.setText("Professional text enhancement - Grammar, punctuation, and style improvement")
    intDesc.setTextSize(11)
    intDesc.setTextColor(0xFFAAAAAA)
    intDesc.setPadding(5, 0, 5, 15)
    layout.addView(intDesc)
    
    -- Mode 3: Only Selected Language Mode
    local onlyLangBtn = Button(service)
    if currentMode == "Only Selected Language Mode" then
        onlyLangBtn.setText("✓ Only Selected Language Mode (Active)")
        onlyLangBtn.setBackgroundColor(0xFF4CAF50)
    else
        onlyLangBtn.setText("Only Selected Language Mode")
        onlyLangBtn.setBackgroundColor(0xFF2196F3)
    end
    onlyLangBtn.setTextSize(14)
    onlyLangBtn.setPadding(0, 15, 0, 15)
    local onlyLangParams = LinearLayout.LayoutParams(-1, -2)
    onlyLangParams.setMargins(0, 0, 0, 10)
    onlyLangBtn.setLayoutParams(onlyLangParams)
    onlyLangBtn.onClick = function()
        playClickSound()
        saveSelectedTypingMode("Only Selected Language Mode")
        local selectedLang = getLanguageNameFromCode(savedLang)
        service.speak("Only Selected Language Mode selected - Converting speech to " .. selectedLang)
        dlg.dismiss()
        if parentDlg and type(parentDlg) == "function" then
            parentDlg()
        end
    end
    layout.addView(onlyLangBtn)
    
    local onlyLangDesc = TextView(service)
    onlyLangDesc.setText("Converts speech to your selected voice language only with punctuation")
    onlyLangDesc.setTextSize(11)
    onlyLangDesc.setTextColor(0xFFAAAAAA)
    onlyLangDesc.setPadding(5, 0, 5, 15)
    layout.addView(onlyLangDesc)
    
    local backBtn = Button(service)
    backBtn.setText("🔘 Back to Extension Settings")
    backBtn.setTextSize(14)
    backBtn.setBackgroundColor(0xFFF44336)
    backBtn.setPadding(0, 15, 0, 15)
    backBtn.onClick = function()
        playClickSound()
        dlg.dismiss()
        if parentDlg and type(parentDlg) == "function" then
            parentDlg()
        end
    end
    layout.addView(backBtn)
    
    dlg.setView(layout)
    dlg.show()
end

function showAISettingsDialog(mainDlg)
    local dlg = LuaDialog(service)
    dlg.setTitle("AI Engine Settings")
    dlg.setCancelable(true)
    
    local scrollView = ScrollView(service)
    local mainLayout = LinearLayout(service)
    mainLayout.setOrientation(1)
    mainLayout.setPadding(30, 20, 30, 20)
    
    local providerLabel = TextView(service)
    providerLabel.setText("Select AI Provider:")
    providerLabel.setTextSize(14)
    providerLabel.setTextColor(0xFFFFFFFF)
    providerLabel.setPadding(0, 0, 0, 10)
    mainLayout.addView(providerLabel)
    
    local providerSpinner = Spinner(service)
    local providerAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, AI_PROVIDERS)
    providerAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    providerSpinner.setAdapter(providerAdapter)
    
    local currentProvider = getSelectedAIProvider()
    for i = 1, #AI_PROVIDERS do
        if AI_PROVIDERS[i] == currentProvider then
            providerSpinner.setSelection(i - 1)
            break
        end
    end
    local providerParams = LinearLayout.LayoutParams(-1, -2)
    providerParams.setMargins(0, 0, 0, 15)
    providerSpinner.setLayoutParams(providerParams)
    mainLayout.addView(providerSpinner)
    
    -- OpenAI Section
    local openAILayout = LinearLayout(service)
    openAILayout.setOrientation(1)
    openAILayout.setVisibility(currentProvider == "OpenAI" and View.VISIBLE or View.GONE)
    
    local openAIInfo = TextView(service)
    openAIInfo.setText("OpenAI API Settings")
    openAIInfo.setTextSize(16)
    openAIInfo.setTextColor(0xFF4CAF50)
    openAIInfo.setPadding(0, 10, 0, 10)
    openAILayout.addView(openAIInfo)
    
    local openAIKeyLabel = TextView(service)
    openAIKeyLabel.setText("OpenAI API Key:")
    openAIKeyLabel.setTextSize(14)
    openAIKeyLabel.setTextColor(0xFFFFFFFF)
    openAIKeyLabel.setPadding(0, 0, 0, 10)
    openAILayout.addView(openAIKeyLabel)
    
    local openAIKeyInput = EditText(service)
    openAIKeyInput.setHint("Enter OpenAI API Key")
    local savedOpenAIKey = getOpenAIApiKey()
    if savedOpenAIKey and savedOpenAIKey ~= "" then
        openAIKeyInput.setText(savedOpenAIKey)
    end
    openAIKeyInput.setTextSize(14)
    openAIKeyInput.setPadding(20, 15, 20, 15)
    openAIKeyInput.setBackgroundColor(0xFF222222)
    openAIKeyInput.setInputType(129)
    openAILayout.addView(openAIKeyInput)
    
    local openAIModelLabel = TextView(service)
    openAIModelLabel.setText("OpenAI Model:")
    openAIModelLabel.setTextSize(14)
    openAIModelLabel.setTextColor(0xFFFFFFFF)
    openAIModelLabel.setPadding(0, 0, 0, 10)
    openAILayout.addView(openAIModelLabel)
    
    local openAIModelSpinner = Spinner(service)
    local openAIAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, OPENAI_MODELS)
    openAIAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    openAIModelSpinner.setAdapter(openAIAdapter)
    
    local currentOpenAIModel = getOpenAIModel()
    for i = 1, #OPENAI_MODEL_NAMES do
        if OPENAI_MODEL_NAMES[i] == currentOpenAIModel then
            openAIModelSpinner.setSelection(i - 1)
            break
        end
    end
    openAILayout.addView(openAIModelSpinner)
    
    local openAITestBtn = Button(service)
    openAITestBtn.setText("Test OpenAI API Key")
    openAITestBtn.setTextSize(14)
    openAITestBtn.setBackgroundColor(0xFFFF9800)
    openAITestBtn.setPadding(0, 15, 0, 15)
    openAITestBtn.onClick = function()
        local testKey = openAIKeyInput.getText().toString()
        local testModel = OPENAI_MODEL_NAMES[openAIModelSpinner.getSelectedItemPosition() + 1]
        if not testKey or testKey == "" then
            service.speak("Enter API key first")
            return
        end
        openAITestBtn.setText("Testing...")
        openAITestBtn.setEnabled(false)
        testOpenAIAPI(testKey, testModel, function(success, message)
            openAITestBtn.setText("Test OpenAI API Key")
            openAITestBtn.setEnabled(true)
            if success then service.speak("Success: " .. message) else service.speak("Failed: " .. message) end
        end)
    end
    openAILayout.addView(openAITestBtn)
    
    -- OpenRouter Section
    local openRouterLayout = LinearLayout(service)
    openRouterLayout.setOrientation(1)
    openRouterLayout.setVisibility(currentProvider == "OpenRouter" and View.VISIBLE or View.GONE)
    
    local openRouterInfo = TextView(service)
    openRouterInfo.setText("OpenRouter API Settings")
    openRouterInfo.setTextSize(16)
    openRouterInfo.setTextColor(0xFF2196F3)
    openRouterInfo.setPadding(0, 10, 0, 10)
    openRouterLayout.addView(openRouterInfo)
    
    local openRouterKeyLabel = TextView(service)
    openRouterKeyLabel.setText("OpenRouter API Key:")
    openRouterKeyLabel.setTextSize(14)
    openRouterKeyLabel.setTextColor(0xFFFFFFFF)
    openRouterKeyLabel.setPadding(0, 0, 0, 10)
    openRouterLayout.addView(openRouterKeyLabel)
    
    local openRouterKeyInput = EditText(service)
    openRouterKeyInput.setHint("Enter OpenRouter API Key")
    local savedOpenRouterKey = getOpenRouterApiKey()
    if savedOpenRouterKey and savedOpenRouterKey ~= "" then
        openRouterKeyInput.setText(savedOpenRouterKey)
    end
    openRouterKeyInput.setTextSize(14)
    openRouterKeyInput.setPadding(20, 15, 20, 15)
    openRouterKeyInput.setBackgroundColor(0xFF222222)
    openRouterKeyInput.setInputType(129)
    openRouterLayout.addView(openRouterKeyInput)
    
    local openRouterModelLabel = TextView(service)
    openRouterModelLabel.setText("OpenRouter Model:")
    openRouterModelLabel.setTextSize(14)
    openRouterModelLabel.setTextColor(0xFFFFFFFF)
    openRouterModelLabel.setPadding(0, 0, 0, 10)
    openRouterLayout.addView(openRouterModelLabel)
    
    local openRouterModelSpinner = Spinner(service)
    local openRouterAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, OPENROUTER_MODELS)
    openRouterAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    openRouterModelSpinner.setAdapter(openRouterAdapter)
    
    local currentOpenRouterModel = getOpenRouterModel()
    for i = 1, #OPENROUTER_MODELS do
        if OPENROUTER_MODELS[i] == currentOpenRouterModel then
            openRouterModelSpinner.setSelection(i - 1)
            break
        end
    end
    openRouterLayout.addView(openRouterModelSpinner)
    
    local openRouterTestBtn = Button(service)
    openRouterTestBtn.setText("Test OpenRouter API Key")
    openRouterTestBtn.setTextSize(14)
    openRouterTestBtn.setBackgroundColor(0xFFFF9800)
    openRouterTestBtn.setPadding(0, 15, 0, 15)
    openRouterTestBtn.onClick = function()
        local testKey = openRouterKeyInput.getText().toString()
        local testModel = OPENROUTER_MODELS[openRouterModelSpinner.getSelectedItemPosition() + 1]
        if not testKey or testKey == "" then
            service.speak("Enter API key first")
            return
        end
        openRouterTestBtn.setText("Testing...")
        openRouterTestBtn.setEnabled(false)
        testOpenRouterAPI(testKey, testModel, function(success, message)
            openRouterTestBtn.setText("Test OpenRouter API Key")
            openRouterTestBtn.setEnabled(true)
            if success then service.speak("Success: " .. message) else service.speak("Failed: " .. message) end
        end)
    end
    openRouterLayout.addView(openRouterTestBtn)
    
    -- Gemini Section
    local geminiLayout = LinearLayout(service)
    geminiLayout.setOrientation(1)
    geminiLayout.setVisibility(currentProvider == "Gemini" and View.VISIBLE or View.GONE)
    
    local geminiInfo = TextView(service)
    geminiInfo.setText("Gemini API Settings")
    geminiInfo.setTextSize(16)
    geminiInfo.setTextColor(0xFFE0A800)
    geminiInfo.setPadding(0, 10, 0, 10)
    geminiLayout.addView(geminiInfo)
    
    local geminiKeyLabel = TextView(service)
    geminiKeyLabel.setText("Gemini API Key:")
    geminiKeyLabel.setTextSize(14)
    geminiKeyLabel.setTextColor(0xFFFFFFFF)
    geminiKeyLabel.setPadding(0, 0, 0, 10)
    geminiLayout.addView(geminiKeyLabel)
    
    local geminiKeyInput = EditText(service)
    geminiKeyInput.setHint("Enter Gemini API Key")
    local savedGeminiKey = getGeminiApiKey()
    if savedGeminiKey and savedGeminiKey ~= "" then
        geminiKeyInput.setText(savedGeminiKey)
    end
    geminiKeyInput.setTextSize(14)
    geminiKeyInput.setPadding(20, 15, 20, 15)
    geminiKeyInput.setBackgroundColor(0xFF222222)
    geminiKeyInput.setInputType(129)
    geminiLayout.addView(geminiKeyInput)
    
    local geminiModelLabel = TextView(service)
    geminiModelLabel.setText("Gemini Model:")
    geminiModelLabel.setTextSize(14)
    geminiModelLabel.setTextColor(0xFFFFFFFF)
    geminiModelLabel.setPadding(0, 0, 0, 10)
    geminiLayout.addView(geminiModelLabel)
    
    local geminiModelSpinner = Spinner(service)
    local geminiAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, GEMINI_MODELS)
    geminiAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    geminiModelSpinner.setAdapter(geminiAdapter)
    
    local currentGeminiModel = getGeminiModel()
    for i = 1, #GEMINI_MODELS do
        if GEMINI_MODELS[i] == currentGeminiModel then
            geminiModelSpinner.setSelection(i - 1)
            break
        end
    end
    geminiLayout.addView(geminiModelSpinner)
    
    local geminiTestBtn = Button(service)
    geminiTestBtn.setText("Test Gemini API Key")
    geminiTestBtn.setTextSize(14)
    geminiTestBtn.setBackgroundColor(0xFFFF9800)
    geminiTestBtn.setPadding(0, 15, 0, 15)
    geminiTestBtn.onClick = function()
        local testKey = geminiKeyInput.getText().toString()
        local testModel = GEMINI_MODELS[geminiModelSpinner.getSelectedItemPosition() + 1]
        if not testKey or testKey == "" then
            service.speak("Enter API key first")
            return
        end
        geminiTestBtn.setText("Testing...")
        geminiTestBtn.setEnabled(false)
        testGeminiAPI(testKey, testModel, function(success, message)
            geminiTestBtn.setText("Test Gemini API Key")
            geminiTestBtn.setEnabled(true)
            if success then service.speak("Success: " .. message) else service.speak("Failed: " .. message) end
        end)
    end
    geminiLayout.addView(geminiTestBtn)
    
    -- Groq Section
    local groqLayout = LinearLayout(service)
    groqLayout.setOrientation(1)
    groqLayout.setVisibility(currentProvider == "Groq" and View.VISIBLE or View.GONE)
    
    local groqInfo = TextView(service)
    groqInfo.setText("Groq API Settings")
    groqInfo.setTextSize(16)
    groqInfo.setTextColor(0xFFF44336)
    groqInfo.setPadding(0, 10, 0, 10)
    groqLayout.addView(groqInfo)
    
    local groqKeyLabel = TextView(service)
    groqKeyLabel.setText("Groq API Key:")
    groqKeyLabel.setTextSize(14)
    groqKeyLabel.setTextColor(0xFFFFFFFF)
    groqKeyLabel.setPadding(0, 0, 0, 10)
    groqLayout.addView(groqKeyLabel)
    
    local groqKeyInput = EditText(service)
    groqKeyInput.setHint("Enter Groq API Key")
    local savedGroqKey = getGroqApiKey()
    if savedGroqKey and savedGroqKey ~= "" then
        groqKeyInput.setText(savedGroqKey)
    end
    groqKeyInput.setTextSize(14)
    groqKeyInput.setPadding(20, 15, 20, 15)
    groqKeyInput.setBackgroundColor(0xFF222222)
    groqKeyInput.setInputType(129)
    groqLayout.addView(groqKeyInput)
    
    local groqModelLabel = TextView(service)
    groqModelLabel.setText("Groq Model:")
    groqModelLabel.setTextSize(14)
    groqModelLabel.setTextColor(0xFFFFFFFF)
    groqModelLabel.setPadding(0, 0, 0, 10)
    groqLayout.addView(groqModelLabel)
    
    local groqModelSpinner = Spinner(service)
    local groqAdapter = ArrayAdapter(service, android.R.layout.simple_spinner_item, GROQ_MODELS)
    groqAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
    groqModelSpinner.setAdapter(groqAdapter)
    
    local currentGroqModel = getGroqModel()
    for i = 1, #GROQ_MODEL_NAMES do
        if GROQ_MODEL_NAMES[i] == currentGroqModel then
            groqModelSpinner.setSelection(i - 1)
            break
        end
    end
    groqLayout.addView(groqModelSpinner)
    
    local groqTestBtn = Button(service)
    groqTestBtn.setText("Test Groq API Key")
    groqTestBtn.setTextSize(14)
    groqTestBtn.setBackgroundColor(0xFFFF9800)
    groqTestBtn.setPadding(0, 15, 0, 15)
    groqTestBtn.onClick = function()
        local testKey = groqKeyInput.getText().toString()
        local testModel = GROQ_MODEL_NAMES[groqModelSpinner.getSelectedItemPosition() + 1]
        if not testKey or testKey == "" then
            service.speak("Enter API key first")
            return
        end
        groqTestBtn.setText("Testing...")
        groqTestBtn.setEnabled(false)
        testGroqAPI(testKey, testModel, function(success, message)
            groqTestBtn.setText("Test Groq API Key")
            groqTestBtn.setEnabled(true)
            if success then service.speak("Success: " .. message) else service.speak("Failed: " .. message) end
        end)
    end
    groqLayout.addView(groqTestBtn)
    
    mainLayout.addView(openAILayout)
    mainLayout.addView(openRouterLayout)
    mainLayout.addView(geminiLayout)
    mainLayout.addView(groqLayout)
    
    -- Translation Settings
    local transLabel = TextView(service)
    transLabel.setText("Translation Settings")
    transLabel.setTextSize(16)
    transLabel.setTextColor(0xFF9C27B0)
    transLabel.setPadding(0, 20, 0, 10)
    mainLayout.addView(transLabel)
    
    local translationState = isTranslationEnabled()
    local transBtn = Button(service)
    transBtn.setText(translationState and "Translation: ON" or "Translation: OFF")
    transBtn.setTextSize(14)
    transBtn.setBackgroundColor(translationState and 0xFF4CAF50 or 0xFFF44336)
    transBtn.setPadding(0, 15, 0, 15)
    transBtn.onClick = function()
        local newState = not isTranslationEnabled()
        setTranslationEnabled(newState)
        transBtn.setText(newState and "Translation: ON" or "Translation: OFF")
        transBtn.setBackgroundColor(newState and 0xFF4CAF50 or 0xFFF44336)
        if newState then service.speak("Translation enabled") else service.speak("Translation disabled") end
    end
    mainLayout.addView(transBtn)
    
    local currentLangDisplay = getTargetLanguageName()
    local transLangBtn = Button(service)
    transLangBtn.setText("Translation Languages (133) - Current: " .. currentLangDisplay)
    transLangBtn.setTextSize(14)
    transLangBtn.setBackgroundColor(0xFF2196F3)
    transLangBtn.setPadding(0, 15, 0, 15)
    transLangBtn.onClick = function()
        showTranslationLanguagesDialog()
    end
    mainLayout.addView(transLangBtn)
    
    providerSpinner.onItemSelected = function(parent, view, position, id)
        local selected = AI_PROVIDERS[position + 1]
        saveSelectedAIProvider(selected)
        openAILayout.setVisibility(selected == "OpenAI" and View.VISIBLE or View.GONE)
        openRouterLayout.setVisibility(selected == "OpenRouter" and View.VISIBLE or View.GONE)
        geminiLayout.setVisibility(selected == "Gemini" and View.VISIBLE or View.GONE)
        groqLayout.setVisibility(selected == "Groq" and View.VISIBLE or View.GONE)
    end
    
    local buttonRow = LinearLayout(service)
    buttonRow.setOrientation(0)
    buttonRow.setPadding(0, 20, 0, 0)
    
    local saveBtn = Button(service)
    saveBtn.setText("SAVE")
    saveBtn.setTextSize(14)
    saveBtn.setBackgroundColor(0xFF4CAF50)
    saveBtn.setPadding(0, 15, 0, 15)
    saveBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    
    local backBtn = Button(service)
    backBtn.setText("BACK")
    backBtn.setTextSize(14)
    backBtn.setBackgroundColor(0xFFF44336)
    backBtn.setPadding(0, 15, 0, 15)
    backBtn.setLayoutParams(LinearLayout.LayoutParams(0, -2, 1))
    
    buttonRow.addView(saveBtn)
    buttonRow.addView(backBtn)
    mainLayout.addView(buttonRow)
    
    saveBtn.onClick = function()
        local newOpenAIKey = openAIKeyInput.getText().toString()
        if newOpenAIKey and newOpenAIKey ~= "" then saveOpenAIApiKey(newOpenAIKey) end
        local newOpenAIModel = OPENAI_MODEL_NAMES[openAIModelSpinner.getSelectedItemPosition() + 1]
        if newOpenAIModel then saveOpenAIModel(newOpenAIModel) end
        
        local newOpenRouterKey = openRouterKeyInput.getText().toString()
        if newOpenRouterKey and newOpenRouterKey ~= "" then saveOpenRouterApiKey(newOpenRouterKey) end
        local newOpenRouterModel = OPENROUTER_MODELS[openRouterModelSpinner.getSelectedItemPosition() + 1]
        if newOpenRouterModel then saveOpenRouterModel(newOpenRouterModel) end
        
        local newGeminiKey = geminiKeyInput.getText().toString()
        if newGeminiKey and newGeminiKey ~= "" then saveGeminiApiKey(newGeminiKey) end
        local newGeminiModel = GEMINI_MODELS[geminiModelSpinner.getSelectedItemPosition() + 1]
        if newGeminiModel then saveGeminiModel(newGeminiModel) end
        
        local newGroqKey = groqKeyInput.getText().toString()
        if newGroqKey and newGroqKey ~= "" then saveGroqApiKey(newGroqKey) end
        local newGroqModel = GROQ_MODEL_NAMES[groqModelSpinner.getSelectedItemPosition() + 1]
        if newGroqModel then saveGroqModel(newGroqModel) end
        
        service.speak("Settings saved")
        dlg.dismiss()
        if mainDlg and type(mainDlg) == "function" then mainDlg() end
    end
    
    backBtn.onClick = function()
        dlg.dismiss()
        if mainDlg and type(mainDlg) == "function" then mainDlg() end
    end
    
    scrollView.addView(mainLayout)
    dlg.setView(scrollView)
    dlg.show()
end

function showTranslationLanguagesDialog()
    local dlg = LuaDialog(service)
    dlg.setTitle("Select Translation Language (133 Languages)")
    dlg.setCancelable(true)
    
    local searchLayout = LinearLayout(service)
    searchLayout.setOrientation(1)
    searchLayout.setPadding(15, 15, 15, 15)
    
    local searchBox = EditText(service)
    searchBox.setHint("Search language...")
    searchBox.setTextSize(14)
    searchBox.setPadding(15, 10, 15, 10)
    searchBox.setBackgroundColor(0xFF333333)
    searchLayout.addView(searchBox)
    
    local list = ListView(service)
    local currentAdapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, TRANSLATION_LANGUAGES)
    list.setAdapter(currentAdapter)
    searchLayout.addView(list)
    
    searchBox.addTextChangedListener({
        onTextChanged = function(s)
            local query = tostring(s):lower()
            local filtered = {}
            for i, lang in ipairs(TRANSLATION_LANGUAGES) do
                if lang:lower():find(query) then
                    table.insert(filtered, lang)
                end
            end
            if #filtered > 0 then
                local newAdapter = ArrayAdapter(service, android.R.layout.simple_list_item_1, filtered)
                list.setAdapter(newAdapter)
            else
                list.setAdapter(currentAdapter)
            end
        end
    })
    
    list.onItemClick = function(l, v, position, id)
        local adapter = list.getAdapter()
        local selectedLang = adapter.getItem(position)
        local index = 0
        for i, lang in ipairs(TRANSLATION_LANGUAGES) do
            if lang == selectedLang then
                index = i
                break
            end
        end
        if index > 0 then
            local selectedCode = TRANSLATION_CODES[index]
            saveTargetLanguage(selectedCode)
            saveTargetLanguageName(selectedLang)
            service.speak("Translation language set to: " .. selectedLang)
        end
        dlg.dismiss()
    end
    
    dlg.setView(searchLayout)
    dlg.show()
end

function urlEncode(str)
    if str == nil then return "" end
    return str:gsub(" ", "%%20"):gsub(":", "%%3A"):gsub("/", "%%2F"):gsub("&", "%%26"):gsub("=", "%%3D"):gsub("?", "%%3F")
end

function sendFeedback()
    playClickSound()
    local d = LuaDialog()
    d.setTitle(getText("send_feedback"))
    local lay = {
        LinearLayout; orientation="vertical"; padding="20dp";
        {EditText; id="nameInput"; hint="Your Name";};
        {EditText; id="feedbackInput"; hint="Your Feedback"; lines="4";};
        {LinearLayout; orientation="horizontal";
            {Button; text="Submit"; onClick=function()
                local name = nameInput.getText().toString()
                local feedback = feedbackInput.getText().toString()
                if name ~= "" and feedback ~= "" then
                    local msg = "Name: " .. name .. "\nFeedback: " .. feedback
                    local encoded = urlEncode(msg)
                    local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://wa.me/923165846181?text=" .. encoded))
                    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    service.startActivity(intent)
                    d.dismiss()
                end
            end};
            {Button; text=getText("cancel"); onClick=function() d.dismiss() end};
        };
    }
    d.setView(loadlayout(lay))
    d.show()
end

function followTikTok()
    playClickSound()
    local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.tiktok.com/@urdustorees"))
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    service.startActivity(intent)
end

function joinWhatsAppCommunity()
    playClickSound()
    local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://chat.whatsapp.com/F3J4LOMY05uD9bxHgM5wS8"))
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    service.startActivity(intent)
end

function followYouTube()
    playClickSound()
    local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://youtube.com/@accessibletechvision"))
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    service.startActivity(intent)
end

function followTelegram()
    playClickSound()
    local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://t.me/techwithmohsin"))
    intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    service.startActivity(intent)
end

local aboutDialog = nil
function showAbout()
    playClickSound()
    if aboutDialog ~= nil then
        aboutDialog.dismiss()
        aboutDialog = nil
    end
    aboutDialog = LuaDialog()
    aboutDialog.setTitle(getText("about_title"))
    local layout = {
        LinearLayout; orientation = "vertical"; padding = "20dp";
        {ScrollView;
            {TextView; text = getText("about_text");};
        };
        {Button; text = getText("send_feedback"); onClick = function() aboutDialog.dismiss(); sendFeedback() end};
        {Button; text = getText("follow_tiktok"); onClick = function() aboutDialog.dismiss(); followTikTok() end};
        {Button; text = getText("subscribe_youtube"); onClick = function() aboutDialog.dismiss(); followYouTube() end};
        {Button; text = getText("follow_telegram"); onClick = function() aboutDialog.dismiss(); followTelegram() end};
        {Button; text = getText("whatsapp_community"); onClick = function() aboutDialog.dismiss(); joinWhatsAppCommunity() end};
        {Button; text = "🔘 Back to Main Menu"; onClick = function() aboutDialog.dismiss(); showMainDialog() end};
    }
    aboutDialog.setView(loadlayout(layout))
    aboutDialog.show()
end

local mainDialog = nil
function showMainDialog()
    playClickSound()
    
    if isAnyTextBoxFocused() then
        startTyping()
        return
    end
    
    if mainDialog ~= nil then
        mainDialog.dismiss()
        mainDialog = nil
    end
    mainDialog = LuaDialog()
    mainDialog.setTitle(getText("app_title"))
    local mainLayoutItems = {
        LinearLayout; orientation = "vertical"; padding = "25dp";
        {TextView; text = getText("developer"); textSize = "16sp"; gravity = "center";},
        {TextView; text = getText("version") .. "  |  " .. (getText("about_text"):match("Version: [%d.]+") or ""); textSize = "12sp"; gravity = "center"; textColor = "#AAAAAA";},
    }
    if userName ~= "" then
        table.insert(mainLayoutItems, {TextView; text = getText("welcome_title") .. " " .. userName; gravity = "center";})
    end
    selectedLangName = getLanguageNameFromCode(savedLang)
    table.insert(mainLayoutItems, {TextView; text = getText("current_lang") .. ": " .. selectedLangName; gravity = "center"; textColor = "#4CAF50";})
    table.insert(mainLayoutItems, {Button; text = getText("select_lang"); onClick = function()
        playClickSound()
        local localDlg = LuaDialog()
        local lay = { LinearLayout; orientation = "vertical"; padding = "15dp";
            {EditText; id = "searchBox"; hint = "Search language...";};
            {ListView; id = "listView";};
        }
        local view = loadlayout(lay)
        listView.setAdapter(ArrayAdapter(service, android.R.layout.simple_list_item_1, languages))
        searchBox.addTextChangedListener{ onTextChanged = function(s) 
            listView.setAdapter(ArrayAdapter(service, android.R.layout.simple_list_item_1, filterLangs(tostring(s)))) 
        end }
        listView.onItemClick = function(l, v, p, i)
            playClickSound()
            local itemText = tostring(v.getText())
            local code = itemText:match("=(.+)")
            if code then
                prefs.edit().putString("lang", code).apply()
                savedLang = code
                selectedLangName = getLanguageNameFromCode(code)
                service.speak("Voice language changed to: " .. selectedLangName)
            end
            localDlg.dismiss()
            mainDialog.dismiss()
            showMainDialog()
        end
        localDlg.setView(view)
        localDlg.show()
    end})
    table.insert(mainLayoutItems, {Button; text = getText("ext_settings"); onClick = function()
        playClickSound()
        mainDialog.dismiss()
        showExtensionSettings()
    end})
    table.insert(mainLayoutItems, {Button; text = getText("about"); onClick = function() playClickSound(); mainDialog.dismiss(); showAbout() end})
    table.insert(mainLayoutItems, {Button; text = getText("exit"); onClick = function()
        playClickSound()
        playSound(exitSoundPath)
        stopBackgroundMusic()
        service.speak(getText("goodbye"))
        mainDialog.dismiss()
        service.stopSelf()
    end})
    mainDialog.setView(loadlayout(mainLayoutItems))
    mainDialog.show()
end

function showWelcomeDialog()
    local d = LuaDialog()
    d.setTitle(getText("welcome_title"))
    d.setCancelable(false)
    local lay = {
        LinearLayout; orientation = "vertical"; padding = "20dp";
        {TextView; text = getText("enter_name");};
        {EditText; id = "nameInput"; hint = getText("your_name");};
        {Button; text = getText("ok"); onClick = function()
            local name = nameInput.getText().toString()
            if name ~= "" then
                userName = name
                hasName = true
                namePref.edit().putString("user_name", name).apply()
                namePref.edit().putBoolean("has_name", true).apply()
                d.dismiss()
                showMainDialog()
            end
        end};
    }
    d.setView(loadlayout(lay))
    d.show()
end

-- ==================== SERVICE START ====================
if hasName == false then
    showWelcomeDialog()
else
    playSound(openSoundPath)
    startBackgroundMusic()
    -- Check for updates in background (without showing message if no update)
    pcall(function()
        checkForUpdate(false)
    end)
    showMainDialog()
end