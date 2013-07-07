#pragma semicolon 1

#include "W3SIncs/War3Source_Interface"
#include <tf2>
#include <jetpack>

public Plugin:myinfo =
{
	name = "War3Source Race - Medic",
	author = "Glider",
	description = "The Medic race for War3Source.",
	version = "1.0",
};

//=======================================================================
//                             VARIABLES
//=======================================================================

new thisRaceID;
new SKILL_ARMOR, SKILL_UBERCHARGER, SKILL_HEALING_WAVE, ULT_JETPACK;

new Float:fUberCharge[MAXPLAYERS];

// Damage resistance from Infantry Armor
new Float:fArmorResistance[5] = {1.0, 0.94, 0.91, 0.88, 0.85};

// Amount of ubercharge to add on Ubercharger
new Float:fUberAmount[5] = {0.0, 0.01, 0.02, 0.03, 0.04};

//Amount of % Healing Wave heals and how far it goes
new Float:HealingWaveAmount[5]= {0.0, 1.0, 2.0, 3.0, 4.0};
new Float:HealingWaveDistance[5]= {0.0, 400.0, 450.0, 500.0, 550.0};

#define HEALING_WAVE_TIMER 0.5

#define PARTICLE_HEAL_RED "healthgained_red"
#define PARTICLE_HEAL_BLU "healthgained_blu"

//How much Jetpack fuel you have and how fast it recharges
new fJetpackFuel[] = {0, 40, 60, 80, 100};
const Float:fJetpackRecharge = 25.0;

enum SELECTEDMEDIGUN {
	Uber, Kritz, Quickfix,
}
new SELECTEDMEDIGUN:g_SelectedMedigun[MAXPLAYERS];

//=======================================================================
//                                 INIT
//=======================================================================

public OnWar3PluginReady() {
	thisRaceID = War3_CreateNewRace("Medic", "medic");

	War3_AddRaceSkill(thisRaceID, "Raceinfo", "If you are not a Medic you still charge uber and you're able to uber yourself using the +ultimate key!\nPress +ability to cycle through your uber types!", false, 0);
	SKILL_ARMOR = War3_AddRaceSkill(thisRaceID, "Infantry Armor", "You take 6/9/12/15% less damage", false, 4);
	SKILL_UBERCHARGER = War3_AddRaceSkill(thisRaceID, "Ubercharger", "You charge 1/2/3/4% ubercharge each 4 seconds", false, 4);
	SKILL_HEALING_WAVE = War3_AddRaceSkill(thisRaceID, "Healing Wave", "You heal 1/2/3/4% HP of your teammates in range of 400/450/500/550 every half a second which fills your uber", false, 4);
	ULT_JETPACK = War3_AddRaceSkill(thisRaceID, "Jetpack", "Gives you a jetpack to fly around with. 40/60/80/100 fuel units that recharge each 25 seconds. Jump while in the air to activate", true, 4);
	War3_CreateRaceEnd(thisRaceID);
}

public OnPluginStart()
{
	if(War3_GetGame() != Game_TF)
	SetFailState("Only works in the TF2 engine! %i", War3_GetGame());

	CreateTimer(4.0, UberchargerTimer, _, TIMER_REPEAT);
	CreateTimer(HEALING_WAVE_TIMER, HealingWaveTimer, _, TIMER_REPEAT);
	CreateTimer(0.1, EffectTimer, _, TIMER_REPEAT);

	CreateTimer(1.0, NotifyTimer, _, TIMER_REPEAT);

	ControlJetpack();
}

public OnMapStart()
{
	War3_PrecacheParticle(PARTICLE_HEAL_RED);
	War3_PrecacheParticle(PARTICLE_HEAL_BLU);
}

//=======================================================================
//                                 Stocks
//=======================================================================

stock ControlJetpackSkill(client) {
	if (ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID) {
		new skill_pack = War3_GetSkillLevel(client, thisRaceID, ULT_JETPACK);
		if (skill_pack > 0) {
			GiveJetpack(client, fJetpackFuel[skill_pack], fJetpackRecharge);
		}
		else {
			TakeJetpack( client);
		}
	}
	else {
		TakeJetpack( client);
	}
}

stock Float:Medic_GetUberLevel(client)
{
	if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		new index = GetPlayerWeaponSlot(client, 1);
		if (index > 0)
		{
			return GetEntPropFloat(index, Prop_Send, "m_flChargeLevel");
		}
		else
		{
			return 0.0;
		}
	}
	else {
		return fUberCharge[client];
	}
}

