#!/usr/bin/swift
//
//  wkpdf-proto.swift
//  Usage: wkpdf-proto.swift <input url> <pdf output filename>
//  Note: most of the useful options, including page size, are
//        still hard-coded
//
//  Copyright 2017 Mika Raento
//
//  This software is licensed under the 2-clause BSD license
//  See https://opensource.org/licenses/BSD-2-Clause
//

import Foundation
import WebKit

let input = CommandLine.arguments[1]
let output = CommandLine.arguments[2]

// Application window and delegat
let application:NSApplication! = NSApplication.shared()
application.setActivationPolicy(NSApplicationActivationPolicy.regular)
let styleMask = NSWindowStyleMask(
    rawValue:(NSWindowStyleMask.closable.rawValue |
              NSWindowStyleMask.titled.rawValue |
              NSWindowStyleMask.miniaturizable.rawValue))
let window:NSWindow! = NSWindow(contentRect: NSMakeRect(0, 0, 960, 720),
                                styleMask: styleMask,
                                backing: .buffered, defer: false)
window.center()
window.title = "Webkit PDF renderer proto"
window.makeKeyAndOrderFront(window)

class WindowDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApplication.shared().terminate(0)
    }
}
let windowDelegate = WindowDelegate()
window.delegate = windowDelegate

// Controller -
class Controller: NSObject, WebFrameLoadDelegate {
    var _webView: WebView
    init(webView:WebView) {
        self._webView = webView
        super.init()
        self.log(msg:"init\n")
    }
    func log(msg:String) {
        let handle = FileHandle.standardError
        if let data = msg.data(using: String.Encoding.utf8) {
            handle.write(data)
        }
    }
    public func webView(_ sender: WebView!, didFinishLoadFor frame: WebFrame!) {
        log(msg: String(format:"webView %@ didFinishLoadFor frame %@", sender, frame))
        self.makePaginatedPDF()
        NSApplication.shared().terminate(0)
    }
    func makePaginatedPDF() {
        self.log(msg:"Make paginated PDF...\n")
        var printInfoDict:[String:Any] = NSPrintInfo.shared().dictionary().mutableCopy() as! [String : Any]
        printInfoDict[NSPrintJobDisposition] = NSPrintSaveJob
        printInfoDict[NSPrintJobSavingURL] = URL(fileURLWithPath: "\(output)")
        let viewToPrint = self._webView.mainFrame.frameView.documentView
        let printInfo = NSPrintInfo(dictionary:printInfoDict)
        printInfo.paperSize = NSSize(width:595, height:623)
        printInfo.topMargin = 0.0
        printInfo.leftMargin = 0.0
        printInfo.bottomMargin = 0.0
        printInfo.rightMargin = 0.0
        let printOp = NSPrintOperation(view: viewToPrint!, printInfo: printInfo)
        printOp.showsPrintPanel = false
        self.log(msg:"Start NSPrintOperation\n")
        printOp.run()
        self.log(msg:"Terminate application\n")
    }
}

class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var _window: NSWindow
    var _controller: Controller?
    init(window: NSWindow) {
        self._window = window
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        let webView = WebView(frame: self._window.contentView!.frame)
        let controller = Controller(webView: webView)
        webView.frameLoadDelegate = controller
        let webPrefs = WebPreferences.standard()!
        webPrefs.loadsImagesAutomatically = true
        webPrefs.shouldPrintBackgrounds = true
        webView.preferences = webPrefs
        self._controller = controller
        self._window.contentView!.addSubview(webView)
        webView.mainFrame.load(URLRequest(url: URL(string: "\(input)")!))
    }
}
let applicationDelegate = ApplicationDelegate(window: window)
application.delegate = applicationDelegate
application.activate(ignoringOtherApps: true)
application.run()
