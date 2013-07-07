/**
 * File: War3Source_Race_Engineer.inc
 * Description: Functions for the Engineer
 * Author(s): Glider  
 * 
 */

enum SentryAmmo {
	Regular,
	Incendiary,
	Explosive,
}

enum SentryState {
	State_None,
	State_Scan,
	State_Sleep,
}

native War3_Engineer_SpawnSentry(client, damage, Float:firingInterval, 
								 SentryAmmo:ammotype, MaxAmmo, Float:ScanRange,
								 Float:SentryAccuracy, SentryShots);

native War3_Engineer_DestroySentry(client);

native bool:War3_Engineer_HasSentry(client);
native bool:War3_Engineer_IsSentry(entity);
native War3_Engineer_RefillSentry(sentry);
native War3_Engineer_CheckAmmo(client);
native War3_Engineer_CheckMaxAmmo(client);

stock Float:GetRangeFromWeapon(const String:weapon[])
{
	if (StrEqual(weapon, "weapon_rifle", false) || StrEqual(weapon, "weapon_rifle_ak47", false) || StrEqual(weapon, "weapon_rifle_desert", false) || StrEqual(weapon, "weapon_rifle_sg552", false))
	{
		return 1800.0;
	}
	else if (StrEqual(weapon, "weapon_smg", false) || StrEqual(weapon, "weapon_smg_silenced", false) || StrEqual(weapon, "weapon_smg_mp5", false))
	{
		return 1000.0;
	}	
	else if (StrEqual(weapon, "weapon_pumpshotgun", false) || StrEqual(weapon, "weapon_shotgun_chrome", false))
	{
		return 400.0;
	}
	else if (StrEqual(weapon, "weapon_autoshotgun", false) || StrEqual(weapon, "weapon_shotgun_spas", false))
	{
		return 800.0;
	}
	else if (StrEqual(weapon, "weapon_hunting_rifle", false) || StrEqual(weapon, "weapon_sniper_military", false) || StrEqual(weapon, "weapon_sniper_awp", false) || StrEqual(weapon, "weapon_sniper_scout", false))
	{
		return 50000.0;
	}

	PrintToChatAll("UNKNOWN WEAPON: %s", weapon);
	return 0.0;
}

stock GetDamageFromWeapon(const String:weapon[])
{
	if (StrEqual(weapon, "weapon_rifle", false) || StrEqual(weapon, "weapon_rifle_ak47", false) || StrEqual(weapon, "weapon_rifle_desert", false) || StrEqual(weapon, "weapon_rifle_sg552", false))
	{
		return 50;
	}
	else if (StrEqual(weapon, "weapon_smg", false) || StrEqual(weapon, "weapon_smg_silenced", false) || StrEqual(weapon, "weapon_smg_mp5", false))
	{
		return 33;
	}	
	else if (StrEqual(weapon, "weapon_pumpshotgun", false) || StrEqual(weapon, "weapon_shotgun_chrome", false))
	{
		return 22;
	}
	else if (StrEqual(weapon, "weapon_autoshotgun", false) || StrEqual(weapon, "weapon_shotgun_spas", false))
	{
		return 62;
	}
	else if (StrEqual(weapon, "weapon_hunting_rifle", false) || StrEqual(weapon, "weapon_sniper_military", false) || StrEqual(weapon, "weapon_sniper_awp", false) || StrEqual(weapon, "weapon_sniper_scout", false))
	{
		return 100;
	}

	PrintToChatAll("UNKNOWN WEAPON: %s", weapon);
	return 0;
}

stock Float:GetFiringSpeedFromWeapon(const String:weapon[])
{
	if (StrEqual(weapon, "weapon_rifle", false) || StrEqual(weapon, "weapon_rifle_ak47", false) || StrEqual(weapon, "weapon_rifle_desert", false) || StrEqual(weapon, "weapon_rifle_sg552", false))
	{
		return 0.02;
	}
	else if (StrEqual(weapon, "weapon_smg", false) || StrEqual(weapon, "weapon_smg_silenced", false) || StrEqual(weapon, "weapon_smg_mp5", false))
	{
		return 0.08;
	}	
	else if (StrEqual(weapon, "weapon_pumpshotgun", false) || StrEqual(weapon, "weapon_shotgun_chrome", false))
	{
		return 0.4;
	}
	else if (StrEqual(weapon, "weapon_autoshotgun", false) || StrEqual(weapon, "weapon_shotgun_spas", false))
	{
		return 0.3;
	}
	else if (StrEqual(weapon, "weapon_hunting_rifle", false) || StrEqual(weapon, "weapon_sniper_military", false) || StrEqual(weapon, "weapon_sniper_awp", false) || StrEqual(weapon, "weapon_sniper_scout", false))
	{
		return 0.6;
	}

	PrintToChatAll("UNKNOWN WEAPON: %s", weapon);
	return 0.0;
}

stock Float:GetAccuracyFromWeapon(const String:weapon[])
{
	if (StrEqual(weapon, "weapon_rifle", false) || StrEqual(weapon, "weapon_rifle_ak47", false) || StrEqual(weapon, "weapon_rifle_desert", false) || StrEqual(weapon, "weapon_rifle_sg552", false))
	{
		return 0.2;
	}
	else if (StrEqual(weapon, "weapon_smg", false) || StrEqual(weapon, "weapon_smg_silenced", false) || StrEqual(weapon, "weapon_smg_mp5", false))
	{
		return 0.25;
	}	
	else if (StrEqual(weapon, "weapon_pumpshotgun", false) || StrEqual(weapon, "weapon_shotgun_chrome", false))
	{
		return 0.4;
	}
	else if (StrEqual(weapon, "weapon_autoshotgun", false) || StrEqual(weapon, "weapon_shotgun_spas", false))
	{
		return 0.3;
	}
	else if (StrEqual(weapon, "weapon_hunting_rifle", false) || StrEqual(weapon, "weapon_sniper_military", false) || StrEqual(weapon, "weapon_sniper_awp", false) || StrEqual(weapon, "weapon_sniper_scout", false))
	{
		return 0.0;
	}

	PrintToChatAll("UNKNOWN WEAPON: %s", weapon);
	return 0.0;
}

stock GetAmountOfShotsFromWeapon(const String:weapon[])
{
	if (StrEqual(weapon, "weapon_rifle", false) || StrEqual(weapon, "weapon_rifle_ak47", false) || StrEqual(weapon, "weapon_rifle_desert", false) || StrEqual(weapon, "weapon_rifle_sg552", false))
	{
		return 1;
	}
	else if (StrEqual(weapon, "weapon_smg", false) || StrEqual(weapon, "weapon_smg_silenced", false) || StrEqual(weapon, "weapon_smg_mp5", false))
	{
		return 1;
	}	
	else if (StrEqual(weapon, "weapon_pumpshotgun", false) || StrEqual(weapon, "weapon_shotgun_chrome", false))
	{
		return 2;
	}
	else if (StrEqual(weapon, "weapon_autoshotgun", false) || StrEqual(weapon, "weapon_shotgun_spas", false))
	{
		return 4;
	}
	else if (StrEqual(weapon, "weapon_hunting_rifle", false) || StrEqual(weapon, "weapon_sniper_military", false) || StrEqual(weapon, "weapon_sniper_awp", false) || StrEqual(weapon, "weapon_sniper_scout", false))
	{
		return 1;
	}

	PrintToChatAll("UNKNOWN WEAPON: %s", weapon);
	return 0;
}