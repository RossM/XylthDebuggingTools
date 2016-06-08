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