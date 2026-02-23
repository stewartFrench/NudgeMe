# SLF_notes

2026/02/12 - S.French

I am experimenting with Claude's ability to create a new app with only
my prompts to go on.
I have given it a series of prompts along with some coding guidelines.

## Overview

This is a "Tick Tick" app.  It ticks periodically to remind me what I
am doing.

### Code Format Rules

- Put '{' and '}' on separate lines and have matching braces line up.

- Add a comment after every '}' to indicate what it is closing.
  For example, "// HStack" or "// ScrollView"  or "// if" etc

- Place all function parameters on separate lines and aligning the ':'s  up.

- When indenting use only 2 spaces.

## Claude Prompts

I want an iPhone app that will make a short sound at a given interval.
The interval should be settable by the user at the second, minute, and hourly intervals.
I should be able to create several interval instances each with it's own sound.
The short sound should be one of the many standard iPhone sounds.
I should be able to select the sound for any given interval.
I should be able to create an interval instance, start it ticking, stop it ticking, and delete it.
It will continue ticking even when in background or the iPhone is in standby.

Add some shorter sounds like a simple Ding, or Tick, or Tick, or Blip.

-----
2026/02/13 - S.French

For each Interval Timer Instance in the list view, add the time-of-day of the
next occurence.

-----
The purpose of this app is the remind me periodically that I should 
take a break, or perhaps switch to another task.
It is to make me more mindful of how I am spending my time.
What should I call this app?  I need a very short name, 
or contraction of several names, preferably cute and memorable
so people can remember it easily.

Answer:

Great question! Here are some short, cute, and memorable name 
suggestions for your mindfulness/break reminder app:

Top Suggestions

TickTock - Perfect fit since:
• Short and catchy (2 syllables)
• Relates to time passing
• Already using "Tick" in your project name
• Easy to remember and say
• Cute sound to it

Nudge - Because it:
• Gently reminds you to be mindful
• Short (1 syllable)
• Friendly and non-intrusive feeling
• Memorable

Mindbell - Combines:
• Mindfulness with bell/chime reminder
• 2 syllables, easy to say
• Evokes the meditation bell concept

Other Options

Breather - Reminds you to take a breath/break

Tempo - Controls the pace of your day

Ping - Short, cute, matches the notification sounds

Chime - Simple, relates to the alert sounds

Pomo - If you want to invoke Pomodoro technique vibes

Beat - Like keeping the beat/rhythm of your work

My personal favorite is TickTock - it's playful, memorable, directly 
relates to your interval timing functionality, and has a nice friendly 
sound that fits the mindfulness purpose. Plus, you're already halfway 
there with "NudgeMe" as your project name!


-----
2026/02/13 - S.French (continued)

## Background Audio Implementation

### Current Behavior:
- **When app is active/foreground**: Plays your selected custom sound (Tock, Tink, Pop, etc.)
- **When app is in background/locked**: Plays default iOS notification sound

### iOS Limitation Explanation:
Unfortunately, iOS has strict limitations on background notifications:
- System sounds (accessed via AudioServicesPlaySystemSound) can ONLY be played when the app is in the foreground
- Background notifications can only play:
  1. The default notification sound, OR
  2. Custom audio files bundled with the app (aiff, caf, wav format)

Since we're using iOS system sounds (sound IDs like 1103, 1104, etc.), these cannot be played from background notifications.

### Possible Solutions (not implemented):
1. Create/record custom audio files matching each sound and bundle them with the app
2. Use only a single default sound for all timers
3. Accept the current behavior (custom sounds in foreground, default in background)

### Current Setup:
Background Modes capability is enabled with "Audio, AirPlay, and Picture in Picture" checked.
The app uses local notifications to remind you even when in background, but will use the default notification sound in that case.

-----
end

