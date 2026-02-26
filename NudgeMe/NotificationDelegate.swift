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
  
  // This is called when a notification is delivered while the app is running
  // (foreground or background with audio playing)
  func userNotificationCenter(
    _ center                : UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions
  {
    // Don't show or play anything - the Foundation Timer handles all sounds
    // when the app is running (foreground or background)
    // Notifications only play when app is fully suspended
    return []
  } // func userNotificationCenter
  
  // This is called when the user interacts with a notification
  func userNotificationCenter(
    _ center            : UNUserNotificationCenter,
    didReceive response : UNNotificationResponse
  ) async
  {
    print("User interacted with notification: \(response.notification.request.identifier)")
    
    // Play the sound when user taps notification
    playSound(from: response.notification)
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
