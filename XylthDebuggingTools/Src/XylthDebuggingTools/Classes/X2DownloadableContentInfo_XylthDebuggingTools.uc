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
	local X2AbilityCost_ActionPoints ActionPointsCost;
	local X2AbilityCost_Ammo AmmoCost;
	local X2AbilityCost_Charges ChargesCost;
	local X2AbilityCost_ReserveActionPoints ReserveActionPointsCost;
	local name OtherName;

	Template = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate(DataName);

	`Log("===" @ Template @ "===");
	`Log("AbilityCharges:" @ Template.AbilityCharges);
	foreach Template.AbilityCosts(Cost)
	{
		`Log("AbilityCost:" @ Cost);
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

	`Log("AbilityCooldown:" @ Template.AbilityCooldown);
	`Log("AbilityToHitCalc:" @ Template.AbilityToHitCalc);
}