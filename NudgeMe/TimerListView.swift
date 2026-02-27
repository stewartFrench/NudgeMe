//
//  TimerListView.swift
//  NudgeMe
//
//  Created by Stewart French on 2/12/26.
//

import SwiftUI
import Combine

// ----------------------------------------------

struct TimerListView: View
{
  @StateObject private var timerManager = TimerManager.shared
  @State private var showingAddTimer = false
  
  var body: some View
  {
    NavigationStack
    {
      List
      {
        ForEach(timerManager.timers)
        { timer in
          TimerRow(
            timer       : timer,
            timerManager: timerManager
          )
        } // ForEach
        .onDelete(perform: deleteTimers)
      } // List
      .navigationTitle("Interval Timers")
      .toolbar
      {
        ToolbarItem(placement: .primaryAction)
        {
          Button
          {
            showingAddTimer = true
          } // Button
          label:
          {
            Image(systemName: "plus")
          } // label
        } // ToolbarItem
      } // toolbar
      .sheet(isPresented: $showingAddTimer)
      {
        TimerEditView(timerManager: timerManager)
      } // sheet
      .overlay
      {
        if timerManager.timers.isEmpty
        {
          ContentUnavailableView
          {
            Label(
              "No Timers",
              systemImage: "timer"
            )
          } // ContentUnavailableView
          description:
          {
            Text("Tap the + button to create your first interval timer")
          } // description
        } // if
      } // overlay
    } // NavigationStack
  } // var body
  

  // -----------

  private func deleteTimers(at offsets: IndexSet)
  {
    for index in offsets
    {
      timerManager.deleteTimer(timerManager.timers[index])
    } // for
  } // func deleteTimers
} // struct TimerListView



// ----------------------------------------------
struct TimerRow: View
{
  let timer: IntervalTimer
  @ObservedObject var timerManager: TimerManager
  @State private var showingEditSheet = false
  @State private var currentTime = Date()
  
  let updateTimer = Timer.publish(
    every  : 1,
    on     : .main,
    in     : .common
  ).autoconnect()
  
  var body: some View
  {
    HStack
    {
      VStack(
        alignment: .leading,
        spacing  : 4
      )
      {
        Text(timer.name)
          .font(.headline)
        
        Text(formatInterval(timer.intervalSeconds))
          .font(.subheadline)
          .foregroundStyle(.secondary)
        
        let soundDisplayName = (timer.soundFileName as NSString).deletingPathExtension
        Text("Sound: \(soundDisplayName) • Volume: \(Int(timer.volume * 100))%")
          .font(.caption)
          .foregroundStyle(.secondary)
        
        if timer.isRunning, let nextFire = timer.nextFireDate
        {
          Text("Next: \(formatNextOccurrence(nextFire))")
            .font(.caption)
            .foregroundStyle(.blue)
        } // if
      } // VStack
      
      Spacer()
      
      // Start/Stop button
      Button
      {
        if timer.isRunning
        {
          timerManager.stopTimer(timer)
        } // if
        else
        {
          timerManager.startTimer(timer)
        } // else
      } // Button
      label:
      {
        Image(systemName: timer.isRunning ? "stop.circle.fill" : "play.circle.fill")
          .font(.title2)
          .foregroundStyle(timer.isRunning ? .red : .green)
      } // label
      .buttonStyle(.plain)
    } // HStack
    .contentShape(Rectangle())
    .onTapGesture
    {
      showingEditSheet = true
    } // onTapGesture
    .sheet(isPresented: $showingEditSheet)
    {
      TimerEditView(
        timerManager: timerManager,
        timerToEdit : timer
      )
    } // sheet
    .onReceive(updateTimer)
    { _ in
      currentTime = Date()
      
      // Update next fire date if timer is running and time has passed
      if timer.isRunning, let nextFire = timer.nextFireDate, nextFire <= currentTime
      {
        var updatedTimer = timer
        updatedTimer.nextFireDate = nextFire.addingTimeInterval(timer.intervalSeconds)
        timerManager.updateTimer(updatedTimer)
      } // if
    } // onReceive
  } // var body
  

  // -----------
  private func formatInterval(_ seconds: TimeInterval) -> String
  {
    let hours = Int(seconds) / 3600
    let minutes = (Int(seconds) % 3600) / 60
    let secs = Int(seconds) % 60
    
    var parts: [String] = []
    if hours > 0
    {
      parts.append("\(hours)h")
    } // if
    if minutes > 0
    {
      parts.append("\(minutes)m")
    } // if
    if secs > 0 || parts.isEmpty
    {
      parts.append("\(secs)s")
    } // if
    
    return "Every " + parts.joined(separator: " ")
  } // func formatInterval
  

  // -----------
  private func formatNextOccurrence(_ date: Date) -> String
  {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter.string(from: date)
  } // func formatNextOccurrence
} // struct TimerRow

#Preview
{
  TimerListView()
} // Preview
