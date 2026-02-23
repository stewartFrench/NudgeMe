//
//  NudgeMeApp.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import SwiftUI
import UserNotifications
import AVFoundation
import Combine

// Observable object to manage import state
class ImportManager: ObservableObject
{
  @Published var showImportAlert = false
  @Published var importMessage = ""
  @Published var importSuccess = false
  
  static let shared = ImportManager()
  
  // Handle incoming audio file from Share Sheet
  func handleIncomingURL(_ url: URL)
  {
    print("=== NudgeMe: Received URL: \(url)")
    print("=== URL path: \(url.path)")
    print("=== URL is file: \(url.isFileURL)")
    
    // Check if it's an audio file
    let fileExtension = url.pathExtension.lowercased()
    let audioExtensions = ["caf", "m4a", "mp3", "wav", "aiff", "aifc"]
    
    print("=== File extension: \(fileExtension)")
    
    guard audioExtensions.contains(fileExtension) else
    {
      print("=== ERROR: Not an audio file: \(fileExtension)")
      self.importMessage = "Not a supported audio file format: \(fileExtension)"
      self.importSuccess = false
      self.showImportAlert = true
      return
    } // guard
    
    print("=== Attempting to import audio file...")
    
    // Import the sound file
    let result = CustomSoundManager.shared.importSound(from: url)
    
    switch result
    {
      case .success(let fileName):
        print("=== SUCCESS: Imported sound: \(fileName)")
        self.importMessage = "Successfully imported \(fileName)\n\nTap 'Refresh Sound List' in the timer editor to see it."
        self.importSuccess = true
        self.showImportAlert = true
        
      case .failure(let error):
        print("=== ERROR: Failed to import sound: \(error.localizedDescription)")
        self.importMessage = error.localizedDescription
        self.importSuccess = false
        self.showImportAlert = true
    } // switch
  } // func handleIncomingURL
} // class ImportManager

@main
struct NudgeMeApp: App
{
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  @StateObject private var importManager = ImportManager.shared
  
  init()
  {
    // Set up URL handler
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1)
    {
      AppDelegate.shared?.onURLReceived =
      { url in
        ImportManager.shared.handleIncomingURL(url)
      } // closure
    } // asyncAfter
  } // init
  
  var body: some Scene
  {
    WindowGroup
    {
      ContentHostView(
        showImportAlert: $importManager.showImportAlert,
        importMessage  : $importManager.importMessage,
        importSuccess  : $importManager.importSuccess
      )
    } // WindowGroup
  } // var body
} // struct NudgeMeApp

// App delegate to set up notification handling and URL handling
class AppDelegate: NSObject, UIApplicationDelegate
{
  let notificationDelegate = NotificationDelegate()
  static var shared: AppDelegate?
  
  var onURLReceived: ((URL) -> Void)?
  
  func application(
                                 _ application : UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool
  {
    print("=== AppDelegate: didFinishLaunchingWithOptions called")
    AppDelegate.shared = self
    
    // Check if launched with a URL
    if let url = launchOptions?[.url] as? URL
    {
      print("=== AppDelegate: Launched with URL: \(url)")
    } // if
    
    // Set up notification delegate
    UNUserNotificationCenter.current().delegate = notificationDelegate
    
    // Enable background audio (for notification sounds)
    do
    {
      try AVAudioSession.sharedInstance().setCategory(
        .playback,
        mode   : .default,
        options: [.mixWithOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } // do
    catch
    {
      print("Failed to set up audio session: \(error)")
    } // catch
    
    print("=== AppDelegate: Setup complete")
    return true
  } // func application
  
  // Handle incoming URLs
  func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool
  {
    print("=== AppDelegate: Received URL via application:open:options:")
    print("=== URL: \(url)")
    print("=== URL scheme: \(url.scheme ?? "none")")
    print("=== URL host: \(url.host ?? "none")")
    print("=== Options: \(options)")
    onURLReceived?(url)
    return true
  } // func application
  
  // Alternative method for opening documents
  func application(
    _ application: UIApplication,
    open inputURL: URL,
    sourceApplication: String?,
    annotation: Any
  ) -> Bool
  {
    print("=== AppDelegate: Received URL via LEGACY application:open:sourceApplication:")
    print("=== URL: \(inputURL)")
    print("=== Source application: \(sourceApplication ?? "unknown")")
    onURLReceived?(inputURL)
    return true
  } // func application
} // class AppDelegate

// Helper view to host the main content and show import alerts
struct ContentHostView: View
{
  @Binding var showImportAlert: Bool
  @Binding var importMessage: String
  @Binding var importSuccess: Bool
  
  var body: some View
  {
    TimerListView()
      .alert(
        importSuccess ? "Import Successful" : "Import Failed",
        isPresented: $showImportAlert
      )
      {
        Button("OK")
        {
          showImportAlert = false
        } // Button
      } message:
      {
        Text(importMessage)
      } // alert
  } // var body
} // struct ContentHostView
