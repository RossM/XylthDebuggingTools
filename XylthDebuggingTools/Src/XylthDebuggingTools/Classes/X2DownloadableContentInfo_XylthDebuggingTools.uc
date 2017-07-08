//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_XylthDebuggingTools.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_XylthDebuggingTools extends X2DownloadableContentInfo;

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the 
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{}

/// <summary>
/// Called when the player starts a new campaign while this DLC / Mod is installed
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{}

exec function AddAbility(name AbilityName, optional EInventorySlot Slot = eInvSlot_Unknown)
{
	local XComTacticalController TacticalController;
	local XComGameState NewGameState;
	local XComGameState_Unit NewUnit;
	local X2AbilityTemplate AbilityTemplate;
	local XComGameState_Ability NewAbility;
	local StateObjectReference AbilityRef, ActiveUnitRef, ItemRef;
	local name AdditionalAbility;
	local X2AbilityTemplateManager AbilityTemplateMan;
	local UIScreenStack ScreenStack;
	local UITacticalHUD TacticalHUD;
	local UIArmory Armory;
	local ClassAgnosticAbility AWCAbility;

	AbilityTemplateMan = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	ScreenStack = `SCREENSTACK;

	TacticalController = XComTacticalController(`BATTLE.GetALocalPlayerController());
	Armory = UIArmory(ScreenStack.GetFirstInstanceOf(class'UIArmory'));

	if (TacticalController != none)
	{	
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("XylthDebuggingTools - AddAbility");

		ActiveUnitRef = TacticalController.GetActiveUnitStateRef();
		NewUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', ActiveUnitRef.ObjectID));

		ItemRef = NewUnit.GetItemInSlot(Slot).GetReference();

		AbilityTemplate = AbilityTemplateMan.FindAbilityTemplate(AbilityName);
		AbilityRef = `TACTICALRULES.InitAbilityForUnit(AbilityTemplate, NewUnit, NewGameState, ItemRef);
		NewAbility = XComGameState_Ability(NewGameState.GetGameStateForObjectID(AbilityRef.ObjectID));
		NewAbility.CheckForPostBeginPlayActivation();

		// Add additional abilities
		foreach AbilityTemplate.AdditionalAbilities(AdditionalAbility)
		{
			AbilityTemplate = AbilityTemplateMan.FindAbilityTemplate(AdditionalAbility);

			AbilityRef = `TACTICALRULES.InitAbilityForUnit(AbilityTemplate, NewUnit, NewGameState, ItemRef);
			NewAbility = XComGameState_Ability(NewGameState.GetGameStateForObjectID(AbilityRef.ObjectID));
			NewAbility.CheckForPostBeginPlayActivation();
		}

		NewGameState.AddStateObject(NewUnit);
		`GAMERULES.SubmitGameState(NewGameState);

		// Update perk icons
		TacticalHUD = UITacticalHUD(ScreenStack.GetFirstInstanceOf(class'UITacticalHUD'));
		if (TacticalHUD != none)
			TacticalHUD.m_kPerks.UpdatePerks();
	}
	else if (Armory != none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("XylthDebuggingTools - AddAbility");

		ActiveUnitRef = Armory.GetUnitRef();		
		NewUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', ActiveUnitRef.ObjectID));

		AWCAbility.AbilityType.AbilityName = AbilityName;
		AWCAbility.AbilityType.ApplyToWeaponSlot = Slot;
		AWCAbility.bUnlocked = true;

		NewUnit.AWCAbilities.AddItem(AWCAbility);

		NewGameState.AddStateObject(NewUnit);
		`GAMERULES.SubmitGameState(NewGameState);

		Armory.PopulateData();
	}
}

exec function GrantKills(int NumKills)
{
	local UIScreenStack ScreenStack;
	local XComGameState NewGameState;
	local XComGameState_Unit NewUnit;
	local UIArmory Armory;
	local StateObjectReference ActiveUnitRef, EnemyRef;
	local int i;

	ScreenStack = `SCREENSTACK;
	Armory = UIArmory(ScreenStack.GetFirstInstanceOf(class'UIArmory'));

	if (Armory != none)
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("XylthDebuggingTools - GrantKills");

		ActiveUnitRef = Armory.GetUnitRef();		
		NewUnit = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', ActiveUnitRef.ObjectID));

		for (i = 0; i < NumKills; i++)
			NewUnit.SimGetKill(EnemyRef);

		NewUnit.bRankedUp = false;

		NewGameState.AddStateObject(NewUnit);
		`GAMERULES.SubmitGameState(NewGameState);

		Armory.PopulateData();
	}		
}

