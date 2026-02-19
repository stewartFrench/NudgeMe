//
//  SoundFileGenerator.swift
//  NudgeMe
//
//  Created by Stewart French on 2/13/26.
//

import Foundation
import AVFoundation

// Generates simple tone audio files for notifications
class SoundFileGenerator
{
  // Generate all sound files and save them to the app's documents directory
  static func generateAllSoundFiles()
  {
    let soundConfigs: [(name: String, frequency: Double, duration: Double)] =
    [
      ("tock",   800.0, 0.1),   // Short high tick
      ("tink",   1200.0, 0.08), // Higher, shorter tink
      ("pop",    600.0, 0.12),  // Lower, slightly longer pop
      ("peek",   1500.0, 0.06), // Very high, very short peek
      ("nope",   300.0, 0.15),  // Low, longer nope
      ("ding",   1000.0, 0.2),  // Medium tone, ding
      ("blip",   900.0, 0.09),  // Quick blip
    ]
    
    for config in soundConfigs
    {
      generateToneFile(
        filename : config.name,
        frequency: config.frequency,
        duration : config.duration
      )
    } // for
  } // func generateAllSoundFiles
  
  // Generate a simple tone and save as .caf file
  private static func generateToneFile(
    filename : String,
    frequency: Double,
    duration : Double
  )
  {
    let sampleRate: Double = 44100.0
    let amplitude: Double = 0.3 // Volume (0.0 to 1.0)
    
    // Calculate number of samples
    let frameCount = Int(sampleRate * duration)
    
    // Create audio format
    guard let format = AVAudioFormat(
      standardFormatWithSampleRate: sampleRate,
      channels                    : 1
    )
    else
    {
      print("Failed to create audio format")
      return
    } // guard
    
    // Create buffer
    guard let buffer = AVAudioPCMBuffer(
      pcmFormat    : format,
      frameCapacity: AVAudioFrameCount(frameCount)
    )
    else
    {
      print("Failed to create audio buffer")
      return
    } // guard
    
    buffer.frameLength = AVAudioFrameCount(frameCount)
    
    // Get pointer to the buffer's data
    guard let channelData = buffer.floatChannelData?[0]
    else
    {
      print("Failed to get channel data")
      return
    } // guard
    
    // Generate sine wave with envelope
    for frame in 0..<frameCount
    {
      let sampleTime = Double(frame) / sampleRate
      let sineValue = sin(2.0 * .pi * frequency * sampleTime)
      
      // Apply envelope (fade in and fade out to avoid clicks)
      let fadeInDuration = 0.005  // 5ms fade in
      let fadeOutDuration = 0.01  // 10ms fade out
      var envelope = 1.0
      
      if sampleTime < fadeInDuration
      {
        envelope = sampleTime / fadeInDuration
      } // if
      else if sampleTime > duration - fadeOutDuration
      {
        envelope = (duration - sampleTime) / fadeOutDuration
      } // else if
      
      channelData[frame] = Float(sineValue * amplitude * envelope)
    } // for
    
    // Save to Library/Sounds directory (required for notification sounds)
    let libraryPath = FileManager.default.urls(
      for: .libraryDirectory,
      in : .userDomainMask
    ).first!
    
    let soundsPath = libraryPath.appendingPathComponent("Sounds", isDirectory: true)
    
    // Create Sounds directory if it doesn't exist
    if !FileManager.default.fileExists(atPath: soundsPath.path)
    {
      try? FileManager.default.createDirectory(
        at                : soundsPath,
        withIntermediateDirectories: true,
        attributes        : nil
      )
    } // if
    
    let fileURL = soundsPath.appendingPathComponent("\(filename).caf")
    
    // Create audio file
    do
    {
      let audioFile = try AVAudioFile(
        forWriting: fileURL,
        settings  : format.settings
      )
      
      try audioFile.write(from: buffer)
      print("Generated sound file: \(filename).caf")
    } // do
    catch
    {
      print("Failed to write audio file \(filename): \(error)")
    } // catch
  } // func generateToneFile
} // class SoundFileGenerator
