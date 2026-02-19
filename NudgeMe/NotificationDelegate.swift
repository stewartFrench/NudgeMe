//
//  NotificationDelegate.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import Foundation
import UserNotifications
import AudioToolbox

// Handles notification events and plays sounds when timers fire
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate
{
  
  // This is called when a notification is delivered while the app is in the foreground
  func userNotificationCenter(
    _ center                : UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  )
  {
    print("Notification received in foreground: \(notification.request.identifier)")
    
    // Don't play the sound here - the active timer handles it when in foreground
    // This prevents duplicate sounds
    
    // Don't show anything - the active timer is handling everything in foreground
    completionHandler([])
  } // func userNotificationCenter
  
  // This is called when the user interacts with a notification
  func userNotificationCenter(
    _ center             : UNUserNotificationCenter,
    didReceive response  : UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  )
  {
    print("User interacted with notification: \(response.notification.request.identifier)")
    
    // Play the sound when user taps notification
    playSound(from: response.notification)
    
    completionHandler()
  } // func userNotificationCenter
  
  // Extract and play the sound for a timer
  private func playSound(from notification: UNNotification)
  {
    // First try to get sound filename from userInfo (preferred method)
    if let soundFileName = notification.request.content.userInfo["soundFileName"] as? String
    {
      // Play the custom sound from file
      playSoundFromFile(soundFileName)
      return
    } // if
    
    // Fallback: Extract timer ID from notification identifier and look up in saved timers
    let identifier = notification.request.identifier
    if let timerIDString = identifier.split(separator: "-").first,
       let timerID = UUID(uuidString: String(timerIDString))
    {
      
      // Load saved timers to find the sound filename
      if let data = UserDefaults.standard.data(forKey: "savedTimers"),
         let timers = try? JSONDecoder().decode([IntervalTimer].self, from: data),
         let timer = timers.first(where: { $0.id == timerID })
      {
        
        // Play the sound from file
        playSoundFromFile(timer.soundFileName)
      } // if
    } // if
  } // func playSound
  
  // Play sound from file in the Sounds folder
  private func playSoundFromFile(_ fileName: String)
  {
    if let soundURL = Bundle.main.url(
      forResource  : (fileName as NSString).deletingPathExtension,
      withExtension: (fileName as NSString).pathExtension
    )
    {
      var soundID: SystemSoundID = 0
      AudioServicesCreateSystemSoundID(soundURL as CFURL, &soundID)
      AudioServicesPlaySystemSound(soundID)
    } // if
  } // func playSoundFromFile
} // class NotificationDelegate
