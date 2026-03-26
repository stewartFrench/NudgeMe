//
//  TimerManager.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import Foundation
import UIKit
@preconcurrency import UserNotifications
import AVFoundation
import AudioToolbox
import Combine

// ----------------------------------------------
// Manages all interval timers and handles background notifications

@MainActor
class TimerManager: ObservableObject
{
  static let shared = TimerManager()
  
  @Published var timers: [IntervalTimer] = []
  private let notificationCenter = UNUserNotificationCenter.current()
  private var activeTimers: [UUID: Timer] = [:]

              // Persistent players for each timer -
  private var timerAudioPlayers: [UUID: AVAudioPlayer] = [:]  

  private var isInBackground = false
  private let audioSession = AVAudioSession.sharedInstance()
  private var keepaliveTimer: Timer?
  private var keepalivePlayer: AVAudioPlayer?
  

  // -----------
  private init()
  {
    loadTimers()
    requestNotificationPermissions()
    setupAudioSession()
    setupSceneObservers()
    
        // Cancel all pending notifications since we use background
        // audio instead

    notificationCenter.removeAllPendingNotificationRequests()

  } // init
  

  // -----------
  // Set up audio session for sound playback

  private func setupAudioSession()
  {
    do
    {
      try audioSession.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers]
      )
      
          // Request to keep app active in background for audio
          // This is important for longer timer intervals

      try audioSession.setActive(
        true,
        options: [.notifyOthersOnDeactivation]
      )
      
          // Set preferred buffer duration for better background
          // performance

