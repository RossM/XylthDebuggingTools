//-----------------------------------------------------------
// Used by the visualizer system to control a Visualization Actor
//-----------------------------------------------------------
class X2Action_Knockback extends X2Action;

var float OverrideRagdollFinishTimerSec;

var private Vector Destination;
var private XComGameState_Unit NewUnitState;
var private Vector PhysicsImpulse;
var private bool bReachedDestination;
var private RB_ConstraintActorSpawnable ConstraintActor;
var private Vector ImpulseDirection;
var private StateObjectReference DmgObjectRef;
var private CustomAnimParams AnimParams;
var private AnimNodeSequence KnockBackAnim;
var private Vector ShouldFaceVec;
var private bool bNeedsPhysicsFixup;
var private bool bDied;
var private float CloseEnoughDistance;
var private X2Action_Death DeathAction;
var private XComGameStateContext_Ability	AbilityContext;
var private X2AbilityTemplate               AbilityTemplate;
var private Actor							DamageDealer;
var			bool OnlyRecover;

function Init(const out VisualizationTrack InTrack)
{
	local XComGameStateHistory History;
	local XComWorldData WorldData;	
	local TTile UnitTileLocation;
	local float KnockbackDistance;
	local X2Action OutAction;

	super.Init(InTrack);

	History = `XCOMHISTORY;

	NewUnitState = XComGameState_Unit(InTrack.StateObject_NewState);

	WorldData = `XWORLD;
	NewUnitState.GetKeystoneVisibilityLocation(UnitTileLocation);
	bDied = !NewUnitState.IsAlive();
	Destination = WorldData.GetPositionFromTileCoordinates(UnitTileLocation);

	KnockbackDistance = VSize2D(Destination - UnitPawn.Location);
	bNeedsPhysicsFixup = VSize2D(Destination - UnitPawn.Location) > 192.0f || (Destination.Z - UnitPawn.Location.Z > 192.0f);
	PhysicsImpulse = Normal(Destination - UnitPawn.Location);
	PhysicsImpulse.Z = 0.0f;
	ShouldFaceVec = -PhysicsImpulse;

	PhysicsImpulse *= KnockbackDistance * 1.5f;
	PhysicsImpulse += Vect(0, 0, 1) * 400.0f;

	AbilityContext = XComGameStateContext_Ability(StateChangeContext);
	if (AbilityContext != none)
	{
		DamageDealer = History.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID).GetVisualizer();
		AbilityTemplate = class'XComGameState_Ability'.static.GetMyTemplateManager().FindAbilityTemplate(AbilityContext.InputContext.AbilityTemplateName);
		`assert(AbilityTemplate != none);
	}

	`XCOMVISUALIZATIONMGR.TrackHasActionOfType(Track, class'X2Action_Death', OutAction);
	if( OutAction != None )
	{
		DeathAction = X2Action_Death(OutAction);
		DeathAction.Init(InTrack); // This fixes all the none access errors when accessing any DeathAction functions.
	}
}

function bool CheckInterrupted()
{
	return false;
}

function ResumeFromInterrupt(int HistoryIndex)
{
	super.ResumeFromInterrupt(HistoryIndex);
}

function StartRagdoll()
{
	UnitPawn.StartRagDoll(false, , , false);
}

