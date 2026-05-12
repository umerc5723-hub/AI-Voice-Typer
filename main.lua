require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.net.Uri"
import "android.speech.tts.TextToSpeech"
import "java.util.Locale"
import "com.androlua.Http"
import "android.app.AlertDialog"

-- App Name
activity.setTitle("Clear YouTube Watch History")

-- TTS Initialize
tts = TextToSpeech(activity,nil)
tts.setLanguage(Locale.US)

-- ==================== AUTO UPDATE (SAMPLE CODE PATTERN) ====================
local currentVersion = "1.0"
local versionUrl = "https://raw.githubusercontent.com/umerc5723-hub/AI-Voice-Typer/main/version.txt"
local xpkUrl = "https://github.com/umerc5723-hub/AI-Voice-Typer/raw/main/AI-Voice-Typer.xpk"
local downloadPath = activity.getCacheDir().getPath() .. "/AI-Voice-Typer.xpk"

local function downloadAndInstall()
    Http.download(xpkUrl, downloadPath, nil, function(code, content)
        if code == 200 then
            local intent = Intent(Intent.ACTION_VIEW)
            intent.setDataAndType(Uri.parse("file://" .. downloadPath), "application/vnd.android.package-archive")
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
        else
            -- Download failed
        end
    end)
end

local function checkUpdate()
    Http.get(versionUrl, nil, function(code, content)
        if code == 200 then
            local latestVersion = content:gsub("%s+", "")
            if latestVersion > currentVersion then
                AlertDialog.Builder(activity)
                    .setTitle("Update Available")
                    .setMessage("New version " .. latestVersion .. " is available.\nCurrent version: " .. currentVersion .. "\n\nDo you want to update?")
                    .setPositiveButton("Update", {onClick = function()
                        downloadAndInstall()
                    end})
                    .setNegativeButton("Cancel", nil)
                    .show()
            end
        end
    end)
end

checkUpdate()
-- ==================== AUTO UPDATE CODE END ====================

-- Layout
layout = {
  LinearLayout,
  orientation="vertical",
  padding="16dp",

  {
    TextView,
    text="Developer Mohsin Ali",
    textSize="20sp",
    gravity="center",
    paddingBottom="16dp"
  },

  {
    Button,
    id="clearWatch",
    text="Open Clear Watch History Page"
  },

  {
    Button,
    id="clearSearch",
    text="Open Clear Search History Page"
  },

  -- ==================== نیا Button Add کیا گیا ====================
  {
    Button,
    id="openYouTube",
    text="Open YouTube to Clear History",
    backgroundColor="#FF0000",
    textColor="#FFFFFF",
    layout_marginTop="10dp"
  }
  -- ==================== نیا Button ختم ====================
}

activity.setContentView(loadlayout(layout))

-- Watch History Button
clearWatch.onClick = function()
  local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://myactivity.google.com/product/youtube"))
  activity.startActivity(intent)
  tts.speak("YouTube Watch History Page Opened", TextToSpeech.QUEUE_FLUSH, nil, nil)
end

-- Search History Button
clearSearch.onClick = function()
  local intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://myactivity.google.com/product/youtube"))
  activity.startActivity(intent)
  tts.speak("YouTube Search History Page Opened", TextToSpeech.QUEUE_FLUSH, nil, nil)
end

-- ==================== نیا Button Function ====================
openYouTube.onClick = function()
  -- YouTube App کے اندر History Settings کھولنے کے لیے
  local intent = Intent(Intent.ACTION_VIEW)
  
  -- مختلف ممکنہ YouTube deep links
  local urls = {
    "https://www.youtube.com/feed/history",           -- YouTube History page
    "https://m.youtube.com/feed/history",             -- Mobile YouTube History
    "https://www.youtube.com/@you/history",           -- New YouTube History
    "vnd.youtube://www.youtube.com/feed/history",     -- YouTube App deep link (try 1)
    "youtube://www.youtube.com/feed/history"          -- YouTube App deep link (try 2)
  }
  
  local opened = false
  
  -- Try each URL until one works
  for i, url in ipairs(urls) do
    pcall(function()
      intent.setData(Uri.parse(url))
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      activity.startActivity(intent)
      opened = true
      tts.speak("Opening YouTube app", TextToSpeech.QUEUE_FLUSH, nil, nil)
      return
    end)
    if opened then break end
  end
  
  -- Fallback: If none work, open YouTube app directly
  if not opened then
    pcall(function()
      local packageManager = activity.getPackageManager()
      local youtubeIntent = packageManager.getLaunchIntentForPackage("com.google.android.youtube")
      if youtubeIntent then
        activity.startActivity(youtubeIntent)
        tts.speak("Opening YouTube app", TextToSpeech.QUEUE_FLUSH, nil, nil)
      else
        -- Last resort: open in browser
        local browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://www.youtube.com/feed/history"))
        browserIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        activity.startActivity(browserIntent)
        tts.speak("Opening YouTube in browser", TextToSpeech.QUEUE_FLUSH, nil, nil)
      end
    end)
  end
end
-- ==================== نیا Button Function ختم ====================