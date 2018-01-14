//
//  ViewController.swift
//  AUSid iOS
//
//  Created by Antonio Malara on 14/01/2018.
//

import UIKit
import AudioToolbox
import CoreAudioKit

class ViewController: UIViewController {

    @IBOutlet var playButton:      UIButton!
    @IBOutlet var auContainerView: UIView!
    
    var playEngine: SimplePlayEngine!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var componentDescription = AudioComponentDescription()
        componentDescription.componentType = kAudioUnitType_MusicDevice
        componentDescription.componentSubType = 0x73696464 // 'sidd'
        componentDescription.componentManufacturer = 0x414D616C // 'AMal'
        componentDescription.componentFlags = 0
        componentDescription.componentFlagsMask = 0
        
        // Create an audio file playback engine.
        playEngine = SimplePlayEngine(componentType: kAudioUnitType_MusicDevice)
        
        playEngine.selectAudioUnitWithComponentDescription(componentDescription) {
            self.playEngine.testAudioUnit?.requestViewController {
                controller in
                
                controller.map { self.addChildViewController($0) }
                controller?.view.frame = self.auContainerView.bounds
                (controller?.view).map { self.auContainerView.addSubview($0) }
                controller?.didMove(toParentViewController: self)
            }
        }
    }
    
    @IBAction func togglePlay(_ sender: AnyObject?) {
        let isPlaying = playEngine.togglePlay()
        let titleText = isPlaying ? "Stop" : "Play"
        
        playButton.setTitle(titleText, for: .normal)
    }

}