exec function BTState()
{
	local X2AIBTBehaviorTree BT;
	local int i;

	BT = `BEHAVIORTREEMGR;

	`Log("ActiveQueueID:" @ BT.ActiveQueueID);
	`Log("bBTQueueTimerActive:" @ BT.bBTQueueTimerActive);
	`Log("bWaitingOnSquadConcealment" @ BT.bWaitingOnSquadConcealment);
	`Log("bWaitingOnEndMoveEvent" @ BT.bWaitingOnEndMoveEvent);
	`Log("ActiveBTQueueEntry: (" $ BT.ActiveBTQueueEntry.ObjectID @ BT.ActiveBTQueueEntry.RunCount @ BT.ActiveBTQueueEntry.HistoryIndex @ BT.ActiveBTQueueEntry.Node $ ")");
	for (i = 0; i < BT.ActiveBTQueue.Length; i++)
		`Log("ActiveBTQueue["$i$"]: (" $ BT.ActiveBTQueue[i].ObjectID @ BT.ActiveBTQueue[i].RunCount @ BT.ActiveBTQueue[i].HistoryIndex @ BT.ActiveBTQueue[i].Node $ ")");
}

// TODO: Finish this
exec function DumpAbilityTemplate(name DataName)
{
	local X2AbilityTemplate Template;
	local X2AbilityCost Cost;
	local X2Condition Condition;
	local X2Effect Effect;
	local X2AbilityTrigger Trigger;
	local AbilityEventListener EventListener;

	Template = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(DataName);

	`Log("===" @ Template @ "===");
	`Log("AbilityCharges:" @ Template.AbilityCharges);
	foreach Template.AbilityCosts(Cost)
	{
		`Log("AbilityCosts:" @ Cost @ " (" $ Cost.class $ ")");
		DumpCost(Cost);
	}

	`Log("AbilityCooldown:" @ Template.AbilityCooldown);
	`Log("AbilityToHitCalc:" @ Template.AbilityToHitCalc);
	`Log("AbilityToHitOwnerOnMissCalc:" @ Template.AbilityToHitOwnerOnMissCalc);

	foreach Template.AbilityShooterConditions(Condition)
	{
		`Log("AbilityShooterConditions:" @ Condition @ " (" $ Condition.class $ ")");
		DumpCondition(Condition);
	}
	foreach Template.AbilityTargetConditions(Condition)
	{
		`Log("AbilityTargetConditions:" @ Condition @ " (" $ Condition.class $ ")");
		DumpCondition(Condition);
	}
	foreach Template.AbilityMultiTargetConditions(Condition)
	{
		`Log("AbilityMultiTargetConditions:" @ Condition @ " (" $ Condition.class $ ")");
		DumpCondition(Condition);
	}

	foreach Template.AbilityTargetEffects(Effect)
	{
		`Log("AbilityTargetEffects:" @ Effect @ " (" $ Effect.class $ ")");
		DumpEffect(Effect);
	}
	foreach Template.AbilityMultiTargetEffects(Effect)
	{
		`Log("AbilityMultiTargetEffects:" @ Effect @ " (" $ Effect.class $ ")");
		DumpEffect(Effect);
	}
	foreach Template.AbilityShooterEffects(Effect)
	{
		`Log("AbilityShooterEffects:" @ Effect @ " (" $ Effect.class $ ")");
		DumpEffect(Effect);
	}

	`Log("AbilityTargetStyle:" @ Template.AbilityTargetStyle);
	`Log("AbilityMultiTargetStyle:" @ Template.AbilityMultiTargetStyle);
	`Log("AbilityPassiveAOEStyle:" @ Template.AbilityPassiveAOEStyle);

	foreach Template.AbilityTriggers(Trigger)
	{
		`Log("AbilityTriggers:" @ Trigger @ " (" $ Trigger.class $ ")");
		DumpTrigger(Trigger);
	}
	
	foreach Template.AbilityEventListeners(EventListener)
	{
		`Log("AbilityEventListeners:");
		`Log("  EventID:" @ EventListener.EventID);
		`Log("  EventFn:" @ EventListener.EventFn);
		`Log("  Deferral:" @ EventListener.Deferral);
		`Log("  Filter:" @ EventListener.Filter);
	}
}

