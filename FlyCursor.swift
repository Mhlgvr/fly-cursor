import AppKit
import CoreGraphics

// Cursor graphics stay click-through; no event interception or recording.
// Background hiding uses the dynamically resolved WindowServer connection property.
final class SystemCursor {
 typealias Connection = @convention(c) () -> Int32
 typealias Property = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
 typealias Visibility = @convention(c) () -> Int32
 private let library = dlopen(nil, RTLD_NOW)
 private var connection: Connection?
 private var property: Property?
 private var visibility: Visibility?
 private var ownsHide = false
 private(set) var backgroundReady = false
 private var cid: Int32 = 0
 init() {
  // Load on demand; unresolved symbols fail safely instead of preventing launch.
  _ = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW)
  for name in ["_CGSDefaultConnection", "CGSMainConnectionID", "SLSMainConnectionID"] {
   if let symbol = dlsym(library, name) { connection = unsafeBitCast(symbol, to: Connection.self); break }
  }
  for name in ["CGSSetConnectionProperty", "SLSSetConnectionProperty"] {
   if let symbol = dlsym(library, name) { property = unsafeBitCast(symbol, to: Property.self); break }
  }
  if let symbol = dlsym(library, "CGCursorIsVisible") { visibility = unsafeBitCast(symbol, to: Visibility.self) }
  if let connection, let property {
   cid = connection()
   backgroundReady = property(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue) == 0
  }
 }
 var visible: Bool? { visibility.map { $0() != 0 } }
 func hide() {
  // Reacquire only when an app or a Space transition actually made it visible.
  // Balance our previous request first; never accumulate a hide count per frame.
  if ownsHide && visible != true { return }
  restore()
  ownsHide = CGDisplayHideCursor(CGMainDisplayID()) == .success
 }
 func restore() {
  guard ownsHide else { return }
  CGDisplayShowCursor(CGMainDisplayID()); ownsHide = false
 }
 func shutdown() {
  restore()
  if backgroundReady, let property { _ = property(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanFalse) }
  backgroundReady = false
 }
}
func ellipse(_ r: NSRect, _ color: NSColor) { color.setFill(); NSBezierPath(ovalIn: r).fill() }
let ink = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.11, alpha: 1)
func stroke(_ points: [NSPoint], width: CGFloat, color: NSColor) {
 guard let first = points.first else { return }
 let p = NSBezierPath(); p.move(to: first)
 for v in points.dropFirst() { p.line(to: v) }
 p.lineWidth = width; p.lineCapStyle = .round; p.lineJoinStyle = .round
 color.setStroke(); p.stroke()
}
func drawFly(center: NSPoint, size: CGFloat, heading: CGFloat, flight: CGFloat, phase: Double) {
 NSGraphicsContext.saveGraphicsState()
 var tr = AffineTransform(translationByX: center.x, byY: center.y)
 tr.rotate(byRadians: heading - .pi / 2); tr.scale(size / 30)
 (tr as NSAffineTransform).concat()
 let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
 shadow.shadowBlurRadius = 2.4; shadow.shadowOffset = NSSize(width: 0.5, height: -1.2); shadow.set()
 // Six fine articulated legs, held closer while airborne.
 for side: CGFloat in [-1, 1] {
  for j in 0..<3 {
   let yy = CGFloat(j) * 4.2 - 5
   let tuck = flight * 1.7
   stroke([NSPoint(x: side*3, y: yy),NSPoint(x: side*(7-tuck), y: yy-2),NSPoint(x: side*(10-tuck), y: yy-5)],width:0.75,color:ink)
  }
 }
 // Wings extend while flying, fold over the back when sitting.
 for side: CGFloat in [-1, 1] {
  NSGraphicsContext.saveGraphicsState()
  var wt = AffineTransform(translationByX: side * 2.5, byY: 1.0)
  let flap = CGFloat(sin(phase * .pi * 2 * 19))
  wt.rotate(byRadians: side * (0.22 + flight * (1.0 + flap * 0.32)))
  (wt as NSAffineTransform).concat()
  let wing = NSBezierPath()
  wing.move(to: NSPoint(x:0,y:1)); wing.curve(to:NSPoint(x:side*4,y:-16),controlPoint1:NSPoint(x:side*8,y:-3),controlPoint2:NSPoint(x:side*8,y:-14));wing.curve(to:NSPoint(x:0,y:1),controlPoint1:NSPoint(x:side * -1,y:-17),controlPoint2:NSPoint(x:side * -3,y:-4))
  NSColor(calibratedRed:0.77,green:0.86,blue:0.88,alpha:0.60).setFill();wing.fill()
  NSColor(calibratedWhite:0.36,alpha:0.6).setStroke();wing.lineWidth=0.45;wing.stroke()
  stroke([NSPoint(x:0,y:0),NSPoint(x:side*2,y:-7),NSPoint(x:side*4,y:-14)],width:0.35,color:NSColor.gray.withAlphaComponent(0.65))
  stroke([NSPoint(x:side*2,y:-7),NSPoint(x:side*6,y:-10)],width:0.3,color:NSColor.gray.withAlphaComponent(0.55))
  NSGraphicsContext.restoreGraphicsState()
 }
 let abdomen=NSBezierPath(ovalIn:NSRect(x:-4.4,y:-12,width:8.8,height:12))
 NSGradient(starting:NSColor(calibratedRed:0.31,green:0.34,blue:0.26,alpha:1),ending:ink)!.draw(in:abdomen,angle:0)
 for y: CGFloat in [-9,-6,-3] {stroke([NSPoint(x:-3.6,y:y),NSPoint(x:0,y:y-0.7),NSPoint(x:3.6,y:y)],width:0.65,color:NSColor.black.withAlphaComponent(0.6))}
 let thorax=NSBezierPath(ovalIn:NSRect(x:-4.6,y:-2,width:9.2,height:10))
 NSGradient(starting:NSColor(calibratedWhite:0.35,alpha:1),ending:ink)!.draw(in:thorax,angle:20)
 for x: CGFloat in [-2,0,2] {stroke([NSPoint(x:x,y:0),NSPoint(x:x,y:6)],width:0.65,color:NSColor(calibratedWhite:0.6,alpha:0.7))}
 ellipse(NSRect(x:-3.2,y:6,width:6.4,height:6),ink)
 for side: CGFloat in [-1,1] {
  ellipse(NSRect(x:side*2.1-1.8,y:7,width:3.6,height:4.3),NSColor(calibratedRed:0.48,green:0.13,blue:0.085,alpha:1))
  ellipse(NSRect(x:side*2.1-0.8,y:9.5,width:1,height:1.1),NSColor(calibratedRed:0.87,green:0.47,blue:0.32,alpha:0.8))
  stroke([NSPoint(x:side*1.2,y:11),NSPoint(x:side*2.6,y:14)],width:0.6,color:ink)
 }
 for i in 0..<12 {
  let theta=CGFloat(i) * .pi / 6
  stroke([NSPoint(x:cos(theta)*4.1,y:sin(theta)*4+2),NSPoint(x:cos(theta)*5.9,y:sin(theta)*5.5+2)],width:0.4,color:ink)
 }
 NSGraphicsContext.restoreGraphicsState()
}
final class FlyView: NSView {
 var heading: CGFloat = .pi/2
 var flight: CGFloat = 0
 var phase: Double = 0
 var flySize: CGFloat = 30
 override var isOpaque: Bool { false }
 override func draw(_ dirtyRect: NSRect) { drawFly(center:NSPoint(x:bounds.midX,y:bounds.midY),size:flySize,heading:heading,flight:flight,phase:phase) }
}
final class OverlayPanel: NSPanel {
 override var canBecomeKey: Bool { false }
 override var canBecomeMain: Bool { false }
}
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
 var panel: OverlayPanel!
 var fly: FlyView!
 var status: NSStatusItem!
 var timer: Timer?
 var previous = NSEvent.mouseLocation
 var previousTick = ProcessInfo.processInfo.systemUptime
 var lastMotion = ProcessInfo.processInfo.systemUptime
 var enabled = true
 var hideNative = true
 let systemCursor = SystemCursor()
 var menuOpen = false
 var enabledItem: NSMenuItem!
 var hideItem: NSMenuItem!
 var started = ProcessInfo.processInfo.systemUptime
 var signalSources: [DispatchSourceSignal] = []
 var smoke = CommandLine.arguments.contains("--smoke-test")
 func applicationDidFinishLaunching(_ notification: Notification) {
  // Avoid multiple instances maintaining independent hide counts.
  if NSRunningApplication.runningApplications(withBundleIdentifier:Bundle.main.bundleIdentifier ?? "local.flycursor").filter({$0.processIdentifier != ProcessInfo.processInfo.processIdentifier}).count > 0 {NSApp.terminate(nil);return}
  NSApp.setActivationPolicy(.accessory)
  for sig in [SIGTERM, SIGINT] {
   signal(sig, SIG_IGN)
   let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
   source.setEventHandler { [weak self] in self?.quit() }
   source.resume(); signalSources.append(source)
  }
  panel=OverlayPanel(contentRect:NSRect(x:0,y:0,width:112,height:112),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false
  panel.ignoresMouseEvents=true;panel.hidesOnDeactivate=false
  panel.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.cursorWindow)))
  panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle,.stationary]
  panel.isReleasedWhenClosed=false
  fly=FlyView(frame:NSRect(x:0,y:0,width:112,height:112));panel.contentView=fly
  status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
  status.button?.title="🪰";status.button?.toolTip="Fly Cursor — муха у курсора"
  let menu=NSMenu();menu.delegate=self
  let title=NSMenuItem(title:"Fly Cursor",action:nil,keyEquivalent:"");title.isEnabled=false;menu.addItem(title)
  enabledItem=NSMenuItem(title:"Муха включена",action:#selector(toggle),keyEquivalent:"");enabledItem.target=self;enabledItem.state = .on;menu.addItem(enabledItem)
  hideItem=NSMenuItem(title:"Скрывать обычную стрелку",action:#selector(toggleHide),keyEquivalent:"");hideItem.target=self;hideItem.state = .on;menu.addItem(hideItem)
  let sizeMenu=NSMenu()
  for (name,value) in [("Маленькая",22),("Средняя",30),("Крупная",42)] {let item=NSMenuItem(title:name,action:#selector(setSize(_:)),keyEquivalent:"");item.tag=value;item.target=self;item.state=value==30 ? .on:.off;sizeMenu.addItem(item)}
  let sizeItem=NSMenuItem(title:"Размер",action:nil,keyEquivalent:"");sizeItem.submenu=sizeMenu;menu.addItem(sizeItem)
  menu.addItem(.separator())
  let quit=NSMenuItem(title:"Выйти и вернуть курсор",action:#selector(quit),keyEquivalent:"q");quit.target=self;menu.addItem(quit);status.menu=menu
  DistributedNotificationCenter.default().addObserver(self,selector:#selector(sessionLocked),name:NSNotification.Name("com.apple.screenIsLocked"),object:nil)
  DistributedNotificationCenter.default().addObserver(self,selector:#selector(sessionUnlocked),name:NSNotification.Name("com.apple.screenIsUnlocked"),object:nil)
  NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(sessionLocked),name:NSWorkspace.willSleepNotification,object:nil)
  NSWorkspace.shared.notificationCenter.addObserver(self,selector:#selector(sessionUnlocked),name:NSWorkspace.didWakeNotification,object:nil)
  timer=Timer(timeInterval:1.0/60,repeats:true) { [weak self] _ in self?.tick() }
  RunLoop.main.add(timer!,forMode:.common)
  panel.orderFrontRegardless()
  if smoke {
   print("Background cursor support: \(systemCursor.backgroundReady)")
   Timer.scheduledTimer(withTimeInterval:0.5,repeats:false){[weak self] _ in
    guard let self else {return}
    print("Hidden after startup: \(self.systemCursor.visible == false)")
    print("Foreground is another application: \(NSWorkspace.shared.frontmostApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier)")
    self.enabled=false;self.restoreCursor()
   }
   Timer.scheduledTimer(withTimeInterval:0.7,repeats:false){[weak self] _ in
    guard let self else {return}
    print("Visible after pause settles: \(self.systemCursor.visible == true)")
    self.enabled=true
   }
   Timer.scheduledTimer(withTimeInterval:1,repeats:false){[weak self] _ in
    guard let self else {return}
    print("Hidden after resume: \(self.systemCursor.visible == false)")
    self.sessionLocked()
   }
   Timer.scheduledTimer(withTimeInterval:1.2,repeats:false){[weak self] _ in
    guard let self else {return}
    print("Visible while suspended: \(self.systemCursor.visible == true)")
    self.sessionUnlocked()
   }
   Timer.scheduledTimer(withTimeInterval:1.5,repeats:false){[weak self] _ in
    guard let self else {return}
    self.menuWillOpen(NSMenu())
    print("Hidden in menu mode: \(self.systemCursor.visible == false)")
    self.menuDidClose(NSMenu())
   }
   Timer.scheduledTimer(withTimeInterval:3,repeats:false){[weak self] _ in self?.quit()}
  }
 }
 var suspended=false
 @objc func sessionLocked(){suspended=true;restoreCursor();panel.orderOut(nil)}
 @objc func sessionUnlocked(){suspended=false;previous=NSEvent.mouseLocation;lastMotion=ProcessInfo.processInfo.systemUptime}
 func restoreCursor(){systemCursor.restore()}
 func tick(){
  let now=ProcessInfo.processInfo.systemUptime;let dt=min(0.1,max(0.001,now-previousTick));previousTick=now
  let mouse=NSEvent.mouseLocation;let dx=mouse.x-previous.x;let dy=mouse.y-previous.y
  if hypot(dx,dy)>0.2 {lastMotion=now;let target=atan2(dy,dx);let delta=atan2(sin(target-fly.heading),cos(target-fly.heading));fly.heading += delta * min(1,CGFloat(dt)*22)}
  previous=mouse
  let target:CGFloat = now-lastMotion<0.13 ? 1:0
  fly.flight += (target-fly.flight)*min(1,CGFloat(dt)*18)
  fly.phase=now-started
  // The fly remains the pointer in menu bars and menus as well.
  let active=enabled && !suspended
  if active {
   // The fly's centre stays on the real click point; it never intercepts clicks.
   if dx != 0 || dy != 0 || !panel.isVisible { panel.setFrameOrigin(NSPoint(x:mouse.x-56,y:mouse.y-56)) }
   if !panel.isVisible { panel.orderFrontRegardless() }
   if fly.flight>0.001 || dx != 0 || dy != 0 { fly.needsDisplay=true }
   if hideNative { systemCursor.hide() }
   if !hideNative {restoreCursor()}
  } else {restoreCursor();panel.orderOut(nil)}
 }
 func menuWillOpen(_ menu:NSMenu){menuOpen=true}
 func menuDidClose(_ menu:NSMenu){menuOpen=false}
 @objc func toggle(){enabled.toggle();enabledItem.state=enabled ? .on:.off;if !enabled {restoreCursor()}}
 @objc func toggleHide(){hideNative.toggle();hideItem.state=hideNative ? .on:.off;if !hideNative {restoreCursor()}}
 @objc func setSize(_ sender:NSMenuItem){fly.flySize=CGFloat(sender.tag);fly.needsDisplay=true;for item in sender.menu?.items ?? [] {item.state=item===sender ? .on:.off}}
 @objc func quit(){timer?.invalidate();restoreCursor();panel?.orderOut(nil);systemCursor.shutdown();print("Fly Cursor: stopped; cursor visible=\(systemCursor.visible.map(String.init) ?? "unknown")");NSApp.terminate(nil)}
 func applicationWillTerminate(_ notification:Notification){systemCursor.shutdown()}
}
let app=NSApplication.shared
if CommandLine.arguments.contains("--preview") {
 let image=NSImage(size:NSSize(width:640,height:320));image.lockFocus()
 NSColor(calibratedRed:0.94,green:0.95,blue:0.91,alpha:1).setFill();NSRect(x:0,y:0,width:640,height:320).fill()
 drawFly(center:NSPoint(x:175,y:160),size:130,heading:.pi/2,flight:0,phase:0)
 drawFly(center:NSPoint(x:465,y:160),size:130,heading:.pi/2,flight:1,phase:0.022)
 let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:18,weight:.medium),.foregroundColor:ink]
 ("Покой" as NSString).draw(at:NSPoint(x:145,y:28),withAttributes:attrs)
 ("Движение" as NSString).draw(at:NSPoint(x:417,y:28),withAttributes:attrs)
 image.unlockFocus()
 let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
 let path=CommandLine.arguments.last!
 try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
} else {let delegate=AppDelegate();app.delegate=delegate;app.run()}
