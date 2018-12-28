package arm;

import iron.math.Vec4;
import iron.object.Object;
import iron.object.BoneAnimation;
import iron.system.Time;
import iron.system.Audio;
import iron.system.Input;
import armory.trait.physics.RigidBody;

class PlayerController extends iron.Trait {

#if (!arm_physics)
	public function new() { super(); }
#else

	var mouse:Mouse = null;
	var keyboard:Keyboard = null;
	var gamepad:Gamepad = null;

	var body:RigidBody;
	var anim:BoneAnimation;
	var armature:Object;

	var stepTime = 0.0;
	var dir = new Vec4();
	var lastDir = new Vec4();
	var lastLook:Vec4;
	var state = "idle";

	var soundStep0:kha.Sound = null;
	var soundStep1:kha.Sound = null;
	var soundSword0:kha.Sound = null;
	var soundSword1:kha.Sound = null;

	public function new() {
		super();
		notifyOnInit(init);
		notifyOnUpdate(update);
	}

	function init() {
		// Get input devices
		mouse = Input.getMouse();
		keyboard = Input.getKeyboard();
		gamepad = Input.getGamepad(0);

		// Store references
		body = object.getTrait(RigidBody);
		armature = object.getChild("Armature");
		anim = cast armature.children[0].animation;

		// Load sounds
		iron.data.Data.getSound("step0.wav", function(sound:kha.Sound) { soundStep0 = sound; });
		iron.data.Data.getSound("step1.wav", function(sound:kha.Sound) { soundStep1 = sound; });
		iron.data.Data.getSound("sword0.wav", function(sound:kha.Sound) { soundSword0 = sound; });
		iron.data.Data.getSound("sword1.wav", function(sound:kha.Sound) { soundSword1 = sound; });
	}

	function update() {
		// Movement
		dir.set(0, 0, 0);
		if (keyboard.down("w")) dir.y = 1.0;
		if (keyboard.down("s")) dir.y = -1.0;
		if (keyboard.down("a")) dir.x = -1.0;
		if (keyboard.down("d")) dir.x = 1.0;
		if (gamepad != null && Math.abs(gamepad.leftStick.x) > 0.1) dir.x = gamepad.leftStick.x;
		if (gamepad != null && Math.abs(gamepad.leftStick.y) > 0.1) dir.y = gamepad.leftStick.y;
		dir.normalize();

		// Rotate
		var q = new iron.math.Quat();
		q.fromTo(Vec4.yAxis(), new Vec4(lastDir.x, lastDir.y, 0.0));
		armature.transform.rot.lerp(armature.transform.rot, q, 0.25);
		armature.transform.buildMatrix();

		updateAnim();
		updateBody();

		if (dir.length() > 0) lastDir.setFrom(dir);
	}

	function updateAnim() {
		var look = armature.transform.look().normalize();

		// Move
		if (dir.length() > 0) {
			setState("run", 1.0);

			// Step sounds
			stepTime += Time.delta;
			if (stepTime > 0.3) {
				stepTime = 0;
				Audio.play(Std.random(2) == 0 ? soundStep0 : soundStep1);
			}
		}
		// Slash
		else if (state == "idle") {
			if (mouse.down("left") || (gamepad != null && gamepad.down("r2") > 0.0)) {
				var r = Std.random(2);
				setState(r == 0 ? "slash" : "slash2", 1.5, 0.0, function() { setState("idle", 1.0, 0.0); });
				iron.system.Tween.timer(0.3, function() {
					Audio.play(r == 0 ? soundSword0 : soundSword1);
				});
			}
		} 
		// Idle
		else if (state != "slash" && state != "slash2") {
			setState("idle", 1.0);
		}
	}

	function updateBody() {
		if (!body.ready) return;
		
		body.syncTransform();
		body.activate();
		var linvel = body.getLinearVelocity();
		body.setLinearVelocity(dir.x * 6, dir.y * 6, linvel.z - 1.0); // Push down
		body.setAngularFactor(0, 0, 0); // Keep vertical
	}

	function setState(s:String, speed:Float, blend = 0.2, onComplete:Void->Void = null) {
		if (s == state) return;
		state = s;
		anim.play(s, onComplete, blend, speed);
	}
#end
}
