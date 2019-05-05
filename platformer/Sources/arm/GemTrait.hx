package arm;

class GemTrait extends iron.Trait {

	static var gemsCollected = 0;
	static var player:iron.object.Object = null;
	static var coinSound:kha.Sound = null;

	public function new() {
		super();

		if (coinSound == null) {
			notifyOnInit(function() {
				iron.data.Data.getSound("coin.wav", function(sound:kha.Sound) {
					coinSound = sound;
				});
			});
		}

		notifyOnUpdate(function() {
			object.transform.rotate(iron.math.Vec4.zAxis(), 0.05);

			if (player == null) player = iron.Scene.active.getChild("Player");
			var w1 = object.transform.world;
			var w2 = player.transform.world;
			var d = iron.math.Vec4.distance(w1.getLoc(), w2.getLoc());

			// Collect gem
			if (d < 0.8) {
				gemsCollected++;
				object.remove();

				// Update UI
				var canvas = iron.Scene.active.getTrait(armory.trait.internal.CanvasScript);
				canvas.getElement("Gems").text = gemsCollected + "";

				if (coinSound != null) iron.system.Audio.play(coinSound);
			}
		});
	}
}
