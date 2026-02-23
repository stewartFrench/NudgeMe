//
//  CustomSoundManager.swift
//  NudgeMe
//
//  Created by Stewart French on 2/19/26.
//

import Foundation
import AVFoundation

// Manages custom sound files imported by the user
class CustomSoundManager
{
  static let shared = CustomSoundManager()
  
  // Directory for custom sounds in Documents
  private let customSoundsDirectory: URL
  
  private init()
  {
    // Create custom sounds directory in Documents
    let documentsPath = FileManager.default.urls(
      for: .documentDirectory,
      in : .userDomainMask
    ).first!
    
    customSoundsDirectory = documentsPath.appendingPathComponent(
      "CustomSounds",
      isDirectory: true
    )
    
    // Create directory if it doesn't exist
    createCustomSoundsDirectoryIfNeeded()
  } // init
  
  // Create the custom sounds directory
  private func createCustomSoundsDirectoryIfNeeded()
  {
    if !FileManager.default.fileExists(atPath: customSoundsDirectory.path)
    {
      do
      {
        try FileManager.default.createDirectory(
          at                : customSoundsDirectory,
          withIntermediateDirectories: true,
          attributes        : nil
        )
        print("Created custom sounds directory: \(customSoundsDirectory.path)")
      } // do
      catch
      {
        print("Failed to create custom sounds directory: \(error)")
      } // catch
    } // if
  } // func createCustomSoundsDirectoryIfNeeded
  
  // Import an audio file from a URL
  func importSound(from sourceURL: URL) -> Result<String, Error>
  {
    print("=== CustomSoundManager: importSound called")
    print("=== Source URL: \(sourceURL)")
    print("=== Custom sounds directory: \(customSoundsDirectory.path)")
    
    do
    {
      // Start accessing the security-scoped resource
      let accessed = sourceURL.startAccessingSecurityScopedResource()
      print("=== Security-scoped resource accessed: \(accessed)")
      
      defer
      {
        if accessed
        {
          sourceURL.stopAccessingSecurityScopedResource()
          print("=== Stopped accessing security-scoped resource")
        } // if
      } // defer
      
      // Check if file exists at source
      let fileExists = FileManager.default.fileExists(atPath: sourceURL.path)
      print("=== File exists at source: \(fileExists)")
      
      // Get the filename
      let originalFileName = sourceURL.lastPathComponent
      let fileExtension = sourceURL.pathExtension.lowercased()
      print("=== Original filename: \(originalFileName)")
      print("=== File extension: \(fileExtension)")
      
      // Validate audio format
      let supportedFormats = ["caf", "m4a", "mp3", "wav", "aiff", "aifc"]
      guard supportedFormats.contains(fileExtension) else
      {
        print("=== ERROR: Unsupported format")
        throw CustomSoundError.unsupportedFormat
      } // guard
      
      // Convert to CAF format for compatibility with notifications
      let baseName = (originalFileName as NSString).deletingPathExtension
      let cafFileName = "\(baseName).caf"
      let destinationURL = customSoundsDirectory.appendingPathComponent(cafFileName)
      print("=== Base destination URL: \(destinationURL.path)")
      
      // If file already exists, add a number suffix
      let finalDestinationURL = makeUniqueFileName(baseURL: destinationURL)
      print("=== Final destination URL: \(finalDestinationURL.path)")
      
      // Convert audio file to CAF format
      print("=== Starting conversion to CAF...")
      try convertToCAF(
        sourceURL     : sourceURL,
        destinationURL: finalDestinationURL
      )
      
      print("=== Successfully imported sound: \(finalDestinationURL.lastPathComponent)")
      return .success(finalDestinationURL.lastPathComponent)
    } // do
    catch
    {
      print("=== ERROR: Failed to import sound: \(error)")
      print("=== Error details: \(error.localizedDescription)")
      return .failure(error)
    } // catch
  } // func importSound
  
