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

import Cocoa

final class ColoredView: NSView {
    
    var backgroundColor: NSColor? {
        didSet {
            self.needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let backgroundColor = self.backgroundColor ?? NSColor.clear
        backgroundColor.setFill()
        NSRectFill(dirtyRect)
        //super.draw(dirtyRect)
    }
}
