//
//  TimerEditView.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

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
  @State private var availableSounds: [SoundFile]
  @State private var showingImportInstructions = false
  @State private var showingFilePicker = false
  @State private var showingManageCustomSounds = false
  
  init(
    timerManager: TimerManager,
    timerToEdit : IntervalTimer? = nil
  )
  {
    self.timerManager = timerManager
    self.timerToEdit = timerToEdit
    
    // Load available sounds
    let sounds = loadAvailableSounds()
    _availableSounds = State(initialValue: sounds)
    
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
          
          Button("Import Custom Sound from Files")
          {
            showingFilePicker = true
          } // Button
          .foregroundStyle(.blue)
          
          Button("Manage Custom Sounds")
          {
            showingManageCustomSounds = true
          } // Button
          .foregroundStyle(.blue)
          
          Button("How to Import from Voice Memos")
          {
            showingImportInstructions = true
          } // Button
          .foregroundStyle(.secondary)
          
          Button("Refresh Sound List")
          {
            refreshSoundList()
          } // Button
          .foregroundStyle(.blue)
          
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
    .alert(
      "Import from Voice Memos",
      isPresented: $showingImportInstructions
    )
    {
      Button("OK") { }
    } message:
    {
      Text("To import from Voice Memos:\n\n1. Open Voice Memos app\n2. Tap on a recording\n3. Tap Share button\n4. Select \"Save to Files\"\n5. Save to Downloads or any folder\n6. Return to NudgeMe\n7. Tap \"Import Custom Sound from Files\"\n8. Browse to where you saved it")
    } // alert
    .fileImporter(
      isPresented: $showingFilePicker,
      allowedContentTypes: [.audio],
      allowsMultipleSelection: false
    )
    { result in
      handleFileImport(result)
    } // fileImporter
    .sheet(isPresented: $showingManageCustomSounds)
    {
      ManageCustomSoundsView(onSoundsChanged: refreshSoundList)
    } // sheet
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
    // First check if it's a custom sound
    if let customURL = CustomSoundManager.shared.getCustomSoundURL(fileName: selectedSoundFileName)
    {
      do
      {
        previewPlayer = try AVAudioPlayer(contentsOf: customURL)
        previewPlayer?.volume = volume
        previewPlayer?.prepareToPlay()
        previewPlayer?.play()
        return
      } // do
      catch
      {
        print("Failed to preview custom sound: \(error)")
      } // catch
    } // if
    
    // Otherwise, try built-in sound from bundle
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
  
  // Refresh the sound list to include newly imported sounds
  private func refreshSoundList()
  {
    availableSounds = loadAvailableSounds()
    print("Refreshed sound list: \(availableSounds.count) sounds available")
  } // func refreshSoundList
  
  // Handle file import from file picker
  private func handleFileImport(_ result: Result<[URL], Error>)
  {
    switch result
    {
      case .success(let urls):
        guard let url = urls.first else { return }
        
        print("=== TimerEditView: File picker selected URL: \(url)")
        
        // Import the file
        let importResult = CustomSoundManager.shared.importSound(from: url)
        
        switch importResult
        {
          case .success(let fileName):
            print("=== TimerEditView: Successfully imported \(fileName)")
            // Refresh the sound list
            refreshSoundList()
            // Select the newly imported sound
            selectedSoundFileName = fileName
            
          case .failure(let error):
            print("=== TimerEditView: Failed to import: \(error.localizedDescription)")
        } // switch
        
      case .failure(let error):
        print("=== TimerEditView: File picker error: \(error.localizedDescription)")
    } // switch
  } // func handleFileImport
  
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

// View for managing (deleting) custom sounds
struct ManageCustomSoundsView: View
{
  @Environment(\.dismiss) private var dismiss
  @State private var customSounds: [SoundFile] = []
  let onSoundsChanged: () -> Void
  
  var body: some View
  {
    NavigationStack
    {
      List
      {
        if customSounds.isEmpty
        {
          Text("No custom sounds imported yet")
            .foregroundStyle(.secondary)
        } // if
        else
        {
          ForEach(customSounds)
          { sound in
            HStack
            {
              Text(sound.name)
              Spacer()
              Button(role: .destructive)
              {
                deleteSound(sound)
              } // Button
              label:
              {
                Image(systemName: "trash")
                  .foregroundStyle(.red)
              } // label
            } // HStack
          } // ForEach
        } // else
      } // List
      .navigationTitle("Manage Custom Sounds")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar
      {
        ToolbarItem(placement: .confirmationAction)
        {
          Button("Done")
          {
            dismiss()
          } // Button
        } // ToolbarItem
      } // toolbar
      .onAppear
      {
        loadCustomSounds()
      } // onAppear
    } // NavigationStack
  } // var body
  
  private func loadCustomSounds()
  {
    customSounds = CustomSoundManager.shared.getCustomSounds()
    print("Loaded \(customSounds.count) custom sounds for management")
  } // func loadCustomSounds
  
  private func deleteSound(_ sound: SoundFile)
  {
    do
    {
      try CustomSoundManager.shared.deleteCustomSound(fileName: sound.fileName)
      loadCustomSounds()
      onSoundsChanged()
    } // do
    catch
    {
      print("Failed to delete sound: \(error)")
    } // catch
  } // func deleteSound
} // struct ManageCustomSoundsView
