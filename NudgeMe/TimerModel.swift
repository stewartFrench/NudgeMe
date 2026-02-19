//
//  TimerModel.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import Foundation
import AudioToolbox

// Represents a single interval timer instance
struct IntervalTimer: Identifiable, Codable
{
  let id: UUID
  var name: String
  var intervalSeconds: TimeInterval
  var soundFileName: String  // Store filename instead of system sound ID
  var volume: Float  // Volume level from 0.0 to 1.0
  var isRunning: Bool
  var nextFireDate: Date?
  
  init(
    id             : UUID = UUID(),
    name           : String,
    intervalSeconds: TimeInterval,
    soundFileName  : String,
    volume         : Float = 1.0,
    isRunning      : Bool = false,
    nextFireDate   : Date? = nil
  )
  {
    self.id = id
    self.name = name
    self.intervalSeconds = intervalSeconds
    self.soundFileName = soundFileName
    self.volume = volume
    self.isRunning = isRunning
    self.nextFireDate = nextFireDate
  } // init
} // struct IntervalTimer

// Available sound for selection
struct SoundFile: Identifiable, Hashable
{
  let id: String  // Use filename as ID
  let name: String  // Display name (filename without extension)
  let fileName: String  // Full filename with extension
  
  init(
    fileName: String
  )
  {
    self.fileName = fileName
    self.id = fileName
    // Remove extension for display name
    self.name = (fileName as NSString).deletingPathExtension
  } // init
} // struct SoundFile

// Load all sound files from the bundle
// Note: Xcode copies files from Sounds folder to the bundle root
func loadAvailableSounds() -> [SoundFile]
{
  var sounds: [SoundFile] = []
  
  // Get all resources from the bundle
  if let resourcePath = Bundle.main.resourcePath
  {
    do
    {
      let allFiles = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
      
      // Filter for audio files (.caf, .wav, .aiff, .m4a)
      let audioExtensions = ["caf", "wav", "aiff", "m4a"]
      for file in allFiles
      {
        let ext = (file as NSString).pathExtension.lowercased()
        if audioExtensions.contains(ext)
        {
          sounds.append(SoundFile(fileName: file))
        } // if
      } // for
    } // do
    catch
    {
      print("Error loading sounds from bundle: \(error)")
    } // catch
  } // if
  
  // Sort by name
  sounds.sort { $0.name < $1.name }
  
  // Add a default sound if no sounds found
  if sounds.isEmpty
  {
    sounds.append(SoundFile(fileName: "default"))
  } // if
  
  return sounds
} // func loadAvailableSounds
