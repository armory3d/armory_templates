// Warning: not final code yet, to be cleaned up!
package arm;

import iron.math.Vec4;
import iron.math.Quat;
import iron.math.Mat4;
import iron.system.Input;
import iron.object.Object;
import iron.object.BoneAnimation;
import iron.system.Time;
import iron.system.Audio;
import armory.trait.physics.PhysicsWorld;
import armory.trait.internal.CameraController;

class FirstPersonController extends CameraController {

#if (!arm_physics)
	public function new() { super(); }
#else

	static inline var rotationSpeed = 1.0;
	
	var stepTime = 0.0;
	var soundStep0:kha.Sound = null;
	var soundStep1:kha.Sound = null;

	var xVec = Vec4.xAxis();
	var zVec = Vec4.zAxis();
	var angle = 0.0;
	var nextFrameRot = 0.0;
	var anim:BoneAnimation;
	var q = new Quat();
	var mat = Mat4.identity();

	var nextIdle = false;
	var firingTime = 0.0;
	var speed = 1.0;
	var dir = new Vec4();
	var state = "idle";

	public function new() {
		super();
		notifyOnInit(function() {
			PhysicsWorld.active.notifyOnPreUpdate(preUpdate);
			notifyOnUpdate(update);
			
			notifyOnRemove(function() {
				PhysicsWorld.active.removePreUpdate(preUpdate);
			});

			iron.data.Data.getSound("step0.wav", function(sound:kha.Sound) {
				soundStep0 = sound;
			});

			iron.data.Data.getSound("step1.wav", function(sound:kha.Sound) {
				soundStep1 = sound;
			});

			anim = findAnimation(object.getChild("Armature"));
			anim.notifyOnUpdate(updateBones);
		});
	}

	function findAnimation(o:Object):BoneAnimation {
		if (o.animation != null) return cast o.animation;
		for (c in o.children) {
			var co = findAnimation(c);
			if (co != null) return co;
		}
		return null;
	}

	function updateBones() {

		// Fetch bone
		var bone1 = anim.getBone("mixamorig:LeftForeArm");
		var bone2 = anim.getBone("mixamorig:RightForeArm");

		// Fetch bone matrix - this is in local bone space for now
		var m1 = anim.getBoneMat(bone1);
		var m2 = anim.getBoneMat(bone2);
		var m1b = anim.getBoneMatBlend(bone1);
		var m2b = anim.getBoneMatBlend(bone2);
		var a1 = anim.getAbsMat(bone1.parent);
		var a2 = anim.getAbsMat(bone2.parent);

		// Rotate hand bones to aim with gun
		// Some raw math follows..
		var tx = m1._30;
		var ty = m1._31;
		var tz = m1._32;
		m1._30 = 0;
		m1._31 = 0;
		m1._32 = 0;
		mat.getInverse(a1);
		q.fromAxisAngle(mat.right(), angle);
		m1.applyQuat(q);
		m1._30 = tx;
		m1._31 = ty;
		m1._32 = tz;
		
		var tx = m2._30;
		var ty = m2._31;
		var tz = m2._32;
		m2._30 = 0;
		m2._31 = 0;
		m2._32 = 0;
		mat.getInverse(a2);
		var v = mat.right();
		v.mult(-1);
		q.fromAxisAngle(v, -angle);
		m2.applyQuat(q);
		m2._30 = tx;
		m2._31 = ty;
		m2._32 = tz;

		// Animation blending is in progress, we need to rotate those bones too
		if (m1b != null && m2b != null) {
			var tx = m1b._30;
			var ty = m1b._31;
			var tz = m1b._32;
			m1b._30 = 0;
			m1b._31 = 0;
			m1b._32 = 0;
			mat.getInverse(a1);
			q.fromAxisAngle(mat.right(), angle);
			m1b.applyQuat(q);
			m1b._30 = tx;
			m1b._31 = ty;
			m1b._32 = tz;
			
			var tx = m2b._30;
			var ty = m2b._31;
			var tz = m2b._32;
			m2b._30 = 0;
			m2b._31 = 0;
			m2b._32 = 0;
			mat.getInverse(a2);
			var v = mat.right();
			v.mult(-1);
			q.fromAxisAngle(v, -angle);
			m2b.applyQuat(q);
			m2b._30 = tx;
			m2b._31 = ty;
			m2b._32 = tz;
		}
	}

	function preUpdate() {
		if (Input.occupied || !body.ready) return;
		
		var mouse = Input.getMouse();
		var kb = Input.getKeyboard();
		
		if (mouse.started() && !mouse.locked) mouse.lock();
		else if (kb.started("escape") && mouse.locked) mouse.unlock();
		
		if (nextFrameRot != 0.0) {
			var origin = object.getChild("CameraOrigin");
			origin.transform.rotate(xVec, nextFrameRot);
			origin.transform.buildMatrix();
		}
		nextFrameRot = 0;

		if (mouse.moved) {
			var d = mouse.movementY / 250;
			if (angle + d > 1.5) return;
			if (angle + d < -0.25) return;
			angle += d;
			nextFrameRot = -mouse.movementY / 250 * rotationSpeed;
		}

		if (mouse.moved) transform.rotate(zVec, -mouse.movementX / 250 * rotationSpeed);
		body.syncTransform();
	}

	function update() {
		if (!body.ready) return;

		// Move
		dir.set(0, 0, 0);
		if (moveForward) dir.add(transform.look());
		if (moveBackward) dir.add(transform.look().mult(-1));
		if (moveLeft) dir.add(transform.right().mult(-1));
		if (moveRight) dir.add(transform.right());

		// Push down
		var btvec = body.getLinearVelocity();
		body.setLinearVelocity(0.0, 0.0, btvec.z - 1.0);

		if (moveForward || moveBackward || moveLeft || moveRight) {
			if (state != "run") {
				state = "run";
				anim.play(state, null, 0.2);
			}

			var kb = iron.system.Input.getKeyboard();
			if (kb.down("shift")) speed = 1.6;
			else speed = 1.0;

			dir.mult(speed * 5);
			body.activate();
			body.setLinearVelocity(dir.x, dir.y, btvec.z - 1.0);

			stepTime += Time.delta;
			if (stepTime > 0.3 / speed) {
				stepTime = 0;
				Audio.play(Std.random(2) == 0 ? soundStep0 : soundStep1);
			}
		}
		// Play correct state
		else if (state != "fire" || state != "idle") {
			var mouse = iron.system.Input.getMouse();
			if (mouse.down("left")) {
				firingTime = 0.0;
				if (state != "fire") {
					state = "fire";
					anim.play(state, null, 0.2, 2.0);
				}
			}
			else {
				if (state != "idle" && state == "run") {
					state = "idle";
					anim.play(state, null, 0.2, 2.0);
				}

				if (state != "idle" && state == "fire" && firingTime > 0.1) {
					state = "idle";
					anim.play(state, null, 0.2, 2.0);
				}
			}
		}

		if (state == "fire") firingTime += Time.delta;
		else firingTime = 0.0;

		// Keep vertical
		body.setAngularFactor(0, 0, 0);
		camera.buildMatrix();
	}
#end
}