stock Medic_SetUberLevel(client, Float:uberlevel)
{
	if (TF2_GetPlayerClass(client) == TFClass_Medic)
	{
		new index = GetPlayerWeaponSlot(client, 1);
		if (index > 0)
		{
			SetEntPropFloat(index, Prop_Send, "m_flChargeLevel", uberlevel);
		}
	}
	else {
		fUberCharge[client] = uberlevel;
	}
}

public Action:NotifyTimer(Handle:timer, any:userid)
{
	for(new client=1; client <= MaxClients; client++)
	{
		if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID))
		{
			if (TF2_GetPlayerClass(client) != TFClass_Medic) {
				new uber = RoundToFloor(fUberCharge[client] * 100);

				if(g_SelectedMedigun[client] == Uber)
				{
					W3Hint(client, HINT_SKILL_STATUS, 1.0, "%i percent Ubercharge (Uber)", uber);
				}
				else if(g_SelectedMedigun[client] == Kritz)
				{
					W3Hint(client, HINT_SKILL_STATUS, 1.0, "%i percent Ubercharge (Kritzkrieg)", uber);
				}
				else if(g_SelectedMedigun[client] == Quickfix)
				{
					W3Hint(client, HINT_SKILL_STATUS, 1.0, "%i percent Ubercharge (Quickfix)", uber);
				}
			}
		}
	}
}

//=======================================================================
//                          GENERIC EVENTS
//=======================================================================

public OnWar3EventSpawn(client)
{
	if (ValidPlayer(client, true)) {
		ControlJetpackSkill(client);
		fUberCharge[client] = 0.0;
		War3_SetBuff(client, fHPRegen, thisRaceID, 0.0);
	}
}

public OnRaceChanged(client, oldrace, newrace)
{
	ControlJetpackSkill(client);
}

//=======================================================================
//                                JETPACK
//=======================================================================

public OnSkillLevelChanged(client, race, skill, newskilllevel)
{
	if(race == thisRaceID)
	{
		if(skill == ULT_JETPACK)
		{
			ControlJetpackSkill(client);
		}
	}
}

// JETPACK!!
public OnUltimateCommand(client, race, bool:pressed)
{
	if(ValidPlayer(client, true) && race == thisRaceID && !Silenced(client))
	{
		if (TF2_GetPlayerClass(client) != TFClass_Medic) {
			if (fUberCharge[client] == 1.0) {
				if(g_SelectedMedigun[client] == Uber)
				{
					TF2_AddCondition(client, TFCond_Ubercharged, 5.0);
				}
				else if(g_SelectedMedigun[client] == Kritz)
				{
					TF2_AddCondition(client, TFCond_Kritzkrieged, 5.0);
				}
				else if(g_SelectedMedigun[client] == Quickfix)
				{
					TF2_AddCondition(client, TFCond_MegaHeal, 5.0);
					War3_SetBuff(client, fHPRegen, thisRaceID, 100.0);

					CreateTimer(5.0, StopRegenerating, client);
				}
				fUberCharge[client] = 0.0;
			}
			else {
				W3Hint(client, HINT_SKILL_STATUS, 1.0, "You don't have full uber!");
			}
		}
	}
}

public Action:StopRegenerating(Handle:timer, any:client)
{
	if (ValidPlayer(client))
	{
		War3_SetBuff(client, fHPRegen, thisRaceID, 0.0);
	}
}

public OnAbilityCommand(client, ability, bool:pressed)
{
	if(ValidPlayer(client, true) && War3_GetRace(client) == thisRaceID && pressed)
	{
		if(g_SelectedMedigun[client] == Uber)
		{
			g_SelectedMedigun[client] = Kritz;
		}
		else if(g_SelectedMedigun[client] == Kritz)
		{
			g_SelectedMedigun[client] = Quickfix;
		}
		else if(g_SelectedMedigun[client] == Quickfix)
		{
			g_SelectedMedigun[client] = Uber;
		}
	}
}

//=======================================================================
//                                 INFANTRY ARMOR
//=======================================================================

public OnW3TakeDmgAllPre(victim,attacker,Float:damage)
{
	if(ValidPlayer(victim, true) && (War3_GetRace(victim) == thisRaceID))
	{
		new skill = War3_GetSkillLevel(victim, thisRaceID, SKILL_ARMOR);
		War3_DamageModPercent(fArmorResistance[skill]);
	}
}

