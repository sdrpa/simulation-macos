/**
 Created by Sinisa Drpa on 2/6/17.

 Simulation is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License or any later version.

 Simulation is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Simulation.  If not, see <http://www.gnu.org/licenses/>
 */

import AirspaceKit
import ATCKit
import ATCSIM
import Cocoa
import FDPS
import FoundationKit

final class MainWindowController: NSWindowController {

    @IBOutlet weak var playButton: NSButton!
    @IBOutlet weak var resetButton: NSButton!
    @IBOutlet weak var speedTextField: NSTextField!
    @IBOutlet weak var speedStepper: NSStepper!
    @IBOutlet weak var slider: NSSlider!
    @IBOutlet weak var sliderStartTimeTextField: NSTextField!
    @IBOutlet weak var sliderEndTimeTextField: NSTextField!
    @IBOutlet weak var timeTextField: NSTextField!
    @IBOutlet weak var playStatusView: ColoredView!

    dynamic var airspaceName: String?
    dynamic var airspaceDescription: String?
    dynamic var scenarioName: String?
    dynamic var scenarioDescription: String?
    dynamic var speed: Int = 1 {
        didSet {
            self.simulation?.speed = self.speed
        }
    }

    var server: FDPServer?
    // We cache the last message to broadcast it when a new client connects.
    var lastMessage: Messageable?

    override init(window: NSWindow?) {
        super.init(window: window)

        self.server = FDPServer(port: 1337)
        self.server?.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var minimumSpeed: Int {
        return Simulation.minimumSpeed
    }
    var maximumSpeed: Int {
        return Simulation.maximumSpeed
    }

    var airspace: Airspace? {
        didSet {
            self.airspaceName = self.airspace?.title
            self.airspaceDescription = self.airspace?.description
        }
    }
    var simulation: Simulation? {
        didSet {
            self.scenarioName = self.simulation?.scenario.title
            self.scenarioDescription = self.simulation?.scenario.description

            // Set slider range
            //self.slider.maxValue = 60.0 * 30.0 // 30 min
            let end = String(timeInterval: slider.maxValue) ?? "00:00:00"
            self.sliderEndTimeTextField.stringValue = end

            self.enableUIIfNecessary()

            self.simulation?.speed = self.speed
            self.simulation?.runningUpdate = { [weak self] isRunning in
                self?.playButton.title = isRunning ? "Pause" : "Play"
                self?.playStatusView.backgroundColor = isRunning ? .green : .red
            }
            self.simulation?.simulationUpdate = { [weak self] result in
                let current = String(timeInterval: result.timestamp) ?? "00:00:00"
                self?.timeTextField.stringValue = current
                self?.slider.floatValue = Float(result.timestamp)

                typealias FlightsUpdate = FDPS.Message.FlightsUpdate
                let message = FlightsUpdate(timestamp: result.timestamp,
                                            flights: result.flights)
                self?.server?.broadcast(flightsUpdate: message)

                self?.lastMessage = message
            }
            self.simulation?.timestamp = 0
        }
    }

    override func windowDidLoad() {
        self.speed = 1
        self.playStatusView.backgroundColor = .red
        self.enableUIIfNecessary()

        self.airspace = self.defaultAirspace
        self.simulation = self.defaultSimulation
    }

    @IBAction func selectAirspace(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.message = "Select an airspace directory"
        openPanel.canCreateDirectories = false
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.prompt = "Select"
        openPanel.begin { (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                guard let url = openPanel.url else { return }
                self.airspace = Airspace(directoryURL: url)
            }
        }
    }

    @IBAction func selectScenario(_ sender: NSButton) {
        let openPanel = NSOpenPanel()
        openPanel.message = "Select a scenario"
        openPanel.canCreateDirectories = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        openPanel.prompt = "Select"
        openPanel.begin { (result) -> Void in
            if result == NSFileHandlingPanelOKButton {
                guard let url = openPanel.url else { return }
                self.simulation = self.createSimulation(scenario: url)
            }
        }
    }

    @IBAction func toggleRunning(_ sender: NSButton) {
        self.simulation?.toggle()
    }

    @IBAction func reset(_ sender: NSButton) {
        self.simulation?.reset()
    }

    @IBAction func scrub(_ sender: NSSlider) {
        print("Scrub to: \(TimeInterval(ceil(sender.floatValue)))")
        self.simulation?.timestamp = TimeInterval(ceil(sender.floatValue))
    }

    override func setNilValueForKey(_ key: String) {
        if key == #keyPath(MainWindowController.speed) {
            self.speed = 1
            return
        }
        super.setNilValueForKey(key)
    }

    // MARK:

    fileprivate func enableUIIfNecessary() {
        let isSimulationReady = (self.simulation != nil)
        self.playButton.isEnabled = isSimulationReady
        self.resetButton.isEnabled = isSimulationReady
        self.speedTextField.isEnabled = isSimulationReady
        self.speedStepper.isEnabled = isSimulationReady
        self.slider.isEnabled = isSimulationReady
        self.sliderStartTimeTextField.isEnabled = false //isSimulationReady
        self.sliderEndTimeTextField.isEnabled = false //isSimulationReady
        self.timeTextField.isEnabled = isSimulationReady
    }

    // MARK:

    static var dataURL: URL {
        let fileURL = URL(fileURLWithPath: (#file)).deletingLastPathComponent()
        let url = fileURL.appendingPathComponent("../../../../Data")
        return url
    }

    lazy var defaultAirspace: Airspace? = {
        let airspaceURL = dataURL.appendingPathComponent("Airspace/Demo")
        return Airspace(directoryURL: airspaceURL)
    }()

    lazy var defaultSimulation: Simulation? = {
        let fileURL = dataURL.appendingPathComponent("Scenario/Two.txt")
        return self.createSimulation(scenario: fileURL)
    }()

    fileprivate func createSimulation(scenario fileURL: URL) -> Simulation? {
        let aircraftURL = MainWindowController.dataURL.appendingPathComponent("Aircraft")
        guard let airspace = self.airspace else {
            return nil
        }
        guard let scenario = Scenario(fileURL: fileURL, airspace: airspace, aircraftURL: aircraftURL) else {
            return nil
        }
        return Simulation(scenario: scenario)
    }
}

extension MainWindowController: FDPServerDelegate {

    func serverDidAcceptConnection(_ server: FDPServer) {
        if let lastMessage = self.lastMessage as? Message.FlightsUpdate {
            self.server?.broadcast(flightsUpdate: lastMessage)
        }
    }
}

extension MainWindowController {

    override var windowNibName: String? {
        return "\(MainWindowController.self)"
    }
}
