package app.noorify.noorify

import com.ryanheise.audioservice.AudioServiceActivity

// audio_service needs its activity so the media notification can reopen the
// app.
class MainActivity : AudioServiceActivity()
