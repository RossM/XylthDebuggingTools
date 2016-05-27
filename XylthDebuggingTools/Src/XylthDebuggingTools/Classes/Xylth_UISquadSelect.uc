class Xylth_UISquadSelect extends UISquadSelect;

simulated function UpdateNavHelp()
{
	local XComHeadquartersCheatManager CheatMgr;

	LaunchButton.SetDisabled(!CanLaunchMission());

	if( `HQPRES != none )
	{
		CheatMgr = XComHeadquartersCheatManager(GetALocalPlayerController().CheatManager);
		`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();
	
		if( !bNoCancel )
			`HQPRES.m_kAvengerHUD.NavHelp.AddBackButton(CloseScreen);

		if(CheatMgr == none || !CheatMgr.bGamesComDemo)
		{
			`HQPRES.m_kAvengerHUD.NavHelp.AddCenterHelp(m_strStripItems, "", OnStripItems, false, m_strTooltipStripItems);
			`HQPRES.m_kAvengerHUD.NavHelp.AddCenterHelp(m_strStripGear, "", OnStripGear, false, m_strTooltipStripGear);
			`HQPRES.m_kAvengerHUD.NavHelp.AddCenterHelp(m_strStripWeapons, "", OnStripWeapons, false, m_strTooltipStripWeapons);
		}

		if (class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M5_WelcomeToEngineering'))
		{
			`HQPRES.m_kAvengerHUD.NavHelp.AddCenterHelp(m_strBuildItems, "", OnBuildItems, false, m_strTooltipBuildItems);
		}

		// Re-enabling this option for Steam builds to assist QA testing, TODO: disable this option before release
		if(CheatMgr == none || !CheatMgr.bGamesComDemo)
		{
			`HQPRES.m_kAvengerHUD.NavHelp.AddCenterHelp("SIM COMBAT", "", OnSimCombat, !CanLaunchMission(), GetTooltipText());
		}	
	}
}
