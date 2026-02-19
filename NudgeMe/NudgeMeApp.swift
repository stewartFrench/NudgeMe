//
//  NudgeMeApp.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import SwiftUI
import UserNotifications
import AVFoundation

@main
struct NudgeMeApp: App
{
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  var body: some Scene
  {
    WindowGroup
    {
      TimerListView()
    } // WindowGroup
  } // var body
} // struct NudgeMeApp

// App delegate to set up notification handling
class AppDelegate: NSObject, UIApplicationDelegate
{
  let notificationDelegate = NotificationDelegate()
  
  func application(
                                 _ application : UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool
  {
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
    
    return true
  } // func application
} // class AppDelegate