      try audioSession.setPreferredIOBufferDuration(0.005)
    } // do
    catch
    {
      print("Failed to set audio session category: \(error)")
    } // catch
  } // func setupAudioSession
  

  // -----------
  // Set up observers for app state changes

  private func setupSceneObservers()
  {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appDidEnterBackground),
      name    : UIApplication.didEnterBackgroundNotification,
      object  : nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillEnterForeground),
      name    : UIApplication.willEnterForegroundNotification,
      object  : nil
    )
  } // func setupSceneObservers
  

  // -----------
  @objc private func appDidEnterBackground()
  {
    isInBackground = true

        // Start keepalive if any timers are running

    if timers.contains(where: { $0.isRunning })
    {
      let timestamp = Date().formatted(date: .omitted, time: .standard)
      print("[\(timestamp)] === App entered background with \(timers.filter { $0.isRunning }.count) running timers - starting keepalive")
      startKeepalive()
    } // if
    else
    {
      let timestamp = Date().formatted(date: .omitted, time: .standard)
      print("[\(timestamp)] === App entered background with no running timers")
    }
  } // func appDidEnterBackground
  

  // -----------
  @objc private func appWillEnterForeground()
  {
    isInBackground = false

        // Stop keepalive when in foreground

    stopKeepalive()

  } // func appWillEnterForeground
  
  
  // -----------
  // Start keepalive audio to maintain background session
  
  private func startKeepalive()
  {
        // Don't restart if already running

    if keepaliveTimer != nil && keepaliveTimer!.isValid
    {
      let timestamp = Date().formatted(date: .omitted, time: .standard)
      print("[\(timestamp)] === Keepalive already running, skipping restart")
      return
    }
    
        // Stop existing keepalive if any

    stopKeepalive()
    
        // Create keepalive audio player if needed

    if keepalivePlayer == nil
    {
      let timestamp = Date().formatted(date: .omitted, time: .standard)
      print("[\(timestamp)] === Creating keepalive player")
      createKeepalivePlayer()
    } // if
    
    let timestamp = Date().formatted(date: .omitted, time: .standard)
    print("[\(timestamp)] === Starting keepalive timer (1 second interval)")
    
        // Start a timer to play keepalive sound every 1 second
    // Use RunLoop.main and .common mode to ensure it runs in background

    keepaliveTimer = Timer.scheduledTimer(
      withTimeInterval: 1.0,
      repeats: true
    )
    { [weak self] _ in
      guard let self = self else { return }
      Task { @MainActor in
        self.playKeepalive()
      }
    } // scheduledTimer
    
    RunLoop.main.add(keepaliveTimer!, forMode: .common)
    
        // Play immediately

    playKeepalive()

  } // func startKeepalive
  
  
  // -----------
  // Stop keepalive audio
  
  private func stopKeepalive()
  {
    keepaliveTimer?.invalidate()
    keepaliveTimer = nil
    keepalivePlayer?.stop()
  } // func stopKeepalive
  
  
  // -----------
  // Create a very short, quiet audio player for keepalive
  
  private func createKeepalivePlayer()
  {
        // Create a very short silent audio file in memory

    let format = AVAudioFormat(
      standardFormatWithSampleRate: 44100,
      channels: 1
    )!
    
        // Create 0.01 second (10ms) of near-silent audio at very low volume

    let frameCount = AVAudioFrameCount(format.sampleRate * 0.01)
    guard let buffer = 
       AVAudioPCMBuffer(
          pcmFormat: format,
      frameCapacity: frameCount
    ) 
    else { return }
    
    buffer.frameLength = frameCount
    
        // Fill with very low amplitude samples (barely audible)

    if let samples = buffer.floatChannelData?[0]
    {
      for i in 0..<Int(frameCount)
      {
        samples[i] = 0.0001 * sin(Float(i) * 0.1) // Very quiet sine wave
      }
    } // if
    
        // Write to a temporary file

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("keepalive.caf")
    
    do
    {
      let file = 
           try AVAudioFile(
                  forWriting: tempURL,
                    settings: format.settings,
                commonFormat: .pcmFormatFloat32,
                 interleaved: false
      )
      try file.write(from: buffer)
      
          // Create player from the file

      keepalivePlayer = try AVAudioPlayer(contentsOf: tempURL)
      keepalivePlayer?.volume = 0.01 // Very quiet
      keepalivePlayer?.prepareToPlay()
    } // do
    catch
    {
      print("Failed to create keepalive player: \(error)")
    } // catch

  } // func createKeepalivePlayer
  
  
  // -----------
  // Play keepalive sound
  
  private func playKeepalive()
  {
    if keepalivePlayer == nil
    {
      let timestamp = Date().formatted(date: .omitted, time: .standard)
      print("[\(timestamp)] === WARNING: playKeepalive called but keepalivePlayer is nil")
      return
    }
    
    keepalivePlayer?.currentTime = 0
    let success = keepalivePlayer?.play() ?? false
    
    // Only log occasionally to avoid console spam
    if Int(Date().timeIntervalSince1970) % 10 == 0
    {
      let timestamp = Date().formatted(date: .omitted, time: .standard)
      print("[\(timestamp)] === Keepalive playing: \(success)")
    }
  } // func playKeepalive
  

  // -----------
  // Request permission for notifications

  func requestNotificationPermissions()
  {
    notificationCenter.requestAuthorization(
      options: [.alert, .sound, .badge]
    )
    { granted, error in
      if let error = error
      {
        print("Notification permission error: \(error)")
      } // if
    } // requestAuthorization
  } // func requestNotificationPermissions
  

  // -----------
  // Add a new timer

  func addTimer(_ timer: IntervalTimer)
  {
    timers.append(timer)
    saveTimers()
  } // func addTimer
  

  // -----------
  // Update an existing timer

  func updateTimer(_ timer: IntervalTimer)
  {
    if let index = timers.firstIndex(where: { $0.id == timer.id })
    {
      let oldTimer = timers[index]
      timers[index] = timer
      
          // If timer is running and sound file changed, recreate the audio player

      if timer.isRunning && oldTimer.soundFileName != timer.soundFileName
      {
        timerAudioPlayers.removeValue(forKey: timer.id)
      } // if

          // If volume changed and timer is running, update the audio player volume

      else if timer.isRunning && oldTimer.volume != timer.volume
      {
        updateTimerVolume(timer)
      } // else if
      
      saveTimers()
    } // if
  } // func updateTimer
  

  // -----------
  // Update the volume of a running timer's audio player

  private func updateTimerVolume(_ timer: IntervalTimer)
  {
    timerAudioPlayers[timer.id]?.volume = timer.volume
  } // func updateTimerVolume
  

  // -----------
  // Delete a timer

  func deleteTimer(_ timer: IntervalTimer)
  {
    stopTimer(timer)
    timers.removeAll { $0.id == timer.id }
    saveTimers()
  } // func deleteTimer
  

  // -----------
  // Move timers to reorder them

  func moveTimers(from source: IndexSet, to destination: Int)
  {
    var updatedTimers = timers
    
        // Extract the items to move

    let itemsToMove = source.reversed().map { updatedTimers.remove(at: $0) }.reversed()
    
        // Calculate the adjusted destination index

    let adjustedDestination = destination - source.filter { $0 < destination }.count
    
        // Insert items at the destination

    for (offset, item) in itemsToMove.enumerated()
    {
      updatedTimers.insert(item, at: adjustedDestination + offset)
    }
    
    timers = updatedTimers
    saveTimers()
  } // func moveTimers
  

  // -----------
  // Start a timer

  func startTimer(_ timer: IntervalTimer)
  {
    var updatedTimer = timer
    updatedTimer.isRunning = true
    updatedTimer.nextFireDate = 
        Date().addingTimeInterval(timer.intervalSeconds)
    
        // Cancel any existing notifications for this timer
        // (in case there are any leftover from previous versions)

    cancelNotifications(for: timer.id)
    
        // Play the sound IMMEDIATELY when starting

    playSoundForTimer(updatedTimer)

        // Start an active timer that works in both foreground and
        // background

    startActiveTimer(for: updatedTimer)
    
        // Start keepalive if in background

    if isInBackground
    {
      startKeepalive()
    } // if
    
    updateTimer(updatedTimer)
  } // func startTimer
  

  // -----------
  // Stop a timer

  func stopTimer(_ timer: IntervalTimer)
  {
    var updatedTimer = timer
    updatedTimer.isRunning = false
    updatedTimer.nextFireDate = nil
    
        // Cancel all notifications for this timer

    cancelNotifications(for: timer.id)
    
        // Stop the active timer

    stopActiveTimer(for: timer.id)
    
        // Clean up the audio player for this timer

    timerAudioPlayers[timer.id]?.stop()
    timerAudioPlayers.removeValue(forKey: timer.id)

    updateTimer(updatedTimer)
    
        // Stop keepalive if no timers are running

    if !timers.contains(where: { $0.isRunning })
    {
      stopKeepalive()
    } // if
  } // func stopTimer
  
  
  // -----------
  // Stop all running timers (called when app terminates)
  
  func stopAllTimers()
  {
        // Stop each running timer

    for timer in timers where timer.isRunning
    {
      stopTimer(timer)
    } // for
  } // func stopAllTimers
  
  
  // -----------
  // Start an active timer that fires in the app

  private func startActiveTimer(for timer: IntervalTimer)
  {
        // Cancel existing timer if any

    stopActiveTimer(for: timer.id)
    
        // Capture the timer ID to look up current state on each fire

    let timerID = timer.id
    
        // Create a repeating timer

    let newTimer = 
          Timer.scheduledTimer(
              withTimeInterval : timer.intervalSeconds,
              repeats          : true
    )
    { [weak self] _ in
      Task
      {
        await self?.handleTimerFireByID(timerID)
      } // Task
    } // Timer
    
        // Store the timer

    activeTimers[timer.id] = newTimer

  } // func startActiveTimer
  

  // -----------
  // Stop an active timer

  private func stopActiveTimer(for timerID: UUID)
  {
    activeTimers[timerID]?.invalidate()
    activeTimers.removeValue(forKey: timerID)
  } // func stopActiveTimer
  

  // -----------
  // Handle when a timer fires (by timer ID to ensure we use current state)

  private func handleTimerFireByID(_ timerID: UUID)
  {
        // Look up the current timer state from the array

    guard let index = timers.firstIndex(where: { $0.id == timerID }) 
    else
    {
      return
    }
    
    let timer = timers[index]
    
        // Only fire if timer is still running

    guard timer.isRunning 
    else
    {
      return
    }
    
        // Always play the timer sound (works in both foreground and
        // background) This is legitimate audible content that the
        // user expects

    playSoundForTimer(timer)
    
        // Update the next fire date

    var updatedTimer = timer
    updatedTimer.nextFireDate = Date().addingTimeInterval(timer.intervalSeconds)
    timers[index] = updatedTimer
    saveTimers()
  } // func handleTimerFireByID
  

  // -----------
  // Prepare audio player for a timer (create if doesn't exist)
  
  private func prepareAudioPlayer(for timer: IntervalTimer)
  {
        // Skip if player already exists

    if timerAudioPlayers[timer.id] != nil
    {
      return
    }
    
        // First try custom sounds directory

    var soundURL: URL? = CustomSoundManager.shared.getCustomSoundURL(
      fileName: timer.soundFileName
    )
    
        // If not found in custom sounds, try bundle

    if soundURL == nil
    {
      soundURL = Bundle.main.url(
        forResource  : (timer.soundFileName as NSString).deletingPathExtension,
        withExtension: (timer.soundFileName as NSString).pathExtension
      )
    } // if
    
        // Create a new player for this timer

    if let soundURL = soundURL
    {
      do
      {
        let player = try AVAudioPlayer(contentsOf: soundURL)
        player.volume = timer.volume
        player.prepareToPlay()
        timerAudioPlayers[timer.id] = player
      } // do
      catch
      {
        print("Failed to create audio player: \(error)")
      } // catch
    } // if
    else
    {
      print("Sound file not found: \(timer.soundFileName)")
    } // else
  } // func prepareAudioPlayer
  
  
  // -----------
  // Play sound for a specific timer using persistent audio player

  private func playSoundForTimer(_ timer: IntervalTimer)
  {
        // Get or create the audio player for this timer

    if timerAudioPlayers[timer.id] == nil
    {
      prepareAudioPlayer(for: timer)
    } // if
    
        // Update volume in case it changed

    timerAudioPlayers[timer.id]?.volume = timer.volume
    
        // Play from the beginning
        // Don't stop first - just reset position and play

    timerAudioPlayers[timer.id]?.currentTime = 0
    timerAudioPlayers[timer.id]?.play()
  } // func playSoundForTimer
  

  // -----------
  // Schedule repeating notifications for a timer

  private func scheduleNotifications(for timer: IntervalTimer)
  {
        // Cancel existing notifications first

    cancelNotifications(for: timer.id)
    
        // print("=== Scheduling notifications for timer: \(timer.name) (ID: \(timer.id))")
    
        // Schedule multiple notifications (iOS limits, so we schedule
        // for the next 24 hours)

    let maxNotifications = 64 // iOS limit
    let secondsInDay: TimeInterval = 86400
    let notificationsToSchedule = 
            min(maxNotifications, Int(secondsInDay / timer.intervalSeconds))

        // print("=== Will schedule \(notificationsToSchedule) notifications")
    
    for i in 0..<notificationsToSchedule
    {
      let content = UNMutableNotificationContent()
      content.title = timer.name
      content.body = "Timer alert"
      
          // Use the custom sound file from the Sounds folder
          // This will only play when app is fully suspended (not
          // running in background)

      content.sound = 
        UNNotificationSound(
            named: UNNotificationSoundName(rawValue: timer.soundFileName))
      
          // Store the timer ID and sound filename in userInfo

      content.userInfo = [
        "timerID"       : timer.id.uuidString,
        "soundFileName" : timer.soundFileName
      ]
      
      let timeInterval = timer.intervalSeconds * Double(i + 1)
      let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval : timeInterval,
        repeats      : false
      )
      
      let request = 
             UNNotificationRequest(
                identifier : "\(timer.id.uuidString)-\(i)",
                content    : content,
                trigger    : trigger
      )
      
          // if i < 3 {
          //   print("=== Notification \(i): scheduled for \(triggerDate)")
          // }
      
      notificationCenter.add(request)
      { error in
        if let error = error
        {
          print("Error scheduling notification: \(error)")
        } // if
        else
        {
          // print("Successfully scheduled notification \(i) for timer '\(timer.name)' at \(triggerDate)")
        } // else
      } // add
    } // for
  } // func scheduleNotifications
  

  // -----------
  // Cancel all notifications for a timer

  private func cancelNotifications(for timerID: UUID)
  {
    let center = notificationCenter
    center.getPendingNotificationRequests
    { requests in
      let identifiersToRemove = requests
        .filter { $0.identifier.hasPrefix(timerID.uuidString) }
        .map { $0.identifier }
      
      center.removePendingNotificationRequests(
                 withIdentifiers: identifiersToRemove)

    } // getPendingNotificationRequests
  } // func cancelNotifications
  
  
  // -----------
  // Save timers to UserDefaults

  private func saveTimers()
  {
    if let encoded = try? JSONEncoder().encode(timers)
    {
      UserDefaults.standard.set(
        encoded,
        forKey: "savedTimers"
      )
    } // if
  } // func saveTimers
  

  // -----------
  // Load timers from UserDefaults

  private func loadTimers()
  {
    if let data = UserDefaults.standard.data(forKey: "savedTimers"),
       let decoded = try? JSONDecoder().decode([IntervalTimer].self, from: data)
    {
      timers = decoded
      
          // Stop all running timers on app launch
          // This ensures timers don't remain active after app
          // termination

      for index in timers.indices
      {
        if timers[index].isRunning
        {
          timers[index].isRunning = false
          timers[index].nextFireDate = nil
        }
      }
      
          // Save the updated state

      saveTimers()

    } // if
  } // func loadTimers

} // class TimerManager