static function DumpCost(X2AbilityCost Cost)
{
	local X2AbilityCost_ActionPoints ActionPointsCost;
	local X2AbilityCost_Ammo AmmoCost;
	local X2AbilityCost_Charges ChargesCost;
	local X2AbilityCost_ReserveActionPoints ReserveActionPointsCost;
	local name OtherName;

	`Log("  bFreeCost:" @ Cost.bFreeCost);

	ActionPointsCost = X2AbilityCost_ActionPoints(Cost);
	if (ActionPointsCost != none)
	{
		`Log("  iNumPoints:" @ ActionPointsCost.iNumPoints);
		`Log("  bAddWeaponTypicalCost:" @ ActionPointsCost.bAddWeaponTypicalCost);
		`Log("  bConsumeAllPoints:" @ ActionPointsCost.bConsumeAllPoints);
		`Log("  bMoveCost:" @ ActionPointsCost.bMoveCost);
		foreach ActionPointsCost.AllowedTypes(OtherName)
			`Log("  AllowedType:" @ OtherName);
		foreach ActionPointsCost.DoNotConsumeAllEffects(OtherName)
			`Log("  DoNotConsumeAllEffect:" @ OtherName);
		foreach ActionPointsCost.DoNotConsumeAllSoldierAbilities(OtherName)
			`Log("  DoNotConsumeAllSoldierAbilitie:" @ OtherName);
	}

	AmmoCost = X2AbilityCost_Ammo(Cost);
	if (AmmoCost != none)
	{
		`Log("  iAmmo:" @ AmmoCost.iAmmo);
		`Log("  UseLoadedAmmo:" @ AmmoCost.UseLoadedAmmo);
		`Log("  bReturnChargesError:" @ AmmoCost.bReturnChargesError);
	}

	ChargesCost = X2AbilityCost_Charges(Cost);
	if (ChargesCost != none)
	{
		`Log("  NumCharges:" @ ChargesCost.NumCharges);
		foreach ChargesCost.SharedAbilityCharges(OtherName)
			`log("  SharedAbilityCharges:" @ OtherName);
		`Log("  bOnlyOnHit:" @ ChargesCost.bOnlyOnHit);
	}

	ReserveActionPointsCost = X2AbilityCost_ReserveActionPoints(Cost);
	if (ReserveActionPointsCost != none)
	{
		`Log("  iNumPoints:" @ ReserveActionPointsCost.iNumPoints);
		foreach ReserveActionPointsCost.AllowedTypes(OtherName)
			`Log("  AllowedType:" @ OtherName);
	}
}

static function DumpCondition(X2Condition Condition)
{
	local X2Condition_UnitEffects UnitEffectsCondition;
	local EffectReason Effect;

	UnitEffectsCondition = X2Condition_UnitEffects(Condition);
	if (UnitEffectsCondition != none)
	{
		foreach UnitEffectsCondition.ExcludeEffects(Effect)
		{
			`Log("  ExcludeEffects:" @ Effect.EffectName $ "," @ Effect.Reason);
		}
		foreach UnitEffectsCondition.RequireEffects(Effect)
		{
			`Log("  RequireEffects:" @ Effect.EffectName $ "," @ Effect.Reason);
		}
	}
}

static function DumpEffect(X2Effect Effect)
{
}

static function DumpTrigger(X2AbilityTrigger Trigger)
{
	local X2AbilityTrigger_Event EventTrigger;
	local X2AbilityTrigger_EventListener EventListenerTrigger;

	EventTrigger = X2AbilityTrigger_Event(Trigger);
	if (EventTrigger != none)
	{
		`Log("  EventObserverClass:" @ EventTrigger.EventObserverClass);
		`Log("  MethodName:" @ EventTrigger.MethodName);
	}

	EventListenerTrigger = X2AbilityTrigger_EventListener(Trigger);
	if (EventListenerTrigger != none)
	{
		`Log("  EventID:" @ EventListenerTrigger.ListenerData.EventID);
		`Log("  EventFn:" @ EventListenerTrigger.ListenerData.EventFn);
		`Log("  Deferral:" @ EventListenerTrigger.ListenerData.Deferral);
		`Log("  Filter:" @ EventListenerTrigger.ListenerData.Filter);
		`Log("  OverrideListenerSource:" @ EventListenerTrigger.ListenerData.OverrideListenerSource);
		`Log("  Priority:" @ EventListenerTrigger.ListenerData.Priority);	
	}
}

