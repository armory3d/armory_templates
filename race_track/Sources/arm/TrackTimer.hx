package arm;

import iron.Scene;
import iron.object.Transform;

class TrackTimer extends iron.Trait {

	var time = 0.0;
	var running = false;
	var finished = false;
	var triggers:Array<Transform> = [];

	public function new() {
		super();

		notifyOnInit(function() {
			var canvas = Scene.active.getTrait(armory.trait.internal.CanvasScript);
			var t = object.transform;

			// Retrieve triggers
			var t0 = Scene.active.getChild("Trigger0").transform; // Start line
			var t1 = Scene.active.getChild("Trigger1").transform;
			var t2 = Scene.active.getChild("Trigger2").transform;
			var t3 = Scene.active.getChild("Trigger3").transform;

			notifyOnUpdate(function() {

				if (!running && !finished) {
					// Start line crossed, begin lap
					running = t.overlap(t0);
				}
				else {
					// Update timer
					if (!finished) {
						time += iron.system.Time.delta;
						var s = Std.int(time);
						var ms = Std.int((time - s) * 100);
						canvas.getElement("Time").text = s + "." + ms;
					}

					// Mark touched triggers
					if (t.overlap(t1) && triggers.indexOf(t1) == -1) triggers.push(t1);
					if (t.overlap(t2) && triggers.indexOf(t2) == -1) triggers.push(t2);
					if (t.overlap(t3) && triggers.indexOf(t3) == -1) triggers.push(t3);

					// Crossed finish line
					if (t.overlap(t0) && triggers.length == 3) {
						finished = true;
					}
				}
			});
		});
	}
}
