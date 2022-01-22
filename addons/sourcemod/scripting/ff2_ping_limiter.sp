#include <sourcemod>
#include <freak_fortress_2>
#include <clients>
#include <convars>
#include <lang>
#pragma semicolon 1
#pragma newdecls required

#define MAXTF2PLAYERS	36		// Maximum players + console + any in-game bots

int PingArray[MAXTF2PLAYERS+1]; // Stores queue points
bool DontAsk[MAXTF2PLAYERS+1]; //Selected menu option
float averageofaverage; //Stores average pint computations
int TimerArray[MAXTF2PLAYERS+1];

//Cvars. Handles in disguise. Basically global variables.
ConVar PingLimit;
ConVar CheckDelay;
ConVar NotifyChat;
ConVar ComputeDelay;
ConVar Mode;
ConVar Modifier;

public Plugin myinfo =
{
	name		=	"Freak Fortress 2: Ping Manager",
	description	=	"Prevent players from being bosses with excessive ping",
	author		=	"Nolo001",
	version		=	"1.2.0",
};

public void OnPluginStart()
{
	LogMessage("Freak Fortress : Ping Manager Initializing...");
	
	// ConVar stuff
	PingLimit=CreateConVar("ff2_pinglimit", "0", "0-Disable, Any number above 0 - Enable and use the value as ping limit. This is not used if Mode cvar is 1", _, true, 0.0);
	ComputeDelay=CreateConVar("ff2_pinglimit_compute", "5.0", "Any number above 0 - Use average ping computations instead of static limit every <value> seconds.", _);
	CheckDelay=CreateConVar("ff2_pingcheckdelay", "1.0", "Player latency will be checked every <this_value> seconds", _, true, 0.1);
	NotifyChat=CreateConVar("ff2_pinglimit_chat", "0.0", "0-Disable, 1-Show chat messages when somebody's points were cleared", _, true, 0.0, true, 1.0);
	Mode=CreateConVar("ff2_pinglimit_mode", "1.0", "0 - Static limit is used, 1 - compute average ping of all players", _);
	Modifier=CreateConVar("ff2_pinglimit_modifier", "1.0", "Any value above 0.1 with Mode cvar active - maximum latency is averagelatency+(averagelatency)*<this_value>", _, true, 0.1);
	
	//Autogenerating config
	AutoExecConfig(true, "FF2_Pinglimiter");

	// Translations
	LoadTranslations("ff2pinglimit.phrases");
	
	//Command that shows ping values
	RegConsoleCmd("maxping", Command_ShowMaxPing);
	//RegConsoleCmd("ping", Command_ShowMaxPing);
	//Needed to clear selection array cell
	HookEvent("player_disconnect", OnPlayerQuit);
}

public void OnMapStart() //Start the timers when map starts. A FORWARD.
{
	CreateTimer(CheckDelay.FloatValue, Timer_CheckPing, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(ComputeDelay.FloatValue, Timer_ComputeAveragePing, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
 	CreateTimer(1.0, Timer_1s, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	for(int i=1; i<=MaxClients; i++)//Set values of array to 0
	{
		DontAsk[i]=false;
		PingArray[i]=0;
		TimerArray[i]=0;
	}	
}

public Action Command_ShowMaxPing(int client, int args) //Command callback
{
	SetGlobalTransTarget(client); //Use proper language
	if(PingLimit || ComputeDelay) //If ping limiter is on
	{
		CPrintToChat(client, "%t", "Maxping Command", (Mode) ? ((RoundFloat(averageofaverage+(averageofaverage*Modifier.FloatValue))<PingLimit.FloatValue) ? PingLimit.FloatValue : RoundFloat(averageofaverage+(averageofaverage*Modifier.FloatValue))) : RoundFloat(PingLimit.FloatValue), RoundFloat(GetClientAvgLatency(client, NetFlow_Outgoing)*1000));
	}
	else
	{
		CPrintToChat(client, "Freak Fortress Ping Limiter is not active.");
	}
	return Plugin_Handled; //Dont send to engine
}
public Action Timer_ComputeAveragePing(Handle atimer) //Average ping computations
{
	if(FF2_IsFF2Enabled() && !Mode && FF2_GetRoundState() != 1)
		return Plugin_Continue;
		
	int clients;
	float tempaverage;
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client) || TimerArray[client]>0)
			continue;
	
		clients++;
		tempaverage+=GetClientAvgLatency(client, NetFlow_Outgoing)*1000;
	}
	averageofaverage=(averageofaverage>0.1) ? ((averageofaverage<PingLimit.FloatValue) ? PingLimit.FloatValue : ((averageofaverage+(tempaverage/clients))/2.0)) : tempaverage/clients; //Ternary operator right here
	FF2Dbg("Current average ping is %i", RoundFloat(averageofaverage)); //Will print in chat if ff2_debug cvar is 1
	return Plugin_Continue;
}	

