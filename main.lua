require "import"
import "android.widget.*"
import "android.view.*"
import "android.content.*"
import "android.net.Uri"
import "android.speech.tts.TextToSpeech"
import "java.util.Locale"

-- App Name
activity.setTitle("Clear YouTube Watch History")

-- TTS Initialize
tts = TextToSpeech(activity,nil)
tts.setLanguage(Locale.US)

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
  }
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