//=======================================================================
//                                 Ubercharger
//=======================================================================

public Action:UberchargerTimer(Handle:timer, any:userid)
{
	for(new client=1; client <= MaxClients; client++)
	{
		if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID))
		{
			new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_UBERCHARGER);
			if (skill > 0)
			{
				new team = GetClientTeam(client);
				if (team >= 2 && team <= 3)
				{
					new Float:UberCharge = Medic_GetUberLevel(client);
					if (UberCharge < 1.0)
					{
						UberCharge += fUberAmount[skill];
						if (UberCharge >= 1.0)
						{
							UberCharge = 1.0;
						}
						Medic_SetUberLevel(client, UberCharge);
					}
				}
			}
		}
	}
}

//=======================================================================
//                                 Healing Wave
//=======================================================================

public Action:EffectTimer(Handle:timer, any:userid)
{
	for(new client=1; client <= MaxClients; client++)
	{
		if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID))
		{
			new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_HEALING_WAVE);
			if(skill > 0)
			{
				//new HealerTeam = GetClientTeam(client);
				new Float:fHealingRingPos[3];

				//for (new i=0; i<4; i++) {
				GetClientAbsOrigin(client, fHealingRingPos);

				fHealingRingPos[2] += 10 * Sine(GetGameTime() * 1.5) + 45;

				fHealingRingPos[0] += 45 * Sine(GetGameTime() * 8);
				fHealingRingPos[1] += 45 * Cosine(GetGameTime() * 8);

				AttachThrowAwayParticle(client, GetRandomInt(0, 1) == 0 ? PARTICLE_HEAL_RED : PARTICLE_HEAL_BLU, fHealingRingPos, "", 0.5);
			}
		}
	}
}

public Action:HealingWaveTimer(Handle:timer, any:userid)
{
	for(new client=1; client <= MaxClients; client++)
	{
		if(ValidPlayer(client, true) && (War3_GetRace(client) == thisRaceID))
		{
			new skill = War3_GetSkillLevel(client, thisRaceID, SKILL_HEALING_WAVE);
			if(skill > 0)
			{
				new Float:fMaxDistance = HealingWaveDistance[skill];
				new HealerTeam = GetClientTeam(client);
				new Float:fHealerPos[3];
				new Float:fTeammatePos[3];
				new Float:fHealingRingPos[3];

				new AmountHealed;

				GetClientAbsOrigin(client, fHealerPos);
				GetClientAbsOrigin(client, fHealingRingPos);

				// Search for teammates around (Don't heal yourself with this)
				for(new i=1; i <= MaxClients; i++)
				{
					if(ValidPlayer(i, true) && GetClientTeam(i) == HealerTeam && (i != client))
					{
						GetClientAbsOrigin(i, fTeammatePos);
						if(GetVectorDistance(fHealerPos, fTeammatePos) <= fMaxDistance)
						{
							new VictimCurHP = GetClientHealth(i);
							new VictimMaxHP = War3_GetMaxHP(i);
							if(VictimCurHP < VictimMaxHP)
							{
								new VictimNewHP = RoundToCeil(VictimMaxHP / 100 * HealingWaveAmount[skill]);
								War3_HealToMaxHP(i, VictimNewHP);
								AmountHealed = GetClientHealth(i) - VictimCurHP;

								if (AmountHealed > 0) {
									fTeammatePos[2] += 70;
									AttachThrowAwayParticle(i, HealerTeam == TEAM_RED ? PARTICLE_HEAL_RED : PARTICLE_HEAL_BLU, fTeammatePos, "", 0.5);
								}
							}
						}
					}
				}

				new Float:uberlevel = Medic_GetUberLevel(client);

				// A Medigun heals 24 hp /s while in combat
				// When the target is at 142.5% health it charges at
				// 1.25% /s so that means 1 hp = 0,052083
				// Now just divide that by 100 and tada, our healing wave
				// does the same thing as a medigun on a overhealed fella
				new Float:amount = AmountHealed * 0.000520833333333333;
				if(amount > 0.0)
				{
					if((amount + uberlevel) > 1.0)
					{
						Medic_SetUberLevel(client, 1.0);
					}
					else
					{
						Medic_SetUberLevel(client, amount + uberlevel);
					}
				}
			}
		}
	}
}