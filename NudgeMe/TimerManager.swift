//
//  TimerManager.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import Foundation
@preconcurrency import UserNotifications
import AVFoundation
import AudioToolbox
import Combine

// Manages all interval timers and handles background notifications
@MainActor
class TimerManager: ObservableObject
{
  @Published var timers: [IntervalTimer] = []
  private let notificationCenter = UNUserNotificationCenter.current()
  private var activeTimers: [UUID: Timer] = [:]
  private let audioSession = AVAudioSession.sharedInstance()
  private var silentPlayer: AVAudioPlayer?
  private var timerAudioPlayers: [UUID: AVAudioPlayer] = [:]  // Persistent players for each timer
  
  init()
  {
    // Generate sound files on first launch
    generateSoundFilesIfNeeded()
    
    loadTimers()
    requestNotificationPermissions()
    setupBackgroundAudio()
  } // init
  
  // Generate sound files if they don't exist yet
  private func generateSoundFilesIfNeeded()
  {
    let userDefaults = UserDefaults.standard
    let soundFilesGenerated = userDefaults.bool(forKey: "soundFilesGenerated")
    
    if !soundFilesGenerated
    {
      SoundFileGenerator.generateAllSoundFiles()
      userDefaults.set(true, forKey: "soundFilesGenerated")
    } // if
  } // func generateSoundFilesIfNeeded
  
  // Set up audio session for background playback
  private func setupBackgroundAudio()
  {
    do
    {
      try audioSession.setCategory(
        .playback,
        mode   : .default,
        options: [.mixWithOthers]
      )
      try audioSession.setActive(true)
      
      // Create a silent audio buffer to keep the app alive
      createSilentAudioPlayer()
    } // do
    catch
    {
      print("Failed to set up background audio: \(error)")
    } // catch
  } // func setupBackgroundAudio
  
  // Create and start playing silent audio to keep app active in background
  private func createSilentAudioPlayer()
  {
    // Create a 1-second silent audio file in memory
    let silenceURL = createSilentAudioFile()
    
    do
    {
      silentPlayer = try AVAudioPlayer(contentsOf: silenceURL)
      silentPlayer?.numberOfLoops = -1 // Loop forever
      silentPlayer?.volume = 0.0 // Silent
      silentPlayer?.prepareToPlay()
    } // do
    catch
    {
      print("Failed to create silent audio player: \(error)")
    } // catch
  } // func createSilentAudioPlayer
  
  // Create a silent audio file
  private func createSilentAudioFile() -> URL
  {
    let tempDir = FileManager.default.temporaryDirectory
    let silenceURL = tempDir.appendingPathComponent("silence.m4a")
    
    // If file already exists, return it
    if FileManager.default.fileExists(atPath: silenceURL.path)
    {
      return silenceURL
    } // if
    
    // Create a 1-second silent audio file
    let settings: [String: Any] = [
      AVFormatIDKey             : kAudioFormatMPEG4AAC,
      AVSampleRateKey           : 44100.0,
      AVNumberOfChannelsKey     : 1,
      AVEncoderAudioQualityKey  : AVAudioQuality.min.rawValue
    ]
    
    do
    {
      let audioFile = try AVAudioFile(
        forWriting : silenceURL,
        settings   : settings
      )
      
      // Create silent buffer (1 second of silence)
      let format = AVAudioFormat(
        standardFormatWithSampleRate: 44100.0,
        channels                    : 1
      )!
      let frameCount = AVAudioFrameCount(44100)
      let buffer = AVAudioPCMBuffer(
        pcmFormat   : format,
        frameCapacity: frameCount
      )!
      buffer.frameLength = frameCount
      
      // Write the silent buffer
      try audioFile.write(from: buffer)
    } // do
    catch
    {
      print("Failed to create silent audio file: \(error)")
    } // catch
    
    return silenceURL
  } // func createSilentAudioFile
  
  // Start silent audio playback when timers are active
  private func startSilentAudio()
  {
    silentPlayer?.play()
  } // func startSilentAudio
  
  // Stop silent audio playback when no timers are active
  private func stopSilentAudio()
  {
    silentPlayer?.stop()
  } // func stopSilentAudio
  
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
  
  // Add a new timer
  func addTimer(_ timer: IntervalTimer)
  {
    timers.append(timer)
    saveTimers()
  } // func addTimer
  
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
  
  // Update the volume of a running timer's audio player
  private func updateTimerVolume(_ timer: IntervalTimer)
  {
    timerAudioPlayers[timer.id]?.volume = timer.volume
  } // func updateTimerVolume
  
  // Delete a timer
  func deleteTimer(_ timer: IntervalTimer)
  {
    stopTimer(timer)
    timers.removeAll { $0.id == timer.id }
    saveTimers()
  } // func deleteTimer
  
  // Start a timer
  func startTimer(_ timer: IntervalTimer)
  {
    var updatedTimer = timer
    updatedTimer.isRunning = true
    updatedTimer.nextFireDate = Date().addingTimeInterval(timer.intervalSeconds)
    
    // Schedule notifications for this timer (for background/locked screen)
    scheduleNotifications(for: updatedTimer)
    
    // Start an active timer for foreground/background sound playback
    startActiveTimer(for: updatedTimer)
    
    // Start silent audio to keep app alive in background
    updateSilentAudioState()
    
    updateTimer(updatedTimer)
  } // func startTimer
  
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
    
