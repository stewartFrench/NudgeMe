//
//  TimerEditView.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import SwiftUI
import AVFoundation

struct TimerEditView: View
{
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var timerManager: TimerManager
  
  let timerToEdit: IntervalTimer?
  
  @State private var    name: String
  @State private var   hours: Int
  @State private var minutes: Int
  @State private var seconds: Int
  @State private var selectedSoundFileName: String
  @State private var  volume: Float
  @State private var previewPlayer: AVAudioPlayer?
  
  let availableSounds = loadAvailableSounds()
  
  init(
    timerManager: TimerManager,
    timerToEdit : IntervalTimer? = nil
  )
  {
    self.timerManager = timerManager
    self.timerToEdit = timerToEdit
    
    if let timer = timerToEdit
    {
      _name = State(initialValue: timer.name)
      let totalSeconds = Int(timer.intervalSeconds)
      _hours = State(initialValue: totalSeconds / 3600)
      _minutes = State(initialValue: (totalSeconds % 3600) / 60)
      _seconds = State(initialValue: totalSeconds % 60)
      _selectedSoundFileName = State(initialValue: timer.soundFileName)
      _volume = State(initialValue: timer.volume)
    } // if
    else
    {
      _name = State(initialValue: "")
      _hours = State(initialValue: 0)
      _minutes = State(initialValue: 1)
      _seconds = State(initialValue: 0)
      // Default to first available sound
      let sounds = loadAvailableSounds()
      _selectedSoundFileName = State(initialValue: sounds.first?.fileName ?? "default")
      _volume = State(initialValue: 1.0)
    } // else
  } // init
  
  var body: some View
  {
    NavigationStack
    {
      Form
      {
        Section("Timer Name")
        {
          TextField(
            "Enter name",
            text: $name
          )
        } // Section
        
        Section("Interval")
        {
          Picker(
            "Hours",
            selection: $hours
          )
          {
            ForEach(0..<24)
            { hour in
              Text("\(hour)").tag(hour)
            } // ForEach
          } // Picker
          
          Picker(
            "Minutes",
            selection: $minutes
          )
          {
            ForEach(0..<60)
            { minute in
              Text("\(minute)").tag(minute)
            } // ForEach
          } // Picker
          
          Picker(
            "Seconds",
            selection: $seconds
          )
          {
            ForEach(0..<60)
            { second in
              Text("\(second)").tag(second)
            } // ForEach
          } // Picker
        } // Section
        
        Section("Sound")
        {
          Picker(
            "Alert Sound",
            selection: $selectedSoundFileName
          )
          {
            ForEach(
              availableSounds,
              id: \.id
            )
            { sound in
              Text(sound.name).tag(sound.fileName)
            } // ForEach
          } // Picker
          
          VStack(alignment: .leading)
          {
            HStack
            {
              Text("Volume")
              Spacer()
              Text("\(Int(volume * 100))%")
                .foregroundStyle(.secondary)
            } // HStack
            
            Slider(
              value: $volume,
              in   : 0.0...1.0,
              step : 0.01
            )
          } // VStack
          
          Button("Preview Sound")
          {
            previewSound()
          } // Button
        } // Section
      } // Form
      .navigationTitle(timerToEdit == nil ? "New Timer" : "Edit Timer")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar
      {
        ToolbarItem(placement: .cancellationAction)
        {
          Button("Cancel")
          {
            dismiss()
          } // Button
        } // ToolbarItem
        
        ToolbarItem(placement: .confirmationAction)
        {
          Button("Save")
          {
            saveTimer()
          } // Button
          .disabled(!isValid)
        } // ToolbarItem
      } // toolbar
    } // NavigationStack
  } // var body
  
  private var isValid: Bool
  {
    !name.isEmpty && totalSeconds > 0
  } // var isValid
  
  private var totalSeconds: TimeInterval
  {
    TimeInterval(hours * 3600 + minutes * 60 + seconds)
  } // var totalSeconds
  
  private func previewSound()
  {
    // Get the sound file URL from the bundle root
    if let soundURL = Bundle.main.url(
      forResource  : (selectedSoundFileName as NSString).deletingPathExtension,
      withExtension: (selectedSoundFileName as NSString).pathExtension
    )
    {
      do
      {
        // Store player as state to prevent deallocation
        previewPlayer = try AVAudioPlayer(contentsOf: soundURL)
        previewPlayer?.volume = volume
        previewPlayer?.prepareToPlay()
        previewPlayer?.play()
      } // do
      catch
      {
        print("Failed to preview sound: \(error)")
      } // catch
    } // if
  } // func previewSound
  
  private func saveTimer()
  {
    if let existing = timerToEdit
    {
      var updated = existing
      updated.name = name
      updated.intervalSeconds = totalSeconds
      updated.soundFileName = selectedSoundFileName
      updated.volume = volume
      
      // If timer was running, restart it with new settings
      if updated.isRunning
      {
        timerManager.stopTimer(updated)
        timerManager.updateTimer(updated)
        timerManager.startTimer(updated)
      } // if
      else
      {
        timerManager.updateTimer(updated)
      } // else
    } // if
    else
    {
      let newTimer = IntervalTimer(
        name           : name,
        intervalSeconds: totalSeconds,
        soundFileName  : selectedSoundFileName,
        volume         : volume
      )
      timerManager.addTimer(newTimer)
    } // else
    
    dismiss()
  } // func saveTimer
} // struct TimerEditView

#Preview
{
  TimerEditView(timerManager: TimerManager())
} // Preview