  // Convert audio file to CAF format
  private func convertToCAF(
    sourceURL     : URL,
    destinationURL: URL
  ) throws
  {
    // Read the source audio file
    let sourceFile = try AVAudioFile(forReading: sourceURL)
    
    // Create output format (CAF with same settings as source)
    let outputFormat = sourceFile.processingFormat
    
    // Create destination file
    let outputFile = try AVAudioFile(
      forWriting : destinationURL,
      settings   : outputFormat.settings,
      commonFormat: outputFormat.commonFormat,
      interleaved: outputFormat.isInterleaved
    )
    
    // Read and write in chunks
    let bufferSize: AVAudioFrameCount = 4096
    guard let buffer = AVAudioPCMBuffer(
      pcmFormat    : outputFormat,
      frameCapacity: bufferSize
    )
    else
    {
      throw CustomSoundError.conversionFailed
    } // guard
    
    while sourceFile.framePosition < sourceFile.length
    {
      try sourceFile.read(into: buffer)
      try outputFile.write(from: buffer)
    } // while
  } // func convertToCAF
  
  // Make a unique filename if file already exists
  private func makeUniqueFileName(baseURL: URL) -> URL
  {
    var destinationURL = baseURL
    var counter = 1
    
    while FileManager.default.fileExists(atPath: destinationURL.path)
    {
      let baseName = (baseURL.lastPathComponent as NSString).deletingPathExtension
      let ext = baseURL.pathExtension
      let newFileName = "\(baseName)_\(counter).\(ext)"
      destinationURL = baseURL.deletingLastPathComponent().appendingPathComponent(newFileName)
      counter += 1
    } // while
    
    return destinationURL
  } // func makeUniqueFileName
  
  // Get all custom sound files
  func getCustomSounds() -> [SoundFile]
  {
    print("=== CustomSoundManager: getCustomSounds called")
    print("=== Looking in directory: \(customSoundsDirectory.path)")
    
    do
    {
      let files = try FileManager.default.contentsOfDirectory(
        at                : customSoundsDirectory,
        includingPropertiesForKeys: nil
      )
      
      print("=== Found \(files.count) total files in custom sounds directory")
      
      let audioFiles = files.filter
      { url in
        let ext = url.pathExtension.lowercased()
        let isAudio = ["caf", "m4a", "mp3", "wav", "aiff", "aifc"].contains(ext)
        if isAudio
        {
          print("===   Audio file: \(url.lastPathComponent)")
        } // if
        return isAudio
      } // filter
      
      print("=== Returning \(audioFiles.count) custom sound files")
      
      return audioFiles.map { SoundFile(fileName: $0.lastPathComponent, isCustom: true) }
    } // do
    catch
    {
      print("=== ERROR: Failed to get custom sounds: \(error)")
      return []
    } // catch
  } // func getCustomSounds
  
  // Get URL for a custom sound file
  func getCustomSoundURL(fileName: String) -> URL?
  {
    let url = customSoundsDirectory.appendingPathComponent(fileName)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
  } // func getCustomSoundURL
  
  // Delete a custom sound file
  func deleteCustomSound(fileName: String) throws
  {
    let url = customSoundsDirectory.appendingPathComponent(fileName)
    try FileManager.default.removeItem(at: url)
    print("Deleted custom sound: \(fileName)")
  } // func deleteCustomSound
} // class CustomSoundManager

// Custom errors
enum CustomSoundError: LocalizedError
{
  case unsupportedFormat
  case conversionFailed
  case fileNotFound
  
  var errorDescription: String?
  {
    switch self
    {
      case .unsupportedFormat:
        return "Unsupported audio format. Please use CAF, M4A, MP3, WAV, or AIFF files."
      case .conversionFailed:
        return "Failed to convert audio file to CAF format."
      case .fileNotFound:
        return "Audio file not found."
    } // switch
  } // var errorDescription
} // enum CustomSoundError
