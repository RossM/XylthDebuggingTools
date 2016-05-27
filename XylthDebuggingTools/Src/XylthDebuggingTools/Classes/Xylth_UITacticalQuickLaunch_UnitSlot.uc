class Xylth_UITacticalQuickLaunch_UnitSlot extends UITacticalQuickLaunch_UnitSlot;

var array<ClassAgnosticAbility> m_AWCAbilities;

simulated function LoadTemplatesFromCharacter(XComGameState_Unit Unit, XComGameState FromGameState)
{
	super.LoadTemplatesFromCharacter(Unit, FromGameState);

	m_AWCAbilities = Unit.AWCAbilities;
}

simulated function UpdateUnit(XComGameState_Unit Unit, XComGameState UseGameState)
{
	super.UpdateUnit(Unit, UseGameState);

	if (Unit.IsSoldier())
	{
		Unit.AWCAbilities = m_AWCAbilities;
	}
}