    // Update silent audio state (stop if no timers running)
    updateSilentAudioState()
    
    updateTimer(updatedTimer)
  } // func stopTimer
  
  // Update silent audio playback based on whether any timers are running
  private func updateSilentAudioState()
  {
    let hasRunningTimers = timers.contains { $0.isRunning }
    
    if hasRunningTimers
    {
      startSilentAudio()
    } // if
    else
    {
      stopSilentAudio()
    } // else
  } // func updateSilentAudioState
  
  // Start an active timer that fires in the app
  private func startActiveTimer(for timer: IntervalTimer)
  {
    // Cancel existing timer if any
    stopActiveTimer(for: timer.id)
    
    // Create a repeating timer
    let newTimer = Timer.scheduledTimer(
      withTimeInterval: timer.intervalSeconds,
      repeats         : true
    )
    { [weak self] _ in
      Task
      {
        await self?.handleTimerFire(timer)
      } // Task
    } // Timer
    
    // Store the timer
    activeTimers[timer.id] = newTimer
  } // func startActiveTimer
  
  // Stop an active timer
  private func stopActiveTimer(for timerID: UUID)
  {
    activeTimers[timerID]?.invalidate()
    activeTimers.removeValue(forKey: timerID)
  } // func stopActiveTimer
  
  // Handle when a timer fires
  private func handleTimerFire(_ timer: IntervalTimer)
  {
    // Play the sound from file with volume
    playSoundForTimer(timer)
    
    // Update the next fire date
    if let index = timers.firstIndex(where: { $0.id == timer.id })
    {
      var updatedTimer = timers[index]
      updatedTimer.nextFireDate = Date().addingTimeInterval(timer.intervalSeconds)
      timers[index] = updatedTimer
      saveTimers()
    } // if
  } // func handleTimerFire
  
  // Play sound for a specific timer using persistent audio player
  private func playSoundForTimer(_ timer: IntervalTimer)
  {
    // Get or create the audio player for this timer
    if timerAudioPlayers[timer.id] == nil
    {
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
          return
        } // catch
      } // if
      else
      {
        print("Sound file not found: \(timer.soundFileName)")
        return
      } // else
    } // if
    
    // Update volume in case it changed
    timerAudioPlayers[timer.id]?.volume = timer.volume
    
    // Play the sound from the beginning
    timerAudioPlayers[timer.id]?.currentTime = 0
    timerAudioPlayers[timer.id]?.play()
  } // func playSoundForTimer
  
  // Schedule repeating notifications for a timer
  private func scheduleNotifications(for timer: IntervalTimer)
  {
    // Cancel existing notifications first
    cancelNotifications(for: timer.id)
    
    // Schedule multiple notifications (iOS limits, so we schedule for the next 24 hours)
    let maxNotifications = 64 // iOS limit
    let secondsInDay: TimeInterval = 86400
    let notificationsToSchedule = min(maxNotifications, Int(secondsInDay / timer.intervalSeconds))
    
    for i in 0..<notificationsToSchedule
    {
      let content = UNMutableNotificationContent()
      content.title = timer.name
      content.body = "Timer alert"
      
      // Use the custom sound file from the Sounds folder
      // iOS will look for this file in the app bundle
      content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: timer.soundFileName))
      
      // Store the timer ID and sound filename in userInfo
      // This allows the foreground delegate to play the custom sound
      content.userInfo = [
        "timerID"      : timer.id.uuidString,
        "soundFileName": timer.soundFileName
      ]
      
      let triggerDate = Date().addingTimeInterval(timer.intervalSeconds * Double(i + 1))
      let dateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute, .second],
        from: triggerDate
      )
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: dateComponents,
        repeats     : false
      )
      
      let request = UNNotificationRequest(
        identifier: "\(timer.id.uuidString)-\(i)",
        content   : content,
        trigger   : trigger
      )
      
      notificationCenter.add(request)
      { error in
        if let error = error
        {
          print("Error scheduling notification: \(error)")
        } // if
        else
        {
          print("Successfully scheduled notification \(i) for timer '\(timer.name)' at \(triggerDate)")
        } // else
      } // add
    } // for
  } // func scheduleNotifications
  
  // Cancel all notifications for a timer
  private func cancelNotifications(for timerID: UUID)
  {
    let center = notificationCenter
    center.getPendingNotificationRequests
    { requests in
      let identifiersToRemove = requests
        .filter { $0.identifier.hasPrefix(timerID.uuidString) }
        .map { $0.identifier }
      
      center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    } // getPendingNotificationRequests
  } // func cancelNotifications
  
  
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
  
  // Load timers from UserDefaults
  private func loadTimers()
  {
    if let data = UserDefaults.standard.data(forKey: "savedTimers"),
       let decoded = try? JSONDecoder().decode([IntervalTimer].self, from: data)
    {
      timers = decoded
      
      // Restart any running timers
      for timer in timers where timer.isRunning
      {
        scheduleNotifications(for: timer)
        startActiveTimer(for: timer)
      } // for
    } // if
  } // func loadTimers
} // class TimerManager
