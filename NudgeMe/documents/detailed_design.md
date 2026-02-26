# NudgeMe - Detailed Design Document

**Project**: NudgeMe (formerly TickTick_1)  
**Date Created**: 2026-02-12  
**Author**: Stewart French with Claude Sonnet 4.5  
**Last Updated**: 2026-02-24

----------------------------------------------

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Data Models](#data-models)
4. [Core Components](#core-components)
5. [Audio System](#audio-system)
6. [Custom Sound Management](#custom-sound-management)
7. [Notification System](#notification-system)
8. [Background Execution](#background-execution)
9. [User Interface](#user-interface)
10. [Implementation Details](#implementation-details)
11. [Known Limitations](#known-limitations)
12. [Development History](#development-history)

----------------------------------------------

## Project Overview

### Purpose
NudgeMe is a mindfulness and productivity iPhone application that helps users stay aware of how they spend their time by providing periodic audio reminders at customizable intervals.

--------
### Core Functionality
- Create multiple independent interval timers
- Customize each timer with:
  - User-defined name
  - Interval duration (seconds, minutes, hours)
  - Custom sound selection (built-in or imported)
  - Volume control
- Import custom audio files from Voice Memos or other sources
- Manage (delete) imported custom sounds
- Start/stop timers independently
- Continue ticking in background and when device is locked
- Display next occurrence time for each active timer

--------
### Name Origin

The application was renamed from "TickTick_1" to "NudgeMe" to better reflect its purpose as a gentle reminder system that nudges users to be mindful of their time usage.

---

## Architecture

--------
### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        NudgeMeApp                           │
│                    (Application Entry)                      │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴──────────┬────────────────┬──────────────┐
         │                      │                │              │
┌────────▼────────┐  ┌──────────▼──────┐  ┌──────▼─────────┐ ┌──▼──────────┐
│  TimerManager   │  │ ContentHostView │  │ Notification   │ │   Import    │
│  (@MainActor)   │  │ (Alert Host)    │  │ Delegate       │ │   Manager   │
└────────┬────────┘  └──────────┬──────┘  └────────────────┘ └─────────────┘
         │                      │
         │                      │
         ├──────────────────────┼─────────────────┬────────────┐
         │                      │                 │            │
┌────────▼────────┐  ┌──────────▼──────┐  ┌───────▼──────┐ ┌───▼──────────┐
│ IntervalTimer   │  │ TimerList       │  │ TimerEdit    │ │   Custom     │
│ (Data Model)    │  │ View            │  │ View         │ │   Sound      │
└─────────────────┘  └─────────────────┘  └──────┬───────┘ │   Manager    │
                                                 │         └──────────────┘
                                         ┌───────▼-────────┐
                                         │ ManageCustom    │
                                         │ Sounds View     │
                                         └─────────────────┘
```

--------
### Design Pattern
The application follows the MVVM (Model-View-ViewModel) pattern with SwiftUI:
- **Model**: `IntervalTimer` (Codable struct), `SoundFile` (struct)
- **ViewModel**: `TimerManager` (ObservableObject), `ImportManager` (ObservableObject), `CustomSoundManager` (singleton)
- **View**: SwiftUI views (`TimerListView`, `TimerEditView`, `ManageCustomSoundsView`, `ContentHostView`)

---

----------------------------------------------
## Data Models

--------
### IntervalTimer

Located in: `NudgeMe/TimerModel.swift`

```swift
struct IntervalTimer: Identifiable, Codable
{
  let id: UUID
  var name: String
  var intervalSeconds: TimeInterval
  var soundFileName: String
  var volume: Float
  var isRunning: Bool
  var nextFireDate: Date?
}
```

**Properties**:
- `id`: Unique identifier for each timer instance
- `name`: User-defined name for the timer
- `intervalSeconds`: Duration between notifications (in seconds)
- `soundFileName`: Name of the audio file to play (e.g., "Marimba_Bb3.caf")
- `volume`: Playback volume (0.0 to 1.0)
- `isRunning`: Current state of the timer
- `nextFireDate`: Scheduled time for next notification (nil if stopped)

**Persistence**:
- Conforms to `Codable` protocol for JSON serialization
- Stored in UserDefaults under key "savedTimers"
- Automatically saved on every timer state change

---

----------------------------------------------
## Core Components

--------
### TimerManager

Located in: `NudgeMe/TimerManager.swift`

**Role**: Central coordinator for all timer operations, audio playback, and notification scheduling.

**Key Responsibilities**:
1. Timer lifecycle management (create, start, stop, delete)
2. Audio session configuration and playback
3. Local notification scheduling
4. Persistence (save/load from UserDefaults)
5. Background audio management

**Important Attributes**:
- `@MainActor`: Ensures all UI updates happen on the main thread
- `ObservableObject`: Allows SwiftUI views to observe state changes
- `@Published var timers`: Reactive array of all timer instances

**Audio Management**:
```swift
private let audioSession = AVAudioSession.sharedInstance()
private var silentPlayer: AVAudioPlayer?
private var timerAudioPlayers: [UUID: AVAudioPlayer] = [:]
```

- `audioSession`: Configured for background playback with `.playback` category
- `silentPlayer`: Plays silent audio loop to keep app active in background
- `timerAudioPlayers`: Persistent audio players for each timer (prevents recreation overhead)

**Timer Execution**:
```swift
private var activeTimers: [UUID: Timer] = [:]
```
- Foundation `Timer` objects that fire at specified intervals
- Each timer has weak self reference to prevent retain cycles
- Timers are stored in dictionary keyed by timer ID for easy lookup

---

--------
### Built-In Sound Files

Located in: `NudgeMe/Sounds/` directory (bundled with app)

**Role**: Pre-generated high-quality audio files that ship with the application.

**Available Sounds** (20 total):
1. **Marimba_Bb1.caf** - Deep marimba tone
2. **Marimba_Bb2.caf** - Mid marimba tone
3. **Marimba_Bb3.caf** - High marimba tone
4. **Xylo_Bb4.caf** - High xylophone tone
5. **Xylo_Bb5.caf** - Very high xylophone tone
6. **SLF_Hey.caf** - Custom compound tone
7. **SLF_Change.caf** - Custom compound tone
8. **TongueDrum_3.1.caf** - Tongue drum low
9. **TongueDrum_4.caf** - Tongue drum mid-low
10. **TongueDrum_5.caf** - Tongue drum mid
11. **TongueDrum_5.1.caf** - Tongue drum mid-high
12. **Vibraphone.caf** - Vibraphone tone
13. **Music_Box.caf** - Music box chime
14. **Absolute_Zero.caf** - Custom tone
15. **Boxy_Room_Pluck.caf** - Plucked string
16. **Mini_Marimba.caf** - Small marimba
17. **Pensive_Pluck.caf** - Mellow pluck
18. **Silicon_Pluck.caf** - Synthetic pluck
19. **Sweet_Luck_Chime.caf** - Bell chime

**Technical Details**:
- All files are in CAF (Core Audio Format)
- Pre-generated and bundled with app (no runtime generation)
- Optimized for iOS notification sounds
- Loaded directly from app bundle
- App developer can easily add CAF files by putting them in the Sounds folder.
  No other changes are required.

**Sound Selection**:

Users can choose from these built-in sounds or import their own custom audio files via the CustomSoundManager.

---

----------------------------------------------
## Audio System

--------
### Foreground Audio Playback

**Implementation**:
```swift

private func playSoundForTimer(_ timer: IntervalTimer)
{
  // Get or create the audio player for this timer
  if timerAudioPlayers[timer.id] == nil {
    // Create new AVAudioPlayer for this timer
    let player = try AVAudioPlayer(contentsOf: soundURL)
    player.volume = timer.volume
    player.prepareToPlay()
    timerAudioPlayers[timer.id] = player
  }
  
  // Play the sound from the beginning
  timerAudioPlayers[timer.id]?.currentTime = 0
  timerAudioPlayers[timer.id]?.play()
}
```

**Key Features**:
- Persistent audio players per timer (avoids recreation overhead)
- Immediate playback from beginning (resets currentTime to 0)
- Volume control per timer
- Optimized for rapid repeated playback

--------
### Background Audio Strategy

**Problem**: iOS suspends apps in background, preventing timer execution.

**Solution**: Silent audio loop keeps app active
```swift

private func setupBackgroundAudio()
{
  // Configure audio session for background playback
  try audioSession.setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers]
  )
  try audioSession.setActive(true)
  
  // Create silent audio player
  silentPlayer = try AVAudioPlayer(contentsOf: silenceURL)
  silentPlayer?.numberOfLoops = -1  // Loop forever
  silentPlayer?.volume = 0.0        // Silent
}
```

**Activation Logic**:
```swift

private func updateSilentAudioState()
{
  let hasRunningTimers = timers.contains { $0.isRunning }
  
  if hasRunningTimers {
    silentPlayer?.play()   // Keep app alive
  } else {
    silentPlayer?.stop()   // Allow app to sleep
  }
}
```

**Silent Audio File**:
- Location: Temporary directory (created on-demand)
- Duration: 1 second of silence
- Format: M4A (MPEG-4 AAC)
- Purpose: Minimal battery impact while keeping app active

---

----------------------------------------------
## Custom Sound Management

--------
### Overview

NudgeMe allows users to import their own audio files to use as timer sounds, in addition to the built-in generated sounds. This feature enables personalization with recordings from Voice Memos, downloaded sound effects, or any audio file.

--------
### CustomSoundManager

Located in: `NudgeMe/CustomSoundManager.swift`

**Role**: Manages the lifecycle of user-imported audio files.

**Key Responsibilities**:

1. Import audio files from external sources
2. Convert audio to CAF format for iOS notification compatibility
3. Store custom sounds in app's Documents directory
4. List all custom sounds
5. Delete custom sounds
6. Handle duplicate filenames

**Storage Location**:
```swift

Documents/CustomSounds/
```

Custom sounds are stored in the app's Documents directory under a `CustomSounds` subdirectory, separate from the built-in sounds in the app bundle.

--------
### Import Process

**Supported Formats**:
- CAF (Core Audio Format)
- M4A (MPEG-4 Audio) - Voice Memos default
- MP3
- WAV
- AIFF/AIFC

**Import Workflow**:

```swift

func importSound(from sourceURL: URL) -> Result<String, Error>
{
  // 1. Access security-scoped resource
  let accessed = sourceURL.startAccessingSecurityScopedResource()
  
  // 2. Validate audio format
  guard supportedFormats.contains(fileExtension) else {
    throw CustomSoundError.unsupportedFormat
  }
  
  // 3. Convert to CAF format
  let cafFileName = "\(baseName).caf"
  try convertToCAF(sourceURL: sourceURL, destinationURL: finalURL)
  
  // 4. Return success with filename
  return .success(cafFileName)
}
```

**Conversion to CAF**:
```swift
private func convertToCAF(sourceURL: URL, destinationURL: URL) throws
{
  // Read source audio file
  let sourceFile = try AVAudioFile(forReading: sourceURL)
  
  // Create output file in CAF format
  let outputFile = try AVAudioFile(
    forWriting: destinationURL,
    settings: outputFormat.settings,
    commonFormat: outputFormat.commonFormat,
    interleaved: outputFormat.isInterleaved
  )
  
  // Copy audio data in chunks
  while sourceFile.framePosition < sourceFile.length {
    try sourceFile.read(into: buffer)
    try outputFile.write(from: buffer)
  }
}
```

**Why CAF Format?**

- Native iOS audio format
- Required for local notification sounds
- Supports all audio codecs
- Efficient for short audio clips
- No quality loss during conversion

--------
### Duplicate Handling

When importing a file with a name that already exists, the system automatically adds a numeric suffix:

```
Recording.caf      (original)
Recording_1.caf    (first duplicate)
Recording_2.caf    (second duplicate)
```

--------
### User Interface Integration

#### Import Methods

**1. File Picker (Primary Method)**
```swift

.fileImporter(
  isPresented: $showingFilePicker,
  allowedContentTypes: [.audio],
  allowsMultipleSelection: false
)
```

Users can:

- Browse to any accessible audio file
- Import from Files app, iCloud Drive, or Downloads
- Get immediate feedback on success/failure

**Workflow for Voice Memos**:

1. Open Voice Memos app
2. Select a recording
3. Tap Share → "Save to Files"
4. Save to Downloads or any folder
5. Return to NudgeMe
6. Tap "Import Custom Sound from Files"
7. Browse to the saved file
8. File is imported and converted automatically

**2. Share Sheet (Secondary Method - Limited)**

The app is registered to handle audio files via iOS Share Sheet, though this method has limitations due to iOS restrictions on document handling.

Info.plist configuration:
```xml
<key>CFBundleDocumentTypes</key>
<array>
  <dict>
    <key>CFBundleTypeName</key>
    <string>Audio File</string>
    <key>CFBundleTypeRole</key>
    <string>Viewer</string>
    <key>LSHandlerRank</key>
    <string>Owner</string>
    <key>LSItemContentTypes</key>
    <array>
      <string>public.audio</string>
    </array>
  </dict>
</array>
```

--------
### Manage Custom Sounds View

Located in: `NudgeMe/TimerEditView.swift` (ManageCustomSoundsView struct)

**Features**:

- List all imported custom sounds
- Delete individual sounds
- Automatically refresh sound list after deletion
- Empty state message when no custom sounds exist

**UI Layout**:
```
┌─────────────────────────────────────┐
│  ← Manage Custom Sounds      [Done] │
├─────────────────────────────────────┤
│  My Recording               [🗑]    │
│  Notification Tone          [🗑]    │
│  Custom Alert               [🗑]    │
└─────────────────────────────────────┘
```

**Delete Operation**:
```swift

private func deleteSound(_ sound: SoundFile)
{
  try CustomSoundManager.shared.deleteCustomSound(fileName: sound.fileName)
  loadCustomSounds()      // Refresh list
  onSoundsChanged()       // Notify parent view
}
```

--------
### Sound File Display

**Built-in vs Custom Distinction**:

The `SoundFile` model tracks whether a sound is custom:
```swift
struct SoundFile: Identifiable, Hashable
{
  let fileName: String
  let isCustom: Bool
  var name: String  // Display name with 📁 prefix if custom
}
```

**Display Format**:

- Built-in sounds: "Marimba Bb3"
- Custom sounds: "📁 My Recording"

--------
### Loading All Sounds

The `loadAvailableSounds()` function combines both built-in and custom sounds:

```swift

func loadAvailableSounds() -> [SoundFile]
{
  var sounds: [SoundFile] = []
  
  // 1. Load built-in sounds from bundle
  sounds.append(contentsOf: bundleSounds)
  
  // 2. Load custom sounds from Documents
  sounds.append(contentsOf: CustomSoundManager.shared.getCustomSounds())
  
  // 3. Sort: built-in first, then custom (alphabetically)
  sounds.sort { sound1, sound2 in
    if sound1.isCustom != sound2.isCustom {
      return !sound1.isCustom  // Built-in before custom
    }
    return sound1.name < sound2.name
  }
  
  return sounds
}
```

--------
### Playback Integration

**TimerManager Integration**:

When playing a timer sound, the system checks both locations:

```swift

private func playSoundForTimer(_ timer: IntervalTimer)
{
  // First try custom sounds directory
  var soundURL = CustomSoundManager.shared.getCustomSoundURL(
    fileName: timer.soundFileName
  )
  
  // If not found, try bundle
  if soundURL == nil {
    soundURL = Bundle.main.url(
      forResource: (timer.soundFileName as NSString).deletingPathExtension,
      withExtension: (timer.soundFileName as NSString).pathExtension
    )
  }
  
  // Create audio player and play
  let player = try AVAudioPlayer(contentsOf: soundURL)
  player.play()
}
```

This seamless integration allows custom and built-in sounds to be used interchangeably without any special handling in the timer logic.

--------
### Error Handling

**Custom Sound Errors**:
```swift

enum CustomSoundError: LocalizedError
{
  case unsupportedFormat
  case conversionFailed
  case fileNotFound
  
  var errorDescription: String? {
    switch self {
      case .unsupportedFormat:
        return "Unsupported audio format. Please use CAF, M4A, MP3, WAV, or AIFF files."
      case .conversionFailed:
        return "Failed to convert audio file to CAF format."
      case .fileNotFound:
        return "Audio file not found."
    }
  }
}
```

--------
### Security Considerations

**Sandboxing**:

- Custom sounds stored within app's sandbox
- Files cannot be accessed by other apps
- Security-scoped resources properly managed:
  ```swift

  let accessed = sourceURL.startAccessingSecurityScopedResource()
  defer {
    if accessed {
      sourceURL.stopAccessingSecurityScopedResource()
    }
  }
  ```

**Permissions**:

- No special permissions required for file import
- Uses standard iOS file picker (user explicitly grants access)
- Documents directory access is automatic for the app

--------
### Performance Considerations

**Import Performance**:

- Conversion happens synchronously during import
- Typical Voice Memo (30 seconds): ~0.5 seconds conversion time
- Longer files may cause brief UI pause
- Future improvement: async conversion with progress indicator

**Storage**:

- CAF files are typically smaller than M4A for short clips
- No arbitrary size limit (respects iOS app storage limits)
- Users responsible for managing storage via delete functionality

--------
### Future Enhancements

Potential improvements for custom sound management:

1. **Async Import**: Convert files in background with progress indicator
2. **Sound Preview in Manager**: Play sounds before deleting
3. **Bulk Delete**: Select multiple sounds for deletion
4. **Sound Renaming**: Allow users to rename imported sounds
5. **iCloud Sync**: Sync custom sounds across devices
6. **Recording Integration**: Record directly within app
7. **Waveform Display**: Show visual waveform of custom sounds
8. **Trim/Edit**: Basic audio editing before import

---

----------------------------------------------
## Notification System

--------
### Local Notifications

**Purpose**: Provide audio alerts when app is in background or device is locked.

**Implementation Architecture**:
```swift

private let notificationCenter = UNUserNotificationCenter.current()
```


--------
### Notification Scheduling

**Strategy**: Schedule multiple notifications in advance (iOS limit: 64 pending notifications)

```swift

private func scheduleNotifications(for timer: IntervalTimer)
{
  let maxNotifications = 64
  let secondsInDay: TimeInterval = 86400
  let notificationsToSchedule = min(
    maxNotifications, 
    Int(secondsInDay / timer.intervalSeconds)
  )
  
  for i in 0..<notificationsToSchedule {
    let content = UNMutableNotificationContent()
    content.title = timer.name
    content.body = "Timer alert"
    content.sound = UNNotificationSound(
      named: UNNotificationSoundName(rawValue: timer.soundFileName)
    )
    
    // Store timer metadata for foreground handling
    content.userInfo = [
      "timerID": timer.id.uuidString,
      "soundFileName": timer.soundFileName
    ]
    
    let triggerDate = Date().addingTimeInterval(
      timer.intervalSeconds * Double(i + 1)
    )
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: dateComponents,
      repeats: false
    )
    
    let request = UNNotificationRequest(
      identifier: "\(timer.id.uuidString)-\(i)",
      content: content,
      trigger: trigger
    )
    
    notificationCenter.add(request)
  }
}
```

**Key Design Decisions**:

1. **Batch Scheduling**: Schedule up to 24 hours of notifications
2. **Unique Identifiers**: `{timerID}-{index}` format for easy cancellation
3. **Calendar Triggers**: More reliable than time intervals for background execution
4. **UserInfo Metadata**: Allows foreground notification delegate to play custom sounds

--------
### Notification Cancellation

```swift

private func cancelNotifications(for timerID: UUID)
{
  notificationCenter.getPendingNotificationRequests { requests in
    let identifiersToRemove = requests
      .filter { $0.identifier.hasPrefix(timerID.uuidString) }
      .map { $0.identifier }
    
    center.removePendingNotificationRequests(
      withIdentifiers: identifiersToRemove
    )
  }
}
```

--------
### NotificationDelegate

Located in: `NudgeMe/NotificationDelegate.swift`

**Purpose**: Handle notification presentation and user interaction.

```swift
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate
{
  // Display notifications even when app is in foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions
  {
    return [.banner, .sound]
  }
  
  // Handle notification taps
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async
  {
    // Extract timer metadata
    let userInfo = response.notification.request.content.userInfo
    // Could open specific timer edit view
  }
}
```

---

----------------------------------------------
## Background Execution

--------
### iOS Background Modes

**Enabled Capabilities**:
- Audio, AirPlay, and Picture in Picture

**Configuration** (in `NudgeMeApp.swift`):
```swift
init()
{
  let audioSession = AVAudioSession.sharedInstance()
  try? audioSession.setCategory(
    .playback,
    mode: .default,
    options: [.mixWithOthers]
  )
  try? audioSession.setActive(true)
}
```

--------
### Multi-Layer Background Strategy

**Layer 1: Background Audio**
- Silent audio loop keeps app active
- Allows Foundation `Timer` to continue firing
- Plays custom sounds with volume control
- **Trade-off**: Higher battery usage

**Layer 2: Local Notifications**
- Scheduled via UNUserNotificationCenter
- Fire even if app is fully suspended
- Play custom sound files (but no volume control)
- **Trade-off**: 64 notification limit per app

**Layer 3: Timer Persistence**
- All timer states saved to UserDefaults
- On app relaunch, running timers are restored
- Notifications rescheduled automatically
- **Trade-off**: Requires periodic app activation

--------
### State Restoration

```swift
private func loadTimers()
{
  if let data = UserDefaults.standard.data(forKey: "savedTimers"),
     let decoded = try? JSONDecoder().decode([IntervalTimer].self, from: data)
  {
    timers = decoded
    
    // Restart any running timers
    for timer in timers where timer.isRunning {
      scheduleNotifications(for: timer)
      startActiveTimer(for: timer)
    }
  }
}
```

---

----------------------------------------------
## User Interface

--------
### Navigation Structure

```
NudgeMeApp
    │
    ├─ ContentView (Navigation Container)
    │       │
    │       └─ TimerListView (Default View)
    │               │
    │               ├─ NavigationLink → TimerEditView (Edit Existing)
    │               └─ NavigationLink → TimerEditView (Create New)
    │
    └─ NotificationDelegate (Background)
```

--------
### TimerListView

Located in: `NudgeMe/TimerListView.swift`

**Layout**:
```
┌─────────────────────────────────────────┐
│  Timer List                       [+]   │ ← Navigation Bar
├─────────────────────────────────────────┤
│  ┌───────────────────────────────────┐  │
│  │ Timer Name               [▶]      │  │
│  │ Every X seconds                   │  │
│  │ Next: 10:45:30 AM                 │  │
│  └───────────────────────────────────┘  │
│  ┌───────────────────────────────────┐  │
│  │ Break Reminder         [⏸]        │  │
│  │ Every 25 minutes                  │  │
│  │ Next: 11:10:00 AM                 │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

**Features**:
- Displays all timer instances in a scrollable list
- Start/Stop button for each timer (▶/⏸)
- Shows interval duration in human-readable format
- Displays next occurrence time (only for running timers)
- Swipe-to-delete gesture
- Navigation to edit view on tap
- Add button (+) in toolbar

**Key UI Code**:
```swift
List {
  ForEach(timerManager.timers) { timer in
    NavigationLink(destination: TimerEditView(timer: timer)) {
      VStack(alignment: .leading) {
        HStack {
          Text(timer.name).font(.headline)
          Spacer()
          Button(action: { toggleTimer(timer) }) {
            Image(systemName: timer.isRunning ? "pause.circle.fill" : "play.circle.fill")
          }
        }
        Text(formatInterval(timer.intervalSeconds))
        if timer.isRunning, let nextFire = timer.nextFireDate {
          Text("Next: \(nextFire, formatter: timeFormatter)")
        }
      }
    }
  }
  .onDelete(perform: deleteTimer)
}
```

--------
### TimerEditView

Located in: `NudgeMe/TimerEditView.swift`

**Layout**:
```
┌─────────────────────────────────────────┐
│  ← Timer List            [Save]         │
├─────────────────────────────────────────┤
│  Name                                   │
│  ┌───────────────────────────────────┐  │
│  │ My Timer Name                     │  │
│  └───────────────────────────────────┘  │
│                                         │
│  Interval                               │
│  ┌─────┐  ┌─────┐  ┌─────┐              │
│  │  0  │  │  1  │  │ 30  │              │
│  └─────┘  └─────┘  └─────┘              │
│   Hours    Minutes  Seconds             │
│                                         │
│  Sound                                  │
│  ┌───────────────────────────────────┐  │
│  │ Marimba Bb3              ▼        │  │
│  └───────────────────────────────────┘  │
│  [Preview Sound]                        │
│                                         │
│  Volume                                 │
│  ├─────────●──────────────────┤         │
│  0%                          100%       │
└─────────────────────────────────────────┘
```

**Form Sections**:

1. **Name Field**
   - TextField for timer name
   - Default: "New Timer"

2. **Interval Pickers**
   - Three separate Pickers: Hours (0-23), Minutes (0-59), Seconds (0-59)
   - Displays in stacked HStack
   - Validation: Prevents zero-duration timers

3. **Sound Selection**
   - Picker with all available sound files
   - Preview button to test sound
   - Uses AVAudioPlayer for immediate playback

4. **Volume Control**
   - Slider (0.0 to 1.0)
   - Real-time volume adjustment
   - Applies to both foreground playback and preview

**Available Sounds**:
- Marimba Bb1 (Deep)
- Marimba Bb2 (Mid)
- Marimba Bb3 (High)
- Xylophone Bb4 (Very High)
- Xylophone Bb5 (Ultra High)
- SLF Hey (Compound)
- SLF Change (Compound)
- Test Short (Custom M4A file)

**Save Logic**:
```swift
Button("Save") {
  if isNewTimer {
    timerManager.addTimer(editedTimer)
  } else {
    timerManager.updateTimer(editedTimer)
  }
  presentationMode.wrappedValue.dismiss()
}
```

---

----------------------------------------------
## Implementation Details

--------
### Code Style Guidelines

Per project requirements:

1. **Braces**: Opening and closing braces on separate lines
   ```swift
   if condition
   {
     // code
   } // if
   ```

2. **Closing Comments**: Every closing brace has a comment indicating what it closes
   ```swift
   } // func
   } // class
   } // if
   ```

3. **Parameter Alignment**: Function parameters on separate lines with aligned colons
   ```swift
   func example(
     parameter1: String,
     parameter2: Int
   )
   {
     // implementation
   }
   ```

4. **Indentation**: 2 spaces (not tabs)

--------
### Concurrency Handling

**Swift Concurrency Warning Fix**:
```swift
import Foundation
@preconcurrency import UserNotifications  // Suppresses Sendable warnings
import AVFoundation
```

The `@preconcurrency` attribute is used because `UserNotifications` framework hasn't been fully updated for Swift's strict concurrency checking.

--------
### Timer Firing Mechanism

**Foundation Timer → Async Task Bridge**:
```swift
let newTimer = Timer.scheduledTimer(
  withTimeInterval: timer.intervalSeconds,
  repeats: true
)
{ [weak self] _ in
  Task {
    await self?.handleTimerFire(timer)
  }
}
```

This pattern:
1. Uses Foundation `Timer` for reliable periodic execution
2. Bridges to Swift Concurrency with `Task`
3. Calls `@MainActor` function safely
4. Weak self prevents retain cycles

--------
### Audio Player Lifecycle

**Creation**:
- Created once per timer when first sound is played
- Stored in dictionary: `timerAudioPlayers[timer.id]`
- Prepared for playback (`prepareToPlay()`)

**Reuse**:
- Reset `currentTime` to 0 before each play
- Update volume if changed during runtime
- Avoid recreation unless sound file changes

**Cleanup**:
- Stopped when timer is stopped
- Removed from dictionary when timer is deleted
- Automatic deallocation when app terminates

---

----------------------------------------------
## Known Limitations

--------
### Background Notification Sound Volume

**Issue**: Notification sounds play at system volume when app is in background or device is locked. The app cannot control the volume of notification sounds.

**Reason**: iOS security restriction - apps cannot modify system notification volume.

**Workaround**: The app controls volume perfectly when in foreground via `AVAudioPlayer.volume` property.

**User Impact**: Users must adjust system volume for background notifications, but can have per-timer volume in foreground.

--------
### Notification Limit

**Issue**: iOS limits apps to 64 pending local notifications.

**Current Strategy**: Schedule notifications for up to 24 hours in advance.

**Consequence**: For very short intervals (e.g., every 30 seconds), notifications will run out after ~32 minutes.

**Mitigation**: 
1. Background audio keeps app active, allowing Foundation timers to continue
2. App reschedules notifications on next activation
3. For typical use cases (minutes to hours), 64 notifications is sufficient

--------
### Battery Usage

**Trade-off**: Background audio playback consumes more battery than suspended state.

**Mitigation**:
- Silent audio loop is minimal (1-second M4A file)
- Only active when at least one timer is running
- Automatically stops when all timers are stopped

**Alternative Considered**: Pure notification-based approach would save battery but lose custom volume control and reliable short intervals.

--------
### System Sound Limitation (Historical)

**Original Problem**: iOS system sounds (accessed via `AudioServicesPlaySystemSound`) cannot play in background.

**Solution Implemented**: Generate custom CAF audio files bundled with the app, which can be used for both foreground playback and notification sounds.

---

----------------------------------------------
## Development History

--------
### Initial Requirements (2026-02-12)

**User Request**:
> I want an iPhone app that will make a short sound at a given interval. The interval should be settable by the user at the second, minute, and hourly intervals. I should be able to create several interval instances each with its own sound. The short sound should be one of the many standard iPhone sounds. I should be able to select the sound for any given interval. I should be able to create an interval instance, start it ticking, stop it ticking, and delete it. It will continue ticking even when in background or the iPhone is in standby.

--------
### Phase 1: Basic Implementation
- Created `IntervalTimer` model
- Implemented `TimerManager` with Foundation `Timer`
- Built basic UI with `TimerListView` and `TimerEditView`
- Added UserDefaults persistence
- Attempted system sound playback (later replaced)

--------
### Phase 2: Sound Customization (2026-02-13)

**User Request**:
> Add some shorter sounds like a simple Ding, or Tick, or Blip.

**Implementation**:
- Created `SoundFileGenerator` class
- Generated 7 custom CAF audio files
- Implemented programmatic sine wave synthesis
- Added volume control per timer

--------
### Phase 3: UI Enhancement (2026-02-13)

**User Request**:
> For each Interval Timer Instance in the list view, add the time-of-day of the next occurrence.

**Implementation**:
- Added `nextFireDate` property to `IntervalTimer`
- Updated UI to display formatted next fire time
- Implemented date formatter for time-of-day display

--------
### Phase 4: Background Audio (2026-02-13)

**Challenge**: Timers stop firing when app enters background.

**Solution**:
1. Enabled Background Modes capability
2. Configured AVAudioSession for background playback
3. Implemented silent audio loop strategy
4. Added local notification scheduling
5. Created `NotificationDelegate` for foreground notification handling

--------
### Phase 5: Project Renaming (2026-02-18)

**User Question**:
> What should I call this app? I need a very short name, or contraction of several names, preferably cute and memorable so people can remember it easily.

**Claude Suggestions**:
- TickTock
- **NudgeMe** (selected)
- Mindbell
- Breather
- Tempo
- Ping
- Chime

**Rationale**: "NudgeMe" best captures the gentle reminder nature of the app while being short, memorable, and friendly.

**Implementation**:
- Renamed project from TickTick_1 to NudgeMe
- Updated all references in code
- Renamed classes and files accordingly
- Updated Xcode project structure

--------
### Phase 6: Swift Concurrency Fix (2026-02-19)

**Issue**: Compiler warning about Sendable conformance in UserNotifications module.

**Warning**:
```
warning: Add '@preconcurrency' to suppress 'Sendable'-related warnings from module 'UserNotifications'
```

**Fix**: Added `@preconcurrency` attribute to UserNotifications import.

--------
### Phase 7: Git and GitHub Setup (2026-02-19)

**User Request**:
> I want to capture NudgeMe in Git and push it all up GitHub. I have not created anything on github.com. I want to stay in Xcode as much as possible.

**Implementation**:
1. Installed Homebrew package manager
2. Installed GitHub CLI (`gh`)
3. Authenticated with GitHub account
4. Committed all project changes to Git
5. Created GitHub repository: https://github.com/stewartFrench/NudgeMe
6. Pushed code to remote repository

**Commit Message**:
> Rename project from TickTick_1 to NudgeMe and implement interval timer functionality
> 
> This commit renames the project and adds a complete interval timer application with custom sound notifications, background audio support, and notification handling.

--------
### Phase 8: Custom Sound Upload (2026-02-23)

**User Request**:
> I would like this app enhanced with custom sound uploads. This will allow users to import their own audio files. For example, I could record something on my iPhone with the app "Voice Memos" then tap "Share" and select NudgeMe to receive the sound and make it available for the user to select.

**Implementation**:

1. **CustomSoundManager Class**:
   - Created singleton manager for custom sound lifecycle
   - Stores sounds in `Documents/CustomSounds/` directory
   - Converts all imported audio to CAF format for notification compatibility
   - Handles duplicate filenames with numeric suffixes
   - Supports CAF, M4A, MP3, WAV, AIFF formats

2. **Import Methods**:
   - **File Picker Integration** (primary): Native iOS file browser
   - **Share Sheet Support** (attempted): Info.plist configuration for document types
   - Security-scoped resource access for sandboxed file import

3. **UI Enhancements**:
   - "Import Custom Sound from Files" button in TimerEditView
   - "Manage Custom Sounds" view for deletion
   - "Refresh Sound List" to update after import
   - Visual distinction: 📁 prefix for custom sounds
   - Instructions dialog for Voice Memos workflow

4. **Audio Conversion**:
   - Automatic conversion to CAF format using AVAudioFile
   - Preserves audio quality and format characteristics
   - Chunk-based reading/writing for memory efficiency

5. **Integration**:
   - Updated `SoundFile` model with `isCustom` flag
   - Modified `loadAvailableSounds()` to merge built-in and custom
   - Updated `TimerManager.playSoundForTimer()` to check both locations
   - Seamless playback of custom and built-in sounds

**Challenges**:
- iOS Share Sheet from Voice Memos didn't reliably trigger URL handler
- Resolved by implementing native file picker as primary method
- Added instructions for exporting from Voice Memos to Files first

**File Picker Workflow**:
1. Export Voice Memo to Files app
2. Use "Import Custom Sound from Files" in NudgeMe
3. Browse to saved file
4. Automatic import and conversion
5. Sound immediately available in picker

**Result**:
Users can now personalize their timers with custom recordings, downloaded sounds, or any audio file accessible through the Files app.

--------
### Phase 9: Code Cleanup (2026-02-24)

**User Request**:
> Since I created my own sounds, and now support user-defined sounds, can't I delete SoundFileGenerator and the call to generateAllSoundFiles?
> 
> Also, I think ContentView is no longer needed. Is that correct?

**Implementation**:

1. **Removed SoundFileGenerator.swift**:
   - Deleted the entire `SoundFileGenerator` class
   - Removed `generateSoundFilesIfNeeded()` method from `TimerManager`
   - Removed UserDefaults check for "soundFilesGenerated"
   - No longer generates sounds at runtime

2. **Removed ContentView.swift**:
   - Deleted unused template file (original "Hello, world!" view)
   - App now uses `ContentHostView` → `TimerListView` directly

3. **Updated Architecture**:
   - Replaced runtime sound generation with 20 pre-generated CAF files
   - Sounds now bundled in `NudgeMe/Sounds/` directory
   - Cleaner initialization process in `TimerManager`

**Rationale**:
- Pre-generated sounds provide better quality and consistency
- No need for runtime generation with CAF files in bundle
- CustomSoundManager handles user imports separately
- ContentView was never used in actual app flow

**Result**:
Cleaner, more maintainable codebase with only actively used files. App startup is faster without sound generation logic.

---

----------------------------------------------
## Future Enhancement Opportunities

--------
### Potential Features
1. **Notification Rescheduling**: Automatically reschedule notifications when approaching the 64-notification limit
2. **Pomodoro Presets**: Quick-start buttons for common intervals (25/5, 52/17, etc.)
3. **Timer Groups**: Organize timers into categories or workflows
4. **Statistics**: Track how many times each timer has fired
5. ~~**Custom Sound Upload**: Allow users to import their own audio files~~ ✅ **Implemented 2026-02-23**
6. **Haptic Feedback**: Vibration patterns in addition to sound
7. **Watch App**: WatchOS companion app for wrist-based notifications
8. **Widgets**: Home screen widgets showing next timer
9. **Shortcuts Integration**: Siri shortcuts to start/stop timers
10. **In-App Recording**: Record custom sounds directly within NudgeMe
11. **Sound Trimming**: Edit imported sounds (trim start/end)
12. **iCloud Sync**: Sync custom sounds across devices

--------
### Technical Improvements
1. **Core Data Migration**: Replace UserDefaults with Core Data for better scalability
2. **Combine Framework**: Use Combine publishers for reactive state management (or migrate to Swift's async/await patterns)
3. **Unit Tests**: Comprehensive test coverage for `TimerManager` logic
4. **UI Tests**: Automated UI testing for timer workflows
5. **Accessibility**: VoiceOver support and Dynamic Type

--------
### Performance Optimizations
1. **Lazy Loading**: Load timer audio files on-demand rather than keeping all in memory
2. **Background Task**: Use BGTaskScheduler for more efficient background execution
3. **Battery Monitoring**: Adjust background audio strategy based on battery level

---

----------------------------------------------
## Conclusion

NudgeMe successfully implements a multi-timer interval reminder system with sophisticated background execution, custom audio generation, user sound import capabilities, and a clean SwiftUI interface. The application demonstrates advanced iOS concepts including:

- Background audio playback for app persistence
- Local notification scheduling and management
- Programmatic audio file generation
- Custom audio file import with format conversion
- SwiftUI MVVM architecture with file pickers
- Data persistence with Codable
- Swift concurrency with async/await
- Security-scoped resource access for sandboxed file import
- Xcode project management and Git version control

The implementation prioritizes user experience (custom sounds, volume control, next-fire-time display, sound import/management) while navigating iOS's strict background execution limitations through a multi-layer strategy of background audio, local notifications, and state persistence.

---

**Document Version**: 1.2  
**Generated**: 2026-02-24  
**Repository**: https://github.com/stewartFrench/NudgeMe

----------------------------------------------
## Project Files

--------
### Core Application Files
- `NudgeMeApp.swift` - Application entry point with ImportManager
- `TimerManager.swift` - Timer business logic and state management
- `TimerModel.swift` - Data models (IntervalTimer, SoundFile)
- `CustomSoundManager.swift` - Custom sound import and management

--------
### View Files
- `TimerListView.swift` - Main timer list interface
- `TimerEditView.swift` - Timer editor with sound selection
- `ManageCustomSoundsView.swift` - Custom sound management UI (in TimerEditView.swift)
- `ContentHostView.swift` - Alert host for import feedback (in NudgeMeApp.swift)

--------
### Supporting Files
- `NotificationDelegate.swift` - Notification handling
- `Assets.xcassets` - App icons and visual assets
- `Sounds/` - 20 pre-generated CAF sound files

--------
### Documentation
- `documents/detailed_design.md` - This document
- `documents/SLF_notes.md` - Development notes

--------
### Removed Files (Historical)
- ~~`SoundFileGenerator.swift`~~ - Removed 2026-02-24 (replaced with pre-generated sounds)
- ~~`ContentView.swift`~~ - Removed 2026-02-24 (unused template)

----------------------------------------------
end