public Action Timer_CheckPing(Handle timer) //Main logic
{
	if(!FF2_IsFF2Enabled() && !(PingLimit || ComputeDelay) && FF2_GetRoundState() != 1) //FF2 off, not ff2 round or plugin is off? Abort.
		return Plugin_Continue;

	for(int client=1; client<=MaxClients; client++)
	{
		if(IsValidClient(client) && !CheckCommandAccess(client, "ff2_bypass_pinglimit", ADMFLAG_CHEATS, true)) //If the client is valid and if the client doesnt have immunity
		{
			float maxping=(Mode) ? averageofaverage+(averageofaverage*Modifier.FloatValue) : PingLimit.FloatValue;
			float latency=GetClientAvgLatency(client, NetFlow_Outgoing)*1000;
			if(latency>maxping && FF2_GetQueuePoints(client)>0 && PingArray[client]==0) // If the client has bigger latency than allowed, if queue points are not 0 and if queue points are not yet stored
			{			
				char buffer[512];
				FF2Dbg("Client %N has %i points. Moving to DB and setting to 0.", client, FF2_GetQueuePoints(client));
				PingArray[client]=FF2_GetQueuePoints(client);
				TimerArray[client]=120;
				FF2_SetQueuePoints(client, 0);
				SetGlobalTransTarget(client);
				if(DontAsk[client]==false) //If client previously selected to show the menu every time
				{
					Menu menu = new Menu(CheckPing_Menu);
					menu.SetTitle("%t", "Boss Blocked Ping", client, RoundFloat(latency), RoundFloat(maxping));
					Format(buffer, sizeof(buffer), "%t", "Boss Blocked Ok Button");
					menu.AddItem(buffer, buffer);
					Format(buffer, sizeof(buffer), "%t", "Boss Blocked Ok Button Don't Show");
					menu.AddItem(buffer, buffer);
					menu.ExitButton = false;
					menu.Display(client, MENU_TIME_FOREVER);
				}
				if(NotifyChat)
					CPrintToChatAll("%t", "Boss Blocked Ping Message Chat", client);
			}
			if(PingArray[client] != 0 && latency<=maxping && TimerArray[client]==0) // If ping stabilized
			{
				FF2Dbg("Client %N had %i points in DB and their ping is now below the limit. Restoring.", client, FF2_GetQueuePoints(client));
				FF2_SetQueuePoints(client, PingArray[client]);
				PingArray[client]=0;
				CPrintToChat(client, "%t", "Ping Boss Unblocked");
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_1s(Handle timer)
{
	if(!FF2_IsFF2Enabled() && !(PingLimit || ComputeDelay) && FF2_GetRoundState() != 1) //FF2 off, not ff2 round or plugin is off? Abort.
		return Plugin_Continue;
		
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
			continue;
		
		if(TimerArray[client]>0)
			TimerArray[client]--;
	}
	return Plugin_Continue;
}

public Action OnPlayerQuit(Handle event, const char[] name, bool dontBroadcast) //Player disconnects - set their selection to 0 so new clients can use the cell. CALLBACK.
{
	int client=GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client))
		return Plugin_Continue;
		
	DontAsk[client]=false;	
	TimerArray[client]=0;
	return Plugin_Continue;
}

public Action FF2_OnAddQueuePoints(int add_points[MAXPLAYERS+1]) //If client has bad ping, do not give any points. FF2 FORWARD
{		
	for(int client=1; client<=MaxClients; client++)
	{
		if(!IsValidClient(client))
		continue;
		
		if(PingArray[client] != 0)
		{
			FF2Dbg("Client %N has bad ping. No points given.", client);
			add_points[client]=0;
		}
	}
	return Plugin_Changed;
}

public int CheckPing_Menu(Menu menu, MenuAction action, int param1, int param2) // Menu actions placeholder
{
	if (action==MenuAction_Select)
	{
		if(param2==1)
			DontAsk[param1]=true;
	}
}

public void OnMapEnd() //Map end restores all points.
{
    if(!(PingLimit || ComputeDelay))
        return;
		
    FF2Dbg("Map ending. Restoring all queue points.");  		
    for(int client=1; client<=MaxClients; client++)
    {
        if(!IsValidClient(client) || PingArray[client]==0)
            continue;
              
        FF2_SetQueuePoints(client, PingArray[client]);
        PingArray[client]=0;
    }
} 

public void OnClientDisconnect(int client) // Disconnect - give the client their points back and set array cell value to 0
{
	if(!FF2_IsFF2Enabled() && !(PingLimit || ComputeDelay))
		return;
	
	//DontAsk[client]=false;	
	if(PingArray[client] != 0)
	{
		FF2Dbg("Client %N left and had %i points in DB. Restoring.", client, PingArray[client]);	
		FF2_SetQueuePoints(client, PingArray[client]);
		PingArray[client]=0;
	}
}

stock bool IsValidClient(int client, bool replaycheck=true, bool onlyrealclients=true) //stock that checks if the client is valid(not bot, connected, in game, authorized etc)
{
	if(client<=0 || client>MaxClients)
	{
		return false;
	}

	if(!IsClientInGame(client))
	{
		return false;
	}

	if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
	{
		return false;
	}

	if(replaycheck)
	{
		if(IsClientSourceTV(client) || IsClientReplay(client))
		{
			return false;
		}
	}
	
	if(onlyrealclients)
	{
		if(IsFakeClient(client))
			return false;
	}
	
	return true;
}		
