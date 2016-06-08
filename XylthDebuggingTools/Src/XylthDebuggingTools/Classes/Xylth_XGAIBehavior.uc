class Xylth_XGAIBehavior extends XGAIBehavior;

// Force AI traversals to be saved.
function SaveBTTraversals()
{
	local int RootIndex;
	local array<BTDetailedInfo> arrStatusList;

	BT_GetNodeDetailList(arrStatusList);
	RootIndex = `BEHAVIORTREEMGR.GetNodeIndex(m_kBehaviorTree.m_strName);
	AddTraversalData(arrStatusList, RootIndex);
}
