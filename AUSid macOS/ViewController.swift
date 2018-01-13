//
//  ViewController.swift
//  AUSid macOS
//
//  Created by Antonio Malara on 14/01/2018.
//

import Cocoa
import AudioToolbox
import CoreAudioKit

class ViewController: NSViewController {

    @IBOutlet weak var playButton    : NSButton!
    @IBOutlet weak var containerView : NSView!

    var playEngine : SimplePlayEngine!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_MusicDevice
        componentDescription.componentSubType = 0x73696464 // 'sidd'
        componentDescription.componentManufacturer = 0x414D616C // 'AMal'
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        
        playEngine = SimplePlayEngine(componentType: kAudioUnitType_MusicDevice)
        
        playEngine.selectAudioUnitWithComponentDescription(componentDescription) {
            self.playEngine.testAudioUnit?.requestViewController {
                $0.map { self.embedPluginView($0) }
            }
        }
    }
    
    func embedPluginView(_ controller: NSViewController) {
        let view = controller.view
        containerView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "H:|-[view]-|",
                options: [],
                metrics: nil,
                views: ["view": view]
            )
        )
        
        containerView.addConstraints(
            NSLayoutConstraint.constraints(
                withVisualFormat: "V:|-[view]-|",
                options: [],
                metrics: nil,
                views: ["view": view]
            )
        )
    }
    
    @IBAction func togglePlay(_ sender: AnyObject?) {
        let isPlaying = playEngine.togglePlay()
        let titleText = isPlaying ? "Stop" : "Play"
        
        playButton.title = titleText
    }

}