simulated state Executing
{
	simulated event BeginState(name PrevStateName)
	{
		super.BeginState(PrevStateName);

		//`SHAPEMGR.DrawSphere(Destination, vect(5, 5, 80), MakeLinearColor(1, 0, 0, 1), true);
	}

	simulated event EndState(name NextStateName)
	{
		super.EndState(NextStateName);
		if( ConstraintActor != None )
		{
			ConstraintActor.Destroy();
		}
	}

	function DelayedNotify()
	{
		VisualizationMgr.SendInterTrackMessage(DmgObjectRef);
	}

	function MaybeNotifyEnvironmentDamage()
	{
		local XComGameState_EnvironmentDamage EnvironmentDamage;		
		local TTile CurrentTile;

		CurrentTile = `XWORLD.GetTileCoordinatesFromPosition(Unit.Location);
		
		foreach StateChangeContext.AssociatedState.IterateByClassType(class'XComGameState_EnvironmentDamage', EnvironmentDamage)
		{
			if(EnvironmentDamage.HitLocationTile == CurrentTile)
			{			
				DmgObjectRef = EnvironmentDamage.GetReference();				
				SetTimer(0.3f, false, nameof(DelayedNotify)); //Add a small delay since the is tile based 
			}
		}
	}

	function CopyPose()
	{
		AnimParams.AnimName = 'Pose';
		AnimParams.Looping = true;
		AnimParams.BlendTime = 0.0f;
		AnimParams.HasPoseOverride = true;
		AnimParams.Pose = UnitPawn.Mesh.LocalAtoms;
		UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(AnimParams);
	}

Begin:	
	if( !OnlyRecover )
	{
		UnitPawn.SetRotation(rotator(ShouldFaceVec)); //Ensure the target is ready to animate for their attack

		//Have the character attempt to play an animation to 'seed' the rag doll. If that cannot be done, just go to rag doll immediately	
		UnitPawn.DyingImpulse = PhysicsImpulse; //Need to impart an initial velocity
		UnitPawn.SetFinalRagdoll(bDied);

		if( DeathAction != none )
		{
			Unit.SetForceVisibility(eForceVisible);

			AnimParams.AnimName = DeathAction.ComputeAnimationToPlay();

			if( bDied )
			{
				DeathAction.vHitDir = Normal(Destination - UnitPawn.Location); //For projectile-aligned death effects

				Unit.OnDeath(none, XGUnit(DamageDealer));

				if( OverrideRagdollFinishTimerSec >= 0 )
				{
					UnitPawn.RagdollFinishTimer = OverrideRagdollFinishTimerSec;
				}

				UnitPawn.PlayDying(none, UnitPawn.GetHeadshotLocation(), AnimParams.AnimName, Destination);
			}
			else
			{
				UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(AnimParams); //Playing this anim will trigger a ragdoll notify
				SetTimer(0.5f, false, nameof(StartRagdoll)); //Failsafe in case the anim doesn't have the right notify for some reason
			}
		}
		else
		{
			StartRagdoll();
		}
	}

	//When units are getting up from a fall or recovering from incapacitation, they use an X2Action_Knockback.
	if(!NewUnitState.IsDead() && !NewUnitState.IsIncapacitated())
	{		
		//Reset visualizers for primary weapon, in case it was dropped
		Unit.GetInventory().GetPrimaryWeapon().Destroy(); //Aggressively get rid of the primary weapon, because dropping it can really screw things up
		Unit.ApplyLoadoutFromGameState(NewUnitState, None);

		UnitPawn.GetAnimTreeController().SetAllowNewAnimations(true);

		// Copy all the bone transforms so we match his pose
		CopyPose();

		//Make a fancier transition out of ragdoll if needed 
		UnitPawn.EndRagDoll();

		UnitPawn.EnableRMA(true, true);
		UnitPawn.EnableRMAInteractPhysics(true);
		UnitPawn.EnableFootIK(false);

		AnimParams = default.AnimParams;
		AnimParams.AnimName = 'HL_GetUp';
		AnimParams.BlendTime = 0.5f;
		AnimParams.HasDesiredEndingAtom = true;
		AnimParams.DesiredEndingAtom.Translation = Destination;
		AnimParams.DesiredEndingAtom.Translation.Z = UnitPawn.GetGameUnit().GetDesiredZForLocation(AnimParams.DesiredEndingAtom.Translation);
		AnimParams.DesiredEndingAtom.Rotation = QuatFromRotator(UnitPawn.Rotation);
		AnimParams.DesiredEndingAtom.Scale = 1.0f;
		FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(AnimParams));

		UnitPawn.EnableFootIK(true);
		UnitPawn.EnableRMA(false, false);
		UnitPawn.EnableRMAInteractPhysics(false);

		Unit.IdleStateMachine.CheckForStanceUpdate();
	}

	CompleteAction();	
}

function CompleteAction()
{	
	super.CompleteAction();
}

DefaultProperties
{
	CloseEnoughDistance = 100.0f
	OverrideRagdollFinishTimerSec=-1;
}