exec function Respec()
{
	local UIArmory Armory;
	local StateObjectReference UnitRef;
	local XComGameState_Unit UnitState;
	local XComGameState NewGameState;
	local int i;
	local XComGameStateHistory History;

	History = `XCOMHISTORY;

	Armory = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));
	if (Armory == none)
		return;

	UnitRef = Armory.GetUnitRef();

	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
	if (UnitState == none)
		return;
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Respec Soldier");

	// Set the soldier status back to active, and rank them up to their new class
	UnitState = XComGameState_Unit(NewGameState.CreateStateObject(class'XComGameState_Unit', UnitState.ObjectID));
	UnitState.ResetSoldierAbilities(); // First clear all of the current abilities
	for (i = 0; i < UnitState.GetSoldierClassTemplate().GetAbilityTree(0).Length; ++i) // Then give them their squaddie ability back
	{
		UnitState.BuySoldierProgressionAbility(NewGameState, 0, i);
	}
	NewGameState.AddStateObject(UnitState);

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`XCOMGAME.GameRuleset.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}

	Armory.PopulateData();
}

exec function DumpXPInfo()
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local XComGameState_HeadquartersXCom XComHQ;
	local array<XComGameState_Unit> Soldiers;
	local UnitValue MissionExperienceValue, OfficerBonusKillsValue;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class' XComGameState_HeadquartersXCom'));
	Soldiers = XComHQ.GetSoldiers();

	foreach Soldiers(UnitState)
	{
		UnitState.GetUnitValue('MissionExperience', MissionExperienceValue);
		UnitState.GetUnitValue('OfficerBonusKills', OfficerBonusKillsValue);
		
		`Log("CSV," $
			UnitState.GetName(eNameType_FullNick) $ "," $ 
			UnitState.GetSoldierClassTemplateName() $ "," $ 
			UnitState.GetNumMissions() $ "," $ 
			UnitState.GetNumKills() $ "," $
			UnitState.GetKillAssists().Length $ "," $ 
			MissionExperienceValue.fValue $ "," $
			OfficerBonusKillsValue.fValue);
	}
}

exec function CompleteActions(optional name ClassName)
{
	local X2Action Action;
	foreach `XComGRI.AllActors(class'X2Action', Action)
	{
		if (ClassName != '' && !Action.IsA(ClassName))
			continue;

		Action.CompleteAction();
	}
}

exec function RemoveDeadUnits()
{
	local XComGameStateHistory History;
	local XComGameState_Unit UnitState;
	local XComGameState NewGameState;

	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("RemoveDeadUnits");

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		if (!UnitState.IsInPlay())
			NewGameState.RemoveStateObject(UnitState.ObjectID);
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
		`GAMERULES.SubmitGameState(NewGameState);
	else
		History.CleanupPendingGameState(NewGameState);
}

static function ReceivedStatsKVP( bool Success, array<string> GlobalKeys, array<int> GlobalValues, array<string> UserKeys, array<int> UserValues )
{
	local string resultStr;
	local int i;

	//if (GlobalKeys.Length > 0)
		//resultStr $= "\n[global]\n";
	for (i = 0; i < GlobalKeys.Length; i++)
	{
		//resultStr $= GlobalKeys[i] @ "=" @ GlobalValues[i] $ "\n";
		`Log(GlobalKeys[i] @ "=" @ GlobalValues[i]);
	}

	//if (UserKeys.Length > 0)
		//resultStr $= "\n[user]\n";
	for (i = 0; i < UserKeys.Length; i++)
	{
		// resultStr $= UserKeys[i] @ "=" @ UserValues[i] $ "\n";
	}
	
	//`log(resultStr);
}

exec function DumpAnalyticsValues()
{
	local XComGameState_Analytics Analytics;

	Analytics = XComGameState_Analytics(`XCOMHISTORY.GetSingleGameStateObjectForClass( class'XComGameState_Analytics' ));

	Analytics.DumpValues();
}

exec function DumpGlobalValues()
{
	local AnalyticsManager AnalyticsManager;
	local X2FiraxisLiveClient LiveClient;

	AnalyticsManager = `XANALYTICS;
	LiveClient = `FXSLIVE;

	if (AnalyticsManager.WaitingOnWorldStats())
	{
		`Log("Still waiting on AnalyticsManager, please wait...");
		return;
	}

	LiveClient.AddReceivedStatsKVPDelegate( ReceivedStatsKVP );

	AnalyticsManager.DebugDoEndgameStats(false);
}